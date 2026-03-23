import 'dart:convert';
import 'package:http/http.dart' as http;

import 'moodle_datasource.dart';

/// Interface – estado compartilhado do quiz via Moodle mod_data.
abstract class IStateDatasource {
  /// Lê o estado atual do quiz (qualquer token válido serve).
  Future<Map<String, dynamic>> getState(
      String baseUrl, String token, int courseId);

  /// Professor libera uma questão (timer + página).
  Future<void> releaseQuestion({
    required String baseUrl,
    required String token,
    required int courseId,
    required int page,
    required int duration,
    required int totalPages,
    required String quizName,
    required int quizId,
  });

  /// Professor encerra a questão ativa.
  Future<void> closeQuestion(String baseUrl, String token, int courseId);

  /// Professor marca o quiz como finalizado.
  Future<void> setFinished(String baseUrl, String token, int courseId);

  /// Estudante registra pontuação com bônus de tempo.
  Future<void> submitScore({
    required String baseUrl,
    required String token,
    required int courseId,
    required String studentId,
    required String studentName,
    required int score,
    required bool correct,
    required int page,
  });

  /// Retorna todas as pontuações dos estudantes.
  Future<List<Map<String, dynamic>>> getScores(
      String baseUrl, String token, int courseId);

  /// Professor reseta o quiz (apaga scores, volta a 'waiting').
  Future<void> resetQuiz(String baseUrl, String token, int courseId);
}

/// Implementação via Moodle mod_data (atividade "Database" chamada **mq_state**).
///
/// O banco usa UMA ÚNICA atividade Database com as seguintes entradas:
///
/// **Entrada de estado** (type = "state"):
///   - state_json: JSON com {state, current_page, total_pages, quiz_id, quiz_name, ends_at}
///
/// **Entradas de pontuação** (type = "score"), UMA por aluno:
///   - student_id, student_name, score, correct_count, pages (JSON array)
///
/// O dataid é descoberto automaticamente buscando a Database chamada "mq_state" no curso.
class MoodleStateDatasource implements IStateDatasource {
  final http.Client _client;
  final IMoodleDatasource _moodle;

  // Cache de dataid por curso — reduz chamadas repetidas de discovery
  final Map<int, int> _dataidByCourse = {};
  int? _currentCourseId;
  int? _dataid;

  int? _typeFieldId;
  int? _stateJsonFieldId;
  int? _studentIdFieldId;
  int? _studentNameFieldId;
  int? _scoreFieldId;
  int? _correctCountFieldId;
  int? _pagesFieldId;

  int? _stateEntryId; // ID da entrada type=state

  static const Map<String, dynamic> _emptyState = {
    'state': 'waiting',
    'current_page': -1,
    'total_pages': 0,
    'quiz_id': 0,
    'course_id': 0,
    'quiz_name': '',
    'ends_at': '',
  };

  MoodleStateDatasource(this._moodle, [http.Client? client])
      : _client = client ?? http.Client();

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Log para debug de problemas com tipos dinâmicos do Moodle
  void _logDebug(String label, dynamic value) {
    print('🔍 [$label] Type: ${value.runtimeType}, Value: $value');
  }

  /// Extrai string de forma segura de valores do Moodle que podem ser Map, String, etc.
  String _safeString(dynamic value, [String context = '']) {
    if (context.isNotEmpty) {
      _logDebug('_safeString($context)', value);
    }

    if (value == null) return '';
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is Map) {
      // Alguns campos do Moodle retornam {value: "texto"}
      _logDebug('_safeString($context) - Map keys', value.keys.toList());
      return _safeString(value['value'] ?? value['text'] ?? '', context);
    }

