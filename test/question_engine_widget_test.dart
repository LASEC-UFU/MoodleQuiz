import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moodle_quiz_live/core/utils/moodle_html_parser.dart';
import 'package:moodle_quiz_live/domain/entities/question_entity.dart';
import 'package:moodle_quiz_live/presentation/widgets/question_engine_widget.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('gap prompt falls back to displayHtml when htmlText is empty',
      (tester) async {
    const optionHtml = '''
      <option value="0">Escolha...</option>
      <option value="1">rho</option>
    ''';
    const question = QuestionEntity(
      slot: 3,
      page: 0,
      text: '',
      htmlText: '<div></div>',
      displayHtml:
          '<div class="qtext">Enunciado recuperado <select name="q42:3_p1">$optionHtml</select>.</div>',
      choices: [],
      inputBaseName: 'q42:3_p',
      seqCheck: '1',
      type: 'gapselect',
      gapInputData: GapInputData(
        gapCount: 1,
        inputNamePrefix: 'q42:3_p',
        options: [ParsedChoice(value: '1', text: 'rho')],
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuestionEngineWidget(
            question: question,
            mode: QuestionEngineMode.preview,
            compact: true,
          ),
        ),
      ),
    );

    final renderedText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join(' ');

    expect(renderedText, contains('Enunciado recuperado'));
    expect(renderedText, contains('[1]'));
  });
}
