import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:neurallens/features/questions/logic/question_cubit.dart';
import 'package:neurallens/features/questions/models/question_answer.dart';

const questionJson = {
  'status': 'answered',
  'kind': 'multiple_choice',
  'answer': '4',
  'code': '',
  'codeLanguage': '',
  'glassesSummary': 'B. 4',
  'question': 'What is 2 + 2?',
  'options': [
    {'label': 'A', 'text': '3'},
    {'label': 'B', 'text': '4'},
  ],
  'selectedLabel': 'B',
  'explanation': 'Adding two and two gives four.',
};

const codingQuestionJson = {
  'status': 'answered',
  'kind': 'coding',
  'question': 'Write a Python function that adds two numbers.',
  'options': [],
  'selectedLabel': '',
  'answer': 'Return the sum of the two arguments.',
  'explanation': 'For fixed-width numbers, this takes constant time and space.',
  'code': 'def add(a, b):\n    return a + b\n',
  'codeLanguage': 'Python',
  'glassesSummary': 'Return a + b. Time O(1), space O(1).',
};

const openEndedQuestionJson = {
  'status': 'answered',
  'kind': 'open_ended',
  'question': 'Discuss the advantages and limitations of remote work.',
  'options': [],
  'selectedLabel': '',
  'answer':
      'Remote work offers flexibility and reduces commuting.\n\n'
      'It can also create isolation and coordination challenges. A hybrid approach '
      'may balance these needs, depending on the team.',
  'explanation':
      'This is one perspective; the best arrangement depends on the work and people.',
  'code': '',
  'codeLanguage': '',
  'glassesSummary':
      'Flexibility and less commuting; isolation and coordination remain challenges.',
};

void main() {
  test('selects only an option actually present in the result', () {
    final answer = QuestionAnswer.parse(jsonEncode(questionJson));
    expect(answer.answerText, 'B. 4');
    expect(
      () => QuestionAnswer.parse(
        jsonEncode({...questionJson, 'selectedLabel': 'Z'}),
      ),
      throwsFormatException,
    );
  });

  test('rejects malformed, duplicate, incomplete and oversized answers', () {
    for (final invalid in [
      {...questionJson, 'options': 'A and B'},
      {
        ...questionJson,
        'options': [
          {'label': 'B', 'text': '4'},
        ],
      },
      {
        ...questionJson,
        'options': [
          {'label': 'B', 'text': '3'},
          {'label': 'B', 'text': '4'},
        ],
      },
      {...questionJson, 'question': ''},
      {...questionJson, 'explanation': 'x' * 3001},
      {...questionJson, 'selectedLabel': null},
      {...questionJson, 'status': 'certain'},
    ]) {
      expect(
        () => QuestionAnswer.parse(jsonEncode(invalid)),
        throwsFormatException,
      );
    }
  });

  test('unreadable image has no suggested answer', () {
    final answer = QuestionAnswer.parse(
      jsonEncode({
        ...questionJson,
        'status': 'retake',
        'answer': '',
        'glassesSummary': 'Take a clearer photo.',
        'options': [],
        'selectedLabel': '',
      }),
    );
    expect(answer.selectedLabel, isNull);
    expect(answer.answerText, 'Retake photo');
    expect(
      () => QuestionAnswer.parse(
        jsonEncode({...questionJson, 'status': 'retake'}),
      ),
      throwsFormatException,
    );
  });

  test('bounds display text even for unbroken formulas', () {
    final lines = QuestionCubit.compactLines('A. ${'x' * 200}');
    expect(lines.length, lessThanOrEqualTo(4));
    expect(lines.every((line) => line.length <= 28), isTrue);
    expect(lines.last, endsWith('…'));
  });
  test('coding answers need no options and preserve code indentation', () {
    final result = QuestionAnswer.parse(jsonEncode(codingQuestionJson));
    expect(result.kind, QuestionKind.coding);
    expect(result.hasAnswer, isTrue);
    expect(result.selectedLabel, isNull);
    expect(result.answerText, codingQuestionJson['answer']);
    expect(result.code, 'def add(a, b):\n    return a + b\n');
    expect(result.glassesText, codingQuestionJson['glassesSummary']);
  });

  test('subjective answers preserve paragraphs without requiring options', () {
    final result = QuestionAnswer.parse(jsonEncode(openEndedQuestionJson));
    expect(result.kind, QuestionKind.openEnded);
    expect(result.hasAnswer, isTrue);
    expect(result.heading, 'Suggested answer');
    expect(result.answerText, contains('\n\n'));
    expect(result.options, isEmpty);
  });

  test('coding MCQs still require a visible selected option', () {
    final result = QuestionAnswer.parse(
      jsonEncode({
        ...questionJson,
        'question': 'What does print(2 + 2) output?',
      }),
    );
    expect(result.kind, QuestionKind.multipleChoice);
    expect(result.answerText, 'B. 4');
  });

  test('uncertainty is distinct from an unreadable photo', () {
    final result = QuestionAnswer.parse(
      jsonEncode({
        ...openEndedQuestionJson,
        'status': 'uncertain',
        'answer': '',
        'explanation': 'The referenced passage is not included.',
        'glassesSummary': 'Provide the referenced passage.',
      }),
    );
    expect(result.hasAnswer, isFalse);
    expect(result.heading, 'Could not answer');
    expect(result.glassesText, 'Provide the referenced passage.');
  });

  test(
    'rejects inconsistent answer formats, missing solutions, and oversized payloads',
    () {
      for (final invalid in [
        {...codingQuestionJson, 'selectedLabel': 'B'},
        {...openEndedQuestionJson, 'options': questionJson['options']},
        {...codingQuestionJson, 'answer': ''},
        {...codingQuestionJson, 'codeLanguage': ''},
        {...openEndedQuestionJson, 'codeLanguage': 'Python'},
        {...codingQuestionJson, 'status': 'retake', 'answer': ''},
        {...openEndedQuestionJson, 'kind': 'unknown'},
        {...openEndedQuestionJson, 'kind': 'essay'},
        {...openEndedQuestionJson, 'glassesSummary': 'x' * 101},
        {...openEndedQuestionJson, 'answer': 'x' * 12001},
        {...codingQuestionJson, 'code': 'x' * 20001},
      ]) {
        expect(
          () => QuestionAnswer.parse(jsonEncode(invalid)),
          throwsFormatException,
        );
      }
    },
  );
}
