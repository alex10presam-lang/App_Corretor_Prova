import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:corretor_provas/scanner/local_omr.dart';
import 'package:corretor_provas/scanner/scan_contract.dart';
import 'package:corretor_provas/services/local_omr_service.dart';

// Fixture coordinates are intentionally explicit: changes to the production
// geometry must not silently move both the reader and its expected inputs.
img.Image sheet(
  int count, {
  Map<int, List<int>>? marks,
  bool orientation = true,
}) {
  final image = img.Image(width: 1191, height: 1684);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  final black = img.ColorRgb8(0, 0, 0);
  for (final p in [
    const Point(32.0, 32.0),
    const Point(563.28, 32.0),
    const Point(563.28, 809.89),
    const Point(32.0, 809.89),
  ]) {
    img.fillRect(
      image,
      x1: ((p.x - 9) * 2).round(),
      y1: ((p.y - 9) * 2).round(),
      x2: ((p.x + 9) * 2).round(),
      y2: ((p.y + 9) * 2).round(),
      color: black,
    );
  }
  if (orientation) {
    for (final x in [74, 106, 122]) {
      img.fillRect(
        image,
        x1: (x - 4) * 2,
        y1: 56,
        x2: (x + 4) * 2,
        y2: 72,
        color: black,
      );
    }
  }
  for (var q = 0; q < count; q++) {
    for (var a = 0; a < 5; a++) {
      final x = (116 + (q ~/ 25) * 265 + a * 32) * 2;
      final y = (218 + (q % 25) * 20) * 2;
      img.fillCircle(image, x: x, y: y, radius: 12, color: black);
      img.fillCircle(
        image,
        x: x,
        y: y,
        radius: 10,
        color: img.ColorRgb8(255, 255, 255),
      );
      if ((marks?[q] ?? [q % 5]).contains(a)) {
        img.fillCircle(image, x: x, y: y, radius: 10, color: black);
      }
    }
  }
  return image;
}

Uint8List encode(img.Image image) =>
    Uint8List.fromList(img.encodeJpg(image, quality: 90));
String qr({String version = 'local-v1', int count = 40, String prova = 'p'}) =>
    jsonEncode({
      'layout': version,
      'provaId': prova,
      'totalPages': 1,
      'questions': count,
    });

