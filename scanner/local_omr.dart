import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'sheet_layout.dart';

class LocalScanResult {
  final List<int> answers;

  /// Zero-based question indices that require explicit review.
  final List<int> uncertain;
  final List<List<double>> fillRatios;
  const LocalScanResult(this.answers, this.uncertain, this.fillRatios);
}

/// Reads only the versioned sheet geometry. No network, Firebase or Flutter APIs.
LocalScanResult recognizeSheet(Uint8List bytes, int count) {
  SheetLayout.validateCount(count);
  if (bytes.length > 20 * 1024 * 1024) {
    throw const FormatException(
      'Foto muito grande. Use a câmera do aplicativo.',
    );
  }
  img.Image decoded;
  try {
    if (bytes.length < 32) throw const FormatException('Imagem inválida.');
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width * info.height > 24000000) {
      throw const FormatException(
        'Imagem inválida ou com resolução excessiva.',
      );
    }
    final frame = decoder!.decodeFrame(0);
    if (frame == null) {
      throw const FormatException('Não foi possível abrir a foto.');
    }
    decoded = frame;
  } catch (_) {
    throw const FormatException(
      'Imagem inválida ou com resolução excessiva. Fotografe novamente.',
    );
  }
  var image = img.bakeOrientation(decoded);
  if (min(image.width, image.height) < 600) {
    throw const FormatException(
      'Foto pequena demais. Aproxime e fotografe novamente.',
    );
  }
  if (max(image.width, image.height) > 1600) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 1600 : null,
      height: image.height > image.width ? 1600 : null,
      interpolation: img.Interpolation.average,
    );
  }
  return _Reader(image).read(count);
}

class _Reader {
  final int width;
  final int height;
  late final Uint8List gray;
  _Reader(img.Image image) : width = image.width, height = image.height {
    gray = Uint8List(width * height);
    for (final pixel in image) {
      gray[pixel.y * width + pixel.x] =
          (.299 * pixel.r + .587 * pixel.g + .114 * pixel.b).round();
    }
  }

  LocalScanResult read(int count) {
    final corners = _findAnchors();
    _Projection? projection;
    double black = 0;
    for (var rotation = 0; rotation < 4; rotation++) {
      final candidate = _Projection.fit(
        SheetLayout.anchors,
        List.generate(4, (i) => corners[(i + rotation) % 4]),
      );
      final cells = [
        for (var i = 0; i < 5; i++)
          _disc(candidate, SheetLayout.orientationCell(i), 2.0),
      ];
      final whites = [cells[1], cells[4]];
      final blacks = [cells[0], cells[2], cells[3]];
      final paper = whites.reduce(min);
      final ink = blacks.reduce(max);
      if (paper > 120 && paper - ink > 75) {
        if (projection != null) {
          throw const FormatException(
            'Orientação da folha ambígua. Fotografe novamente.',
          );
        }
        projection = candidate;
        black = blacks.reduce((a, b) => a + b) / blacks.length;
      }
    }
    if (projection == null) {
      throw const FormatException(
        'Modelo não reconhecido. Inclua os quatro marcadores e use a nova folha local.',
      );
    }
    final answers = <int>[];
    final uncertain = <int>[];
    final scores = <List<double>>[];
    var badOutlines = 0;
    for (var q = 0; q < count; q++) {
      final fills = <double>[];
      for (var option = 0; option < 5; option++) {
        final center = SheetLayout.bubble(q, option);
        final paper = _ring(projection, center, 10.0);
        if (paper - black < 65 || paper < 100) {
          throw const FormatException(
            'Iluminação insuficiente. Evite sombras e reflexos sobre as respostas.',
          );
        }
        final threshold = paper - (paper - black) * .45;
        var marked = 0;
        var samples = 0;
        // Sample the interior only. Printed borders are never counted as ink.
        for (var dy = -3.5; dy <= 3.5; dy += .7) {
          for (var dx = -3.5; dx <= 3.5; dx += .7) {
            if (dx * dx + dy * dy > 12.25) continue;
            final p = projection.map(Point(center.x + dx, center.y + dy));
            if (_sample(p) < threshold) marked++;
            samples++;
          }
        }
        fills.add(marked / samples);
        // Misalignment or heavy blur must not turn an entire sheet into blanks.
        final border = _ring(projection, center, SheetLayout.bubbleRadius - .4);
        if (paper - border < (paper - black) * .14) badOutlines++;
      }
      scores.add(fills);
      final marked = [
        for (var i = 0; i < 5; i++)
          if (fills[i] >= .55) i,
      ];
      final weak = fills.any((value) => value >= .15 && value < .55);
      if (marked.length > 1) {
        answers.add(-2);
        uncertain.add(q);
      } else if (marked.length == 1) {
        answers.add(marked.single);
        if (weak || fills[marked.single] < .72) uncertain.add(q);
      } else {
        answers.add(-1);
        // Blank answers are also explicitly reviewed; an unfilled interior may
        // be an erasure or an unreadable light mark, not necessarily intentional.
        uncertain.add(q);
      }
    }
    if (badOutlines > count * 5 * .12) {
      throw const FormatException(
        'Folha desfocada ou desalinhada. Mantenha o celular firme e fotografe novamente.',
      );
    }
    return LocalScanResult(answers, uncertain, scores);
  }

