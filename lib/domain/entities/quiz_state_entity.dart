import 'package:equatable/equatable.dart';

/// Estados possíveis do quiz.
enum QuizStatus { waiting, active, closed, finished }

/// Snapshot do estado atual do quiz no servidor (Google Sheets).
class QuizStateEntity extends Equatable {
  final QuizStatus status;
  final int
      currentPage; // página Moodle sendo exibida (0-indexed; -1 = nenhuma)
  final int totalPages; // total de páginas/questões no quiz
  final int quizId; // id do quiz Moodle
  final int courseId; // id do curso Moodle
  final String quizTitle;
  final DateTime? startedAt;
  final DateTime? endsAt;

  const QuizStateEntity({
    required this.status,
    this.currentPage = -1,
    this.totalPages = 0,
    this.quizId = 0,
    this.courseId = 0,
    this.quizTitle = 'Quiz',
    this.startedAt,
    this.endsAt,
  });

  /// Segundos restantes calculados localmente.
  int get secondsRemaining {
    if (endsAt == null || status != QuizStatus.active) return 0;
    final diff = endsAt!.difference(DateTime.now().toUtc()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  bool get isActive => status == QuizStatus.active;
  bool get isWaiting => status == QuizStatus.waiting;
  bool get isClosed => status == QuizStatus.closed;
  bool get isFinished => status == QuizStatus.finished;

  static QuizStateEntity empty() =>
      const QuizStateEntity(status: QuizStatus.waiting);

  @override
  List<Object?> get props => [status, currentPage, endsAt];
}
