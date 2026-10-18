import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:corretor_provas/scanner/scan_contract.dart';
import 'package:corretor_provas/services/omr_service.dart';

class TestClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  bool closed = false;
  TestClient(this.handler);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
  @override
  void close() {
    closed = true;
  }
}

http.StreamedResponse response(String body, [int status = 200]) =>
    http.StreamedResponse(Stream.value(utf8.encode(body)), status);

void main() {
  group('QR da folha', () {
    test('folha do gerador mantém todas as 40 questões, sem limitar a 25', () {
      final sheet = ScanSheet.parse('{"provaId":"prova-1","totalPages":1}');
      expect(sheet.questionsOnSheet(40), 40);
    });
    test('identificação personalizada', () {
      final sheet = ScanSheet.parse(
        '{"provaId":"p","alunoId":"a","turmaId":"t","totalPages":1}',
      );
      expect(sheet.alunoId, 'a');
      expect(sheet.turmaId, 't');
    });
    for (final invalid in [
      '[]',
      'texto',
      '{}',
      '{"provaId":"p","totalPages":0}',
      '{"provaId":"p","totalPages":"1"}',
      '{"provaId":"p/x","totalPages":1}',
      '{"provaId":"p","alunoId":"a","totalPages":1}',
    ]) {
      test('rejeita QR inválido: $invalid', () {
        expect(() => ScanSheet.parse(invalid), throwsFormatException);
      });
    }
    test('não calcula nota de páginas sem identificação individual', () {
      expect(
        () => const ScanSheet('p', null, null, 2).questionsOnSheet(40),
        throwsFormatException,
      );
    });
    test('rejeita prova vazia', () {
      expect(
        () => const ScanSheet('p', null, null, 1).questionsOnSheet(0),
        throwsFormatException,
      );
    });
  });

  group('Respostas OMR', () {
    test('preserva alternativas, branco e múltipla marcação', () {
      expect(decodeOmrAnswers('{"answers":[0,1,2,3,4,-1,-2]}', 7), [
        0,
        1,
        2,
        3,
        4,
        -1,
        -2,
      ]);
    });
    for (final body in [
      '{}',
      '[]',
      '<html>erro</html>',
      '{"answers":[0]}',
      '{"answers":[0,1,2]}',
      '{"answers":[0,5]}',
      '{"answers":[-3,1]}',
      '{"answers":["A",1]}',
      '{"answers":[0.0,1]}',
      '{"answers":[null,1]}',
    ]) {
      test('rejeita leitura incompleta ou inválida: $body', () {
        expect(() => decodeOmrAnswers(body, 2), throwsFormatException);
      });
    }
  });

  group('Transporte HTTP', () {
    late Directory directory;
    late File photo;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('scanner-test-');
      photo = await File(
        '${directory.path}/sheet.jpg',
      ).writeAsBytes([255, 216, 255, 217]);
    });
    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('envia JPEG e quantidade integral no contrato existente', () async {
      final client = TestClient((request) async {
        expect(request.method, 'POST');
        final multipart = request as http.MultipartRequest;
        expect(multipart.fields, {'expected_questions': '40'});
        expect(multipart.files.single.field, 'file');
        expect(multipart.files.single.contentType.toString(), 'image/jpeg');
        expect(await multipart.files.single.finalize().toBytes(), [
          255,
          216,
          255,
          217,
        ]);
        return response(jsonEncode({'answers': List.filled(40, 2)}));
      });
      final service = OmrService(clientFactory: () => client);
      expect(await service.scan(photo.path, 40), hasLength(40));
      expect(client.closed, isTrue);
    });

    for (final status in [400, 401, 403, 413, 422, 500, 503]) {
      test('HTTP $status gera erro e fecha conexão', () async {
        final client = TestClient(
          (_) async => response('detalhes internos', status),
        );
        final service = OmrService(clientFactory: () => client);
        await expectLater(
          service.scan(photo.path, 2),
          throwsA(isA<OmrException>()),
        );
        expect(client.closed, isTrue);
      });
    }

    test('timeout também cobre leitura do corpo da resposta', () async {
      final body = StreamController<List<int>>();
      final client = TestClient(
        (_) async => http.StreamedResponse(body.stream, 200),
      );
      final service = OmrService(
        clientFactory: () => client,
        timeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        service.scan(photo.path, 2),
        throwsA(isA<OmrException>()),
      );
      expect(client.closed, isTrue);
      await body.close();
    });

    test('timeout cobre espera pelos cabeçalhos', () async {
      final pending = Completer<http.StreamedResponse>();
      final client = TestClient((_) => pending.future);
      final service = OmrService(
        clientFactory: () => client,
        timeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        service.scan(photo.path, 2),
        throwsA(isA<OmrException>()),
      );
      expect(client.closed, isTrue);
      pending.complete(response('{"answers":[0,1]}'));
    });

    test(
      'não aceita dois uploads simultâneos; cancelamento fecha o cliente',
      () async {
        final started = Completer<void>();
        final pending = Completer<http.StreamedResponse>();
        final client = TestClient((_) {
          started.complete();
          return pending.future;
        });
        final service = OmrService(clientFactory: () => client);
        final first = service.scan(photo.path, 2);
        await started.future;
        await expectLater(
          service.scan(photo.path, 2),
          throwsA(isA<OmrException>()),
        );
        service.cancel();
        expect(client.closed, isTrue);
        pending.completeError(http.ClientException('cancelled'));
        await expectLater(first, throwsA(isA<OmrException>()));
      },
    );

    test('erro de conexão permite nova tentativa', () async {
      var attempts = 0;
      final service = OmrService(
        clientFactory: () => TestClient((_) async {
          if (++attempts == 1) throw const SocketException('offline');
          return response('{"answers":[0,1]}');
        }),
      );
      await expectLater(
        service.scan(photo.path, 2),
        throwsA(isA<OmrException>()),
      );
      expect(await service.scan(photo.path, 2), [0, 1]);
    });

    test('bloqueia endereço sem HTTPS antes do upload', () async {
      final service = OmrService(endpoint: Uri.parse('http://example.test'));
      await expectLater(
        service.scan(photo.path, 2),
        throwsA(isA<OmrException>()),
      );
    });
  });
}
