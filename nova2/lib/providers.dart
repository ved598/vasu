import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services.dart';

// ─── Prefs ────────────────────────────────────────────────────────────────────
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

// ─── Services ─────────────────────────────────────────────────────────────────
final apiProvider = Provider<ApiService>((ref) {
  final url = ref.watch(settingsProvider).apiUrl;
  return ApiService(url);
});

final ttsProvider = Provider<TtsService>((ref) {
  final svc = TtsService();
  ref.onDispose(svc.dispose);
  return svc;
});

final sttProvider = Provider<SttService>((ref) {
  final svc = SttService();
  ref.onDispose(svc.dispose);
  return svc;
});

final automationProvider = Provider<AutomationService>((_) => AutomationService());

// ─── Settings ─────────────────────────────────────────────────────────────────
class SettingsState {
  final String apiUrl;
  final String apiKey;
  final String model;
  final double ttsRate;
  final double ttsPitch;
  final String userName;
  final bool wakeWordEnabled;
  final bool serverOnline;
  final List<String> models;

  const SettingsState({
    this.apiUrl        = 'http://10.0.2.2:8000',
    this.apiKey        = '',
    this.model         = 'gpt-4o-mini',
    this.ttsRate       = 0.48,
    this.ttsPitch      = 1.0,
    this.userName      = 'User',
    this.wakeWordEnabled = true,
    this.serverOnline  = false,
    this.models        = const [],
  });

  SettingsState copyWith({
    String? apiUrl, String? apiKey, String? model,
    double? ttsRate, double? ttsPitch, String? userName,
    bool? wakeWordEnabled, bool? serverOnline, List<String>? models,
  }) => SettingsState(
    apiUrl: apiUrl ?? this.apiUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    ttsRate: ttsRate ?? this.ttsRate,
    ttsPitch: ttsPitch ?? this.ttsPitch,
    userName: userName ?? this.userName,
    wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
    serverOnline: serverOnline ?? this.serverOnline,
    models: models ?? this.models,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _p;
  SettingsNotifier(this._p) : super(const SettingsState()) { _load(); }

  void _load() {
    state = state.copyWith(
      apiUrl:          _p.getString('apiUrl')  ?? 'http://10.0.2.2:8000',
      apiKey:          _p.getString('apiKey')  ?? '',
      model:           _p.getString('model')   ?? 'gpt-4o-mini',
      ttsRate:         _p.getDouble('ttsRate') ?? 0.48,
      ttsPitch:        _p.getDouble('ttsPitch') ?? 1.0,
      userName:        _p.getString('userName') ?? 'User',
      wakeWordEnabled: _p.getBool('wakeWord')  ?? true,
    );
  }

  Future<void> setApiUrl(String v)   async { await _p.setString('apiUrl', v);   state = state.copyWith(apiUrl: v); }
  Future<void> setApiKey(String v)   async { await _p.setString('apiKey', v);   state = state.copyWith(apiKey: v); }
  Future<void> setModel(String v)    async { await _p.setString('model', v);    state = state.copyWith(model: v); }
  Future<void> setTtsRate(double v)  async { await _p.setDouble('ttsRate', v);  state = state.copyWith(ttsRate: v); }
  Future<void> setTtsPitch(double v) async { await _p.setDouble('ttsPitch', v); state = state.copyWith(ttsPitch: v); }
  Future<void> setUserName(String v) async { await _p.setString('userName', v); state = state.copyWith(userName: v); }
  Future<void> setWakeWord(bool v)   async { await _p.setBool('wakeWord', v);   state = state.copyWith(wakeWordEnabled: v); }
  void setOnline(bool v, List<String> m) => state = state.copyWith(serverOnline: v, models: m);
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref.watch(prefsProvider));
});

// ─── Chat ─────────────────────────────────────────────────────────────────────
enum ChatStatus { idle, loading, streaming, error }

