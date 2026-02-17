// local_storage.dart
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class LocalStorage {
  /// Salvar resultados offline
  static Future<void> salvarResultado(Map<String, dynamic> resultado) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/resultados.json');

      List<dynamic> resultados = [];

      // Se o arquivo existe, carrega os resultados antigos
      if (await file.exists()) {
        final contents = await file.readAsString();
        resultados = json.decode(contents);
      }

      // Adiciona novo resultado
      resultados.add(resultado);

      // Salva de volta
      await file.writeAsString(json.encode(resultados));
    } catch (e) {
      throw Exception('Erro ao salvar resultado: $e');
    }
  }

  /// Carregar resultados offline
  static Future<List<dynamic>> carregarResultados() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/resultados.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        return json.decode(contents);
      }

      return [];
    } catch (e) {
      return [];
    }
  }
}
