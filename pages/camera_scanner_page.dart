// lib/pages/camera_scanner_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Para File e XFile
import 'dart:math';
import 'package:corretor_provas/components/selecionar_aluno_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http; // Para chamadas de API
import 'package:http_parser/http_parser.dart'; // Para MediaType

import '../models/aluno.dart';
import '../models/prova.dart';
// REMOVIDO: import 'package:corretor_provas/scanner/omr_processor.dart';
import '../services/aluno_service.dart';
import '../services/prova_service.dart';
import '../services/resultado_service.dart';
// Mantido para validar as respostas recebidas da API
import 'package:corretor_provas/utils/validator.dart'; // LINHA CORRIGIDA

enum ScannerStage { scanningQrCode, processingQrCode, scanningOmr }

class CameraScannerPage extends StatefulWidget {
  const CameraScannerPage({super.key});
  @override
  CameraScannerPageState createState() => CameraScannerPageState();
}

class CameraScannerPageState extends State<CameraScannerPage> {
  // URL da sua API no Google Cloud Run
  final String _apiUrl =
      "https://omr-scanner-service-61890940348.southamerica-east1.run.app/processar";

  final MobileScannerController _qrScannerController =
      MobileScannerController();
  CameraController? _omrCameraController;
  final ProvaService _provaService = ProvaService();
  final AlunoService _alunoService = AlunoService();
  final ResultadoService _resultadoService = ResultadoService();
  ScannerStage _currentStage = ScannerStage.scanningQrCode;
  String _statusMessage = "Aponte para o QR Code da prova";
  bool _isProcessing = false; // Bloqueia múltiplas capturas
  Prova? _provaEscaneada;
  Aluno? _alunoEscaneado;
  int _expectedPage = 1;
  int _totalPages = 0;
  final Map<int, List<int>> _sessionAnswers =
      {}; // Armazena respostas por página
  FlashMode _currentFlashMode = FlashMode.off;

  // REMOVIDAS: Variáveis de estado do processamento de stream
  // _lastFrameProcessingTime, _isCoolingDown, _markersDetected, _previousCorners, _stableFrames

  @override
  void dispose() {
    _qrScannerController.dispose();
    _omrCameraController?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_omrCameraController == null ||
        !_omrCameraController!.value.isInitialized)
      return;

