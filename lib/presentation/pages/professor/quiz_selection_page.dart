import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../domain/entities/moodle_quiz.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/professor_controller.dart';

class QuizSelectionPage extends StatelessWidget {
  const QuizSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: Responsive.contentWidth(context)),
              child: Padding(
                padding: Responsive.horizontalPadding(context)
                    .add(const EdgeInsets.symmetric(vertical: 24)),
                child: Consumer<ProfessorController>(
                  builder: (_, ctrl, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(courseName: ctrl.selectedCourse?.fullname ?? ''),
                      const SizedBox(height: 24),
                      if (ctrl.error != null) _ErrorCard(ctrl.error!),
                      if (ctrl.isLoading)
                        const Expanded(
                            child:
                                Center(child: CircularProgressIndicator()))
                      else
                        Expanded(child: _QuizList(quizzes: ctrl.quizzes)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String courseName;
  const _Header({required this.courseName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.cardDecoration(
              gradient: AppTheme.primaryGradient, glowing: true),
          child: const Icon(Icons.quiz, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selecionar Questionário', style: AppTheme.headlineMedium),
              if (courseName.isNotEmpty)
                Text(courseName,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuizList extends StatelessWidget {
  final List<MoodleQuiz> quizzes;
  const _QuizList({required this.quizzes});

  @override
  Widget build(BuildContext context) {
    if (quizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('Nenhum questionário nesta disciplina',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: quizzes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _QuizTile(quiz: quizzes[i]),
    );
  }
}

class _QuizTile extends StatelessWidget {
  final MoodleQuiz quiz;
  const _QuizTile({required this.quiz});

  @override
  Widget build(BuildContext context) {
    final timeLabel = quiz.timeLimit != null
        ? '${(quiz.timeLimit! ~/ 60)} min'
        : 'Sem limite';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final user = context.read<AuthController>().user;
          if (user == null) return;
          final router = GoRouter.of(context);
          await context.read<ProfessorController>().selectQuiz(user, quiz);
          router.go(AppRouter.professor);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.quiz, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quiz.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(timeLabel,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(width: 16),
                        const Icon(Icons.repeat,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                            quiz.attempts == 0
                                ? 'Ilimitadas'
                                : '${quiz.attempts} tent.',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(
          color: AppTheme.danger.withValues(alpha: 0.2)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
        ],
      ),
    );
  }
}