void main() {
  group('Contrato da folha', () {
    test(
      'versão e contagem corretas',
      () => expect(ScanSheet.parse(qr()).questionsOnSheet(40), 40),
    );
    test(
      'rejeita folha antiga',
      () => expect(
        () => ScanSheet.parse(qr(version: 'old')),
        throwsFormatException,
      ),
    );
    test(
      'rejeita prova alterada',
      () => expect(
        () => ScanSheet.parse(qr()).questionsOnSheet(25),
        throwsFormatException,
      ),
    );
    test(
      'não aceita trocar prova entre QR e foto',
      () => expect(
        ScanSheet.parse(qr()).sameSheet(ScanSheet.parse(qr(prova: 'outra'))),
        isFalse,
      ),
    );
    for (final n in [0, 51, -1]) {
      test(
        'rejeita contagem $n',
        () =>
            expect(() => ScanSheet.parse(qr(count: n)), throwsFormatException),
      );
    }
    for (final bad in [
      '[]',
      'texto',
      '{}',
      '{"layout":"local-v1","provaId":"p","totalPages":2,"questions":20}',
    ]) {
      test(
        'QR inválido $bad',
        () => expect(() => ScanSheet.parse(bad), throwsFormatException),
      );
    }
  });
  group('Reconhecimento local', () {
    for (final count in [1, 10, 25, 30, 40, 50]) {
      test('$count questões e duas colunas', () {
        final result = recognizeSheet(encode(sheet(count)), count);
        expect(result.answers, List.generate(count, (q) => q % 5));
        expect(result.uncertain, isEmpty);
      });
    }
    for (final angle in [90, 180, 270]) {
      test('rotação $angle', () {
        final result = recognizeSheet(
          encode(img.copyRotate(sheet(30), angle: angle)),
          30,
        );
        expect(result.answers, List.generate(30, (q) => q % 5));
      });
    }
    test('branco e múltiplas marcações exigem revisão', () {
      final result = recognizeSheet(
        encode(
          sheet(
            10,
            marks: {
              0: [],
              1: [0, 3],
            },
          ),
        ),
        10,
      );
      expect(result.answers.take(2), [-1, -2]);
      expect(result.uncertain, containsAll([0, 1]));
    });
    test('marca parcial fica sinalizada', () {
      final image = sheet(10, marks: {0: []});
      img.fillRect(
        image,
        x1: 232,
        y1: 430,
        x2: 238,
        y2: 442,
        color: img.ColorRgb8(0, 0, 0),
      );
      expect(recognizeSheet(encode(image), 10).uncertain, contains(0));
    });
    test('sombra suave com compressão JPEG', () {
      final image = sheet(50);
      for (final p in image) {
        final factor = .6 + .4 * p.x / image.width;
        p.r *= factor;
        p.g *= factor;
        p.b *= factor;
      }
      final result = recognizeSheet(encode(image), 50);
      expect(result.answers, List.generate(50, (q) => q % 5));
    });
    test('perspectiva moderada', () {
      final source = sheet(30);
      final target = img.Image(width: 1250, height: 1750);
      img.fill(target, color: img.ColorRgb8(235, 235, 235));
      // Inverse projective warp, independent from the reader's linear solver.
      for (final p in target) {
        final u = p.x - 20.0, v = p.y - 20.0;
        final y = v / (.95 - .00004 * v);
        final x = u * (1 + .00004 * y) - .045 * y;
        if (x >= 0 && y >= 0 && x < source.width - 1 && y < source.height - 1) {
          p.set(
            source.getPixelInterpolate(
              x,
              y,
              interpolation: img.Interpolation.linear,
            ),
          );
        }
      }
      expect(
        recognizeSheet(encode(target), 30).answers,
        List.generate(30, (q) => q % 5),
      );
    });
    test('marcador ausente bloqueia leitura', () {
      final image = sheet(10);
      img.fillRect(
        image,
        x1: 30,
        y1: 30,
        x2: 90,
        y2: 90,
        color: img.ColorRgb8(255, 255, 255),
      );
      expect(() => recognizeSheet(encode(image), 10), throwsFormatException);
    });
    test(
      'sem código de orientação bloqueia leitura',
      () => expect(
        () => recognizeSheet(encode(sheet(10, orientation: false)), 10),
        throwsFormatException,
      ),
    );
    test(
      'desfoque intenso bloqueia leitura',
      () => expect(
        () =>
            recognizeSheet(encode(img.gaussianBlur(sheet(10), radius: 14)), 10),
        throwsFormatException,
      ),
    );
    test('imagem vazia e arquivo inválido', () {
      expect(
        () => recognizeSheet(Uint8List.fromList([1, 2, 3]), 10),
        throwsFormatException,
      );
      expect(
        () => recognizeSheet(encode(img.Image(width: 800, height: 1000)), 10),
        throwsFormatException,
      );
    });
    test(
      'resolução insuficiente',
      () => expect(
        () => recognizeSheet(encode(img.copyResize(sheet(10), width: 300)), 10),
        throwsFormatException,
      ),
    );
  });
  test(
    'folha renderizada do PDF real: branco e 50 alternativas preenchidas',
    () async {
      final raw = await File('test/fixtures/printed_sheet.png').readAsBytes();
      final blank = recognizeSheet(raw, 50);
      expect(blank.answers, List.filled(50, -1));
      expect(blank.uncertain, hasLength(50));
      final printed = img.decodePng(raw)!;
      final sx = printed.width / 595.28, sy = printed.height / 841.89;
      for (var q = 0; q < 50; q++) {
        img.fillCircle(
          printed,
          x: ((116 + (q ~/ 25) * 265 + (q % 5) * 32) * sx).round(),
          y: ((218 + (q % 25) * 20) * sy).round(),
          radius: (4.8 * sx).round(),
          color: img.ColorRgb8(0, 0, 0),
        );
      }
      expect(
        recognizeSheet(encode(printed), 50).answers,
        List.generate(50, (q) => q % 5),
      );
    },
  );
  test('worker executa e pode ser cancelado antes de processar', () async {
    final directory = await Directory.systemTemp.createTemp('local-omr-test-');
    try {
      final file = await File(
        '${directory.path}/sheet.jpg',
      ).writeAsBytes(encode(sheet(10)));
      final service = LocalOmrService();
      expect(
        (await service.scan(file.path, 10)).answers,
        List.generate(10, (q) => q % 5),
      );
      final pending = service.scan(file.path, 10);
      service.cancel();
      await expectLater(pending, throwsFormatException);
      expect((await service.scan(file.path, 10)).answers, hasLength(10));
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
