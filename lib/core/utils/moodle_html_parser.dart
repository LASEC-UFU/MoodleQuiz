/// Extrai dados estruturados de um bloco HTML de questão do Moodle.
/// Implementado em Dart puro (compatível com WASM – sem dart:html).
library;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

// ── Entidades de saída ────────────────────────────────────────────────────────

class ParsedChoice {
  final String value; // "0", "1", "2"…
  final String text; // texto exibido para o aluno
  final String
      htmlText; // alternativa como HTML rico (preserva imagens/tabelas)
  final bool isCorrect; // true se esta alternativa é a resposta correta

  const ParsedChoice({
    required this.value,
    required this.text,
    this.htmlText = '',
    this.isCorrect = false,
  });
}

class ParsedQuestion {
  final int slot;
  final String text; // texto da questão (HTML stripped — fallback)
  final String
      htmlText; // enunciado como HTML com URLs corrigidas (para renderização rica)
  final List<ParsedChoice> choices;
  final List<String> imageUrls;
  final String inputBaseName; // "q{attemptId}:{slot}_answer"
  final String seqCheck; // valor do input sequencecheck
  final String type; // "multichoice" | "truefalse" | "other"

  const ParsedQuestion({
    required this.slot,
    required this.text,
    required this.htmlText,
    required this.choices,
    required this.imageUrls,
    required this.inputBaseName,
    required this.seqCheck,
    required this.type,
  });

  bool get isMultiChoice => type == 'multichoice' || type == 'truefalse';
}

// ── Parser ────────────────────────────────────────────────────────────────────

class MoodleHtmlParser {
  /// Analisa o HTML de `mod_quiz_get_attempt_data.questions[].html`.
  static ParsedQuestion parse({
    required String html,
    required int attemptId,
    required int slot,
    required String token,
    required String baseUrl,
  }) {
    final text = _extractText(html);
    final htmlText = _extractHtmlText(html, token, baseUrl);
    final choices = _extractChoices(html, token, baseUrl);
    final images = _extractImages(html, token, baseUrl);
    final seqCheck = _extractSeqCheck(html);

    // Extrai o nome real dos inputs do HTML em vez de hardcodar.
    // O Moodle usa o question_usage.id (uniqueid), que pode diferir do attemptId.
    final extractedBase = _extractInputBaseName(html);
    final hardcoded = 'q$attemptId:${slot}_answer';
    final inputBase = extractedBase ?? hardcoded;

    final type = choices.length == 2
        ? 'truefalse'
        : (choices.isEmpty ? 'other' : 'multichoice');

    return ParsedQuestion(
      slot: slot,
      text: text,
      htmlText: htmlText,
      choices: choices,
      imageUrls: images,
      inputBaseName: inputBase,
      seqCheck: seqCheck,
      type: type,
    );
  }

