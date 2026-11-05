import 'package:equatable/equatable.dart';

/// A short, glanceable chunk of a script shown during presentation.
class Cue extends Equatable {
  const Cue({
    required this.index,
    required this.sectionIndex,
    required this.heading,
    required this.text,
    this.keywords = const [],
  });

  final int index;
  final int sectionIndex;
  final String heading;
  final String text;
  final List<String> keywords;

  @override
  List<Object?> get props => [index, sectionIndex, heading, text, keywords];
}
