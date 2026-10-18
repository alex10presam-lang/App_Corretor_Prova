import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import '../scanner/local_omr.dart';

void _readInWorker(List<Object> input) {
  final port = input[0] as SendPort;
  try {
    port.send(recognizeSheet(input[1] as Uint8List, input[2] as int));
  } on FormatException catch (error) {
    port.send(error.message);
  } catch (_) {
    port.send('Não foi possível ler a foto. Fotografe novamente.');
  }
}

class LocalOmrService {
  Isolate? _worker;
  Completer<Object>? _pending;

  void cancel() {
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete('Leitura cancelada.');
    }
  }

  Future<LocalScanResult> scan(String path, int count) async {
    if (_pending != null) {
      throw const FormatException('Uma leitura está em andamento.');
    }
    final pending = Completer<Object>();
    _pending = pending;
    final port = ReceivePort();
    final subscription = port.listen((dynamic value) {
      if (!pending.isCompleted) {
        pending.complete(
          value is LocalScanResult || value is String
              ? value as Object
              : 'Falha no processamento da imagem.',
        );
      }
    });
    Isolate? worker;
    try {
      final file = File(path);
      if (await file.length() > 20 * 1024 * 1024) {
        throw const FormatException('Foto muito grande.');
      }
      final bytes = await file.readAsBytes();
      if (!identical(_pending, pending)) {
        throw const FormatException('Leitura cancelada.');
      }
      worker = await Isolate.spawn(
        _readInWorker,
        <Object>[port.sendPort, bytes, count],
        onError: port.sendPort,
        onExit: port.sendPort,
      );
      if (!identical(_pending, pending)) {
        throw const FormatException('Leitura cancelada.');
      }
      _worker = worker;
      final result = await pending.future.timeout(const Duration(seconds: 30));
      if (result is String) throw FormatException(result);
      return result as LocalScanResult;
    } on TimeoutException {
      throw const FormatException(
        'A foto demorou demais para ser processada. Fotografe novamente.',
      );
    } finally {
      worker?.kill(priority: Isolate.immediate);
      await subscription.cancel();
      port.close();
      if (identical(_pending, pending)) {
        _pending = null;
        _worker = null;
      }
    }
  }
}
