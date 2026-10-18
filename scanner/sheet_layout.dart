import 'dart:math';

/// Coordinates in PDF points. Shared by printing and local recognition.
abstract final class SheetLayout {
  static const version = 'local-v1';
  static const width = 595.28;
  static const height = 841.89;
  static const maxQuestions = 50;
  static const anchorInset = 32.0;
  static const anchorSize = 18.0;
  static const bubbleRadius = 6.0;
  static const rowSpacing = 20.0;
  static const firstRow = 218.0;
  static const columnSpacing = 265.0;
  static const firstBubble = 116.0;
  static const optionSpacing = 32.0;
  static const orientationBits = [true, false, true, true, false];

  static List<Point<double>> get anchors => [
    const Point(anchorInset, anchorInset),
    const Point(width - anchorInset, anchorInset),
    const Point(width - anchorInset, height - anchorInset),
    const Point(anchorInset, height - anchorInset),
  ];
  static Point<double> orientationCell(int index) =>
      Point(74.0 + index * 16, 32.0);
  static Point<double> bubble(int question, int option) => Point(
    firstBubble + (question ~/ 25) * columnSpacing + option * optionSpacing,
    firstRow + (question % 25) * rowSpacing,
  );
  static void validateCount(int count) {
    if (count < 1 || count > maxQuestions) {
      throw const FormatException(
        'O modelo local aceita de 1 a 50 questões por folha.',
      );
    }
  }
}
