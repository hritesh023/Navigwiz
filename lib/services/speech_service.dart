import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech;
  bool _isInitialized = false;

  SpeechService({stt.SpeechToText? speech}) : _speech = speech ?? stt.SpeechToText();

  bool get isInitialized => _isInitialized;
  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(dynamic error)? onError,
  }) async {
    if (_isInitialized) return true;
    final available = await _speech.initialize(onStatus: onStatus, onError: onError);
    _isInitialized = available;
    return available;
  }

  Future<void> startListening({
    required void Function(dynamic result) onResult,
  }) async {
    if (_speech.isListening) await _speech.stop();
    await _speech.listen(
      onResult: onResult,
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(hours: 24),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
      ),
    );
  }

  Future<String?> listen({Duration timeout = const Duration(seconds: 10)}) async {
    if (!_isInitialized) {
      final available = await initialize();
      if (!available) return null;
    }

    final completer = Completer<String?>();

    await startListening(onResult: (result) {
      if (result.finalResult) {
        completer.complete(result.recognizedWords);
      }
    });

    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        stopListening();
        completer.complete(null);
      }
    });

    return completer.future;
  }

  void stopListening() {
    if (_speech.isListening) _speech.stop();
  }

  void dispose() {
    if (_speech.isListening) _speech.stop();
  }
}
