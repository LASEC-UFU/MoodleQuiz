import 'package:equatable/equatable.dart';

class MoodleQuiz extends Equatable {
  final int id;
  final int courseId;
  final String name;
  final int? timeLimit;    // segundos; null = sem limite
  final int attempts;      // máximo de tentativas permitidas
  final String intro;      // descrição HTML

  const MoodleQuiz({
    required this.id,
    required this.courseId,
    required this.name,
    this.timeLimit,
    this.attempts = 0,
    this.intro = '',
  });

  factory MoodleQuiz.fromJson(Map<String, dynamic> json) => MoodleQuiz(
        id: (json['id'] as num).toInt(),
        courseId: (json['course'] as num? ?? 0).toInt(),
        name: json['name']?.toString() ?? '',
        timeLimit: json['timelimit'] == null || json['timelimit'] == 0
            ? null
            : (json['timelimit'] as num).toInt(),
        attempts: (json['attempts'] as num? ?? 0).toInt(),
        intro: json['intro']?.toString() ?? '',
      );

  @override
  List<Object?> get props => [id];
}
