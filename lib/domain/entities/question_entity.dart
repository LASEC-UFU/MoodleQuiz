import 'package:equatable/equatable.dart';

import '../../core/utils/moodle_html_parser.dart';

/// Representa uma questão do Moodle já parseada e pronta para exibição.
class QuestionEntity extends Equatable {
  final int slot; // slot Moodle (1-indexed)
  final int page; // página da questão (0-indexed)
  final String text; // enunciado sem tags HTML (fallback)
  final String htmlText; // enunciado como HTML com URLs corrigidas
  final String
      displayHtml; // HTML completo (todos os blocos, sem interativos) — para exibição
  final List<ParsedChoice> choices;
  final List<String> imageUrls;
  final String inputBaseName; // "q{attemptId}:{slot}_answer"
  final String seqCheck; // valor do hidden sequencecheck
  final String
      type; // tipo real do Moodle: "multichoice", "truefalse", "essay", "shortanswer", "match", "numerical", "other", etc.
  final String generalFeedback; // feedback geral da questão (do gabarito)
  final String
      rightAnswerHtml; // HTML da resposta correta (apenas não-multichoice)

  const QuestionEntity({
    required this.slot,
    required this.page,
    required this.text,
    this.htmlText = '',
    this.displayHtml = '',
    required this.choices,
    this.imageUrls = const [],
    required this.inputBaseName,
    required this.seqCheck,
    this.type = 'multichoice',
    this.generalFeedback = '',
    this.rightAnswerHtml = '',
  });

  /// Retorna true para tipos que usam alternativas de rádio (múltipla escolha e V/F).
  bool get isMultiChoice => type == 'multichoice' || type == 'truefalse';

  @override
  List<Object?> get props => [slot];
}
