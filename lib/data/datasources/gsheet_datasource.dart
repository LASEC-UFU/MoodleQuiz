import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

/// Interface – S: apenas estado compartilhado via Google Apps Script.
/// Questões NÃO são armazenadas aqui – vêm do Moodle.
abstract class IGSheetDatasource {
  /// Retorna todas as configurações do GSheets (moodle_url, quiz_title, etc).
  Future<Map<String, dynamic>> getConfig();

  Future<Map<String, dynamic>> getState();

  Future<Map<String, dynamic>> releaseQuestion({
    required String token,
    required int page,
    required int duration,
    required int totalPages,
    required String quizName,
    required int quizId,
  });

  Future<Map<String, dynamic>> closeQuestion(String token);

  /// Estudante reporta pontuação após receber feedback do Moodle.
  Future<Map<String, dynamic>> submitScore({
    required String token,
    required String studentId,
    required String studentName,
    required int score,
    required bool correct,
    required int page,
  });

  Future<List<Map<String, dynamic>>> getScores();

  Future<Map<String, dynamic>> resetQuiz(String token);

  Future<Map<String, dynamic>> setFinished(String token);
}

/// Implementação concreta via GET ao Apps Script.
class GSheetDatasource implements IGSheetDatasource {
  final http.Client _client;

  GSheetDatasource([http.Client? client]) : _client = client ?? http.Client();

  String get _baseUrl => AppConfig.gsheetScriptUrl;

  @override
  Future<Map<String, dynamic>> getConfig() =>
      _get({'action': 'getConfig'});

  @override
  Future<Map<String, dynamic>> getState() =>
      _get({'action': 'getState'});

  @override
  Future<Map<String, dynamic>> releaseQuestion({
    required String token,
    required int page,
    required int duration,
    required int totalPages,
    required String quizName,
    required int quizId,
  }) =>
      _get({
        'action': 'releaseQuestion',
        'token': token,
        'page': page.toString(),
        'duration': duration.toString(),
        'totalPages': totalPages.toString(),
        'quizName': quizName,
        'quizId': quizId.toString(),
      });

  @override
  Future<Map<String, dynamic>> closeQuestion(String token) =>
      _get({'action': 'closeQuestion', 'token': token});

  @override
  Future<Map<String, dynamic>> submitScore({
    required String token,
    required String studentId,
    required String studentName,
    required int score,
    required bool correct,
    required int page,
  }) =>
      _get({
        'action': 'submitScore',
        'token': token,
        'studentId': studentId,
        'studentName': studentName,
        'score': score.toString(),
        'correct': correct.toString(),
        'page': page.toString(),
      });

  @override
  Future<List<Map<String, dynamic>>> getScores() async {
    final res = await _get({'action': 'getScores'});
    return _asList(res['scores']);
  }

  @override
  Future<Map<String, dynamic>> resetQuiz(String token) =>
      _get({'action': 'resetQuiz', 'token': token});

  @override
  Future<Map<String, dynamic>> setFinished(String token) =>
      _get({'action': 'setFinished', 'token': token});

  // ── Privado ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(Map<String, String> params) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw GSheetException('Erro HTTP ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body);
    if (data is Map<String, dynamic> && data['error'] != null) {
      throw GSheetException(data['error'].toString());
    }
    return data as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

class GSheetException implements Exception {
  final String message;
  GSheetException(this.message);
  @override
  String toString() => message;
}
