import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/moodle_html_parser.dart' show MatchData;
import '../../../core/utils/responsive.dart';
import '../../../domain/entities/question_entity.dart';
import '../../widgets/timer_widget.dart';
import '../../widgets/option_button.dart';
import '../../widgets/moodle_html.dart';

/// Tela de resposta de questão – usada inline dentro do lobby do estudante.
/// Suporta todos os tipos de questão do Moodle com widgets Flutter dedicados.
class StudentQuestionPage extends StatelessWidget {
  final QuestionEntity question;
  final DateTime? endsAt;
  final Map<String, String> selectedAnswers;
  final bool hasAnswered;
  final bool isSubmitting;

  /// Callback unificado para registrar uma resposta.
  /// Para multichoice: onSelectAnswer(question.inputBaseName, choiceValue)
  /// Para match: onSelectAnswer(subQuestion.inputName, optionValue)
  /// Para numerical/shortanswer: onSelectAnswer(question.answerInputName, text)
  final void Function(String inputName, String value) onSelectAnswer;
  final VoidCallback onSubmit;

  const StudentQuestionPage({
    super.key,
    required this.question,
    required this.endsAt,
    required this.selectedAnswers,
    required this.hasAnswered,
    required this.isSubmitting,
    required this.onSelectAnswer,
    required this.onSubmit,
  });

  // Retrocompatibilidade: valor selecionado para multichoice
  String? get _selectedChoice => selectedAnswers[question.inputBaseName];

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  Widget _buildHtml(String html, TextStyle textStyle) =>
      MoodleHtml(html: html, textStyle: textStyle);

