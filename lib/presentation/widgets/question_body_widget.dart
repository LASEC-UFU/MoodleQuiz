import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../domain/entities/question_entity.dart';
import 'moodle_html.dart';

/// Renderiza o conteúdo de uma questão Moodle em modo somente leitura.
/// Motor único de desenho usado nas duas telas do professor (card de
/// questão selecionada e tela de gabarito), garantindo paridade visual.
class QuestionBodyWidget extends StatelessWidget {
  final QuestionEntity question;
  final bool showCorrect;

  /// Modo compacto: fontes menores, paddings reduzidos (para cards laterais).
  final bool compact;

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  const QuestionBodyWidget({
    super.key,
    required this.question,
    this.showCorrect = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final baseFontSize =
        compact ? (isMobile ? 13.0 : 14.0) : (isMobile ? 15.0 : 17.0);

    final textStyle = GoogleFonts.nunito(
      fontSize: baseFontSize,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
      height: 1.5,
    );

    final questionHtml = question.isMultiChoice
        ? question.htmlText
        : (question.displayHtml.isNotEmpty
            ? question.displayHtml
            : question.htmlText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Enunciado ────────────────────────────────────────────────────────
        if (questionHtml.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 10 : 14),
            child: MoodleHtml(html: questionHtml, textStyle: textStyle),
          )
        else if (question.text.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 10 : 14),
            child: Text(question.text, style: textStyle),
          ),

        // ── Alternativas (Múltipla Escolha / V-F / Calculada Múltipla) ───────
        if (question.isMultiChoice && question.choices.isNotEmpty)
          ..._buildChoices(isMobile),

        // ── Pares de Associação (Match) ───────────────────────────────────────
        if (question.isMatch) _buildMatchSection(isMobile, textStyle),

        // ── Gabarito numérico / resposta curta ───────────────────────────────
        if ((question.isNumerical || question.isShortAnswer) &&
            showCorrect &&
            question.rightAnswerHtml.isNotEmpty)
          _buildRightAnswerCard(isMobile, textStyle),

        // ── Gabarito para outros tipos com rightAnswerHtml ───────────────────
        if (!question.isMultiChoice &&
            !question.isMatch &&
            !question.isNumerical &&
            !question.isShortAnswer &&
            showCorrect &&
            question.rightAnswerHtml.isNotEmpty)
          _buildRightAnswerCard(isMobile, textStyle),

        // ── Banner informativo para tipos não interativos ─────────────────────
        if (question.isGapSelect || question.isDdwtos)
          _buildInfoBanner(
            icon: Icons.edit_note_rounded,
            color: AppTheme.accent,
            message: question.isDdwtos
                ? 'Arrastar e soltar palavras — aluno responde no Moodle'
                : 'Selecionar palavras — lacunas com opções exibidas acima',
          ),

        if (question.isGeoGebra)
          _buildInfoBanner(
            icon: Icons.open_in_browser_rounded,
            color: AppTheme.accent,
            message: 'Questão GeoGebra — aluno responde no Moodle',
          ),

        if (question.isDdImage)
          _buildInfoBanner(
            icon: Icons.touch_app_rounded,
            color: AppTheme.accent,
            message: 'Arrastar e soltar na imagem — aluno responde no Moodle',
          ),

        if (question.isOrdering)
          _buildInfoBanner(
            icon: Icons.sort_rounded,
            color: AppTheme.accent,
            message: 'Questão de ordenação — aluno reordena no Moodle',
          ),

        if (question.isCloze)
          _buildInfoBanner(
            icon: Icons.text_fields_rounded,
            color: AppTheme.accent,
            message: 'Respostas embutidas (Cloze) — aluno responde no Moodle',
          ),

        if (question.isEssay)
          _buildInfoBanner(
            icon: Icons.description_rounded,
            color: AppTheme.accent,
            message: 'Questão dissertativa — aluno elabora resposta no Moodle',
          ),
      ],
    );
  }

  // ── Múltipla escolha ────────────────────────────────────────────────────────

  List<Widget> _buildChoices(bool isMobile) {
    final fontSize = compact ? 13.0 : (isMobile ? 14.0 : 16.0);
    final badgeSize = compact ? 26.0 : 32.0;

    return question.choices.asMap().entries.map((e) {
      final idx = e.key;
      final choice = e.value;
      final letter = idx < _letters.length ? _letters[idx] : '${idx + 1}';
      final isCorrect = showCorrect && choice.isCorrect;

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isCorrect
              ? AppTheme.success.withValues(alpha: 0.18)
              : AppTheme.bgCardAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCorrect
                ? AppTheme.success.withValues(alpha: 0.6)
                : AppTheme.bgCardAlt,
            width: isCorrect ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: isCorrect ? AppTheme.success : AppTheme.bgDark,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: compact ? 12 : 14,
                  color: isCorrect ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: choice.htmlText.isNotEmpty
                  ? MoodleHtml(
                      html: choice.htmlText,
                      textStyle: TextStyle(
                        fontSize: fontSize,
                        color:
                            isCorrect ? AppTheme.success : AppTheme.textPrimary,
                        fontWeight:
                            isCorrect ? FontWeight.w700 : FontWeight.w500,
                        height: 1.4,
                      ),
                    )
                  : Text(
                      choice.text,
                      style: TextStyle(
                        fontSize: fontSize,
                        color:
                            isCorrect ? AppTheme.success : AppTheme.textPrimary,
                        fontWeight:
                            isCorrect ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
            ),
            if (isCorrect) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: compact ? 16 : 20),
            ],
          ],
        ),
      );
    }).toList();
  }

  // ── Associação (Match) ──────────────────────────────────────────────────────

  Widget _buildMatchSection(bool isMobile, TextStyle textStyle) {
    final matchData = question.matchData;
    if (matchData == null || matchData.subQuestions.isEmpty) {
      return _buildRightAnswerCard(isMobile, textStyle);
    }

    final optionText = {for (final o in matchData.options) o.value: o.text};

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.bgCardAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 7 : 8,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.bgDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.compare_arrows_rounded,
                    color: AppTheme.accent, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Associação',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!showCorrect)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '(gabarito oculto)',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: compact ? 10 : 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...matchData.subQuestions.asMap().entries.map((e) {
            final idx = e.key;
            final sub = e.value;
            final correctText = sub.correctValue != null
                ? optionText[sub.correctValue] ?? '?'
                : '—';

            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 8 : 10,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: idx > 0
                      ? BorderSide(color: AppTheme.bgCardAlt)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: sub.htmlText.isNotEmpty
                        ? MoodleHtml(
                            html: sub.htmlText,
                            textStyle: textStyle.copyWith(
                                fontSize: compact ? 12 : 14),
                          )
                        : Text(
                            sub.text,
                            style: textStyle.copyWith(
                                fontSize: compact ? 12 : 14),
                          ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: AppTheme.accent, size: 14),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      showCorrect ? correctText : '______',
                      style: TextStyle(
                        color: showCorrect
                            ? AppTheme.success
                            : AppTheme.textSecondary,
                        fontSize: compact ? 12 : 14,
                        fontWeight: showCorrect
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Gabarito (resposta correta) ─────────────────────────────────────────────

  Widget _buildRightAnswerCard(bool isMobile, TextStyle textStyle) {
    if (question.rightAnswerHtml.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppTheme.success, size: compact ? 16 : 20),
          const SizedBox(width: 10),
          Expanded(
            child: MoodleHtml(
              html: question.rightAnswerHtml,
              textStyle: textStyle.copyWith(
                color: AppTheme.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner informativo ──────────────────────────────────────────────────────

  static Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
