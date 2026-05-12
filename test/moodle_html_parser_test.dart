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

    test('extracts generic answer controls from Moodle html', () {
      const html = '''
<div class="que multianswer deferredfeedback notyetanswered">
  <div class="qtext">
    <p>Complete os campos:</p>
    <label for="short">Resposta curta</label>
    <input type="text" id="short" name="q42:2_answer" value="">
    <select name="q42:2_sub1">
      <option value="0">Escolha...</option>
      <option value="1">Alpha</option>
      <option value="2">Beta</option>
    </select>
    <label for="essay">Texto</label>
    <textarea id="essay" name="q42:2_answer_text"></textarea>
    <label for="check0">Marcar opcao</label>
    <input type="checkbox" id="check0" name="q42:2_choice0" value="1">
    <span class="questionflag">
      <label for="flag">Marcar questão</label>
      <input type="checkbox" id="flag" name="q42:2_:flagged" value="1">
    </span>
  </div>
  <input type="hidden" name="q42:2_:sequencecheck" value="1">
</div>
''';

      final parsed = MoodleHtmlParser.parse(
        html: html,
        attemptId: 42,
        slot: 2,
        token: 'abc123',
        baseUrl: 'https://moodle.example.edu',
      );

      final controls = {for (final c in parsed.answerControls) c.name: c};
      expect(controls['q42:2_answer']?.type, 'text');
      expect(controls['q42:2_sub1']?.type, 'select');
      expect(controls['q42:2_sub1']?.options.map((o) => o.text),
          ['Alpha', 'Beta']);
      expect(controls['q42:2_answer_text']?.type, 'textarea');
      expect(controls['q42:2_choice0']?.type, 'checkbox');
      expect(controls.containsKey('q42:2_:sequencecheck'), isFalse);
      expect(controls.containsKey('q42:2_:flagged'), isFalse);
    });
  });
}
