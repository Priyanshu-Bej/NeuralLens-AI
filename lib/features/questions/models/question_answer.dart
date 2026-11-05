import 'dart:convert';

enum QuestionKind { multipleChoice, coding, openEnded, unknown }

enum AnswerStatus { answered, retake, uncertain }

/// Validated answer format and status are independent: no options is valid for
/// coding/open-ended tasks and never implies that the photo needs to be retaken.
class QuestionAnswer {
  const QuestionAnswer({
    required this.kind,
    required this.status,
    required this.question,
    required this.options,
    required this.selectedLabel,
    required this.answer,
    required this.explanation,
    required this.code,
    required this.codeLanguage,
    required this.glassesSummary,
  });

  final QuestionKind kind;
  final AnswerStatus status;
  final String question;
  final Map<String, String> options;
  final String? selectedLabel;
  final String answer;
  final String explanation;
  final String code;
  final String codeLanguage;
  final String glassesSummary;

  bool get hasAnswer => status == AnswerStatus.answered;
  String get heading => switch (status) {
    AnswerStatus.answered => 'Suggested answer',
    AnswerStatus.retake => 'Retake photo',
    AnswerStatus.uncertain => 'Could not answer',
  };

  String get answerText => !hasAnswer
      ? heading
      : selectedLabel != null
      ? '$selectedLabel. ${options[selectedLabel]}'
      : answer;

  // For MCQs the validated label always takes precedence over generated prose.
  String get glassesText => hasAnswer && kind == QuestionKind.multipleChoice
      ? answerText
      : glassesSummary;

  static QuestionAnswer parse(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, Object?>) {
      throw const FormatException('Expected a question result');
    }
    String field(
      Map<String, Object?> map,
      String name,
      int max, {
      bool allowEmpty = false,
      bool preserveWhitespace = false,
    }) {
      final value = map[name];
      if (value is! String ||
          (!allowEmpty && value.trim().isEmpty) ||
          value.length > max) {
        throw FormatException('Invalid $name');
      }
      return preserveWhitespace ? value : value.trim();
    }

    final kind = switch (json['kind']) {
      'multiple_choice' => QuestionKind.multipleChoice,
      'coding' => QuestionKind.coding,
      'open_ended' => QuestionKind.openEnded,
      'unknown' => QuestionKind.unknown,
      _ => throw const FormatException('Invalid question kind'),
    };
    final status = switch (json['status']) {
      'answered' => AnswerStatus.answered,
      'retake' => AnswerStatus.retake,
      'uncertain' => AnswerStatus.uncertain,
      _ => throw const FormatException('Invalid answer status'),
    };
    final question = field(json, 'question', 8000);
    final explanation = field(json, 'explanation', 3000);
    final answer = field(
      json,
      'answer',
      12000,
      allowEmpty: status != AnswerStatus.answered,
    );
    final code = field(
      json,
      'code',
      20000,
      allowEmpty: true,
      preserveWhitespace: true,
    );
    final language = field(json, 'codeLanguage', 40, allowEmpty: true);
    final summary = field(json, 'glassesSummary', 100);
    final selected = field(json, 'selectedLabel', 12, allowEmpty: true);
    final rawOptions = json['options'];
    if (rawOptions is! List || rawOptions.length > 12) {
      throw const FormatException('Invalid question options');
    }
    final options = <String, String>{};
    for (final option in rawOptions) {
      if (option is! Map<String, Object?>) {
        throw const FormatException('Invalid option');
      }
      final label = field(option, 'label', 12);
      if (options.containsKey(label)) {
        throw const FormatException('Duplicate option label');
      }
      options[label] = field(option, 'text', 3000);
    }
    if (kind != QuestionKind.multipleChoice &&
        (options.isNotEmpty || selected.isNotEmpty)) {
      throw const FormatException(
        'Unexpected options for an open-ended question',
      );
    }
    if (status == AnswerStatus.answered) {
      if (kind == QuestionKind.unknown ||
          (kind == QuestionKind.multipleChoice &&
              (options.length < 2 || !options.containsKey(selected)))) {
        throw const FormatException(
          'Answer does not match the question format',
        );
      }
    } else if (selected.isNotEmpty ||
        answer.isNotEmpty ||
        code.trim().isNotEmpty ||
        language.isNotEmpty) {
      throw const FormatException(
        'Unresolved questions cannot include a suggested solution',
      );
    }
    if (code.trim().isEmpty != language.isEmpty) {
      throw const FormatException(
        'Code and language must be provided together',
      );
    }
    return QuestionAnswer(
      kind: kind,
      status: status,
      question: question,
      options: Map.unmodifiable(options),
      selectedLabel: selected.isEmpty ? null : selected,
      answer: answer,
      explanation: explanation,
      code: code.trim().isEmpty ? '' : code,
      codeLanguage: language,
      glassesSummary: summary,
    );
  }
}
