import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurallens/core/theme/app_theme.dart';
import 'package:neurallens/features/ai/data/gemini_service.dart';
import 'package:neurallens/features/questions/models/question_answer.dart';
import 'package:neurallens/features/questions/logic/question_cubit.dart';
import 'package:neurallens/features/questions/ui/question_screen.dart';
import 'package:neurallens/features/wearables/data/wearables_service.dart';
import 'package:neurallens/features/wearables/logic/wearables_cubit.dart';

import 'question_answer_test.dart'
    show questionJson, codingQuestionJson, openEndedQuestionJson;
import 'question_cubit_test.dart' show CameraFake, AnswerFake;

void main() {
  for (final resultJson in [
    questionJson,
    codingQuestionJson,
    openEndedQuestionJson,
  ]) {
    testWidgets('capture and show ${resultJson['kind']} answer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final camera = CameraFake();
      final ai = AnswerFake();
      final connection = WearablesCubit(camera);
      await connection.initialize();
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<WearablesService>.value(value: camera),
            RepositoryProvider<GeminiService>.value(value: ai),
          ],
          child: BlocProvider.value(
            value: connection,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const QuestionScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Open camera'), 100);
      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();
      expect(find.text('Live glasses camera'), findsOneWidget);
      expect(find.text('Take photo & answer'), findsOneWidget);
      expect(camera.captures, 0);
      expect(ai.requests, isEmpty);

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(2);
      await tester.pumpAndSettle();
      expect(find.text('Digital zoom: 2.0×'), findsOneWidget);
      final cubit = tester
          .element(find.text('Take photo & answer'))
          .read<QuestionCubit>();
      await tester.tap(find.text('Take photo & answer'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(
        ai.requests,
        hasLength(1),
        reason:
            '${cubit.state.phase}: ${cubit.state.message}; captures=${camera.captures}; stops=${camera.previewStops}',
      );
      expect(camera.captures, 1);
      expect(camera.capturedZoom, 2);
      ai.requests.single.complete(QuestionAnswer.parse(jsonEncode(resultJson)));
      await tester.pumpAndSettle();
      expect(find.text('Open camera for next question'), findsOneWidget);
      if (resultJson['kind'] == 'coding') {
        await tester.scrollUntilVisible(
          find.text('Code · Python'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(resultJson['code']! as String), findsOneWidget);
      }
      expect(camera.shown.single.heading, 'Suggested answer');
      expect(find.text('Retake photo'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Open camera for next question'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Open camera for next question'));
      await tester.pumpAndSettle();
      expect(camera.captures, 1);
      await tester.tap(find.text('Close camera'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Live glasses camera'), findsNothing);
      expect(camera.captures, 1);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await connection.close();
        await camera.dispose();
      });
    });
  }
}