  /// Extrai os values dos inputs de rádio cuja resposta é correta.
  ///
  /// Moodle 4.x: o gabarito aparece como:
  ///   `<div class="rightanswer">A resposta correta é: TEXTO</div>`
  /// Extrai o TEXTO e acha o radio cujo label bate com esse texto.
  ///
  /// Fallback legacy: containers `<li|div class="... correct ...">` com `<input type="radio">`.
  static List<String> parseCorrectValues(String reviewHtml) {
    // ── Método primário: aria-labelledby + rightanswer ────────────────────────
    // 1. Constrói mapa labelId → value a partir dos radios
    final attrRe = RegExp(r'([\w-]+)="([^"]*)"', caseSensitive: false);
    final radioRe =
        RegExp(r'<input\b[^>]*type="radio"[^>]*/?>', caseSensitive: false);

    // mapa: labelDivId → value
    final idToValue = <String, String>{};
    for (final m in radioRe.allMatches(reviewHtml)) {
      final tag = m.group(0) ?? '';
      String value = '', ariaLabelledBy = '';
      for (final a in attrRe.allMatches(tag)) {
        final k = a.group(1)!.toLowerCase();
        if (k == 'value') value = a.group(2)!;
        if (k == 'aria-labelledby') ariaLabelledBy = a.group(2)!;
      }
      if (value.isNotEmpty && value != '-1' && ariaLabelledBy.isNotEmpty) {
        idToValue[ariaLabelledBy] = value;
      }
    }

    // 2. Constrói mapa labelDivId → texto limpo
    final labelDivRe = RegExp(
      r'<div\b[^>]+id="([^"]+)"[^>]*data-region="answer-label"[^>]*>(.*?)</div>\s*</div>',
      caseSensitive: false,
      dotAll: true,
    );
    final idToText = <String, String>{};
    for (final m in labelDivRe.allMatches(reviewHtml)) {
      final id = m.group(1) ?? '';
      final content = m.group(2) ?? '';
      final cleaned = content.replaceAll(
          RegExp(r'<span[^>]*class="[^"]*answernumber[^"]*"[^>]*>.*?</span>',
              caseSensitive: false, dotAll: true),
          '');
      final text = _stripHtml(cleaned).trim();
      if (id.isNotEmpty && text.isNotEmpty) idToText[id] = text;
    }

    // 3. Extrai o texto correto do div.rightanswer
    final rightAnswerRe = RegExp(
      r'<div[^>]*class="[^"]*rightanswer[^"]*"[^>]*>(.*?)</div>',
      caseSensitive: false,
      dotAll: true,
    );
    final rightMatch = rightAnswerRe.firstMatch(reviewHtml);
    if (rightMatch != null) {
      // Texto pode ser "A resposta correta é: TEXTO" — pega só o TEXTO
      String correctText = _stripHtml(rightMatch.group(1) ?? '').trim();
      final sepIdx = correctText.indexOf(':');
      if (sepIdx >= 0 && sepIdx < correctText.length - 1) {
        correctText = correctText.substring(sepIdx + 1).trim();
      }

      if (correctText.isNotEmpty) {
        // Compara com os textos dos labels
        for (final entry in idToText.entries) {
          if (entry.value == correctText ||
              entry.value.contains(correctText) ||
              correctText.contains(entry.value)) {
            final value = idToValue[entry.key];
            if (value != null) return [value];
          }
        }
      }
    }

    // ── Fallback legacy: containers com classe "correct" ──────────────────────
    final correctValues = <String>[];
    final containerRe = RegExp(
      r'<(?:li|div)\b[^>]*class="([^"]*)"[^>]*>(.*?)</(?:li|div)>',
      caseSensitive: false,
      dotAll: true,
    );
    final radioValueRe = RegExp(
      r'<input\b[^>]*type="radio"[^>]*value="([^"]*)"',
      caseSensitive: false,
    );
    for (final m in containerRe.allMatches(reviewHtml)) {
      final classAttr = m.group(1) ?? '';
      if (classAttr.contains('correct') && !classAttr.contains('incorrect')) {
        final radioMatch = radioValueRe.firstMatch(m.group(2) ?? '');
        if (radioMatch != null) {
          final value = radioMatch.group(1) ?? '';
          if (value.isNotEmpty && value != '-1') correctValues.add(value);
        }
      }
    }
    return correctValues;
  }

  /// Extrai o feedback geral da questão do HTML de revisão.
  /// Moodle coloca em `<div class="generalfeedback">...</div>`.
  static String parseGeneralFeedback(String reviewHtml) {
    final content = _extractTag(reviewHtml, 'generalfeedback') ?? '';
    return content.trim();
  }

  // ── Extração do HTML do enunciado (com URLs corrigidas, sem forms) ──────────

  /// Retorna o HTML do enunciado com URLs de imagens corrigidas.
  /// Remove blocos de resposta (inputs, botões) mas preserva formatação.
  static String _extractHtmlText(String html, String token, String baseUrl) {
    String content =
        _extractTag(html, 'qtext') ?? _extractTag(html, 'formulation') ?? '';
    if (content.isEmpty) content = html;
    content = _removeBlock(content, r'class="(?:ablock|answer)');
    // Corrige URLs de imagens inline
    content = _rewriteResourceUrls(content, token, baseUrl);
    return content;
  }

  // ── Extração do texto da questão ──────────────────────────────────────────

  static String _extractText(String html) {
    String text =
        _extractTag(html, 'qtext') ?? _extractTag(html, 'formulation') ?? '';

    if (text.isEmpty) {
      text = html;
    }

    text = _removeBlock(text, r'class="(?:ablock|answer)');

    return _stripHtml(text).trim();
  }

  // ── Extração de alternativas ──────────────────────────────────────────────

