import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/moodle_html_parser.dart'
    show MoodleAnswerControl, MoodleHtmlParser, ParsedChoice;
import '../../core/utils/responsive.dart';
import '../../domain/entities/question_entity.dart';
import 'moodle_html_renderer.dart';
import 'option_button.dart';
import 'timer_widget.dart';

enum QuestionEngineMode { answer, preview, reveal }

class QuestionEngineWidget extends StatelessWidget {
  final QuestionEntity question;
  final QuestionEngineMode mode;
  final DateTime? endsAt;
  final Map<String, String> selectedAnswers;
  final bool hasAnswered;
  final bool isSubmitting;
  final bool showCorrect;
  final bool compact;
  final void Function(String inputName, String value)? onSelectAnswer;
  final VoidCallback? onSubmit;

  const QuestionEngineWidget({
    super.key,
    required this.question,
    required this.mode,
    this.endsAt,
    this.selectedAnswers = const {},
    this.hasAnswered = false,
    this.isSubmitting = false,
    this.showCorrect = false,
    this.compact = false,
    this.onSelectAnswer,
    this.onSubmit,
  });

  bool get _isAnswerMode => mode == QuestionEngineMode.answer;

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final textStyle = GoogleFonts.nunito(
      fontSize: compact ? 14 : (isMobile ? 16 : 18),
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
      height: 1.5,
    );

