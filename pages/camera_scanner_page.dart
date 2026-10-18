import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../components/selecionar_aluno_dialog.dart';
import '../models/aluno.dart';
import '../models/prova.dart';
import '../scanner/scan_contract.dart';
import '../services/aluno_service.dart';
import '../services/omr_service.dart';
import '../services/prova_service.dart';
import '../services/resultado_service.dart';
import '../utils/validator.dart';

enum ScannerStage { starting, qr, loading, sheet, review }

class CameraScannerPage extends StatefulWidget {
  const CameraScannerPage({super.key});
  @override
  CameraScannerPageState createState() => CameraScannerPageState();
}

class CameraScannerPageState extends State<CameraScannerPage>
    with WidgetsBindingObserver {
  final _qr = MobileScannerController(autoStart: false);
  final _omr = OmrService();
  final _provas = ProvaService();
  final _alunos = AlunoService();
  final _resultados = ResultadoService();
  CameraController? _camera;
  Future<void> _cameraQueue = Future<void>.value();
  ScannerStage _stage = ScannerStage.starting;
  String _status = 'Preparando câmera…';
  bool _busy = false;
  bool _foreground = true;
  bool _reviewing = false;
  bool _torch = false;
  int _generation = 0;
  Prova? _prova;
  Aluno? _aluno;

  bool _current(int generation) =>
      mounted && _foreground && generation == _generation;

  // QR and photo capture share the same hardware. Never open both at once.
  Future<void> _serializeCamera(Future<void> Function() action) {
    final operation = _cameraQueue.then((_) => action());
    _cameraQueue = operation.catchError((Object _) {});
    return operation;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reset());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (!_reviewing) unawaited(_reset());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      ++_generation;
      _omr.cancel();
      unawaited(_serializeCamera(_releaseCameras).catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _omr.cancel();
    unawaited(
      _serializeCamera(() async {
        await _releaseCameras();
        await _qr.dispose();
      }).catchError((Object _) {}),
    );
    super.dispose();
  }

  Future<void> _releaseCameras() async {
    final camera = _camera;
    _camera = null;
    try {
      await _qr.stop();
    } finally {
      await camera?.dispose();
    }
  }

  String _error(Object error) {
    if (error is OmrException) return error.message;
    if (error is FormatException) return error.message;
    if (error is TimeoutException)
      return 'A consulta demorou demais. Tente novamente.';
    if (error is CameraException && error.code.contains('Access')) {
      return 'Permita o acesso à câmera nas configurações do celular.';
    }
    return 'Não foi possível concluir a operação. Verifique a conexão e tente novamente.';
  }

  Future<void> _reset({String? message}) async {
    if (!mounted || !_foreground || _reviewing) return;
    final generation = ++_generation;
    _omr.cancel();
    setState(() {
      _stage = ScannerStage.starting;
      _busy = true;
      _prova = null;
      _aluno = null;
      _torch = false;
      _status = message ?? 'Aponte para o QR Code da folha';
    });
    try {
      await _serializeCamera(() async {
        await _releaseCameras();
        if (_current(generation)) await _qr.start();
      });
      if (!_current(generation)) return;
      setState(() {
        _stage = ScannerStage.qr;
        _busy = false;
      });
    } catch (error) {
      if (!_current(generation)) return;
      setState(() {
        _busy = false;
        _status = _error(error);
      });
    }
  }

  Future<void> _onQr(BarcodeCapture capture) async {
    if (_busy || _stage != ScannerStage.qr || !_foreground) return;
    final codes = capture.barcodes.where((code) => code.rawValue != null);
    if (codes.isEmpty) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _stage = ScannerStage.loading;
      _status = 'Conferindo a prova…';
    });
    try {
      await _serializeCamera(() async => _qr.stop());
      if (!_current(generation)) return;
      final sheet = ScanSheet.parse(codes.first.rawValue!);
      final prova = await _provas
          .getProvaById(sheet.provaId)
          .timeout(const Duration(seconds: 20));
      if (!_current(generation)) return;
      if (prova == null) throw const FormatException('Prova não encontrada.');
      sheet.questionsOnSheet(prova.numeroQuestoes);
      if (prova.gabarito.length != prova.numeroQuestoes ||
          prova.gabarito.any((answer) => answer < 0 || answer > 4)) {
        throw const FormatException(
          'Revise o gabarito da prova antes de escanear.',
        );
      }
      Aluno? aluno;
      if (sheet.alunoId != null) {
        aluno = await _alunos
            .getAlunoById(sheet.turmaId!, sheet.alunoId!)
            .timeout(const Duration(seconds: 20));
        if (!_current(generation)) return;
        if (aluno == null)
          throw const FormatException('Aluno da folha não encontrado.');
      }
      _prova = prova;
      _aluno = aluno;
      await _serializeCamera(() async {
        if (!_current(generation)) return;
        final cameras = await availableCameras();
        if (!_current(generation)) return;
        if (cameras.isEmpty)
          throw const FormatException('Nenhuma câmera disponível.');
        final back = cameras.where(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        final controller = CameraController(
          back.isEmpty ? cameras.first : back.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        try {
          await controller.initialize();
          if (!_current(generation)) {
            await controller.dispose();
            return;
          }
          _camera = controller;
          // Some devices do not support flash. That must not block scanning.
          try {
            await controller.setFlashMode(FlashMode.off);
          } on CameraException {
            /* optional */
          }
        } catch (_) {
          if (identical(_camera, controller)) _camera = null;
          await controller.dispose();
          rethrow;
        }
      });
      if (!_current(generation)) return;
      setState(() {
        _stage = ScannerStage.sheet;
        _busy = false;
        _status = 'Enquadre a folha inteira, incluindo os quatro cantos';
      });
    } catch (error) {
      if (_current(generation)) await _reset(message: _error(error));
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    final prova = _prova;
    if (_busy || camera == null || prova == null || !camera.value.isInitialized)
      return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _status = 'Fotografando…';
    });
    XFile? photo;
    var enteredReview = false;
    try {
      photo = await camera.takePicture();
      if (!_current(generation)) return;
      setState(() => _status = 'Lendo as ${prova.numeroQuestoes} questões…');
      final answers = await _omr.scan(photo.path, prova.numeroQuestoes);
      if (!_current(generation)) return;
      _reviewing = true;
      enteredReview = true;
      setState(() => _stage = ScannerStage.review);
      await _serializeCamera(_releaseCameras);
      if (!mounted || !_foreground) return;
      await _reviewAndSave(prova, answers, photo.path);
    } catch (error) {
      if (_current(generation)) {
        setState(() {
          _status = _error(error);
          _busy = false;
        });
      }
    } finally {
      // The upload completes before cleanup; temporary photos do not accumulate.
      if (photo != null) {
        try {
          await File(photo.path).delete();
        } on FileSystemException {
          /* already removed */
        }
      }
      if (enteredReview) {
        _reviewing = false;
        if (mounted && _foreground) await _reset();
      }
    }
  }

  Future<void> _reviewAndSave(
    Prova prova,
    List<int> detected,
    String path,
  ) async {
    final answers = List<int>.from(detected);
    while (mounted) {
      final save = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, refresh) {
            final grade = GabaritoValidator.validarRespostas(
              respostasDetectadas: answers,
              gabaritoOficial: prova.gabarito,
              numQuestoes: prova.numeroQuestoes,
            );
            return AlertDialog(
              title: const Text('Confira a leitura'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prova.titulo),
                      if (_aluno != null) Text('Aluno: ${_aluno!.nome}'),
                      const SizedBox(height: 12),
                      Image.file(File(path), height: 150, fit: BoxFit.contain),
                      const SizedBox(height: 12),
                      Text(
                        '${grade.acertos} acertos · Nota ${grade.nota.toStringAsFixed(1)}',
                      ),
                      const Text(
                        'Compare com a foto. Toque na alternativa para corrigir a leitura.',
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < answers.length; i++)
                        Row(
                          children: [
                            Expanded(child: Text('Questão ${i + 1}')),
                            DropdownButton<int>(
                              value: answers[i],
                              items: [
                                for (final value in [-2, -1, 0, 1, 2, 3, 4])
                                  DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      value == -2
                                          ? 'Múltiplas'
                                          : value == -1
                                          ? 'Em branco'
                                          : GabaritoValidator.letraAlternativa(
                                              value,
                                            ),
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null)
                                  refresh(() => answers[i] = value);
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Nova leitura'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Continuar'),
                ),
              ],
            );
          },
        ),
      );
      if (!mounted || save != true) return;
      final aluno = await showDialog<Aluno>(
        context: context,
        builder: (context) => _aluno == null
            ? const SelecionarAlunoDialog()
            : AlertDialog(
                title: const Text('Confirmar aluno'),
                content: Text('Salvar a correção para ${_aluno!.nome}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _aluno),
                    child: const Text('Salvar'),
                  ),
                ],
              ),
      );
      if (!mounted) return;
      if (aluno == null) continue;
      setState(() => _status = 'Salvando correção…');
      try {
        await _resultados.salvarResultado(
          provaId: prova.id!,
          turmaId: aluno.turmaId,
          aluno: aluno,
          gabaritoOficial: prova.gabarito,
          respostasAluno: answers,
          imagePath: path,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Correção salva para ${aluno.nome}.')),
        );
        return;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível confirmar o salvamento. As respostas foram mantidas. Confira os resultados antes de tentar novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (_busy || camera == null) return;
    final generation = _generation;
    try {
      final next = !_torch;
      await camera.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (_current(generation)) setState(() => _torch = next);
    } on CameraException {
      if (_current(generation))
        setState(() => _status = 'Flash indisponível nesta câmera.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: const Color(0xff101c29),
      appBar: AppBar(
        title: const Text('Corrigir prova'),
        actions: [
          IconButton(
            tooltip: 'Reiniciar leitura',
            onPressed: _reviewing ? null : () => _reset(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _stage == ScannerStage.qr
                        ? Icons.qr_code_scanner
                        : Icons.document_scanner_outlined,
                    color: Colors.tealAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _prova?.titulo ?? '1. Identifique a folha pelo QR Code',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    // Keep the QR widget mounted; start/stop is controlled explicitly.
                    Offstage(
                      offstage: _stage != ScannerStage.qr,
                      child: MobileScanner(controller: _qr, onDetect: _onQr),
                    ),
                    if (_stage == ScannerStage.sheet &&
                        camera != null &&
                        camera.value.isInitialized)
                      Center(
                        child: AspectRatio(
                          aspectRatio: 1 / camera.value.aspectRatio,
                          child: CameraPreview(camera),
                        ),
                      ),
                    if (_stage == ScannerStage.sheet)
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: min(
                              constraints.maxWidth * .9,
                              constraints.maxHeight * .9 / sqrt(2),
                            ),
                            height: min(
                              constraints.maxHeight * .9,
                              constraints.maxWidth * .9 * sqrt(2),
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white70,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (_stage == ScannerStage.sheet)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          tooltip: 'Alternar flash',
                          onPressed: _busy ? null : _toggleFlash,
                          icon: Icon(
                            _torch ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (_busy)
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.tealAccent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_stage == ScannerStage.sheet)
                    FilledButton.icon(
                      onPressed: _busy ? null : _capture,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Fotografar folha'),
                    ),
                  if (_stage == ScannerStage.starting && !_busy)
                    FilledButton(
                      onPressed: () => _reset(),
                      child: const Text('Tentar novamente'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