  Widget _buildTimer() {
    if (endsAt != null) return TimerWidget(endsAt: endsAt!).animate().fadeIn();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecoration(),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: AppTheme.warning, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'O cronômetro vai começar quando a primeira resposta for enviada.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildAnsweredCard() {
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
                color: AppTheme.success, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.elasticOut);
  }

  Widget _buildSubmitButton(bool hasAnswer, BuildContext context) {
    if (hasAnswered) return _buildAnsweredCard();
    return ElevatedButton.icon(
      onPressed: (hasAnswer && !isSubmitting) ? onSubmit : null,
      icon: isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.send_rounded),
      label: Text(isSubmitting ? 'Enviando...' : 'Confirmar Resposta'),
      style: ElevatedButton.styleFrom(
        backgroundColor: hasAnswer
            ? AppTheme.success
            : AppTheme.primary.withValues(alpha: 0.5),
        minimumSize: const Size(double.infinity, 52),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  // ── Roteamento ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (question.isMultiChoice) return _buildMultiChoiceView(context);
    if (question.isNumerical) return _buildNumericalView(context);
    if (question.isShortAnswer) return _buildShortAnswerView(context);
    if (question.isMatch) return _buildMatchView(context);
    if (question.isGapSelect || question.isDdwtos) {
      return _buildGapDisplayView(context);
    }
    return _buildReadOnlyView(context);
  }

  // ── Múltipla escolha / V-F ──────────────────────────────────────────────────

  Widget _buildMultiChoiceView(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final textStyle = GoogleFonts.nunito(
      fontSize: isMobile ? 16 : 18,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
      height: 1.5,
    );

    return SingleChildScrollView(
      padding:
          Responsive.horizontalPadding(context).copyWith(top: 12, bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTimer(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(glowing: true),
                child: question.htmlText.isNotEmpty
                    ? _buildHtml(question.htmlText, textStyle)
                    : Text(question.text,
                        style: GoogleFonts.nunito(
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),
              ...question.choices.asMap().entries.map((e) {
                final index = e.key;
                final choice = e.value;
                final letter =
                    index < _letters.length ? _letters[index] : '${index + 1}';
                final isSelected = _selectedChoice == choice.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OptionButton(
                    label: letter,
                    text: choice.text,
                    htmlText: choice.htmlText,
                    isSelected: isSelected,
                    isDisabled: hasAnswered,
                    onTap: () =>
                        onSelectAnswer(question.inputBaseName, choice.value),
                  )
                      .animate(delay: Duration(milliseconds: index * 80))
                      .slideX(begin: 0.3, duration: 350.ms, curve: Curves.easeOut)
                      .fadeIn(),
                );
              }),
              const SizedBox(height: 20),
              _buildSubmitButton(_selectedChoice != null, context),
            ],
          ),
        ),
      ),
    );
  }

  // ── Numérica / Calculada ────────────────────────────────────────────────────

  Widget _buildNumericalView(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final inputName =
        question.answerInputName ?? question.inputBaseName;
    final currentValue = selectedAnswers[inputName] ?? '';

    return _NumericalInput(
      question: question,
      endsAt: endsAt,
      inputName: inputName,
      currentValue: currentValue,
      hasAnswered: hasAnswered,
      isSubmitting: isSubmitting,
      isMobile: isMobile,
      onSelectAnswer: onSelectAnswer,
      onSubmit: onSubmit,
      buildTimer: _buildTimer,
      buildHtml: _buildHtml,
      buildSubmitButton: _buildSubmitButton,
    );
  }

  // ── Resposta curta (ShortAnswer) ────────────────────────────────────────────

  Widget _buildShortAnswerView(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final inputName =
        question.answerInputName ?? question.inputBaseName;
    final currentValue = selectedAnswers[inputName] ?? '';

    return _ShortAnswerInput(
      question: question,
      endsAt: endsAt,
      inputName: inputName,
      currentValue: currentValue,
      hasAnswered: hasAnswered,
      isSubmitting: isSubmitting,
      isMobile: isMobile,
      onSelectAnswer: onSelectAnswer,
      onSubmit: onSubmit,
      buildTimer: _buildTimer,
      buildHtml: _buildHtml,
      buildSubmitButton: _buildSubmitButton,
    );
  }

  // ── Associação (Match) ──────────────────────────────────────────────────────

  Widget _buildMatchView(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final matchData = question.matchData;

    if (matchData == null) return _buildReadOnlyView(context);

    return _MatchInput(
      question: question,
      matchData: matchData,
      endsAt: endsAt,
      selectedAnswers: selectedAnswers,
      hasAnswered: hasAnswered,
      isSubmitting: isSubmitting,
      isMobile: isMobile,
      onSelectAnswer: onSelectAnswer,
      onSubmit: onSubmit,
      buildTimer: _buildTimer,
      buildHtml: _buildHtml,
      buildSubmitButton: _buildSubmitButton,
    );
  }

  // ── GapSelect / DDwtos: exibe com banco de palavras visível ────────────────

  Widget _buildGapDisplayView(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final textStyle = GoogleFonts.nunito(
      fontSize: isMobile ? 16 : 18,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
      height: 1.5,
    );
    final html = question.displayHtml.isNotEmpty
        ? question.displayHtml
        : question.htmlText;

    return SingleChildScrollView(
      padding:
          Responsive.horizontalPadding(context).copyWith(top: 12, bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTimer(),
              const SizedBox(height: 12),
              _buildInfoBanner(
                icon: Icons.edit_note_rounded,
                color: AppTheme.accent,
                message: question.isDdwtos
                    ? 'Arraste as palavras para as lacunas no Moodle ou confira o enunciado abaixo.'
                    : 'Selecione as palavras que faltam para completar o texto abaixo.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(glowing: true),
                child: html.isNotEmpty
                    ? _buildHtml(html, textStyle)
                    : Text(question.text, style: textStyle),
              ).animate().fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  // ── Somente leitura (Cloze, GeoGebra, Ordenação, DDImage, Essay…) ──────────

  Widget _buildReadOnlyView(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final textStyle = GoogleFonts.nunito(
      fontSize: isMobile ? 16 : 18,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
      height: 1.5,
    );
    final html = question.displayHtml.isNotEmpty
        ? question.displayHtml
        : question.htmlText;

    String message;
    IconData icon;
    if (question.isGeoGebra) {
      icon = Icons.open_in_browser_rounded;
      message =
          'Esta questão usa um applet GeoGebra. Acesse o Moodle para interagir.';
    } else if (question.isDdImage) {
      icon = Icons.touch_app_rounded;
      message =
          'Questão de arrastar e soltar em imagem. Acesse o Moodle para responder.';
    } else if (question.isOrdering) {
      icon = Icons.sort_rounded;
      message =
          'Questão de ordenação. Acompanhe o enunciado e responda no Moodle.';
    } else if (question.isCloze) {
      icon = Icons.text_fields_rounded;
      message =
          'Questão com respostas embutidas (Cloze). Acesse o Moodle para preencher.';
    } else if (question.isEssay) {
      icon = Icons.description_rounded;
      message = 'Questão dissertativa. Elabore sua resposta no Moodle.';
    } else {
      icon = Icons.info_outline_rounded;
      message =
          'Questão para visualização — acompanhe o enunciado e interaja conforme orientação do professor.';
    }

    return SingleChildScrollView(
      padding:
          Responsive.horizontalPadding(context).copyWith(top: 12, bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTimer(),
              const SizedBox(height: 12),
              _buildInfoBanner(icon: icon, color: AppTheme.accent, message: message),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(glowing: true),
                child: html.isNotEmpty
                    ? _buildHtml(html, textStyle)
                    : Text(question.text,
                        style: GoogleFonts.nunito(
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center),
              ).animate().fadeIn(duration: 400.ms),
            ],
          ),
        ),
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
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

// ── Widget de input numérico (stateful) ────────────────────────────────────────

class _NumericalInput extends StatefulWidget {
  final QuestionEntity question;
  final DateTime? endsAt;
  final String inputName;
  final String currentValue;
  final bool hasAnswered;
  final bool isSubmitting;
  final bool isMobile;
  final void Function(String, String) onSelectAnswer;
  final VoidCallback onSubmit;
  final Widget Function() buildTimer;
  final Widget Function(String, TextStyle) buildHtml;
  final Widget Function(bool, BuildContext) buildSubmitButton;

  const _NumericalInput({
    required this.question,
    required this.endsAt,
    required this.inputName,
    required this.currentValue,
    required this.hasAnswered,
    required this.isSubmitting,
    required this.isMobile,
    required this.onSelectAnswer,
    required this.onSubmit,
    required this.buildTimer,
    required this.buildHtml,
    required this.buildSubmitButton,
  });

  @override
  State<_NumericalInput> createState() => _NumericalInputState();
}

class _NumericalInputState extends State<_NumericalInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.nunito(
      fontSize: widget.isMobile ? 16 : 18,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
      height: 1.5,
    );

    return SingleChildScrollView(
      padding:
          Responsive.horizontalPadding(context).copyWith(top: 12, bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.buildTimer(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(glowing: true),
                child: widget.question.htmlText.isNotEmpty
                    ? widget.buildHtml(widget.question.htmlText, textStyle)
                    : Text(widget.question.text, style: textStyle),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sua resposta numérica:',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      enabled: !widget.hasAnswered,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,\-+eE]')),
                      ],
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: widget.isMobile ? 20 : 24,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Digite o valor numérico...',
                        hintStyle: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14),
                        filled: true,
                        fillColor: AppTheme.bgDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppTheme.bgCardAlt),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: _controller.text.isNotEmpty && !widget.hasAnswered
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: AppTheme.textSecondary),
                                onPressed: () {
                                  _controller.clear();
                                  widget.onSelectAnswer(widget.inputName, '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) {
                        widget.onSelectAnswer(widget.inputName, v.trim());
                      },
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 20),
              widget.buildSubmitButton(_controller.text.trim().isNotEmpty, context),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget de resposta curta (stateful) ────────────────────────────────────────

