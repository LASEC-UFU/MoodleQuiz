import '../../domain/entities/quiz_state_entity.dart';

/// Deserializa o estado do quiz vindo do GSheets/Apps Script.
class QuizStateModel extends QuizStateEntity {
  const QuizStateModel({
    required super.status,
    super.currentPage,
    super.totalPages,
    super.quizId,
    super.quizTitle,
    super.startedAt,
    super.endsAt,
  });

  factory QuizStateModel.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['state'] as String? ?? 'waiting').toLowerCase();
    final status = _parseStatus(statusStr);

    DateTime? endsAt;
    final endsAtStr = json['ends_at']?.toString();
    if (endsAtStr != null && endsAtStr.isNotEmpty) {
      endsAt = DateTime.tryParse(endsAtStr)?.toLocal();
    }

    DateTime? startedAt;
    final startedAtStr = json['started_at']?.toString();
    if (startedAtStr != null && startedAtStr.isNotEmpty) {
      startedAt = DateTime.tryParse(startedAtStr)?.toLocal();
    }

    return QuizStateModel(
      status: status,
      currentPage: int.tryParse(json['current_page']?.toString() ?? '') ?? -1,
      totalPages: int.tryParse(json['total_pages']?.toString() ?? '') ?? 0,
      quizId: int.tryParse(json['quiz_id']?.toString() ?? '') ?? 0,
      quizTitle: json['quiz_name']?.toString() ?? 'Quiz',
      startedAt: startedAt,
      endsAt: endsAt,
    );
  }

  static QuizStatus _parseStatus(String s) => switch (s) {
        'active' => QuizStatus.active,
        'closed' => QuizStatus.closed,
        'finished' => QuizStatus.finished,
        _ => QuizStatus.waiting,
      };
}