  static List<ParsedChoice> _extractChoices(
      String html, String token, String baseUrl) {
    final choices = <ParsedChoice>[];
    final fragment = html_parser.parseFragment(html);

    // Moodle 4.x: <input aria-labelledby="ID"> + <div id="ID">texto</div>
    // Constrói mapa id → conteúdo a partir de todos os divs com data-region="answer-label".
    final ariaLabelMap = <String, _ChoiceContent>{};
    for (final element
        in fragment.querySelectorAll('[data-region="answer-label"]')) {
      final id = element.id;
      if (id.isEmpty) continue;
      final content = _choiceContentFromElement(element, token, baseUrl);
      if (content.hasContent) ariaLabelMap[id] = content;
    }

    // Fallback: <label for="ID">texto</label>
    final forLabelMap = <String, _ChoiceContent>{};
    for (final element in fragment.querySelectorAll('label[for]')) {
      final forAttr = element.attributes['for'] ?? '';
      if (forAttr.isEmpty) continue;
      final content = _choiceContentFromElement(element, token, baseUrl);
      if (content.hasContent) forLabelMap[forAttr] = content;
    }

    // Itera sobre os <input type="radio">
    for (final input in fragment.querySelectorAll('input')) {
      final type = input.attributes['type']?.toLowerCase() ?? '';
      if (type != 'radio') continue;

      final value = input.attributes['value'] ?? '';
      if (value.isEmpty || value == '-1') continue;

      // Prioridade: aria-labelledby → label for → fallback
      final id = input.id;
      final ariaLabelledBy = input.attributes['aria-labelledby'] ?? '';
      final content = ariaLabelMap[ariaLabelledBy] ??
          (id.isNotEmpty ? forLabelMap[id] : null) ??
          const _ChoiceContent(text: '', html: '');

      choices.add(ParsedChoice(
        value: value,
        text: content.text,
        htmlText: content.html,
      ));
    }

    return choices;
  }

  // ── Extração de imagens ───────────────────────────────────────────────────

  static List<String> _extractImages(
      String html, String token, String baseUrl) {
    final images = <String>[];
    final imgRe = RegExp(
      r'''<img[^>]+src=(["'])(.*?)\1''',
      caseSensitive: false,
    );

    for (final m in imgRe.allMatches(html)) {
      var src = m.group(2) ?? '';
      if (src.isEmpty) continue;

      images.add(_normalizeResourceUrl(src, token, baseUrl));
    }

    return images;
  }

  static _ChoiceContent _choiceContentFromElement(
      dom.Element element, String token, String baseUrl) {
    for (final span in element.querySelectorAll('.answernumber')) {
      span.remove();
    }

    final cleanedHtml = _rewriteResourceUrls(element.innerHtml, token, baseUrl);
    final text = _stripHtml(cleanedHtml).trim();
    return _ChoiceContent(text: text, html: cleanedHtml.trim());
  }

  static String _rewriteResourceUrls(
      String html, String token, String baseUrl) {
    return html.replaceAllMapped(
      RegExp("\\b(src|href)=([\"'])(.*?)\\2", caseSensitive: false),
      (m) {
        final attr = m.group(1) ?? 'src';
        final quote = m.group(2) ?? '"';
        final url = _normalizeResourceUrl(m.group(3) ?? '', token, baseUrl);
        return '$attr=$quote$url$quote';
      },
    );
  }

  static String _normalizeResourceUrl(
      String url, String token, String baseUrl) {
    var src = url.trim();
    if (src.isEmpty ||
        src.startsWith('data:') ||
        src.startsWith('blob:') ||
        src.startsWith('mailto:') ||
        src.startsWith('#')) {
      return src;
    }

    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    if (src.startsWith('@@PLUGINFILE@@')) {
      src =
          src.replaceFirst('@@PLUGINFILE@@', '$root/webservice/pluginfile.php');
    } else if (src.startsWith('/') && !src.startsWith('//')) {
      src = '$root$src';
    } else if (!RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false)
        .hasMatch(src)) {
      src = '$root/$src';
    }

    if (src.contains('pluginfile.php') &&
        !RegExp(r'([?&])token=').hasMatch(src)) {
      final sep = src.contains('?') ? '&' : '?';
      src = '$src${sep}token=$token';
    }