    _logDebug('_safeString($context) - FALLBACK to empty', value);
    return '';
  }

  // ── Discovery ──────────────────────────────────────────────────────────────

  /// Busca o dataid da Database "mq_state" no curso. Cacheia o resultado.
  Future<void> _ensureDataId(String baseUrl, String token, int courseId) async {
    print('🔍 _ensureDataId: courseId=$courseId');

    // Se já está em cache para este curso, usa
    if (_dataidByCourse.containsKey(courseId)) {
      _dataid = _dataidByCourse[courseId];
      _currentCourseId = courseId;
      print('✅ _ensureDataId: usando cache, dataid=$_dataid');
      return;
    }

    // Busca Database activities do curso
    print('🔍 _ensureDataId: buscando Database activities...');
    final databases =
        await _moodle.getDataActivitiesByCourse(baseUrl, token, courseId);

    print('🔍 _ensureDataId: encontradas ${databases.length} databases');

    // Procura pela atividade chamada "mq_state"
    for (int i = 0; i < databases.length; i++) {
      final db = databases[i];
      print('🔍 _ensureDataId: database[$i] = $db');

      final name = _safeString(db['name'], 'database[$i].name');
      print('🔍 _ensureDataId: database[$i] name após parse = "$name"');

      if (name.toLowerCase() == 'mq_state') {
        final id = (db['id'] as num?)?.toInt();
        print('✅ _ensureDataId: encontrou mq_state! id=$id');
        if (id != null && id > 0) {
          _dataid = id;
          _dataidByCourse[courseId] = id;
          _currentCourseId = courseId;
          return;
        }
      }
    }

    throw StateException(
        'Atividade Database "mq_state" não encontrada no curso.\n'
        'Crie uma atividade Database com nome exatamente "mq_state" (minúsculas) '
        'e configure os 7 campos conforme documentação.');
  }

  Future<void> _ensureFields(String baseUrl, String token, int courseId) async {
    print('🔍 _ensureFields: courseId=$courseId');

    // Se mudou de curso, limpa cache de fields
    if (_currentCourseId != courseId) {
      _typeFieldId = null;
      _stateJsonFieldId = null;
      _studentIdFieldId = null;
      _studentNameFieldId = null;
      _scoreFieldId = null;
      _correctCountFieldId = null;
      _pagesFieldId = null;
      _stateEntryId = null;
      print('🔍 _ensureFields: limpou cache de fields (curso mudou)');
    }

    if (_typeFieldId != null) {
      print('✅ _ensureFields: usando cache de fields');
      return;
    }

    await _ensureDataId(baseUrl, token, courseId);

    print('🔍 _ensureFields: buscando fields do dataid=$_dataid');
    final result = await _callWs(
      baseUrl,
      token,
      'mod_data_get_fields',
      {'databaseid': _dataid!.toString()},
    );

    final fields = result['fields'] as List? ?? [];
    print('🔍 _ensureFields: encontrados ${fields.length} fields');

    for (int i = 0; i < fields.length; i++) {
      final f = fields[i];
      print('🔍 _ensureFields: field[$i] = $f');

      final name = _safeString(f['name'], 'field[$i].name');
      print('🔍 _ensureFields: field[$i] name após parse = "$name"');

      final id = (f['id'] as num).toInt();
      print('🔍 _ensureFields: field[$i] id = $id');

      switch (name) {
        case 'type':
          _typeFieldId = id;
          break;
        case 'state_json':
          _stateJsonFieldId = id;
          break;
        case 'student_id':
          _studentIdFieldId = id;
          break;
        case 'student_name':
          _studentNameFieldId = id;
          break;
        case 'score':
          _scoreFieldId = id;
          break;
        case 'correct_count':
          _correctCountFieldId = id;
          break;
        case 'pages':
          _pagesFieldId = id;
          break;
      }
    }

    final missing = <String>[];
    if (_typeFieldId == null) missing.add('type');
    if (_stateJsonFieldId == null) missing.add('state_json');
    if (_studentIdFieldId == null) missing.add('student_id');
    if (_studentNameFieldId == null) missing.add('student_name');
    if (_scoreFieldId == null) missing.add('score');
    if (_correctCountFieldId == null) missing.add('correct_count');
    if (_pagesFieldId == null) missing.add('pages');

    if (missing.isNotEmpty) {
      throw StateException(
          'Campos ausentes em mq_state: ${missing.join(', ')}.\n'
          'Consulte as instruções de configuração do Moodle.');
    }
  }

  /// Busca todas as entradas do banco e devolve como lista de mapas internos.
  Future<List<Map<String, dynamic>>> _fetchAllEntries(
      String baseUrl, String token) async {
    print('🔍 _fetchAllEntries: dataid=$_dataid');

    final result = await _callWs(
      baseUrl,
      token,
      'mod_data_get_entries',
      {
        'databaseid': _dataid!.toString(),
        'perpage': '200',
        'page': '0',
        'returncontents': '1',
      },
    );

    final entries = result['entries'] as List? ?? [];
    print('🔍 _fetchAllEntries: encontradas ${entries.length} entries');

    return entries.map((entry) {
      final entryId = (entry['id'] as num?)?.toInt() ?? 0;
      print('🔍 _fetchAllEntries: processando entry id=$entryId');

      final contents = entry['contents'] as List? ?? [];
      print(
          '🔍 _fetchAllEntries: entry $entryId tem ${contents.length} contents');

      final map = <String, dynamic>{
        '_entry_id': entryId,
      };

      for (int i = 0; i < contents.length; i++) {
        final c = contents[i];
        print('🔍 _fetchAllEntries: entry $entryId content[$i] = $c');

        final fid = (c['fieldid'] as num?)?.toInt();
        print('🔍 _fetchAllEntries: entry $entryId content[$i] fieldid=$fid');

        final val = _safeString(c['content'], 'entry[$entryId].content[$i]');
        print(
            '🔍 _fetchAllEntries: entry $entryId content[$i] value após parse = "$val"');

        if (fid == _typeFieldId) {
          map['type'] = val;
        }
        if (fid == _stateJsonFieldId) {
          map['state_json'] = val;
        }
        if (fid == _studentIdFieldId) {
          map['student_id'] = val;
        }
        if (fid == _studentNameFieldId) {
          map['student_name'] = val;
        }
        if (fid == _scoreFieldId) {
          map['score'] = int.tryParse(val) ?? 0;
        }
        if (fid == _correctCountFieldId) {
          map['correct_count'] = int.tryParse(val) ?? 0;
        }
        if (fid == _pagesFieldId) {
          map['pages'] = val;
        }
      }

      print('🔍 _fetchAllEntries: entry $entryId mapeado = $map');
      return map;
    }).toList();
  }

  // ── Estado ─────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getState(
      String baseUrl, String token, int courseId) async {
    await _ensureFields(baseUrl, token, courseId);
    final entries = await _fetchAllEntries(baseUrl, token);
    final stateEntry = entries.firstWhere(
      (e) => e['type'] == 'state',
      orElse: () => {},
    );
    if (stateEntry.isEmpty) return Map.from(_emptyState);
    _stateEntryId = stateEntry['_entry_id'] as int?;
    final raw = stateEntry['state_json'] as String? ?? '';
    if (raw.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    return Map.from(_emptyState);
  }

  Future<void> _writeState(
      String baseUrl, String token, Map<String, dynamic> state) async {
    final jsonStr = jsonEncode(state);
    final data = {
      'data[0][fieldid]': _typeFieldId!.toString(),
      'data[0][value]': 'state',
      'data[1][fieldid]': _stateJsonFieldId!.toString(),
      'data[1][value]': jsonStr,
      // campos de score ficam vazios na entrada de estado — Moodle aceita
      'data[2][fieldid]': _studentIdFieldId!.toString(),
      'data[2][value]': '',
      'data[3][fieldid]': _studentNameFieldId!.toString(),
      'data[3][value]': '',
      'data[4][fieldid]': _scoreFieldId!.toString(),
      'data[4][value]': '0',
      'data[5][fieldid]': _correctCountFieldId!.toString(),
      'data[5][value]': '0',
      'data[6][fieldid]': _pagesFieldId!.toString(),
      'data[6][value]': '[]',
    };

    if (_stateEntryId == null) {
      final res = await _callWs(baseUrl, token, 'mod_data_add_entry', {
        'databaseid': _dataid!.toString(),
        ...data,
      });
      _stateEntryId = (res['newentryid'] as num?)?.toInt();
    } else {
      await _callWs(baseUrl, token, 'mod_data_update_entry', {
        'entryid': _stateEntryId!.toString(),
        ...data,
      });
    }
  }

  @override
  Future<void> releaseQuestion({
    required String baseUrl,
    required String token,
    required int courseId,
    required int page,
    required int duration,
    required int totalPages,
    required String quizName,
    required int quizId,
  }) async {
    await _ensureFields(baseUrl, token, courseId);
    // Garante que temos o stateEntryId se já existe
    if (_stateEntryId == null) {
      await getState(baseUrl, token, courseId);
    }
    final endsAt = DateTime.now()
        .add(Duration(seconds: duration))
        .toUtc()
        .toIso8601String();
    await _writeState(baseUrl, token, {
      'state': 'active',
      'current_page': page,
      'total_pages': totalPages,
      'quiz_id': quizId,
      'course_id': courseId,
      'quiz_name': quizName,
      'ends_at': endsAt,
    });
  }

  @override
  Future<void> closeQuestion(String baseUrl, String token, int courseId) async {
    await _ensureFields(baseUrl, token, courseId);
    final current = await getState(baseUrl, token, courseId);
    await _writeState(baseUrl, token, {...current, 'state': 'closed'});
  }

  @override
  Future<void> setFinished(String baseUrl, String token, int courseId) async {
    await _ensureFields(baseUrl, token, courseId);
    final current = await getState(baseUrl, token, courseId);
    await _writeState(baseUrl, token, {...current, 'state': 'finished'});
  }

  // ── Pontuação ──────────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getScores(
      String baseUrl, String token, int courseId) async {
    await _ensureFields(baseUrl, token, courseId);
    final entries = await _fetchAllEntries(baseUrl, token);
    return entries
        .where((e) => e['type'] == 'score')
        .map((e) => {
              'student_id': e['student_id'] ?? '',
              'student_name': e['student_name'] ?? '',
              'score': e['score'] ?? 0,
              'correct_count': e['correct_count'] ?? 0,
            })
        .toList();
  }

  @override
  Future<void> submitScore({
    required String baseUrl,
    required String token,
    required int courseId,
    required String studentId,
    required String studentName,
    required int score,
    required bool correct,
    required int page,
  }) async {
    await _ensureFields(baseUrl, token, courseId);

    // Busca entrada existente do aluno
    final entries = await _fetchAllEntries(baseUrl, token);
    final existing = entries.firstWhere(
      (e) => e['type'] == 'score' && e['student_id'] == studentId,
      orElse: () => {},
    );

    if (existing.isEmpty) {
      // Primeira resposta deste aluno
      await _callWs(baseUrl, token, 'mod_data_add_entry', {
        'databaseid': _dataid!.toString(),
        'data[0][fieldid]': _typeFieldId!.toString(),
        'data[0][value]': 'score',
        'data[1][fieldid]': _stateJsonFieldId!.toString(),
        'data[1][value]': '',
        'data[2][fieldid]': _studentIdFieldId!.toString(),
        'data[2][value]': studentId,
        'data[3][fieldid]': _studentNameFieldId!.toString(),
        'data[3][value]': studentName,
        'data[4][fieldid]': _scoreFieldId!.toString(),
        'data[4][value]': score.toString(),
        'data[5][fieldid]': _correctCountFieldId!.toString(),
        'data[5][value]': correct ? '1' : '0',
        'data[6][fieldid]': _pagesFieldId!.toString(),
        'data[6][value]': jsonEncode([page]),
      });
    } else {
      // Acumula — ignora se a página já foi submetida
      List<int> prevPages = [];
      try {
        prevPages = (jsonDecode(existing['pages'] as String? ?? '[]') as List)
            .map((e) => (e as num).toInt())
            .toList();
      } catch (_) {}
      if (prevPages.contains(page)) return;

      final entryId = existing['_entry_id'] as int;
      final newScore = (existing['score'] as int) + score;
      final newCorrect = (existing['correct_count'] as int) + (correct ? 1 : 0);
      final newPages = [...prevPages, page];

      await _callWs(baseUrl, token, 'mod_data_update_entry', {
        'entryid': entryId.toString(),
        'data[0][fieldid]': _typeFieldId!.toString(),
        'data[0][value]': 'score',
        'data[1][fieldid]': _stateJsonFieldId!.toString(),
        'data[1][value]': '',
        'data[2][fieldid]': _studentIdFieldId!.toString(),
        'data[2][value]': studentId,
        'data[3][fieldid]': _studentNameFieldId!.toString(),
        'data[3][value]': studentName,
        'data[4][fieldid]': _scoreFieldId!.toString(),
        'data[4][value]': newScore.toString(),
        'data[5][fieldid]': _correctCountFieldId!.toString(),
        'data[5][value]': newCorrect.toString(),
        'data[6][fieldid]': _pagesFieldId!.toString(),
        'data[6][value]': jsonEncode(newPages),
      });
    }
  }

  @override
  Future<void> resetQuiz(String baseUrl, String token, int courseId) async {
    await _ensureFields(baseUrl, token, courseId);
    final entries = await _fetchAllEntries(baseUrl, token);

    // Apaga todas as entradas de score
    for (final e in entries.where((e) => e['type'] == 'score')) {
      final entryId = e['_entry_id'] as int? ?? 0;
      if (entryId > 0) {
        try {
          await _callWs(baseUrl, token, 'mod_data_delete_entry',
              {'entryid': entryId.toString()});
        } catch (_) {}
      }
    }

    // Reseta estado para waiting
    await _writeState(baseUrl, token, Map.from(_emptyState));
  }

  // ── HTTP helper ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _callWs(
    String baseUrl,
    String token,
    String function,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse('$baseUrl/webservice/rest/server.php').replace(
      queryParameters: {
        'wstoken': token,
        'wsfunction': function,
        'moodlewsrestformat': 'json',
        ...params,
      },
    );
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw StateException('Erro HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body);
    if (data is Map && data['exception'] != null) {
      throw StateException(
        data['message']?.toString() ?? 'Erro desconhecido no Moodle',
        code: data['errorcode']?.toString(),
      );
    }
    if (data is Map<String, dynamic>) return data;
    return {'result': data};
  }
}

class StateException implements Exception {
  final String message;
  final String? code;
  StateException(this.message, {this.code});
  @override
  String toString() => message;
}
