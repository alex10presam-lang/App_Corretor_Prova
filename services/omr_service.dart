import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../scanner/scan_contract.dart';

class OmrException implements Exception {
  final String message;
  const OmrException(this.message);
  @override
  String toString() => message;
}

/// Each capture owns its HTTP client, so timeout/cancellation closes the upload.
class OmrService {
  static const defaultEndpoint = String.fromEnvironment(
    'OMR_API_URL',
    defaultValue:
        'https://omr-scanner-service-61890940348.southamerica-east1.run.app/processar',
  );

  final Uri endpoint;
  final Duration timeout;
  final http.Client Function() _clientFactory;
  http.Client? _activeClient;

  OmrService({
    Uri? endpoint,
    this.timeout = const Duration(seconds: 45),
    http.Client Function()? clientFactory,
  }) : endpoint = endpoint ?? Uri.parse(defaultEndpoint),
       _clientFactory = clientFactory ?? http.Client.new;

  void cancel() {
    _activeClient?.close();
    _activeClient = null;
  }

  Future<List<int>> scan(String imagePath, int expectedQuestions) async {
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty) {
      throw const OmrException(
        'Configure um endereço HTTPS válido para o scanner.',
      );
    }
    if (expectedQuestions < 1) {
      throw const OmrException('A prova não possui questões.');
    }
    if (_activeClient != null) {
      throw const OmrException('Uma leitura já está em andamento.');
    }
    final client = _clientFactory();
    _activeClient = client;
    try {
      return await (() async {
        final request = http.MultipartRequest('POST', endpoint)
          ..fields['expected_questions'] = '$expectedQuestions'
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              imagePath,
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        final streamed = await client.send(request);
        final response = await http.Response.fromStream(streamed);
        switch (response.statusCode) {
          case 200:
            return decodeOmrAnswers(response.body, expectedQuestions);
          case 401:
          case 403:
            throw const OmrException(
              'O serviço recusou o acesso. Verifique a configuração da API.',
            );
          case 400:
          case 422:
            throw const OmrException(
              'Não foi possível ler a folha. Inclua os quatro cantos e evite sombras.',
            );
          case 413:
            throw const OmrException(
              'A foto excedeu o tamanho aceito pelo serviço.',
            );
          default:
            throw OmrException(
              'Serviço de leitura indisponível (HTTP ${response.statusCode}). Tente novamente.',
            );
        }
      })().timeout(timeout);
    } on TimeoutException {
      throw const OmrException(
        'A leitura demorou demais. Verifique a conexão e tente novamente.',
      );
    } on SocketException {
      throw const OmrException('Sem conexão com o serviço de leitura.');
    } on http.ClientException {
      throw const OmrException('A conexão foi interrompida. Tente novamente.');
    } on FormatException catch (error) {
      throw OmrException(error.message);
    } finally {
      client.close();
      if (identical(_activeClient, client)) _activeClient = null;
    }
  }
}