    final newFlashMode = _currentFlashMode == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;
    try {
      await _omrCameraController!.setFlashMode(newFlashMode);
      if (mounted) {
        setState(() => _currentFlashMode = newFlashMode);
      }
    } catch (e) {
      debugPrint("Erro ao mudar modo de flash: $e");
    }
  }

  void _onQrCodeDetected(BarcodeCapture capture) async {
    if (_isProcessing || _currentStage != ScannerStage.scanningQrCode) return;
    final Barcode? barcode = capture.barcodes.firstOrNull;
    if (barcode != null && barcode.rawValue != null) {
      setState(() {
        _isProcessing = true;
        _currentStage = ScannerStage.processingQrCode;
        _statusMessage = "QR Code detectado! Validando...";
      });
      try {
        final data = jsonDecode(barcode.rawValue!) as Map<String, dynamic>;
        final provaId = data['provaId'] as String?;
        final alunoId = data['alunoId'] as String?;
        final turmaId = data['turmaId'] as String?;
        final totalPages = data['totalPages'] as int?;
        if (provaId == null || totalPages == null) {
          throw Exception("QR Code inválido: Faltam informações da prova.");
        }

        final provaFuture = _provaService.getProvaById(provaId);
        final alunoFuture = (alunoId != null && turmaId != null)
            ? _alunoService.getAlunoById(turmaId, alunoId)
            : Future.value(null);

        final results = await Future.wait([provaFuture, alunoFuture]);
        _provaEscaneada = results[0] as Prova?;
        _alunoEscaneado = results[1] as Aluno?;

        if (_provaEscaneada == null) {
          throw Exception("Prova com ID '$provaId' não encontrada.");
        }

        _totalPages = totalPages;
        _expectedPage = 1;
        _sessionAnswers.clear();
        await _initializeOmrCamera();
      } catch (e) {
        _resetScanner(
          errorMessage: "Erro: ${e.toString().replaceAll("Exception: ", "")}",
        );
      }
    }
  }

  Future<void> _initializeOmrCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _resetScanner(errorMessage: "Nenhuma câmera encontrada.");
      return;
    }

    ResolutionPreset resolution =
        ResolutionPreset.high; // Captura em alta resolução

    try {
      _omrCameraController = CameraController(
        cameras[0],
        resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg, // Pede JPEG para takePicture
      );
      await _omrCameraController!.initialize();
    } catch (e) {
      debugPrint("Falha ao inicializar câmera: $e");
      // Tenta fallback para YUV (pode ser mais lento para takePicture)
      try {
        _omrCameraController = CameraController(
          cameras[0],
          resolution,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );
        await _omrCameraController!.initialize();
      } catch (fallbackError) {
        debugPrint("Falha ao inicializar com YUV420. Erro: $fallbackError");
        _resetScanner(errorMessage: "Erro fatal ao iniciar câmera.");
        return;
      }
    }

    if (!mounted) return;
    await _omrCameraController!.setFlashMode(FlashMode.off);
    setState(() => _currentFlashMode = FlashMode.off);

    // REMOVIDO: _omrCameraController!.startImageStream(_processOmrImage);
    // A câmera está pronta para o preview e para takePicture()

    setState(() {
      _currentStage = ScannerStage.scanningOmr;
      _statusMessage = "Posicione a Página 1 de $_totalPages";
      _isProcessing = false;
    });
  }

  // --- FUNÇÕES DE PROCESSAMENTO DE STREAM REMOVIDAS ---
  // REMOVIDO: _processOmrImage(CameraImage image)
  // REMOVIDO: _findCornersForStability(CameraImage image)
  // REMOVIDO: _triggerOMRProcessing(CameraImage image)

  // --- NOVAS FUNÇÕES DE CAPTURA E CHAMADA DE API ---

  /// Chamado quando o botão de captura é pressionado.
  Future<void> _onCapturePressed() async {
    if (_isProcessing ||
        _omrCameraController == null ||
        !_omrCameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Capturando foto...";
    });

    XFile? pictureFile;
    try {
      // 1. Tira a Foto
      pictureFile = await _omrCameraController!.takePicture();

      setState(() {
        _statusMessage = "Foto capturada! Enviando para análise...";
      });

      // 2. Envia para a API
      final List<int>? answers = await _sendImageToApi(pictureFile);

      if (!mounted) return;

      // 3. Processa a Resposta
      if (answers != null && answers.isNotEmpty) {
        _sessionAnswers[_expectedPage] = answers;

        if (_expectedPage < _totalPages) {
          // Mais páginas para escanear
          setState(() {
            _expectedPage++;
            _statusMessage =
                "✅ Página ${_expectedPage - 1} lida! Posicione a Página $_expectedPage.";
            _isProcessing = false;
            // Adiciona um pequeno cooldown
          });
        } else {
          // Última página, compila resultados
          final List<int> allAnswers = [];
          final int questionsPerPage =
              (_provaEscaneada!.numeroQuestoes / _totalPages).ceil();

          for (int i = 1; i <= _totalPages; i++) {
            allAnswers.addAll(
              _sessionAnswers[i] ?? List.filled(questionsPerPage, -1),
            );
          }
          // Garante o tamanho correto
          while (allAnswers.length < _provaEscaneada!.numeroQuestoes) {
            allAnswers.add(-1);
          }
          if (allAnswers.length > _provaEscaneada!.numeroQuestoes) {
            allAnswers.removeRange(
              _provaEscaneada!.numeroQuestoes,
              allAnswers.length,
            );
          }

          setState(
            () => _statusMessage = "Sucesso! Exibindo resultado final...",
          );
          _mostrarResultados(
            allAnswers,
            pictureFile.path,
          ); // Passa o path local
        }
      } else {
        // API falhou ou não retornou respostas
        setState(() {
          _statusMessage = "Falha na análise da API. Tente novamente.";
          _isProcessing = false;
        });
      }
    } catch (e) {
      // Erro ao tirar foto ou na chamada da API
      debugPrint("Erro em _onCapturePressed: $e");
      if (mounted) {
        setState(() {
          _statusMessage = "Erro: ${e.toString()}. Tente novamente.";
          _isProcessing = false;
        });
      }
    }
  }

  /// Envia a imagem capturada para a API Python no Cloud Run.
  Future<List<int>?> _sendImageToApi(XFile imageFile) async {
    try {
      final uri = Uri.parse(_apiUrl);
      var request = http.MultipartRequest('POST', uri);

      // Calcula o número de questões para esta página específica
      final int maxQuestionsPerPage = 25; // Sincronizado com o Python
      final int questoesPaginaAnterior =
          (_expectedPage - 1) * maxQuestionsPerPage;
      final int questionsOnThisPage = min(
        maxQuestionsPerPage,
        _provaEscaneada!.numeroQuestoes - questoesPaginaAnterior,
      );

      // Adiciona campos de formulário (ex: número de questões)
      request.fields['expected_questions'] = questionsOnThisPage.toString();
      // (Você pode adicionar mais campos se a API precisar, ex: 'page_number')

      // Adiciona o ficheiro de imagem
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // Nome do campo esperado pelo servidor Flask/Python
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      debugPrint("Enviando imagem para API ($questionsOnThisPage questões)...");

      // Envia a requisição
      final response = await request.send();

      // Lê a resposta
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        // Sucesso
        final jsonResponse = jsonDecode(responseBody);
        List<int> answers = (jsonResponse['answers'] as List).cast<int>();
        debugPrint("API retornou sucesso. Respostas: $answers");
        return answers;
      } else {
        // Erro do servidor
        debugPrint(
          "Falha na API: ${response.statusCode}. Resposta: $responseBody",
        );
        return null;
      }
    } catch (e) {
      debugPrint("Erro de rede/http ao chamar API: $e");
      return null;
    }
  }

  // --- Funções de Resultado e Reset (Quase inalteradas) ---

  void _mostrarResultados(List<int> resultados, String? imagePath) {
    final gabaritoOficial = (_provaEscaneada!.gabarito as List<dynamic>)
        .cast<int>();
    final validacao = GabaritoValidator.validarRespostas(
      respostasDetectadas: resultados,
      gabaritoOficial: gabaritoOficial,
      numQuestoes: _provaEscaneada!.numeroQuestoes,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Resultados da Correção'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prova: ${_provaEscaneada!.titulo}'),
              if (_alunoEscaneado != null)
                Text('Aluno: ${_alunoEscaneado!.nome}'),
              const SizedBox(height: 8),
              Text(
                'Acertos: ${validacao.acertos} | Nota: ${validacao.nota.toStringAsFixed(1)}/10',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    "Imagem salva localmente (para debug): $imagePath",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScanner();
            },
            child: const Text('Escanear Outro'),
          ),
          ElevatedButton(
            onPressed: () => _salvarResultados(resultados, imagePath),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSave(
    Aluno alunoParaSalvar,
    List<int> resultados,
    String? imagePath,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _resultadoService.salvarResultado(
        provaId: _provaEscaneada!.id!,
        turmaId: alunoParaSalvar.turmaId,
        aluno: alunoParaSalvar,
        gabaritoOficial: (_provaEscaneada!.gabarito as List<dynamic>)
            .cast<int>(),
        respostasAluno: resultados,
        imagePath: imagePath, // Salva o path da imagem local
      );
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('✅ Resultado salvo para ${alunoParaSalvar.nome}!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('❌ Erro ao salvar: $e')),
      );
    } finally {
      _resetScanner();
    }
  }

  Future<void> _salvarResultados(
    List<int> resultados,
    String? imagePath,
  ) async {
    final navigator = Navigator.of(context);
    navigator.pop(); // Fecha o diálogo de resultados

    Aluno? alunoParaSalvar = _alunoEscaneado;

    if (alunoParaSalvar != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Aluno'),
          content: Text(
            'Salvar este resultado para o aluno "${alunoParaSalvar.nome}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CORRIGIR ALUNO'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('CONFIRMAR'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _executeSave(alunoParaSalvar, resultados, imagePath);
      } else if (confirm == false) {
        final Aluno? alunoSelecionado = await showDialog<Aluno>(
          context: context,
          builder: (_) => const SelecionarAlunoDialog(),
        );
        if (alunoSelecionado != null) {
          await _executeSave(alunoSelecionado, resultados, imagePath);
        } else {
          _resetScanner();
        }
      } else {
        _resetScanner();
      }
    } else {
      final Aluno? alunoSelecionado = await showDialog<Aluno>(
        context: context,
        builder: (_) => const SelecionarAlunoDialog(),
      );
      if (alunoSelecionado != null) {
        await _executeSave(alunoSelecionado, resultados, imagePath);
      } else {
        _resetScanner();
      }
    }
  }

  void _resetScanner({String? errorMessage}) {
    // REMOVIDO: _omrCameraController?.stopImageStream();
    _omrCameraController?.dispose();
    _omrCameraController = null;
    _qrScannerController.start();
    setState(() {
      _currentStage = ScannerStage.scanningQrCode;
      _statusMessage = errorMessage ?? "Aponte para o QR Code da prova";
      _isProcessing = false;
      _provaEscaneada = null;
      _alunoEscaneado = null;
      _expectedPage = 1;
      _totalPages = 0;
      _sessionAnswers.clear();
      // REMOVIDO: _isCoolingDown, _previousCorners, _markersDetected, _stableFrames
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner API'), // Título atualizado
        foregroundColor: Colors.white,
        actions: [
          // Botão de Reset movido para a AppBar
          IconButton(
            onPressed: () => _resetScanner(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_currentStage == ScannerStage.scanningQrCode)
            MobileScanner(
              controller: _qrScannerController,
              onDetect: _onQrCodeDetected,
            )
          else if (_omrCameraController != null &&
              _omrCameraController!.value.isInitialized)
            Center(child: CameraPreview(_omrCameraController!))
          else
            const Center(child: CircularProgressIndicator()),
          if (_currentStage == ScannerStage.scanningOmr)
            _buildScannerOverlay(context), // Overlay visual
          if (_currentStage == ScannerStage.scanningOmr)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: _toggleFlash,
                icon: Icon(
                  _currentFlashMode == FlashMode.torch
                      ? Icons.flash_on
                      : Icons.flash_off,
                  size: 32,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withAlpha(100),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_statusMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // --- NOVO BOTÃO DE CAPTURA ---
                  if (_currentStage == ScannerStage.scanningOmr)
                    _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : IconButton(
                            onPressed: _onCapturePressed, // Chama a nova função
                            icon: const Icon(Icons.camera_alt),
                            iconSize: 64, // Botão grande
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withAlpha(100),
                            ),
                          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Overlay visual (inalterado)
  Widget _buildScannerOverlay(BuildContext context) {
    // Agora _markersDetected não existe. O overlay será sempre branco.
    // Poderíamos reativar _markersDetected se fizermos uma chamada leve à API
    // mas por agora vamos simplificar.
    final cornerColor = Colors.white.withAlpha(200);
    const double cornerLength = 30.0;
    const double cornerThickness = 4.0;
    final overlayWidth = MediaQuery.of(context).size.width * 0.9;
    final overlayHeight = overlayWidth * sqrt(2); // A4 ratio

    return Center(
      child: SizedBox(
        width: overlayWidth,
        height: overlayHeight,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: _buildCorner(
                cornerColor,
                cornerLength,
                cornerThickness,
                isTopLeft: true,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _buildCorner(
                cornerColor,
                cornerLength,
                cornerThickness,
                isTopRight: true,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: _buildCorner(
                cornerColor,
                cornerLength,
                cornerThickness,
                isBottomLeft: true,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: _buildCorner(
                cornerColor,
                cornerLength,
                cornerThickness,
                isBottomRight: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(
    Color color,
    double length,
    double thickness, {
    bool isTopLeft = false,
    bool isTopRight = false,
    bool isBottomLeft = false,
    bool isBottomRight = false,
  }) {
    return SizedBox(
      width: length,
      height: length,
      child: CustomPaint(
        painter: _CornerPainter(
          color,
          thickness,
          isTopLeft: isTopLeft,
          isTopRight: isTopRight,
          isBottomLeft: isBottomLeft,
          isBottomRight: isBottomRight,
        ),
      ),
    );
  }
} // Fim de CameraScannerPageState

// --- Funções Helper Removidas ---
// REMOVIDO: _saveImageTemporarily, _convertBGRA8888, _convertFromPlanes

// Custom painter (inalterado)
class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isTopLeft;
  final bool isTopRight;
  final bool isBottomLeft;
  final bool isBottomRight;

  _CornerPainter(
    this.color,
    this.thickness, {
    this.isTopLeft = false,
    this.isTopRight = false,
    this.isBottomLeft = false,
    this.isBottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (isTopLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTopRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (isBottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (isBottomRight) {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => false;
}
