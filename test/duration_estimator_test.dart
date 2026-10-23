import 'package:flutter_test/flutter_test.dart';
import 'package:neurallens/features/scripts/util/duration_estimator.dart';

void main() {
  test('counts words including contractions and numbers', () {
    expect(DurationEstimator.wordCount("It's 2026, let's go!"), 4);
    expect(DurationEstimator.wordCount('   '), 0);
    expect(DurationEstimator.wordCount('well-known — fact'), 2);
  });

  test('estimates seconds at the default 150 wpm', () {
    final text = List.filled(150, 'word').join(' ');
    expect(DurationEstimator.estimateSeconds(text), 60);
    expect(DurationEstimator.estimateSeconds(text, wpm: 300), 30);
    expect(DurationEstimator.estimateSeconds(''), 0);
    expect(DurationEstimator.estimateSeconds('hi'), 1);
  });

  test('target words scale with duration', () {
    expect(DurationEstimator.targetWords(60), 150);
    expect(DurationEstimator.targetWords(30), 75);
    expect(DurationEstimator.targetWords(120, wpm: 120), 240);
  });

  test('cue duration has a readable minimum', () {
    expect(
      DurationEstimator.cueDuration('Hi', wpm: 150),
      const Duration(milliseconds: 1500),
    );
    final ten = List.filled(10, 'w').join(' ');
    expect(
      DurationEstimator.cueDuration(ten, wpm: 150),
      const Duration(seconds: 4),
    );
  });

  test('formats durations', () {
    expect(DurationEstimator.format(45), '45s');
    expect(DurationEstimator.format(65), '1:05');
    expect(DurationEstimator.formatApprox(0), '0 sec');
    expect(DurationEstimator.formatApprox(40), '~40 sec');
    expect(DurationEstimator.formatApprox(120), '~2 min');
    expect(DurationEstimator.formatApprox(150), '~2.5 min');
  });
}
