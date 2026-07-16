import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/client.dart';
import '../config/app_config.dart';
import '../models/message.dart';
import '../services/file_service.dart';
import '../services/preferences_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../widgets/camera_screen.dart';

class ChatProvider extends ChangeNotifier {
  final ApiClient _api;
  final PreferencesService _prefs;
  final FileService _fileService;
  final SpeechService _speech;
  final TtsService _tts;

  ChatProvider({
    ApiClient? api,
    PreferencesService? prefs,
    FileService? fileService,
    SpeechService? speech,
    TtsService? tts,
  }) : _api = api ?? ApiClient(),
       _prefs = prefs ?? PreferencesService(),
       _fileService = fileService ?? FileService(),
       _speech = speech ?? SpeechService(),
       _tts = tts ?? TtsService() {
    _init();
  }

  final List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  bool _isTakingLong = false;
  bool get isTakingLong => _isTakingLong;
  ThemeMode _themeMode = ThemeMode.system;

  bool _isListening = false;
  String _voiceText = '';

  bool _isSpeaking = false;
  String? _speakingMessageId;

  final List<MessageAttachment> _pendingAttachments = [];

  String _searchQuery = '';

  double _ttsSpeed = 1.0;
  double _ttsPitch = 1.0;
  bool _autoSendVoice = false;

  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
  bool get isListening => _isListening;
  String get voiceText => _voiceText;
  bool get isSpeaking => _isSpeaking;
  String? get speakingMessageId => _speakingMessageId;
  List<MessageAttachment> get pendingAttachments => _pendingAttachments;
  String get searchQuery => _searchQuery;
  double get ttsSpeed => _ttsSpeed;
  double get ttsPitch => _ttsPitch;
  bool get autoSendVoice => _autoSendVoice;
  ApiClient get apiClient => _api;
  List<ChatMessage> get currentMessages => _currentConversation?.messages ?? [];
  String? get currentConversationId => _currentConversation?.id;
  String? _error;
  String? get error => _error;

