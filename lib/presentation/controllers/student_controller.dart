import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/moodle_course.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/quiz_state_entity.dart';
import '../../domain/entities/score_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/i_quiz_repository.dart';
import '../../domain/usecases/submit_answer_usecase.dart';

/// Gerencia estado do estudante: seleÃ§Ã£o de disciplina + tentativa Moodle + polling.
class StudentController extends ChangeNotifier {
  final IQuizRepository _quizRepo;
  final SubmitAnswerUseCase _submitAnswer;

  // â”€â”€ SeleÃ§Ã£o de disciplina â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<MoodleCourse> _courses = [];
  int? _selectedCourseId;
  bool _isLoadingCourses = false;
  // null = nÃ£o verificado | false = sem mq_state | true = tem mq_state
  bool? _hasActivity;

  // â”€â”€ Tentativa Moodle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  int? _attemptId;
  int? _currentQuizId;
  QuestionEntity? _currentQuestion;

  // â”€â”€ Estado do quiz â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  QuizStateEntity _quizState = QuizStateEntity.empty();
  List<ScoreEntity> _scores = [];
  String? _selectedChoice;
  bool _hasAnswered = false;
  bool _isSubmitting = false;
  bool _lastAnswerCorrect = false;
  bool _isLoadingQuestion = false;
  String? _error;
  Timer? _pollTimer;
  int _lastSeenSlot = 0;
  bool _autoSubmitted = false;

  StudentController({
    required IQuizRepository quizRepo,
    required SubmitAnswerUseCase submitAnswer,
  })  : _quizRepo = quizRepo,
        _submitAnswer = submitAnswer;

  // â”€â”€ Getters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<MoodleCourse> get courses => _courses;
  int? get selectedCourseId => _selectedCourseId;
  bool get isLoadingCourses => _isLoadingCourses;

  /// null = verificando | false = sem mq_state | true = tem
  bool? get hasActivity => _hasActivity;
  int? get attemptId => _attemptId;
  QuizStateEntity get quizState => _quizState;
  QuestionEntity? get currentQuestion => _currentQuestion;
  List<ScoreEntity> get scores => _scores;
  String? get selectedChoice => _selectedChoice;
  bool get hasAnswered => _hasAnswered;
  bool get isSubmitting => _isSubmitting;
  bool get lastAnswerCorrect => _lastAnswerCorrect;
  bool get isLoadingQuestion => _isLoadingQuestion;
  String? get error => _error;

  ScoreEntity? myScore(String userId) {
    try {
      return _scores.firstWhere((s) => s.studentId == userId);
    } catch (_) {
      return null;
    }
  }

  // â”€â”€ SeleÃ§Ã£o de disciplina â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> loadCourses(UserEntity user) async {
    _isLoadingCourses = true;
    _error = null;
    notifyListeners();
    try {
      _courses = await _quizRepo.getCourses(user);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingCourses = false;
      notifyListeners();
    }
  }

  /// Define o curso cujo mq_state serÃ¡ monitorado.
  /// Verifica se a atividade existe antes de iniciar o polling.
  void selectCourse(UserEntity user, int courseId) {
    stopPolling();
    _selectedCourseId = courseId;
    _hasActivity = null; // verificando
    _lastSeenSlot = 0;
    _quizState = QuizStateEntity.empty();
    _currentQuestion = null;
    _scores = [];
    _error = null;
    notifyListeners();
    _checkAndStartPolling(user);
  }

  Future<void> _checkAndStartPolling(UserEntity user) async {
    final courseId = _selectedCourseId;
    if (courseId == null) return;
    try {
      // Uma chamada de teste â€” se lanÃ§ar "mq_state nÃ£o encontrada" â†’ sem atividade
      await _quizRepo.getQuizState(user, courseId);
      _hasActivity = true;
      notifyListeners();
      startPolling(user);
    } catch (e) {
      final msg = e.toString();
      // Mensagem especÃ­fica do MoodleStateDatasource quando nÃ£o acha o Database
      if (msg.contains('mq_state') || msg.contains('nÃ£o encontrada')) {
        _hasActivity = false;
      } else {
        _hasActivity = null;
        _error = msg;
      }
      notifyListeners();
    }
  }

  // â”€â”€ Ciclo de tentativa â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> ensureAttempt(UserEntity user, int quizId) async {
    if (_attemptId != null && _currentQuizId == quizId) return;
    try {
      _attemptId = await _quizRepo.startAttempt(user, quizId);
      _currentQuizId = quizId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> finishAttempt(UserEntity user) async {
    final id = _attemptId;
    if (id == null) return;
    try {
      await _quizRepo.finishAttempt(user, id);
      _attemptId = null;
      _currentQuizId = null;
      _currentQuestion = null;
    } catch (_) {}
  }

  // â”€â”€ Resposta â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void selectChoice(String choiceValue) {
    if (_hasAnswered || !_quizState.isActive) return;
    _selectedChoice = choiceValue;
    notifyListeners();
  }

  Future<void> submitAnswer(UserEntity user) async {
    final choice = _selectedChoice;
    final q = _currentQuestion;
    final id = _attemptId;
    final courseId = _selectedCourseId;
    if (choice == null ||
        q == null ||
        id == null ||
        _hasAnswered ||
        courseId == null) {
      return;
    }

    _isSubmitting = true;
    notifyListeners();
    try {
      final bonus = _quizState.secondsRemaining * 10;
      final baseScore = 1000 + bonus;

      _lastAnswerCorrect = await _submitAnswer(
        user: user,
        courseId: courseId,
        attemptId: id,
        question: q,
        choiceValue: choice,
        baseScore: baseScore,
      );
      _hasAnswered = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // â”€â”€ Polling â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void startPolling(UserEntity user) {
    _pollTimer?.cancel();
    _refreshState(user);
    _pollTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _refreshState(user));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // â”€â”€ Privado â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _refreshState(UserEntity user) async {
    final courseId = _selectedCourseId;
    if (courseId == null) return;
    try {
      final newState = await _quizRepo.getQuizState(user, courseId);

      if (newState.isActive && newState.currentSlot != _lastSeenSlot) {
        _selectedChoice = null;
        _hasAnswered = false;
        _lastAnswerCorrect = false;
        _autoSubmitted = false;
        _currentQuestion = null;

        if (newState.quizId > 0) {
          await ensureAttempt(user, newState.quizId);
        }

        final id = _attemptId;
        if (id != null && newState.currentSlot > 0) {
          _isLoadingQuestion = true;
          notifyListeners();
          try {
            _currentQuestion =
                await _quizRepo.getQuestion(user, id, newState.currentSlot);
            _lastSeenSlot = newState.currentSlot;
            _error = null;
          } catch (e) {
            _error = e.toString();
          } finally {
            _isLoadingQuestion = false;
          }
        }
      }

      if (newState.isClosed &&
          !_hasAnswered &&
          !_autoSubmitted &&
          _selectedChoice != null) {
        _autoSubmitted = true;
        await submitAnswer(user);
      }

      if (newState.isFinished && _attemptId != null) {
        await finishAttempt(user);
      }

      _quizState = newState;
      _scores = await _quizRepo.getScores(user, courseId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