  double _disc(_Projection projection, Point<double> center, double radius) {
    var total = 0.0;
    var count = 0;
    for (var y = -radius; y <= radius; y++) {
      for (var x = -radius; x <= radius; x++) {
        if (x * x + y * y > radius * radius) continue;
        total += _sample(projection.map(Point(center.x + x, center.y + y)));
        count++;
      }
    }
    return total / count;
  }

  double _ring(_Projection projection, Point<double> center, double radius) {
    var sum = 0.0;
    for (var i = 0; i < 32; i++) {
      final angle = i * pi / 16;
      sum += _sample(
        projection.map(
          Point(center.x + radius * cos(angle), center.y + radius * sin(angle)),
        ),
      );
    }
    return sum / 32;
  }

  double _sample(Point<double> p) {
    if (!p.x.isFinite ||
        !p.y.isFinite ||
        p.x < 0 ||
        p.y < 0 ||
        p.x >= width - 1 ||
        p.y >= height - 1) {
      throw const FormatException(
        'Parte da folha ficou fora da foto. Inclua todos os cantos.',
      );
    }
    final x = p.x.floor(), y = p.y.floor();
    final fx = p.x - x, fy = p.y - y;
    return gray[y * width + x] * (1 - fx) * (1 - fy) +
        gray[y * width + x + 1] * fx * (1 - fy) +
        gray[(y + 1) * width + x] * (1 - fx) * fy +
        gray[(y + 1) * width + x + 1] * fx * fy;
  }