  List<Conversation> get filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    final query = _searchQuery.toLowerCase();
    return _conversations.where((c) => c.displayTitle.toLowerCase().contains(query)).toList();
  }

  Future<void> _init() async {
    await _loadPrefs();
    await _initTts();
    _newConversation();
  }

  void _newConversation() {
    _currentConversation = Conversation(id: DateTime.now().millisecondsSinceEpoch.toString());
    _conversations.insert(0, _currentConversation!);
    _prefs.saveConversations(_conversations).catchError((_) {});
    notifyListeners();
  }

  void newChat() {
    _pendingAttachments.clear();
    _voiceText = '';
    _newConversation();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs.saveThemeMode(mode);
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.system) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _themeMode = brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    } else {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    }
    _prefs.saveThemeMode(_themeMode);
    notifyListeners();
  }

  void switchConversation(String id) {
    final idx = _conversations.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _currentConversation = _conversations[idx];
      _pendingAttachments.clear();
      _voiceText = '';
      notifyListeners();
    }
  }

  void deleteConversation(String id) {
    _conversations.removeWhere((c) => c.id == id);
    if (_currentConversation?.id == id) {
      if (_conversations.isNotEmpty) {
        _currentConversation = _conversations.first;
      } else {
        _newConversation();
      }
    }
    _prefs.saveConversations(_conversations).catchError((_) {});
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void cancelGeneration() {
    _isLoading = false;
    _isTakingLong = false;
    _api.cancelCurrentRequest();
    notifyListeners();
  }

  static const String autoDetectPrompt =
      'Analyze this image and auto-detect its type. '
      'If it contains a QR code or barcode, decode its contents. '
      'If it contains text in another language, translate it. '
      'If it appears to be a medical image, analyze for diseases or anomalies. '
      'If it contains encoded or hidden data, decode it. '
      'If it is a document or screenshot, extract and summarize the content. '
      'Otherwise, provide a detailed analysis of what you see.';

  Future<void> sendMessage(String text, {List<MessageAttachment>? attachments}) async {
    final attach = attachments ?? _pendingAttachments;
    if (text.trim().isEmpty && attach.isEmpty) return;

    if (_currentConversation == null) _newConversation();
    if (_isLoading) cancelGeneration();

    _isLoading = true;
    _isTakingLong = false;
    notifyListeners();

    final userMsg = ChatMessage(role: 'user', content: text, attachments: List.from(attach));
    _currentConversation!.messages.add(userMsg);
    _currentConversation!.updatedAt = DateTime.now();
    if (attachments == null) _pendingAttachments.clear();
    notifyListeners();

    const maxAttempts = 3;
    String? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final resp = await _callApi(userMsg, text);
        final imageData = resp['image_data'] as String? ?? '';
        final fileData = resp['file_data'] as String? ?? '';
        final fileName = resp['file_name'] as String? ?? '';
        final fileType = resp['file_type'] as String? ?? '';
        final rawContent = resp['response'] as String? ?? '';
        final respType = resp['type'] as String? ?? 'chat';

        if (respType == 'error') {
          final errMsg = resp['response'] as String? ?? resp['error'] as String? ?? '';
          _addAssistantMessage(errMsg.isNotEmpty ? errMsg : 'An error occurred. Please try again.');
          _isTakingLong = false;
          _isLoading = false;
          _prefs.saveConversations(_conversations).catchError((_) {});
          notifyListeners();
          return;
        }

        if (rawContent.isNotEmpty || imageData.isNotEmpty || fileData.isNotEmpty) {
          _currentConversation!.messages.add(ChatMessage(
            role: 'assistant', content: rawContent,
            imageData: imageData, fileData: fileData, fileName: fileName, fileType: fileType,
          ));
        }
        _isTakingLong = false;
        _isLoading = false;
        _prefs.saveConversations(_conversations).catchError((_) {});
        notifyListeners();
        return;
      } catch (e) {
        lastError = e.toString();
        if (attempt < maxAttempts - 1) {
          _isTakingLong = true;
          notifyListeners();
          await Future.delayed(Duration(seconds: (1 << attempt)));
          continue;
        }
      }
    }

    _addAssistantMessage(_generateFallbackResponse(text, lastError));
    _isTakingLong = false;
    _isLoading = false;
    _prefs.saveConversations(_conversations).catchError((_) {});
    notifyListeners();
  }

  String _generateFallbackResponse(String userText, String? error) {
    final isNetworkError = error != null && (
      error.contains('SocketException') ||
      error.contains('TimeoutException') ||
      error.contains('HandshakeException') ||
      error.contains('Connection refused') ||
      error.contains('No address associated with hostname') ||
      error.contains('Failed host lookup') ||
      error.contains('ClientException') ||
      error.contains('Failed to fetch') ||
      error.contains('TypeError') ||
      error.contains('XMLHttpRequest'));
    final isServerError = error != null && (
      error.contains('ApiException') ||
      error.contains('500') ||
      error.contains('502') ||
      error.contains('503'));

    if (isNetworkError) {
      return 'I\'m having trouble connecting to the server. Your message has been received and I\'ll respond as soon as the connection is restored. Please try again in a moment.';
    }
    if (isServerError) {
      return 'The AI service is temporarily unavailable. Please try again in a few moments. If the issue persists, the server may be undergoing maintenance.';
    }
    return 'I\'m currently unable to process your request. Please try again. If this continues, check your internet connection or try again later.';
  }

  void _addAssistantMessage(String content) {
    _currentConversation!.messages.add(ChatMessage(role: 'assistant', content: content));
  }

  Future<void> sendPendingAnalysis() async {
    if (_pendingAttachments.isEmpty) return;
    final attachments = List<MessageAttachment>.from(_pendingAttachments);
    _pendingAttachments.clear();
    notifyListeners();
    await sendMessage(autoDetectPrompt, attachments: attachments);
  }

  bool _isImageGenRequest(String text) {
    final t = text.trim().toLowerCase();
    if (t.length < 4) return false;
    final prefixes = ['draw ', 'paint ', 'sketch ', 'generate ', 'create '];
    for (final p in prefixes) { if (t.startsWith(p)) return true; }
    final patterns = [
      'generate an image', 'generate a picture', 'generate a photo',
      'create an image', 'create a picture', 'create a photo',
      'make an image', 'make a picture', 'make a photo',
      'generate image of', 'generate picture of', 'create image of', 'create picture of',
      'image of a', 'image of an', 'picture of a', 'picture of an',
      'draw me a', 'draw me an', 'paint me a',
    ];
    for (final pat in patterns) { if (t.contains(pat)) return true; }
    return false;
  }

  Future<Map<String, dynamic>> _callApi(ChatMessage userMsg, String text) async {
    final hasImage = userMsg.attachments.any((a) => a.type == AttachmentType.image);
    final sessionId = _currentConversation?.id;
    const timeout = AppConfig.aiResponseTimeout;

    if (hasImage) {
      final imgAttach = userMsg.attachments.firstWhere((a) => a.type == AttachmentType.image);
      final bytes = await FileService.readAttachmentBytes(imgAttach);
      final resp = await _api.chatWithImage(message: text, imageBytes: bytes, fileName: imgAttach.name, sessionId: sessionId, timeout: timeout);
      return {'response': resp.content, 'image_data': '', 'type': resp.type};
    } else if (userMsg.attachments.isNotEmpty) {
      final attach = userMsg.attachments.first;
      final bytes = await FileService.readAttachmentBytes(attach);
      final resp = await _api.uploadFile(fileBytes: bytes, fileName: attach.name, message: text, sessionId: sessionId, timeout: timeout);
      return {'response': resp.content, 'image_data': '', 'type': resp.type};
    }

    if (_isImageGenRequest(text)) {
      final imgResp = await _api.generateImage(prompt: text, sessionId: sessionId, timeout: timeout);
      return {
        'response': (imgResp['response'] as String?) ?? (imgResp['content'] as String?) ?? '',
        'image_data': (imgResp['image_data'] as String?) ?? (imgResp['imageBase64'] as String?) ?? '',
        'type': (imgResp['type'] as String?) ?? 'image_gen',
      };
    }

    final resp = await _api.chat(message: text, sessionId: sessionId, timeout: timeout);
    return {
      'response': resp.content,
      'image_data': resp.imageBase64 ?? '',
      'type': resp.type,
      'file_data': resp.fileData ?? '',
      'file_name': resp.fileName ?? '',
      'file_type': resp.fileType ?? '',
    };
  }

  Future<void> pickImageForAnalysis(BuildContext context) async {
    try {
      final attachment = await _fileService.pickImageFromGallery();
      if (attachment != null) { _pendingAttachments.add(attachment); notifyListeners(); }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to load image. Please try again.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  Future<void> analyzeWithCamera(BuildContext context) async {
    try {
      final result = await Navigator.push<(String?, CameraResult)>(
        context,
        MaterialPageRoute<(String?, CameraResult)>(
          builder: (_) => const CameraScreen(),
          fullscreenDialog: true,
        ),
      );
      if (result != null && context.mounted) {
        final (path, camResult) = result;
        if (path != null && camResult == CameraResult.success) {
          _pendingAttachments.add(
            MessageAttachment(name: 'Camera.jpg', path: path, type: AttachmentType.image),
          );
          notifyListeners();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not access camera: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  Future<void> startVoiceInput() async {
    try {
      final available = await _speech.initialize(
        onError: (_) { _isListening = false; notifyListeners(); },
        onStatus: (status) {
          if (status == 'notListening' && _isListening) {
            _isListening = false;
            if (_voiceText.isNotEmpty && _autoSendVoice) {
              final text = _voiceText;
              _voiceText = '';
              sendMessage(text);
            }
            notifyListeners();
          }
        },
      );
      if (!available) return;

      _isListening = true;
      _voiceText = '';
      notifyListeners();

      await _speech.startListening(onResult: (result) {
        _voiceText = result.recognizedWords ?? '';
        notifyListeners();
      });
    } catch (e) {
      _isListening = false;
      notifyListeners();
    }
  }

  void stopVoiceInput() {
    _isListening = false;
    _speech.stopListening();
    notifyListeners();
  }

  void clearVoiceText() { _voiceText = ''; notifyListeners(); }

  Future<void> pickImage(ImageSource source) async {
    try {
      final attachment = source == ImageSource.camera
          ? await _fileService.pickImageFromCamera()
          : await _fileService.pickImageFromGallery();
      if (attachment != null) { _pendingAttachments.add(attachment); notifyListeners(); }
    } catch (_) {}
  }

  Future<void> pickFile() async {
    try {
      final attachment = await _fileService.pickFile();
      if (attachment != null) { _pendingAttachments.add(attachment); notifyListeners(); }
    } catch (_) {}
  }

  void removePendingAttachment(int index) {
    if (index >= 0 && index < _pendingAttachments.length) {
      _pendingAttachments.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> _initTts() async {
    try {
      await _tts.initialize(
        onComplete: () { _isSpeaking = false; _speakingMessageId = null; notifyListeners(); },
        onError: (_) { _isSpeaking = false; _speakingMessageId = null; notifyListeners(); },
      );
    } catch (_) {}
  }

  Future<void> speakMessage(String messageId, String text) async {
    try {
      if (_isSpeaking && _speakingMessageId == messageId) {
        await _tts.stop();
        _isSpeaking = false;
        _speakingMessageId = null;
        notifyListeners();
        return;
      }
      if (_isSpeaking) await _tts.stop();
      await _tts.setSpeed(_ttsSpeed);
      await _tts.setPitch(_ttsPitch);
      _isSpeaking = true;
      _speakingMessageId = messageId;
      notifyListeners();
      await _tts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      _speakingMessageId = null;
      notifyListeners();
    }
  }

  void stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    _speakingMessageId = null;
    notifyListeners();
  }

  void updateTtsSpeed(double speed) {
    _ttsSpeed = speed;
    _tts.setSpeed(speed);
    _prefs.saveTtsSpeed(speed);
    notifyListeners();
  }

  void updateTtsPitch(double pitch) {
    _ttsPitch = pitch;
    _tts.setPitch(pitch);
    _prefs.saveTtsPitch(pitch);
    notifyListeners();
  }

  void setAutoSendVoice(bool v) {
    _autoSendVoice = v;
    _prefs.saveAutoSendVoice(v);
    notifyListeners();
  }

  void setError(String? error) { _error = error; notifyListeners(); }
  void handleSendMessage(String query) => sendMessage(query);
  void loadTheme() { notifyListeners(); }


  Future<void> _loadPrefs() async {
    try {
      _themeMode = await _prefs.loadThemeMode();
      _ttsSpeed = await _prefs.loadTtsSpeed();
      _ttsPitch = await _prefs.loadTtsPitch();
      _autoSendVoice = await _prefs.loadAutoSendVoice();
      final loaded = await _prefs.loadConversations();
      _conversations.addAll(loaded);
      if (_conversations.isNotEmpty) _currentConversation = _conversations.first;
      notifyListeners();
    } catch (_) {}
  }
}