class ChatState {
  final List<Message> messages;
  final ChatStatus status;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.status   = ChatStatus.idle,
    this.error,
  });

  bool get busy => status == ChatStatus.loading || status == ChatStatus.streaming;

  ChatState copyWith({
    List<Message>? messages,
    ChatStatus? status,
    String? error,
  }) => ChatState(
    messages: messages ?? this.messages,
    status: status ?? this.status,
    error: error,
  );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService       _api;
  final TtsService       _tts;
  final AutomationService _auto;
  final SharedPreferences _prefs;

  ChatNotifier(this._api, this._tts, this._auto, this._prefs)
      : super(const ChatState()) {
    _loadHistory();
  }

  void _loadHistory() {
    try {
      final raw = _prefs.getString('history');
      if (raw == null) return;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final msgs = list.map(Message.fromJson).toList();
      state = state.copyWith(
        messages: msgs.length > 40 ? msgs.sublist(msgs.length - 40) : msgs,
      );
    } catch (_) {}
  }

  void _save() {
    _prefs.setString('history',
        jsonEncode(state.messages.map((m) => m.toJson()).toList()));
  }

  Future<void> send(String text, {bool voice = false}) async {
    if (text.trim().isEmpty) return;
    final userMsg = Message.user(text.trim(), voice: voice);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      status:   ChatStatus.loading,
      error:    null,
    );

    try {
      // Try streaming
      final buffer = StringBuffer();
      Message? botMsg;
      await for (final token in _api.chatStream(state.messages.sublist(
        0, state.messages.length - 1), text)) {
        buffer.write(token);
        if (botMsg == null) {
          botMsg = Message.assistant(buffer.toString());
          state = state.copyWith(
            messages: [...state.messages, botMsg],
            status: ChatStatus.streaming,
          );
        } else {
          final updated = [...state.messages];
          updated[updated.length - 1] = botMsg.copyWith(content: buffer.toString());
          state = state.copyWith(messages: updated);
        }
      }

      final full = buffer.toString();
      if (full.isNotEmpty) {
        final clean  = _stripAction(full);
        final action = _extractAction(full);
        final updated = [...state.messages];
        if (botMsg != null) {
          updated[updated.length - 1] = botMsg.copyWith(content: clean);
        } else {
          updated.add(Message.assistant(clean));
        }
        state = state.copyWith(messages: updated, status: ChatStatus.idle);
        _tts.speak(clean).ignore();
        if (action != null) _auto.runAction(action).ignore();
      } else {
        // Streaming returned nothing — fallback to non-stream
        await _sendNormal(text);
        return;
      }
    } catch (_) {
      try {
        await _sendNormal(text);
      } catch (e) {
        final updated = [...state.messages];
        updated.add(Message.assistant('⚠️ ${e.toString()}'));
        state = state.copyWith(
            messages: updated, status: ChatStatus.error, error: e.toString());
      }
    }
    _save();
  }

  Future<void> _sendNormal(String text) async {
    final history = state.messages.where((m) => m.role == Role.user).length > 0
        ? state.messages.sublist(0, state.messages.length)
        : <Message>[];
    final resp = await _api.chat(history, text);
    final updated = [...state.messages, Message.assistant(resp.reply)];
    state = state.copyWith(messages: updated, status: ChatStatus.idle);
    _tts.speak(resp.reply).ignore();
    if (resp.hasAction) _auto.runAction(resp.action!).ignore();
    _save();
  }

  void clear() {
    state = const ChatState();
    _prefs.remove('history');
  }

  String _stripAction(String t) =>
      t.replaceAll(RegExp(r'```action[\s\S]*?```'), '').trim();

  Map<String, dynamic>? _extractAction(String t) {
    final m = RegExp(r'```action\s*([\s\S]*?)```').firstMatch(t);
    if (m == null) return null;
    try { return jsonDecode(m.group(1)!.trim()) as Map<String, dynamic>; }
    catch (_) { return null; }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    ref.watch(apiProvider),
    ref.watch(ttsProvider),
    ref.watch(automationProvider),
    ref.watch(prefsProvider),
  );
});

// ─── Voice ────────────────────────────────────────────────────────────────────
enum VoiceMode { idle, listening, processing }

class VoiceNotifier extends StateNotifier<VoiceMode> {
  final SttService _stt;
  final TtsService _tts;
  final ChatNotifier _chat;

  StreamSubscription? _finalSub;

  VoiceNotifier(this._stt, this._tts, this._chat) : super(VoiceMode.idle) {
    _finalSub = _stt.finalStream.listen(_onFinal);
  }

  Future<bool> toggle() async {
    if (state == VoiceMode.listening) {
      await _stt.stop();
      state = VoiceMode.idle;
      return false;
    }
    _tts.stop();
    final micOk = await Permission.microphone.request().isGranted;
    if (!micOk) return false;
    final ok = await _stt.start();
    if (ok) state = VoiceMode.listening;
    return ok;
  }

  Future<void> _onFinal(String text) async {
    if (text.trim().isEmpty) { state = VoiceMode.idle; return; }
    state = VoiceMode.processing;
    await _chat.send(text, voice: true);
    state = VoiceMode.idle;
  }

  @override
  void dispose() {
    _finalSub?.cancel();
    super.dispose();
  }
}

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceMode>((ref) {
  return VoiceNotifier(
    ref.watch(sttProvider),
    ref.watch(ttsProvider),
    ref.read(chatProvider.notifier),
  );
});

// partial transcript
final transcriptProvider = StreamProvider<String>((ref) {
  return ref.watch(sttProvider).partialStream;
});
