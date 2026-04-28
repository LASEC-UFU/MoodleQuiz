import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../domain/entities/question_entity.dart';
import '../../controllers/professor_controller.dart';

/// Tela de revisão da questão para o professor apresentar aos alunos.
/// Mostra o enunciado completo (HTML rico) e as alternativas com a
/// resposta correta destacada em verde.
class ProfessorRevealPage extends StatelessWidget {
  const ProfessorRevealPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfessorController>(
      builder: (context, prof, _) {
        final state = prof.quizState;

        // Encontra a questão que estava ativa pelo slot (identificador único Moodle)
        final QuestionEntity? question = prof.questions.isEmpty
            ? null
            : prof.questions.cast<QuestionEntity?>().firstWhere(
                  (q) => q!.slot == state.currentSlot,
                  orElse: () => prof.questions.first,
                );

        return _RevealScaffold(
          state: state,
          question: question,
        );
      },
    );
  }
}

class _RevealScaffold extends StatefulWidget {
  final dynamic state;
  final QuestionEntity? question;
  const _RevealScaffold({required this.state, required this.question});

  @override
  State<_RevealScaffold> createState() => _RevealScaffoldState();
}

class _RevealScaffoldState extends State<_RevealScaffold> {
  bool _showFeedback = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final question = widget.question;
    final hasFeedback = question != null && question.generalFeedback.isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.textSecondary, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.currentPage >= 0
                            ? 'Gabarito — Questão ${state.currentPage + 1}'
                                '${state.totalPages > 0 ? ' de ${state.totalPages}' : ''}'
                            : 'Gabarito',
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17),
                      ),
                    ),
                    if (hasFeedback)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showFeedback = !_showFeedback),
                        icon: Icon(
                          _showFeedback
                              ? Icons.list_alt_rounded
                              : Icons.feedback_outlined,
                          size: 16,
                        ),
                        label: Text(
                          _showFeedback
                              ? 'Ver alternativas'
                              : 'Ver feedback geral',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          backgroundColor: AppTheme.bgCardAlt,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Conteúdo ─────────────────────────────────────────
              Expanded(
                child: question == null
                    ? const Center(
                        child: Text('Nenhuma questão disponível.',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : _QuestionReveal(
                        question: question,
                        showFeedback: _showFeedback,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionReveal extends StatelessWidget {
  final QuestionEntity question;
  final bool showFeedback;
  const _QuestionReveal({required this.question, required this.showFeedback});

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      padding:
          Responsive.horizontalPadding(context).copyWith(top: 8, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Enunciado ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(glowing: false),
                child: question.htmlText.isNotEmpty
                    ? _MoodleHtml(
                        html: question.htmlText,
                        textStyle: TextStyle(
                          fontSize: isMobile ? 16 : 20,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      )
                    : Text(
                        question.text,
                        style: TextStyle(
                          fontSize: isMobile ? 17 : 21,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // ── Alternativas ou Feedback ──────────────────────────────
              if (!showFeedback)
                ...question.choices.asMap().entries.map((e) {
                  final idx = e.key;
                  final choice = e.value;
                  final letter =
                      idx < _letters.length ? _letters[idx] : '${idx + 1}';
                  final correct = choice.isCorrect;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: correct
                          ? AppTheme.success.withValues(alpha: 0.18)
                          : AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: correct ? AppTheme.success : AppTheme.bgCardAlt,
                        width: correct ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: correct ? AppTheme.success : AppTheme.bgDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                color: correct
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            choice.text,
                            style: TextStyle(
                              color: correct
                                  ? AppTheme.success
                                  : AppTheme.textPrimary,
                              fontSize: isMobile ? 14 : 16,
                              fontWeight:
                                  correct ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (correct)
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.success, size: 24),
                      ],
                    ),
                  );
                })
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(glowing: false),
                  child: question.generalFeedback.isNotEmpty
                      ? _MoodleHtml(
                          html: question.generalFeedback,
                          textStyle: TextStyle(
                            fontSize: isMobile ? 15 : 17,
                            color: AppTheme.textPrimary,
                            height: 1.6,
                          ),
                        )
                      : const Text(
                          'Nenhum feedback disponível para esta questão.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 15),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodleHtml extends StatelessWidget {
  final String html;
  final TextStyle textStyle;

  const _MoodleHtml({
    required this.html,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      _withLatexTags(html),
      textStyle: textStyle,
      customWidgetBuilder: (element) {
        if (element.localName != 'mq-latex') return null;

        final latex = element.attributes['data-latex'];
        if (latex == null) return null;

        final decoded = Uri.decodeComponent(latex);
        final display = element.attributes['data-display'] == 'true';
        final math = Math.tex(
          decoded,
          mathStyle: display ? MathStyle.display : MathStyle.text,
          textStyle: textStyle.copyWith(color: AppTheme.textPrimary),
          onErrorFallback: (error) => Text(
            decoded,
            style: textStyle.copyWith(color: AppTheme.textPrimary),
          ),
        );

        if (!display) return InlineCustomWidget(child: math);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: math,
          ),
        );
      },
      customStylesBuilder: (element) {
        if (element.localName == 'table') {
          return {'border-collapse': 'collapse', 'width': '100%'};
        }
        if (element.localName == 'td' || element.localName == 'th') {
          return {'border': '1px solid #444', 'padding': '6px 10px'};
        }
        if (element.localName == 'img') {
          return {'max-width': '100%', 'height': 'auto'};
        }
        return null;
      },
    );
  }

  static String _withLatexTags(String source) {
    final buffer = StringBuffer();
    var index = 0;

    while (index < source.length) {
      final tagStart = source.indexOf('<', index);
      if (tagStart < 0) {
        buffer.write(_replaceLatexInText(source.substring(index)));
        break;
      }

      if (tagStart > index) {
        buffer.write(_replaceLatexInText(source.substring(index, tagStart)));
      }

      final tagEnd = source.indexOf('>', tagStart);
      if (tagEnd < 0) {
        buffer.write(source.substring(tagStart));
        break;
      }

      buffer.write(source.substring(tagStart, tagEnd + 1));
      index = tagEnd + 1;
    }

    return buffer.toString();
  }

  static String _replaceLatexInText(String text) {
    final decoded = _decodeHtmlEntities(text);
    final delimited = _replaceDelimitedLatex(decoded);
    if (delimited != null) return delimited;

    final replaced = decoded.split('\n').map(_replaceLooseLatexLine).join('\n');
    if (replaced != decoded) return replaced;

    final cleaned = _cleanPlainLatexText(decoded);
    if (cleaned != decoded) return _escapeHtmlText(cleaned);

    return text;
  }

  static String? _replaceDelimitedLatex(String text) {
    final buffer = StringBuffer();
    var index = 0;
    var changed = false;

    while (index < text.length) {
      final match = _nextLatex(text, index);
      if (match == null) {
        buffer.write(_escapeHtmlText(_cleanPlainLatexText(
          text.substring(index),
        )));
        break;
      }

      changed = true;
      buffer.write(_escapeHtmlText(_cleanPlainLatexText(
        text.substring(index, match.start),
      )));
      buffer.write(_latexTag(match.content, display: match.display));
      index = match.end;
    }

    return changed ? buffer.toString() : null;
  }

  static String _replaceLooseLatexLine(String text) {
    final leading = RegExp(r'^\s*').firstMatch(text)?.group(0) ?? '';
    final trailing = RegExp(r'\s*$').firstMatch(text)?.group(0) ?? '';
    final line = text.trim();

    if (line.isEmpty) return text;

    if (_looksLikeLatexLine(line)) {
      return '$leading${_latexTag(line, display: true)}$trailing';
    }

    final fragments = _findLooseLatexFragments(line);
    if (fragments.isEmpty) return text;

    final buffer = StringBuffer(leading);
    var index = 0;
    for (final fragment in fragments) {
      if (fragment.start < index) continue;

      buffer.write(_escapeHtmlText(_cleanPlainLatexText(
        line.substring(index, fragment.start),
      )));
      buffer.write(_latexTag(fragment.content, display: false));
      index = fragment.end;
    }
    buffer.write(_escapeHtmlText(_cleanPlainLatexText(line.substring(index))));
    buffer.write(trailing);

    return buffer.toString();
  }

  static bool _looksLikeLatexLine(String line) {
    final startsAsMath = RegExp(
      r'^(?:\\(?:Delta|delta|frac|sqrt|sum|int|left|right)\b|[A-Za-z]\s*=|\d)',
    ).hasMatch(line);
    if (!startsAsMath) return false;

    if (RegExp(
            r'\\(?:Delta|delta|frac|cdot|times|div|sqrt|circ|pi|alpha|beta|gamma|theta|lambda|mu|sigma|sum|int|left|right)\b')
        .hasMatch(line)) {
      return true;
    }

    return RegExp(r'^[A-Za-z\\][A-Za-z0-9\\\s{}.,+\-*/^=()]+$')
            .hasMatch(line) &&
        line.contains('=') &&
        (line.contains(r'\') || line.contains('{') || line.contains('^'));
  }

  static List<_LatexMatch> _findLooseLatexFragments(String line) {
    final fragments = <_LatexMatch>[];
    var index = 0;

    while (index < line.length) {
      final match = _nextLooseLatexFragment(line, index);
      if (match == null) break;

      fragments.add(match);
      index = match.end;
    }

    return fragments;
  }

  static _LatexMatch? _nextLooseLatexFragment(String line, int from) {
    final patterns = <RegExp>[
      RegExp(
        r'\\(?:Delta|delta|frac|cdot|times|div|sqrt|circ|pi|alpha|beta|gamma|theta|lambda|mu|sigma|sum|int|left|right)\b(?:\{,\}|[^.;\n])*',
      ),
      RegExp(
        r'[A-Za-z\\][A-Za-z0-9\\\s{},+\-*/^=()]*=\s*[A-Za-z0-9\\\s{},+\-*/^()]+',
      ),
      RegExp(
        r'\d+(?:\{,\}\d+)?(?:\\,)?\^?\\circ\}?\s*[A-Za-z]',
      ),
    ];

    _LatexMatch? best;
    for (final pattern in patterns) {
      final match = pattern.matchAsPrefix(line, from) ??
          pattern.allMatches(line, from).firstOrNull;
      if (match == null) continue;

      final content = match.group(0)?.trim() ?? '';
      if (content.isEmpty) continue;
      if (!_looksLikeLatexFragment(content)) continue;

      final candidate = _LatexMatch(
        start: match.start,
        end: match.end,
        content: content,
        display: false,
      );

      if (best == null || candidate.start < best.start) best = candidate;
    }

    return best;
  }

  static bool _looksLikeLatexFragment(String text) {
    return text.contains(r'\') ||
        text.contains('{') ||
        text.contains('^') ||
        text.contains('=');
  }

  static _LatexMatch? _nextLatex(String text, int from) {
    final candidates = <_LatexDelimiter>[
      const _LatexDelimiter(r'\(', r'\)', false),
      const _LatexDelimiter(r'\[', r'\]', true),
      const _LatexDelimiter(r'$$', r'$$', true),
    ];

    _LatexMatch? best;
    for (final delimiter in candidates) {
      final start = text.indexOf(delimiter.open, from);
      if (start < 0) continue;

      final contentStart = start + delimiter.open.length;
      final end = text.indexOf(delimiter.close, contentStart);
      if (end < 0) continue;

      final match = _LatexMatch(
        start: start,
        end: end + delimiter.close.length,
        content: text.substring(contentStart, end).trim(),
        display: delimiter.display,
      );

      if (best == null || match.start < best.start) best = match;
    }

    return best;
  }

  static String _latexTag(String latex, {required bool display}) {
    final encoded = Uri.encodeComponent(_normalizeLatex(latex));
    return '<mq-latex data-latex="$encoded" data-display="$display"></mq-latex>';
  }

  static String _normalizeLatex(String latex) {
    final decoded = _decodeHtmlEntities(latex)
        .replaceAllMapped(
          RegExp(r'\\circ\}?([A-Za-z])'),
          (match) => r'\circ ' '${match.group(1)}',
        )
        .replaceAll(r'\,', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final buffer = StringBuffer();
    var balance = 0;
    for (final codeUnit in decoded.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (char == '{') {
        balance++;
        buffer.write(char);
      } else if (char == '}') {
        if (balance > 0) {
          balance--;
          buffer.write(char);
        }
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  static String _cleanPlainLatexText(String text) {
    return text
        .replaceAll(RegExp(r'\{,\}'), ',')
        .replaceAll(r'\,', ' ')
        .replaceAll(RegExp(r'\}(?=[A-Za-z])'), '');
  }

  static String _escapeHtmlText(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _decodeHtmlEntities(String value) {
    final named = value
        .replaceAll('&bsol;', r'\')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    return named.replaceAllMapped(
      RegExp(r'&#(?:x([0-9a-fA-F]+)|([0-9]+));'),
      (match) {
        final hex = match.group(1);
        final decimal = match.group(2);
        final codePoint = hex != null
            ? int.tryParse(hex, radix: 16)
            : int.tryParse(decimal ?? '');

        if (codePoint == null) return match.group(0) ?? '';
        return String.fromCharCode(codePoint);
      },
    );
  }
}

class _LatexDelimiter {
  final String open;
  final String close;
  final bool display;

  const _LatexDelimiter(this.open, this.close, this.display);
}

class _LatexMatch {
  final int start;
  final int end;
  final String content;
  final bool display;

  const _LatexMatch({
    required this.start,
    required this.end,
    required this.content,
    required this.display,
  });
}