    final children = <Widget>[
      if (_isAnswerMode) ...[
        _buildTimer(),
        SizedBox(height: compact ? 10 : 16),
      ],
      _buildQuestionPrompt(textStyle),
      SizedBox(height: compact ? 10 : 16),
      ..._buildAnswerSurface(textStyle),
      if (_isAnswerMode) ...[
        SizedBox(height: compact ? 12 : 20),
        _buildSubmitButton(_hasAnswer),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildTimer() {
    if (endsAt != null) return TimerWidget(endsAt: endsAt!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecoration(),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: AppTheme.warning, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'O cronometro vai comecar quando a primeira resposta for enviada.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPrompt(TextStyle textStyle) {
    final html = _promptHtml;
    final content = html.isNotEmpty
        ? MoodleHtmlRenderer(html: html, textStyle: textStyle)
        : Text(question.text, style: textStyle);

    if (compact) return content;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(glowing: _isAnswerMode),
      child: content,
    );
  }

  String get _promptHtml {
    if (question.isMultiChoice && question.choices.isNotEmpty) {
      return question.htmlText;
    }
    if (_isAnswerMode &&
        (question.isGapSelect || question.isDdwtos) &&
        question.gapInputData != null) {
      return MoodleHtmlParser.extractTextWithGapMarkers(
        question.htmlText.isNotEmpty ? question.htmlText : question.displayHtml,
        '',
        '',
      );
    }
    return question.displayHtml.isNotEmpty
        ? question.displayHtml
        : question.htmlText;
  }

  List<Widget> _buildAnswerSurface(TextStyle textStyle) {
    if (question.isMultiChoice && question.choices.isNotEmpty) {
      return _isAnswerMode
          ? _buildChoiceInputs()
          : _buildStaticChoices(choices: question.choices);
    }

    final checkboxControls = _answerableControls
        .where((c) => c.isMultipleChoice)
        .toList(growable: false);
    if (checkboxControls.isNotEmpty) {
      return _isAnswerMode
          ? [_buildCheckboxInputs(checkboxControls)]
          : [_buildStaticCheckboxes(checkboxControls)];
    }

    if (question.isMatch && question.matchData != null) {
      return _isAnswerMode
          ? [_buildMatchInputs(textStyle)]
          : [_buildStaticMatch(textStyle)];
    }

    if ((question.isGapSelect || question.isDdwtos) &&
        question.gapInputData != null) {
      return _isAnswerMode
          ? [_buildGapInputs()]
          : _buildStaticGapAnswer(textStyle);
    }

    final genericControls = _genericControls;
    if (genericControls.isNotEmpty) {
      return _isAnswerMode
          ? [_buildGenericControls(genericControls)]
          : [_buildStaticGenericControls(genericControls)];
    }

    if (!_isAnswerMode && showCorrect && question.rightAnswerHtml.isNotEmpty) {
      return [_buildRightAnswerCard(textStyle)];
    }

    if (_isAnswerMode) {
      return [
        _buildInfoBanner(
          icon: Icons.info_outline_rounded,
          color: AppTheme.warning,
          message:
              'Este tipo de questao nao expos campos de resposta pela API. O enunciado foi aberto neste app, mas nao ha campos para envio.',
        ),
      ];
    }

    return const [];
  }

  List<MoodleAnswerControl> get _answerableControls =>
      question.answerControls.where((c) => c.isAnswerable).toList();

  List<MoodleAnswerControl> get _genericControls {
    final controls = _answerableControls.where((c) {
      if (c.isMultipleChoice) return false;
      if (question.isMatch && question.matchData != null) {
        return !question.matchData!.subQuestions
            .any((s) => s.inputName == c.name);
      }
      final gap = question.gapInputData;
      if (gap != null && c.name.startsWith(gap.inputNamePrefix)) {
        return false;
      }
      if (question.isMultiChoice && question.choices.isNotEmpty) return false;
      return true;
    }).toList();

    if (controls.isEmpty &&
        (question.isNumerical || question.isShortAnswer) &&
        question.answerInputName != null) {
      return [
        MoodleAnswerControl(
          name: question.answerInputName!,
          type: question.isNumerical ? 'number' : 'text',
        ),
      ];
    }

    return controls;
  }

  bool get _hasAnswer {
    if (question.isMultiChoice && question.choices.isNotEmpty) {
      return (selectedAnswers[question.inputBaseName] ?? '').isNotEmpty;
    }

    final checkboxControls = _answerableControls
        .where((c) => c.isMultipleChoice)
        .toList(growable: false);
    if (checkboxControls.isNotEmpty) {
      return checkboxControls.any(
        (c) => (selectedAnswers[c.name] ?? '').isNotEmpty,
      );
    }

    if (question.isMatch && question.matchData != null) {
      return question.matchData!.subQuestions.every(
        (s) => (selectedAnswers[s.inputName] ?? '').isNotEmpty,
      );
    }

    final gap = question.gapInputData;
    if ((question.isGapSelect || question.isDdwtos) && gap != null) {
      return List.generate(gap.gapCount, (i) => gap.inputName(i + 1)).every(
        (name) => (selectedAnswers[name] ?? '').isNotEmpty,
      );
    }

    final controls = _genericControls;
    if (controls.isNotEmpty) {
      return controls.where((c) => !c.isMultipleChoice).every(
            (c) => (selectedAnswers[c.name] ?? '').trim().isNotEmpty,
          );
    }

    return selectedAnswers.values.any((v) => v.trim().isNotEmpty);
  }

  List<Widget> _buildChoiceInputs() {
    final selected = selectedAnswers[question.inputBaseName];
    return question.choices.asMap().entries.map((entry) {
      final index = entry.key;
      final choice = entry.value;
      final letter = index < _letters.length ? _letters[index] : '${index + 1}';
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OptionButton(
          label: letter,
          text: choice.text,
          htmlText: choice.htmlText,
          isSelected: selected == choice.value,
          isDisabled: hasAnswered,
          onTap: () =>
              onSelectAnswer?.call(question.inputBaseName, choice.value),
        ),
      );
    }).toList();
  }

  List<Widget> _buildStaticChoices({required List<ParsedChoice> choices}) {
    return choices.asMap().entries.map((entry) {
      final index = entry.key;
      final choice = entry.value;
      final letter = index < _letters.length ? _letters[index] : '${index + 1}';
      final correct = showCorrect && choice.isCorrect;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: correct
              ? AppTheme.success.withValues(alpha: 0.18)
              : AppTheme.bgCardAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: correct ? AppTheme.success : AppTheme.bgCardAlt,
            width: correct ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _badge(letter, correct),
            const SizedBox(width: 10),
            Expanded(
              child: choice.htmlText.isNotEmpty
                  ? MoodleHtmlRenderer(
                      html: choice.htmlText,
                      textStyle: TextStyle(
                        color:
                            correct ? AppTheme.success : AppTheme.textPrimary,
                        fontSize: compact ? 13 : 16,
                        fontWeight: correct ? FontWeight.w700 : FontWeight.w500,
                        height: 1.4,
                      ),
                    )
                  : Text(
                      choice.text,
                      style: TextStyle(
                        color:
                            correct ? AppTheme.success : AppTheme.textPrimary,
                        fontSize: compact ? 13 : 16,
                        fontWeight: correct ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
            ),
            if (correct) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 20),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _badge(String text, bool correct) {
    final size = compact ? 26.0 : 34.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: correct ? AppTheme.success : AppTheme.bgDark,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: correct ? Colors.white : AppTheme.textSecondary,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 12 : 15,
        ),
      ),
    );
  }

  Widget _buildCheckboxInputs(List<MoodleAnswerControl> controls) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: controls.map((control) {
          final selected = selectedAnswers[control.name] == control.value;
          return CheckboxListTile(
            value: selected,
            onChanged: hasAnswered
                ? null
                : (next) => onSelectAnswer?.call(
                      control.name,
                      next == true ? control.value : '',
                    ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppTheme.primary,
            title: _controlLabel(control),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStaticCheckboxes(List<MoodleAnswerControl> controls) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: AppTheme.cardDecoration(color: AppTheme.bgCardAlt),
      child: Column(
        children: controls
            .map(
              (control) => Row(
                children: [
                  const Icon(Icons.check_box_outline_blank_rounded,
                      color: AppTheme.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: _controlLabel(control)),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMatchInputs(TextStyle textStyle) {
    final matchData = question.matchData!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: matchData.subQuestions.asMap().entries.map((entry) {
          final index = entry.key;
          final sub = entry.value;
          final selected = selectedAnswers[sub.inputName];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _badge('${index + 1}', false),
                    const SizedBox(width: 10),
                    Expanded(
                      child: sub.htmlText.isNotEmpty
                          ? MoodleHtmlRenderer(
                              html: sub.htmlText,
                              textStyle: textStyle.copyWith(fontSize: 15),
                            )
                          : Text(sub.text, style: textStyle),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _dropdown(
                  value: selected,
                  options: matchData.options,
                  hint: 'Escolha uma opcao...',
                  onChanged: (value) => onSelectAnswer?.call(
                    sub.inputName,
                    value ?? '',
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStaticMatch(TextStyle textStyle) {
    final matchData = question.matchData;
    if (matchData == null || matchData.subQuestions.isEmpty) {
      return showCorrect && question.rightAnswerHtml.isNotEmpty
          ? _buildRightAnswerCard(textStyle)
          : const SizedBox.shrink();
    }

    final optionText = {for (final o in matchData.options) o.value: o.text};
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.bgCardAlt),
      ),
      child: Column(
        children: matchData.subQuestions.map((sub) {
          final answer = sub.correctValue != null
              ? optionText[sub.correctValue] ?? ''
              : '';
          return Padding(
            padding: EdgeInsets.all(compact ? 10 : 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: sub.htmlText.isNotEmpty
                      ? MoodleHtmlRenderer(
                          html: sub.htmlText,
                          textStyle:
                              textStyle.copyWith(fontSize: compact ? 12 : 14),
                        )
                      : Text(sub.text, style: textStyle),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: AppTheme.accent, size: 16),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    showCorrect && answer.isNotEmpty ? answer : '______',
                    style: TextStyle(
                      color: showCorrect
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                      fontSize: compact ? 12 : 14,
                      fontWeight:
                          showCorrect ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGapInputs() {
    final gap = question.gapInputData!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(gap.gapCount, (index) {
          final gapNum = index + 1;
          final inputName = gap.inputName(gapNum);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                _badge('[$gapNum]', false),
                const SizedBox(width: 10),
                Expanded(
                  child: _dropdown(
                    value: selectedAnswers[inputName],
                    options: gap.options,
                    hint: 'Escolha uma palavra...',
                    onChanged: (value) => onSelectAnswer?.call(
                      inputName,
                      value ?? '',
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildStaticGapAnswer(TextStyle textStyle) {
    if (showCorrect && question.rightAnswerHtml.isNotEmpty) {
      return [_buildRightAnswerCard(textStyle)];
    }
    return [
      _buildInfoBanner(
        icon: Icons.edit_note_rounded,
        color: AppTheme.accent,
        message: question.isDdwtos
            ? 'Arrastar e soltar palavras - respondido neste app com seletores.'
            : 'Selecionar palavras - lacunas respondidas neste app.',
      ),
    ];
  }

  Widget _buildGenericControls(List<MoodleAnswerControl> controls) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: controls.map((control) {
          if (control.isSelect || control.isSingleChoice) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _labeledField(
                control,
                _dropdown(
                  value: selectedAnswers[control.name],
                  options: control.options,
                  hint: 'Escolha uma opcao...',
                  onChanged: (value) => onSelectAnswer?.call(
                    control.name,
                    value ?? '',
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _labeledField(
              control,
              TextFormField(
                initialValue: selectedAnswers[control.name] ?? control.value,
                enabled: !hasAnswered,
                minLines: control.isLongText ? 4 : 1,
                maxLines: control.isLongText ? 8 : 1,
                keyboardType:
                    control.type == 'number' ? TextInputType.number : null,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Digite sua resposta...',
                ),
                onChanged: (value) => onSelectAnswer?.call(
                  control.name,
                  value.trim(),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStaticGenericControls(List<MoodleAnswerControl> controls) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: AppTheme.cardDecoration(color: AppTheme.bgCardAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...controls.map((control) {
            if (control.isSelect || control.isSingleChoice) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _labeledField(
                  control,
                  Text(
                    control.options.map((o) => o.text).join(' / '),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _labeledField(
                control,
                Container(
                  height: control.isLongText ? 80 : 38,
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.bgCardAlt),
                  ),
                ),
              ),
            );
          }),
          if (showCorrect && question.rightAnswerHtml.isNotEmpty)
            _buildRightAnswerCard(
              TextStyle(
                color: AppTheme.success,
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _labeledField(MoodleAnswerControl control, Widget field) {
    final hasLabel = control.label.isNotEmpty || control.htmlLabel.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasLabel) ...[
          DefaultTextStyle(
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
            child: _controlLabel(control),
          ),
          const SizedBox(height: 8),
        ],
        field,
      ],
    );
  }

  Widget _controlLabel(MoodleAnswerControl control) {
    if (control.htmlLabel.isNotEmpty) {
      return MoodleHtmlRenderer(
        html: control.htmlLabel,
        textStyle: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: compact ? 13 : 15,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Text(
      control.label.isNotEmpty ? control.label : 'Resposta',
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontSize: compact ? 13 : 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required List<ParsedChoice> options,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    final selected = options.any((o) => o.value == value) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.bgCardAlt),
      ),
      child: DropdownButton<String>(
        value: selected,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AppTheme.bgCard,
        hint: Text(
          hint,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option.value,
                child: Text(
                  option.text,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
              ),
            )
            .toList(),
        onChanged: hasAnswered ? null : onChanged,
      ),
    );
  }

  Widget _buildSubmitButton(bool hasAnswer) {
    if (hasAnswered) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppTheme.success),
            SizedBox(width: 8),
            Text(
              'Resposta enviada! Aguardando resultado...',
              style: TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: (hasAnswer && !isSubmitting) ? onSubmit : null,
      icon: isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.send_rounded),
      label: Text(isSubmitting ? 'Enviando...' : 'Confirmar resposta'),
      style: ElevatedButton.styleFrom(
        backgroundColor: hasAnswer
            ? AppTheme.success
            : AppTheme.primary.withValues(alpha: 0.5),
        minimumSize: const Size(double.infinity, 52),
      ),
    );
  }

  Widget _buildRightAnswerCard(TextStyle textStyle) {
    if (question.rightAnswerHtml.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppTheme.success, size: compact ? 16 : 20),
          const SizedBox(width: 10),
          Expanded(
            child: MoodleHtmlRenderer(
              html: question.rightAnswerHtml,
              textStyle: textStyle.copyWith(
                color: AppTheme.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
