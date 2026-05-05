import 'package:flutter_test/flutter_test.dart';
import 'package:moodle_quiz_live/core/utils/moodle_html_parser.dart';

void main() {
  group('MoodleHtmlParser', () {
    test('preserves Moodle images in question text and choices', () {
      const html = '''
<div class="qtext">
  <p>Observe a figura:</p>
  <img src="@@PLUGINFILE@@/question.png" alt="Figura da questão">
</div>
<div class="answer">
  <div class="r0">
    <input type="radio" name="q42:1_answer" value="0" id="q42_1_0" aria-labelledby="q42_1_0_label">
    <div>
      <div id="q42_1_0_label" data-region="answer-label">
        <span class="answernumber">a. </span>
        <p>Alternativa com figura</p>
        <img src="/pluginfile.php/99/answer.png" alt="Figura da alternativa">
      </div>
    </div>
  </div>
</div>
<input type="hidden" name="q42:1_:sequencecheck" value="1">
''';

      final parsed = MoodleHtmlParser.parse(
        html: html,
        attemptId: 42,
        slot: 1,
        token: 'abc123',
        baseUrl: 'https://moodle.example.edu',
      );

      expect(parsed.htmlText,
          contains('webservice/pluginfile.php/question.png?token=abc123'));
      expect(parsed.choices, hasLength(1));
      expect(parsed.choices.single.text, 'Alternativa com figura');
      expect(
          parsed.choices.single.htmlText, contains('Alternativa com figura'));
      expect(
          parsed.choices.single.htmlText,
          contains(
              'https://moodle.example.edu/pluginfile.php/99/answer.png?token=abc123'));
    });
  });
}
