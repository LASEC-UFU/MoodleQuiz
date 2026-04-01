import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/moodle_datasource.dart';
import 'data/datasources/moodle_state_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/quiz_repository_impl.dart';
import 'domain/usecases/close_question_usecase.dart';
import 'domain/usecases/login_usecase.dart';
import 'domain/usecases/release_question_usecase.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/professor_controller.dart';
import 'presentation/controllers/student_controller.dart';

/// Ponto de entrada – composição de dependências seguindo princípio D (IoC).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Lê config.json estático (deployado junto com o app no GitHub Pages) ──
  try {
    final raw = await rootBundle.loadString('assets/config.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    AppConfig.loadFromMap(map);
  } catch (_) {
    // Arquivo ausente em dev local – segue com valores padrão
  }

  // ── Instancia dependências ────────────────────────────────────────────────
  final moodleDs = MoodleDatasource();
  final stateDs = MoodleStateDatasource(moodleDs);

  final authRepo = AuthRepositoryImpl(moodleDs);
  final quizRepo = QuizRepositoryImpl(stateDs, moodleDs);

  final loginUseCase = LoginUseCase(authRepo);
  final releaseUseCase = ReleaseQuestionUseCase(quizRepo);
  final closeUseCase = CloseQuestionUseCase(quizRepo);

  final authCtrl = AuthController(
    loginUseCase: loginUseCase,
    repository: authRepo,
  );

  await authCtrl.loadSavedSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authCtrl),
        ChangeNotifierProvider(
          create: (_) => ProfessorController(
            quizRepo: quizRepo,
            releaseQuestion: releaseUseCase,
            closeQuestion: closeUseCase,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => StudentController(
            quizRepo: quizRepo,
          ),
        ),
      ],
      child: const MoodleQuizApp(),
    ),
  );
}

class MoodleQuizApp extends StatelessWidget {
  const MoodleQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.build(context);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
