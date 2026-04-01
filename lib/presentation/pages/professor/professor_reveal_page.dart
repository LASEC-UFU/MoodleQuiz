import 'package:flutter/material.dart';
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
    final hasFeedback =
        question != null && question.generalFeedback.isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── AppBar ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
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
                            style:
                                TextStyle(color: AppTheme.textSecondary)),
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
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Enunciado ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(glowing: false),
                child: question.htmlText.isNotEmpty
                    ? HtmlWidget(
                        question.htmlText,
                        textStyle: TextStyle(
                          fontSize: isMobile ? 16 : 20,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                        customStylesBuilder: (element) {
                          if (element.localName == 'table') {
                            return {
                              'border-collapse': 'collapse',
                              'width': '100%'
                            };
                          }
                          if (element.localName == 'td' ||
                              element.localName == 'th') {
                            return {
                              'border': '1px solid #444',
                              'padding': '6px 10px'
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
                      ? Text(
                          question.generalFeedback,
                          style: TextStyle(
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
