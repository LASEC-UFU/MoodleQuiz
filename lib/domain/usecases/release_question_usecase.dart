import '../entities/user_entity.dart';
import '../repositories/i_quiz_repository.dart';

/// S: Único propósito – liberar uma página de questão para os estudantes.
class ReleaseQuestionUseCase {
  final IQuizRepository _repository;

  const ReleaseQuestionUseCase(this._repository);

  Future<void> call({
    required UserEntity user,
    required int courseId,
    required int page,
    required int duration,
    required int totalPages,
    required String quizName,
    required int quizId,
  }) {
    return _repository.releaseQuestion(
      user: user,
      courseId: courseId,
      page: page,
      duration: duration,
      totalPages: totalPages,
      quizName: quizName,
      quizId: quizId,
    );
  }
}
