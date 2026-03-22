import '../repositories/i_quiz_repository.dart';

/// S: Único propósito – encerrar a questão atual.
class CloseQuestionUseCase {
  final IQuizRepository _repository;

  const CloseQuestionUseCase(this._repository);

  Future<void> call(String teacherToken) =>
      _repository.closeQuestion(teacherToken);
}
