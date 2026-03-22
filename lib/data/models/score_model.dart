import '../../domain/entities/score_entity.dart';

/// Deserializa pontuações vindas do GSheets.
class ScoreModel extends ScoreEntity {
  const ScoreModel({
    required super.studentId,
    required super.studentName,
    required super.correctCount,
    required super.totalAnswered,
    required super.score,
    required super.rank,
    super.previousRank,
  });

  factory ScoreModel.fromJson(Map<String, dynamic> json,
      {int? previousRank}) {
    return ScoreModel(
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Desconhecido',
      correctCount:
          int.tryParse(json['correct_count']?.toString() ?? '') ?? 0,
      totalAnswered:
          int.tryParse(json['total_answered']?.toString() ?? '') ?? 0,
      score: int.tryParse(json['score']?.toString() ?? '') ?? 0,
      rank: int.tryParse(json['rank']?.toString() ?? '') ?? 99,
      previousRank: previousRank,
    );
  }
}