class _ShortAnswerInput extends StatefulWidget {
  final QuestionEntity question;
  final DateTime? endsAt;
  final String inputName;
  final String currentValue;
  final bool hasAnswered;
  final bool isSubmitting;
  final bool isMobile;
  final void Function(String, String) onSelectAnswer;
  final VoidCallback onSubmit;
  final Widget Function() buildTimer;
  final Widget Function(String, TextStyle) buildHtml;
  final Widget Function(bool, BuildContext) buildSubmitButton;

  const _ShortAnswerInput({
    required this.question,
    required this.endsAt,
    required this.inputName,
    required this.currentValue,
    required this.hasAnswered,
    required this.isSubmitting,
    required this.isMobile,
    required this.onSelectAnswer,
    required this.onSubmit,
    required this.buildTimer,
    required this.buildHtml,
    required this.buildSubmitButton,
  });

  @override
  State<_ShortAnswerInput> createState() => _ShortAnswerInputState();
}

class _ShortAnswerInputState extends State<_ShortAnswerInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.nunito(
      fontSize: widget.isMobile ? 16 : 18,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
      height: 1.5,
    );

    return SingleChildScrollView(
      padding:
          Responsive.horizontalPadding(context).copyWith(top: 12, bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.buildTimer(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(glowing: true),
                child: widget.question.htmlText.isNotEmpty
                    ? widget.buildHtml(widget.question.htmlText, textStyle)
                    : Text(widget.question.text, style: textStyle),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sua resposta:',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      enabled: !widget.hasAnswered,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: widget.isMobile ? 16 : 18,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Digite sua resposta...',
                        hintStyle: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14),
                        filled: true,
                        fillColor: AppTheme.bgDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppTheme.bgCardAlt),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (v) {
                        widget.onSelectAnswer(widget.inputName, v);
                      },
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 20),
              widget.buildSubmitButton(_controller.text.isNotEmpty, context),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget de Associação / Match (stateful) ────────────────────────────────────

