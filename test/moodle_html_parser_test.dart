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
              'https://moodle.example.edu/webservice/pluginfile.php/99/answer.png?token=abc123'));
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

    test('repairs malformed TeX gaps before counting and rendering markers',
        () {
      const optionHtml = '''
        <option value="0">Escolha...</option>
        <option value="1">fluido incompressivel</option>
        <option value="2">rho</option>
      ''';
      const html = '''
<div class="que gapselect deferredfeedback notyetanswered">
  <div class="formulation">
    <div class="qtext">
      \\Delta P = <span class=Em branco 1 Questao 3
        <select name="q42:3_p1">$optionHtml</select>
        · Em branco 2 Questao 3 <select name="q42:3_p2">$optionHtml</select>
        · Em branco 3 Questao 3 <select name="q42:3_p3">$optionHtml</select>
        " alt="\\Delta P = Em branco 1 Questao 3
        <select name="q42:3_dup1">$optionHtml</select>
        · Em branco 2 Questao 3 <select name="q42:3_dup2">$optionHtml</select>
        · Em branco 3 Questao 3 <select name="q42:3_dup3">$optionHtml</select>"
        src="https://moodle.ufu.br/filter/tex/pix.php/hash.gif" />
      A relacao pressupoe fluido em Em branco 4 Questao 3
      <select name="q42:3_p4">$optionHtml</select>
      e comparacao entre pontos pertencentes ao Em branco 5 Questao 3
      <select name="q42:3_p5">$optionHtml</select>.
    </div>
  </div>
</div>
''';

      final parsed = MoodleHtmlParser.parse(
        html: html,
        attemptId: 42,
        slot: 3,
        token: 'abc123',
        baseUrl: 'https://moodle.example.edu',
      );
      final prompt = MoodleHtmlParser.extractTextWithGapMarkers(
        html,
        'abc123',
        'https://moodle.example.edu',
      );

      expect(parsed.gapInputData?.gapCount, 5);
      expect(prompt, isNot(contains('src=')));
      expect(prompt, isNot(contains('alt=')));
      expect(prompt, isNot(contains('<span class=Em')));
      expect(prompt, isNot(contains('Em branco 1 Questao 3')));
      expect(prompt, isNot(contains('Em branco 4 Questao 3')));
      expect(prompt, contains('[1]'));
      expect(prompt, contains('[5]'));
      expect(prompt, isNot(contains('[6]')));
    });

    test('does not let quiz header metadata leak into gap prompt', () {
      const optionHtml = '''
        <option value="0">Escolha...</option>
        <option value="1">fluido incompressivel</option>
        <option value="2">rho</option>
      ''';
      const html = '''
<div class="que gapselect deferredfeedback notyetanswered">
  <div class="info">
    <h3 class="no">Questão <span class="qno">3</span></h3>
    <div class="state">Incompleto</div>
    <div class="grade">Vale 1,00 ponto(s).</div>
  </div>
  <div class="formulation">
    <div class="qtext">
      Complete a análise técnica.
      \\Delta P = <span class=Em branco 1 Questão 3
        <select name="q42:3_p1">$optionHtml</select>
        · Em branco 2 Questão 3 <select name="q42:3_p2">$optionHtml</select>
        · Em branco 3 Questão 3 <select name="q42:3_p3">$optionHtml</select>
        " alt="\\Delta P = Em branco 1 Questão 3
        <select name="q42:3_dup1">$optionHtml</select>
        · Em branco 2 Questão 3 <select name="q42:3_dup2">$optionHtml</select>
        · Em branco 3 Questão 3 <select name="q42:3_dup3">$optionHtml</select>"
        src="https://moodle.ufu.br/filter/tex/pix.php/hash.gif" />
      A relação pressupõe fluido em Em branco 4 Questão 3
      <select name="q42:3_p4">$optionHtml</select>.
      <button>Verificar Questão 3</button>
    </div>
  </div>
</div>
''';

      final parsed = MoodleHtmlParser.parse(
        html: html,
        attemptId: 42,
        slot: 3,
        token: 'abc123',
        baseUrl: 'https://moodle.example.edu',
      );
      final prompt = MoodleHtmlParser.extractTextWithGapMarkers(
        html,
        'abc123',
        'https://moodle.example.edu',
      );

      expect(parsed.gapInputData?.gapCount, 4);
      expect(prompt, contains('Complete a análise técnica'));
      expect(prompt, isNot(contains('"qno">3')));
      expect(prompt, isNot(contains('Incompleto')));
      expect(prompt, isNot(contains('Vale 1,00')));
      expect(prompt, isNot(contains('Verificar Questão 3')));
      expect(prompt, isNot(contains('Em branco 1 Questão 3')));
      expect(prompt, isNot(contains('Em branco 4 Questão 3')));
      expect(prompt, contains('[1]'));
      expect(prompt, contains('[4]'));
      expect(prompt, isNot(contains('[5]')));
    });

    test('strips malformed TeX shell that remains after gap markers', () {
      const html = '''
<div class="qtext">
  \\Delta P = <span class=
    <span style="color:red">[1]</span> ·
    <span style="color:red">[2]</span> ·
    <span style="color:red">[3]</span>
    " alt="\\AP =
    <span style="color:red">[4]</span> ·
    <span style="color:red">[5]</span> ·
    <span style="color:red">[6]</span>"
    src="https://moodle.ufu.br/filter/tex/pix.php/hash.gif" />
  A relação pressupõe fluido em <span>[7]</span>.
</div>
''';

      final prompt = MoodleHtmlParser.extractTextWithGapMarkers(
        html,
        'abc123',
        'https://moodle.example.edu',
      );

      expect(prompt, isNot(contains('<span class=')));
      expect(prompt, isNot(contains('alt=')));
      expect(prompt, isNot(contains('src=')));
      expect(prompt, contains('[1]'));
      expect(prompt, contains('[2]'));
      expect(prompt, contains('[3]'));
      expect(prompt, isNot(contains('[4]')));
      expect(prompt, isNot(contains('[6]')));
      expect(prompt, contains('[7]'));
    });
  });
}
