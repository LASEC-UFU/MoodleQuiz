import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodle_quiz_live/core/utils/moodle_xml_quiz_parser.dart';

void main() {
  test('parses Moodle XML export into the shared question engine model', () {
    final bytes = File('ININD03_banco_questoes_moodle_24_novo_v2_imagens.xml')
        .readAsBytesSync();

    final questions = MoodleXmlQuizParser.parseQuestions(bytes);

    expect(questions.length, greaterThan(20));

    final multichoice = questions.firstWhere((q) => q.type == 'multichoice');
    expect(multichoice.choices, hasLength(4));
    expect(multichoice.choices.where((c) => c.isCorrect), hasLength(1));

    final match = questions.firstWhere((q) => q.type == 'match');
    expect(match.matchData?.subQuestions, hasLength(4));
    expect(match.matchData?.subQuestions.first.correctValue, '1');

    final gapselect = questions.firstWhere((q) => q.type == 'gapselect');
    expect(gapselect.gapInputData?.gapCount, 4);
    expect(gapselect.answerControls.where((c) => c.isSelect), hasLength(4));

    final ddwtos = questions.firstWhere((q) => q.type == 'ddwtos');
    expect(ddwtos.gapInputData?.gapCount, 4);
    expect(ddwtos.answerControls.where((c) => c.isSelect), hasLength(4));
  });
}