class _MatchInput extends StatelessWidget {
  final QuestionEntity question;
  final MatchData matchData;
  final DateTime? endsAt;
  final Map<String, String> selectedAnswers;
  final bool hasAnswered;
  final bool isSubmitting;
  final bool isMobile;
  final void Function(String, String) onSelectAnswer;
  final VoidCallback onSubmit;
  final Widget Function() buildTimer;
  final Widget Function(String, TextStyle) buildHtml;
  final Widget Function(bool, BuildContext) buildSubmitButton;

  const _MatchInput({
    required this.question,
    required this.matchData,
    required this.endsAt,
    required this.selectedAnswers,
    required this.hasAnswered,
    required this.isSubmitting,
    required this.isMobile,
    required this.onSelectAnswer,
    required this.onSubmit,
    required this.buildTimer,
    required this.buildHtml,
    required this.buildSubmitButton,
  });

  bool get _allAnswered =>
      matchData.subQuestions.every((sq) => selectedAnswers.containsKey(sq.inputName));

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.nunito(
      fontSize: isMobile ? 16 : 18,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
      height: 1.5,
    );

    return SingleChildScrollView(
      padding:
          Responsive.horizontalPadding(context).copyWith(top: 12, bottom: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildTimer(),
              const SizedBox(height: 16),
              // Enunciado
              if (question.htmlText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(glowing: true),
                  child: buildHtml(question.htmlText, textStyle),
                ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // Pares de associação
              ...matchData.subQuestions.asMap().entries.map((e) {
                final idx = e.key;
                final sub = e.value;
                final selected = selectedAnswers[sub.inputName];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected != null
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected != null
                          ? AppTheme.primary.withValues(alpha: 0.5)
                          : AppTheme.bgCardAlt,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premissa
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: sub.htmlText.isNotEmpty
                                ? buildHtml(sub.htmlText,
                                    textStyle.copyWith(fontSize: isMobile ? 14 : 16))
                                : Text(sub.text,
                                    style: textStyle.copyWith(
                                        fontSize: isMobile ? 14 : 16)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Dropdown
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.bgDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected != null
                                ? AppTheme.primary.withValues(alpha: 0.6)
                                : AppTheme.bgCardAlt,
                            width: selected != null ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: DropdownButton<String>(
                          value: selected,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          dropdownColor: AppTheme.bgCard,
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 14),
                          hint: const Text(
                            'Escolha uma opção...',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          items: matchData.options
                              .map((opt) => DropdownMenuItem<String>(
                                    value: opt.value,
                                    child: Text(opt.text,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: hasAnswered
                              ? null
                              : (v) {
                                  if (v != null) {
                                    onSelectAnswer(sub.inputName, v);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: Duration(milliseconds: idx * 80)).fadeIn();
              }),

              const SizedBox(height: 20),
              buildSubmitButton(_allAnswered, context),
            ],
          ),
        ),
      ),
    );
  }
}
