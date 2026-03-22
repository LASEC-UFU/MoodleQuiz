/// Configurações globais carregadas do Google Sheets.
/// S: Responsabilidade única – apenas armazena config.
class AppConfig {
  static const String appName = 'MoodleQuiz Live';
  static const String version = '1.0.0';

  static String gsheetScriptUrl = '';
  static String moodleBaseUrl = '';
  static String quizTitle = 'Quiz Interativo';
  static int defaultQuestionTime = 30;
  static String teacherToken = '';

  static void loadFromMap(Map<String, dynamic> config) {
    moodleBaseUrl =
        (config['moodle_url'] as String?)?.trim() ?? moodleBaseUrl;
    quizTitle = (config['quiz_title'] as String?) ?? quizTitle;
    defaultQuestionTime =
        int.tryParse(config['default_question_time']?.toString() ?? '') ??
            defaultQuestionTime;
    teacherToken = (config['teacher_token'] as String?) ?? teacherToken;
  }

  static bool get isConfigured => gsheetScriptUrl.isNotEmpty;
}
