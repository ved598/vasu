import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'models.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const kAutoChannel = MethodChannel('com.nova.ai/automation');

// ─── API Service ──────────────────────────────────────────────────────────────
class ApiService {
  late Dio _dio;
  String _baseUrl;

  static const _system = '''
You are NOVA - a smart AI voice assistant on Android.
Be concise and helpful. When you can perform a device action,
include this JSON block in your reply:
```action
{"type":"open_app","package":"com.android.chrome"}
```
Action types: open_app(package), open_url(url), open_settings(screen),
search_web(query), play_music.
Otherwise just answer normally.
''';

  ApiService(this._baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
  }

  void setApiKey(String key) {
    _dio.options.headers['X-API-Key'] = key;
  }

  Future<bool> ping() async {
    try {
      final r = await _dio.get('/health');
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<NovaResponse> chat(List<Message> history, String userMsg) async {
    final messages = [
      ...history.take(20).map((m) => m.toApi()),
      {'role': 'user', 'content': userMsg},
    ];
    try {
      final r = await _dio.post('/chat', data: {
        'messages': messages,
        'system': _system,
        'temperature': 0.7,
      });
      return NovaResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail']?.toString() ??
          e.message ?? 'Server error';
      throw Exception(msg);
    }
  }

  Stream<String> chatStream(List<Message> history, String userMsg) async* {
    final messages = [
      ...history.take(20).map((m) => m.toApi()),
      {'role': 'user', 'content': userMsg},
    ];

    final response = await _dio.post<ResponseBody>(
      '/chat/stream',
      data: {'messages': messages, 'system': _system, 'stream': true},
      options: Options(responseType: ResponseType.stream),
    );

    await for (final chunk in response.data!.stream) {
      final text = utf8.decode(chunk);
      for (final line in text.split('\n')) {
        if (line.startsWith('data: ')) {
          final raw = line.substring(6).trim();
          if (raw == '[DONE]') return;
          try {
            final j = jsonDecode(raw) as Map;
            final delta = j['delta'] as String? ?? j['token'] as String? ?? '';
            if (delta.isNotEmpty) yield delta;
          } catch (_) {
            if (raw.isNotEmpty) yield raw;
          }
        }
      }
    }
  }

  Future<List<String>> getModels() async {
    try {
      final r = await _dio.get('/models');
      final d = r.data;
      if (d is List) return d.cast<String>();
      if (d is Map && d['models'] is List) return (d['models'] as List).cast<String>();
      return [];
    } catch (_) {
      return ['gpt-4o-mini', 'gpt-4o', 'claude-3-haiku', 'gemini-2.0-flash'];
    }
  }
}

// ─── TTS Service ──────────────────────────────────────────────────────────────
class TtsService {
  final _tts = FlutterTts();
  bool _ready = false;
  bool _speaking = false;

  final _stateCtrl = StreamController<bool>.broadcast();
  Stream<bool> get speakingStream => _stateCtrl.stream;
  bool get isSpeaking => _speaking;

  Future<void> init({double rate = 0.48, double pitch = 1.0}) async {
    if (_ready) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(1.0);
    _tts.setStartHandler(() { _speaking = true; _stateCtrl.add(true); });
    _tts.setCompletionHandler(() { _speaking = false; _stateCtrl.add(false); });
    _tts.setCancelHandler(() { _speaking = false; _stateCtrl.add(false); });
    _ready = true;
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(_clean(text));
  }

  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
    _stateCtrl.add(false);
  }

  Future<void> setRate(double v)   => _tts.setSpeechRate(v.clamp(0.1, 1.0));
  Future<void> setPitch(double v)  => _tts.setPitch(v.clamp(0.5, 2.0));
  Future<void> setVolume(double v) => _tts.setVolume(v.clamp(0.0, 1.0));

  String _clean(String t) => t
      .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
      .replaceAll(RegExp(r'`[^`]*`'), '')
      .replaceAll(RegExp(r'#{1,6}\s'), '')
      .replaceAll(RegExp(r'\n+'), '. ')
      .trim();

  void dispose() {
    _tts.stop();
    _stateCtrl.close();
  }
}

// ─── STT Service ──────────────────────────────────────────────────────────────
class SttService {
  final _stt = SpeechToText();
  bool _init = false;
  bool _listening = false;

  final _partialCtrl = StreamController<String>.broadcast();
  final _finalCtrl   = StreamController<String>.broadcast();

  Stream<String> get partialStream => _partialCtrl.stream;
  Stream<String> get finalStream   => _finalCtrl.stream;
  bool get isListening => _listening;

  Future<bool> start() async {
    if (!_init) _init = await _stt.initialize(onError: (_) => _listening = false);
    if (!_init) return false;
    if (_stt.isListening) await _stt.stop();
    _listening = true;
    await _stt.listen(
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      listenMode: ListenMode.dictation,
      onResult: (SpeechRecognitionResult r) {
        _partialCtrl.add(r.recognizedWords);
        if (r.finalResult) {
          _listening = false;
          _finalCtrl.add(r.recognizedWords);
        }
      },
    );
    return true;
  }

  Future<void> stop() async {
    await _stt.stop();
    _listening = false;
  }

  void dispose() {
    _stt.stop();
    _partialCtrl.close();
    _finalCtrl.close();
  }
}

// ─── Automation Service ───────────────────────────────────────────────────────
class AutomationService {
  Future<bool> openApp(String pkg) async =>
      await kAutoChannel.invokeMethod<bool>('openApp', {'package': pkg}) ?? false;

  Future<bool> openUrl(String url) async =>
      await kAutoChannel.invokeMethod<bool>('openUrl', {'url': url}) ?? false;

  Future<bool> openSettings(String screen) async =>
      await kAutoChannel.invokeMethod<bool>('openSettings', {'screen': screen}) ?? false;

  Future<List<Map<String, String>>> getApps() async {
    final raw = await kAutoChannel.invokeMethod<List>('getInstalledApps') ?? [];
    return raw.map((e) {
      final m = Map<Object?, Object?>.from(e as Map);
      return {'name': m['name'].toString(), 'package': m['package'].toString()};
    }).toList();
  }

  Future<bool> isAccessibilityEnabled() async =>
      await kAutoChannel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  Future<void> requestAccessibility() =>
      kAutoChannel.invokeMethod('requestAccessibility');

  Future<bool> runAction(Map<String, dynamic> action) async {
    final type = action['type'] as String? ?? '';
    switch (type) {
      case 'open_app':
        return openApp(action['package'] as String? ?? '');
      case 'open_url':
        return openUrl(action['url'] as String? ?? '');
      case 'open_settings':
        return openSettings(action['screen'] as String? ?? 'main');
      case 'search_web':
        final q = Uri.encodeComponent(action['query'] as String? ?? '');
        return openUrl('https://www.google.com/search?q=$q');
      case 'play_music':
        return await openApp('com.spotify.music') ||
               await openApp('com.google.android.music');
      default:
        return false;
    }
  }
}
