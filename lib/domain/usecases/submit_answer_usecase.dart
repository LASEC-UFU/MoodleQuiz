import '../entities/question_entity.dart';
import '../entities/user_entity.dart';
import '../repositories/i_quiz_repository.dart';

/// S: Único propósito – submeter resposta ao Moodle e pontuação ao GSheets.
class SubmitAnswerUseCase {
  final IQuizRepository _repository;

  const SubmitAnswerUseCase(this._repository);

  /// Retorna se a resposta foi correta.
  Future<bool> call({
    required UserEntity user,
    required int attemptId,
    required QuestionEntity question,
    required String choiceValue,
    required int baseScore,
  }) async {
    final correct = await _repository.submitPage(
        user, attemptId, question, choiceValue);

    await _repository.submitScore(
      user: user,
      score: correct ? baseScore : 0,
      correct: correct,
      page: question.page,
    );

    return correct;
  }
}