  List<Point<double>> _findAnchors() {
    final stride = width + 1;
    final integral = Float64List((width + 1) * (height + 1));
    for (var y = 0; y < height; y++) {
      var row = 0.0;
      for (var x = 0; x < width; x++) {
        row += gray[y * width + x];
        integral[(y + 1) * stride + x + 1] = integral[y * stride + x + 1] + row;
      }
    }
    final mask = Uint8List(gray.length);
    final radius = (max(width, height) / 35).round();
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final x0 = max(0, x - radius), y0 = max(0, y - radius);
        final x1 = min(width, x + radius + 1), y1 = min(height, y + radius + 1);
        final average =
            (integral[y1 * stride + x1] -
                integral[y0 * stride + x1] -
                integral[y1 * stride + x0] +
                integral[y0 * stride + x0]) /
            ((x1 - x0) * (y1 - y0));
        final index = y * width + x;
        if (gray[index] < average - 30 && gray[index] < 185) mask[index] = 1;
      }
    }
    final queue = Int32List(gray.length);
    final candidates = <_Anchor>[];
    final minSide = min(width, height) * .009;
    final maxSide = max(width, height) * .06;
    for (var start = 0; start < mask.length; start++) {
      if (mask[start] != 1) continue;
      var head = 0, tail = 1;
      queue[0] = start;
      mask[start] = 0;
      var minX = width, maxX = 0, minY = height, maxY = 0;
      while (head < tail) {
        final index = queue[head++];
        final x = index % width, y = index ~/ width;
        minX = min(minX, x);
        maxX = max(maxX, x);
        minY = min(minY, y);
        maxY = max(maxY, y);
        void add(int neighbor) {
          if (mask[neighbor] == 1) {
            mask[neighbor] = 0;
            queue[tail++] = neighbor;
          }
        }

        if (x > 0) add(index - 1);
        if (x < width - 1) add(index + 1);
        if (y > 0) add(index - width);
        if (y < height - 1) add(index + width);
      }
      final w = maxX - minX + 1, h = maxY - minY + 1;
      if (w < minSide ||
          h < minSide ||
          w > maxSide ||
          h > maxSide ||
          w / h < .6 ||
          w / h > 1.67 ||
          tail / (w * h) < .60) {
        continue;
      }
      candidates.add(
        _Anchor(Point((minX + maxX) / 2, (minY + maxY) / 2), tail),
      );
    }
    final corners = <Point<double>>[];
    for (var corner = 0; corner < 4; corner++) {
      final right = corner == 1 || corner == 2;
      final bottom = corner >= 2;
      final matches = candidates
          .where(
            (a) =>
                (right ? a.center.x > width * .65 : a.center.x < width * .35) &&
                (bottom
                    ? a.center.y > height * .65
                    : a.center.y < height * .35),
          )
          .toList();
      if (matches.isEmpty) {
        throw const FormatException(
          'Não encontrei os quatro marcadores. Aproxime a folha e inclua todos os cantos.',
        );
      }
      double score(_Anchor a) {
        final dx = (right ? width - a.center.x : a.center.x) / width;
        final dy = (bottom ? height - a.center.y : a.center.y) / height;
        return a.area / (1 + 4 * (dx + dy));
      }

      matches.sort((a, b) => score(b).compareTo(score(a)));
      corners.add(matches.first.center);
    }
    final area =
        (corners[0].x * corners[1].y -
                corners[1].x * corners[0].y +
                corners[1].x * corners[2].y -
                corners[2].x * corners[1].y +
                corners[2].x * corners[3].y -
                corners[3].x * corners[2].y +
                corners[3].x * corners[0].y -
                corners[0].x * corners[3].y)
            .abs() /
        2;
    if (area < width * height * .28) {
      throw const FormatException(
        'Aproxime o celular da folha sem cortar os marcadores.',
      );
    }
    return corners;
  }
}

class _Anchor {
  final Point<double> center;
  final int area;
  const _Anchor(this.center, this.area);
}

/// Projective map fitted from four correspondences with pivoted elimination.
class _Projection {
  final List<double> h;
  const _Projection(this.h);
  factory _Projection.fit(
    List<Point<double>> source,
    List<Point<double>> target,
  ) {
    final a = <List<double>>[];
    for (var i = 0; i < 4; i++) {
      final x = source[i].x, y = source[i].y, u = target[i].x, v = target[i].y;
      a.add([x, y, 1, 0, 0, 0, -u * x, -u * y, u]);
      a.add([0, 0, 0, x, y, 1, -v * x, -v * y, v]);
    }
    for (var col = 0; col < 8; col++) {
      var pivot = col;
      for (var row = col + 1; row < 8; row++) {
        if (a[row][col].abs() > a[pivot][col].abs()) pivot = row;
      }
      if (a[pivot][col].abs() < 1e-9) {
        throw const FormatException('Geometria da folha inválida.');
      }
      final swap = a[col];
      a[col] = a[pivot];
      a[pivot] = swap;
      final divisor = a[col][col];
      for (var j = col; j < 9; j++) {
        a[col][j] /= divisor;
      }
      for (var row = 0; row < 8; row++) {
        if (row == col) continue;
        final factor = a[row][col];
        for (var j = col; j < 9; j++) {
          a[row][j] -= factor * a[col][j];
        }
      }
    }
    return _Projection([for (var row = 0; row < 8; row++) a[row][8]]);
  }
  Point<double> map(Point<double> point) {
    final x = point.x, y = point.y;
    final d = h[6] * x + h[7] * y + 1;
    return Point(
      (h[0] * x + h[1] * y + h[2]) / d,
      (h[3] * x + h[4] * y + h[5]) / d,
    );
  }
}