    return src;
  }

  // ── Extração do sequencecheck ─────────────────────────────────────────────

  static String _extractSeqCheck(String html) {
    // Passo 1: encontra o <input> inteiro que contenha :sequencecheck no name
    // (independente da ordem dos atributos)
    final inputRe = RegExp(
      r'<input\b[^>]*name="[^"]*:sequencecheck"[^>]*/?>',
      caseSensitive: false,
    );
    final inputTag = inputRe.firstMatch(html)?.group(0) ?? '';
    if (inputTag.isEmpty) return '1';

    // Passo 2: extrai value= de dentro desse elemento
    final valueRe = RegExp(r'\bvalue="([^"]*)"', caseSensitive: false);
    return valueRe.firstMatch(inputTag)?.group(1) ?? '1';
  }

  // ── Extração do inputBaseName real ─────────────────────────────────────────

  /// Extrai o name real dos inputs do HTML do Moodle.
  /// O Moodle usa `q{usageId}:{slot}_answer` nos radio buttons.
  /// O usageId (uniqueid) pode ser diferente do attemptId.
  static String? _extractInputBaseName(String html) {
    final attrRe = RegExp(r'([\w-]+)="([^"]*)"', caseSensitive: false);

    // 1) Tenta extrair o name de um <input type="radio">
    final radioRe =
        RegExp(r'<input\b[^>]*type="radio"[^>]*/?>', caseSensitive: false);
    for (final m in radioRe.allMatches(html)) {
      final inputTag = m.group(0)!;
      for (final a in attrRe.allMatches(inputTag)) {
        final key = a.group(1)!.toLowerCase();
        final val = a.group(2)!;
        if (key == 'name' && val.isNotEmpty) return val;
      }
    }

    // 2) Fallback: deduz do input :sequencecheck
    //    ex: name="q12345:1_:sequencecheck" → "q12345:1_answer"
    final allInputsRe = RegExp(r'<input\b[^>]*/?>', caseSensitive: false);
    for (final m in allInputsRe.allMatches(html)) {
      final inputTag = m.group(0)!;
      if (!inputTag.contains(':sequencecheck')) continue;
      for (final a in attrRe.allMatches(inputTag)) {
        final key = a.group(1)!.toLowerCase();
        final val = a.group(2)!;
        if (key == 'name' && val.contains(':sequencecheck')) {
          return val.replaceFirst(':sequencecheck', 'answer');
        }
      }
    }

    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extrai conteúdo de `<div class="...{className}...">...</div>`
  static String? _extractTag(String html, String className) {
    final re = RegExp(
      'class="[^"]*$className[^"]*"',
      caseSensitive: false,
    );
    final start = re.firstMatch(html)?.start;
    if (start == null) return null;

    int tagStart = html.lastIndexOf('<', start);
    if (tagStart < 0) return null;

    int depth = 1;
    int i = html.indexOf('>', tagStart) + 1;
    while (i < html.length && depth > 0) {
      final openDiv = html.indexOf('<div', i);
      final closeDiv = html.indexOf('</div', i);
      if (closeDiv < 0) break;
      if (openDiv >= 0 && openDiv < closeDiv) {
        depth++;
        i = openDiv + 4;
      } else {
        depth--;
        if (depth == 0) return html.substring(tagStart, closeDiv);
        i = closeDiv + 5;
      }
    }
    return null;
  }

  /// Remove um bloco HTML que contém a classe/atributo indicado.
  static String _removeBlock(String html, String pattern) {
    final re = RegExp(pattern, caseSensitive: false);
    final match = re.firstMatch(html);
    if (match == null) return html;

    int tagStart = html.lastIndexOf('<', match.start);
    if (tagStart < 0) return html;

    int depth = 1;
    int i = html.indexOf('>', tagStart) + 1;
    while (i < html.length && depth > 0) {
      final open = html.indexOf('<div', i);
      final close = html.indexOf('</div', i);
      if (close < 0) break;
      if (open >= 0 && open < close) {
        depth++;
        i = open + 4;
      } else {
        depth--;
        if (depth == 0) {
          final end = html.indexOf('>', close) + 1;
          return html.substring(0, tagStart) + html.substring(end);
        }
        i = close + 5;
      }
    }
    return html;
  }

  /// Remove todas as tags HTML e decodifica entidades básicas.
  static String _stripHtml(String html) {
    return html
        .replaceAll(
            RegExp(r'<br\s*/?>|</p>|</li>|</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

class _ChoiceContent {
  final String text;
  final String html;

  const _ChoiceContent({required this.text, required this.html});

  bool get hasContent => text.isNotEmpty || html.isNotEmpty;
}
