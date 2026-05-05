import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../domain/entities/question_entity.dart';
import '../../widgets/timer_widget.dart';
import '../../widgets/option_button.dart';
import '../../widgets/moodle_image.dart';

/// Tela de resposta de questão – usada inline dentro do lobby do estudante.
class StudentQuestionPage extends StatelessWidget {
  final QuestionEntity question;
  final DateTime? endsAt;
  final String? selectedChoice;
  final bool hasAnswered;
  final bool isSubmitting;
  final void Function(String choiceValue) onSelect;
  final VoidCallback onSubmit;

  const StudentQuestionPage({
    super.key,
    required this.question,
    required this.endsAt,
    required this.selectedChoice,
    required this.hasAnswered,
    required this.isSubmitting,
    required this.onSelect,
    required this.onSubmit,
  });

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return SingleChildScrollView(
      padding:
          Responsive.horizontalPadding(context).copyWith(top: 12, bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Timer ─────────────────────────────────────────────────
              if (endsAt != null)
                TimerWidget(endsAt: endsAt!).animate().fadeIn(),
              if (endsAt == null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: AppTheme.cardDecoration(),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded,
                          color: AppTheme.warning, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'O cronômetro vai começar quando a primeira resposta for enviada.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

              const SizedBox(height: 16),

              // ── Enunciado (HTML rico do Moodle) ───────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(glowing: true),
                child: question.htmlText.isNotEmpty
                    ? HtmlWidget(
                        question.htmlText,
                        customWidgetBuilder: (element) {
                          if (element.localName != 'img') return null;
                          final src = element.attributes['src'];
                          if (src == null || src.isEmpty) return null;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: MoodleImage(
                              src: src,
                              alt: element.attributes['alt'],
                              maxHeight: 260,
                            ),
                          );
                        },
                        textStyle: GoogleFonts.nunito(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                        customStylesBuilder: (element) {
                          // Estiliza tabelas e elementos comuns do Moodle
                          if (element.localName == 'table') {
                            return {
                              'border-collapse': 'collapse',
                              'width': '100%',
                            };
                          }
                          if (element.localName == 'td' ||
                              element.localName == 'th') {
                            return {
                              'border': '1px solid #444',
                              'padding': '6px 10px',
                            };
                          }
                          if (element.localName == 'img') {
                            return {'max-width': '100%', 'height': 'auto'};
                          }
                          return null;
                        },
                      )
                    : Text(
                        question.text,
                        style: GoogleFonts.nunito(
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
              )
                  .animate()
                  .slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOut)
                  .fadeIn(),

              const SizedBox(height: 20),

              // ── Alternativas ──────────────────────────────────────────
              ...question.choices.asMap().entries.map((e) {
                final index = e.key;
                final choice = e.value;
                final letter =
                    index < _letters.length ? _letters[index] : '${index + 1}';
                final isSelected = selectedChoice == choice.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OptionButton(
                    label: letter,
                    text: choice.text,
                    htmlText: choice.htmlText,
                    isSelected: isSelected,
                    isDisabled: hasAnswered,
                    onTap: () => onSelect(choice.value),
                  )
                      .animate(delay: Duration(milliseconds: index * 80))
                      .slideX(
                          begin: 0.3, duration: 350.ms, curve: Curves.easeOut)
                      .fadeIn(),
                );
              }),

              const SizedBox(height: 20),

              // ── Botão enviar ──────────────────────────────────────────
              if (!hasAnswered)
                ElevatedButton.icon(
                  onPressed: (selectedChoice == null || isSubmitting)
                      ? null
                      : onSubmit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label:
                      Text(isSubmitting ? 'Enviando...' : 'Confirmar Resposta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedChoice != null
                        ? AppTheme.success
                        : AppTheme.primary.withValues(alpha: 0.5),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ).animate().fadeIn(delay: 400.ms)
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.success),
                      SizedBox(width: 8),
                      Text(
                        'Resposta enviada! Aguardando resultado...',
                        style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            ],
          ),
        ),
      ),
    );
  }
}
