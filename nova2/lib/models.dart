import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum Role { user, assistant }

class Message {
  final String id;
  final Role role;
  final String content;
  final DateTime time;
  final bool isVoice;

  Message({
    String? id,
    required this.role,
    required this.content,
    DateTime? time,
    this.isVoice = false,
  })  : id = id ?? _uuid.v4(),
        time = time ?? DateTime.now();

  factory Message.user(String text, {bool voice = false}) =>
      Message(role: Role.user, content: text, isVoice: voice);

  factory Message.assistant(String text) =>
      Message(role: Role.assistant, content: text);

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'time': time.toIso8601String(),
        'isVoice': isVoice,
      };

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String?,
        role: j['role'] == 'user' ? Role.user : Role.assistant,
        content: j['content'] as String,
        time: j['time'] != null ? DateTime.parse(j['time'] as String) : null,
        isVoice: j['isVoice'] as bool? ?? false,
      );

  Map<String, String> toApi() => {'role': role.name, 'content': content};

  Message copyWith({String? content}) =>
      Message(id: id, role: role, content: content ?? this.content,
              time: time, isVoice: isVoice);
}

class NovaResponse {
  final String reply;
  final String? intent;
  final Map<String, dynamic>? action;

  const NovaResponse({required this.reply, this.intent, this.action});

  factory NovaResponse.fromJson(Map<String, dynamic> j) => NovaResponse(
        reply: j['reply'] as String? ?? j['message'] as String? ?? '',
        intent: j['intent'] as String?,
        action: j['action'] as Map<String, dynamic>?,
      );

  bool get hasAction => action != null && action!.isNotEmpty;
}
