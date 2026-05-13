import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../providers.dart';
import '../theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatState();
}

class _ChatState extends ConsumerState<ChatScreen> {
  final _scroll  = ScrollController();
  final _textCtrl = TextEditingController();
  final _focus   = FocusNode();

  @override
  void dispose() { _scroll.dispose(); _textCtrl.dispose(); _focus.dispose(); super.dispose(); }

  void _scrollDown() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: 300.ms, curve: Curves.easeOut);
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _textCtrl.clear();
    _focus.unfocus();
    await ref.read(chatProvider.notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
  }

  @override
  Widget build(BuildContext context) {
    final chat  = ref.watch(chatProvider);
    final voice = ref.watch(voiceProvider);
    final partial = ref.watch(transcriptProvider).valueOrNull ?? '';

    ref.listen<ChatState>(chatProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: C.bgGrad),
        child: SafeArea(
          child: Column(children: [
            // app bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: C.border))),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: C.blue),
                  onPressed: () => context.go('/home'),
                ),
                Container(width: 32, height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [C.blue, C.purple])),
                  child: const Icon(Icons.blur_on_rounded, size: 16, color: Colors.white)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('NOVA', style: GoogleFonts.rajdhani(
                    fontSize: 16, fontWeight: FontWeight.w700, color: C.t1, letterSpacing: 3)),
                  Text('AI Assistant', style: GoogleFonts.inter(fontSize: 10, color: C.green)),
                ]),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: C.t2),
                  onPressed: () => _showClearDialog(context),
                ),
              ]),
            ),

            // messages
            Expanded(
              child: chat.messages.isEmpty
                  ? _EmptyState(onSuggest: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: chat.messages.length + (chat.busy ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == chat.messages.length) return _TypingDots();
                        return _Bubble(msg: chat.messages[i],
                            isStreaming: i == chat.messages.length - 1 &&
                                chat.status == ChatStatus.streaming);
                      },
                    ),
            ),

            // voice transcript preview
            if (voice == VoiceMode.listening && partial.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: C.cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.cyan.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.mic_rounded, size: 14, color: C.cyan),
                  const SizedBox(width: 8),
                  Expanded(child: Text(partial,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: C.cyan, fontStyle: FontStyle.italic),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ),

            // input bar
            Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: voice == VoiceMode.listening
                      ? C.cyan.withOpacity(0.5) : C.border,
                  width: 1.5),
                boxShadow: voice == VoiceMode.listening
                    ? [BoxShadow(color: C.cyan.withOpacity(0.12), blurRadius: 20)]
                    : null,
              ),
              child: Row(children: [
                // mic
                GestureDetector(
                  onTap: () => ref.read(voiceProvider.notifier).toggle(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: AnimatedContainer(
                      duration: 300.ms,
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: voice == VoiceMode.listening
                            ? C.cyan.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        voice == VoiceMode.listening
                            ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: voice == VoiceMode.listening ? C.cyan : C.t2,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                // text field
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _focus,
                    enabled: !chat.busy,
                    maxLines: 4, minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    style: GoogleFonts.inter(fontSize: 14.5, color: C.t1),
                    decoration: InputDecoration(
                      hintText: voice == VoiceMode.listening
                          ? 'Listening...' : 'Ask NOVA anything…',
                      hintStyle: GoogleFonts.inter(fontSize: 14,
                          color: voice == VoiceMode.listening
                              ? C.cyan.withOpacity(0.7) : C.t3),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                // send
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: chat.busy
                      ? const SizedBox(width: 36, height: 36,
                          child: Padding(padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(strokeWidth: 2, color: C.blue)))
                      : ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _textCtrl,
                          builder: (_, val, __) {
                            final has = val.text.trim().isNotEmpty;
                            return GestureDetector(
                              onTap: has ? () => _send(_textCtrl.text) : null,
                              child: AnimatedContainer(
                                duration: 200.ms,
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: has ? C.blue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.send_rounded, size: 18,
                                    color: has ? C.bg : C.t3),
                              ),
                            );
                          },
                        ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.border)),
        title: Text('Clear Chat', style: GoogleFonts.rajdhani(
            color: C.t1, fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text('Delete all messages?',
            style: GoogleFonts.inter(color: C.t2, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: C.t2))),
          ElevatedButton(
            onPressed: () { ref.read(chatProvider.notifier).clear(); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: C.red),
            child: Text('Clear', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, this.isStreaming = false});
  final Message msg; final bool isStreaming;
  bool get isUser => msg.role == Role.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(width: 28, height: 28,
              decoration: const BoxDecoration(shape: BoxShape.circle,
                gradient: LinearGradient(colors: [C.blue, C.purple])),
              child: const Icon(Icons.blur_on_rounded, size: 14, color: Colors.white)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Copied', style: GoogleFonts.inter(color: C.t1)),
                  backgroundColor: C.card, duration: 1500.ms,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ));
              },
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.76),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? C.surface : C.card,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: Border.all(
                    color: isUser ? C.blue.withOpacity(0.2) : C.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (msg.isVoice)
                    Row(children: [
                      const Icon(Icons.mic_rounded, size: 10, color: C.cyan),
                      const SizedBox(width: 4),
                      Text('Voice', style: GoogleFonts.inter(fontSize: 9, color: C.cyan)),
                    ]),
                  SelectableText(msg.content,
                      style: GoogleFonts.inter(fontSize: 14.5, color: C.t1, height: 1.55)),
                  if (isStreaming && !isUser)
                    Container(width: 8, height: 14, margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(2)),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                        .fadeIn(duration: 400.ms).fadeOut(delay: 400.ms, duration: 400.ms),
                  const SizedBox(height: 3),
                  Text(DateFormat('HH:mm').format(msg.time),
                      style: GoogleFonts.inter(fontSize: 10, color: C.t3)),
                ]),
              ),
            ),
          ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.08),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Typing dots ───────────────────────────────────────────────────────────────
class _TypingDots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 28, height: 28,
          decoration: const BoxDecoration(shape: BoxShape.circle,
            gradient: LinearGradient(colors: [C.blue, C.purple])),
          child: const Icon(Icons.blur_on_rounded, size: 14, color: Colors.white)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: C.card, borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16),
              bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
            border: Border.all(color: C.border)),
          child: Row(mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => Container(
              width: 7, height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat())
                .scaleXY(begin: 0.6, end: 1.0, duration: 600.ms, delay: (i * 200).ms, curve: Curves.easeInOut)
                .then().scaleXY(begin: 1.0, end: 0.6, duration: 600.ms, curve: Curves.easeInOut))),
        ),
      ]),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggest});
  final void Function(String) onSuggest;

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'What can you do?',
      'Open YouTube for me',
      'Tell me a fun fact',
      'Search for latest AI news',
      'Open Wi-Fi settings',
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Center(child: Column(children: [
          const Icon(Icons.blur_on_rounded, size: 64, color: C.blue),
          const SizedBox(height: 14),
          Text('How can I help?', style: GoogleFonts.rajdhani(
            fontSize: 24, fontWeight: FontWeight.w600, color: C.t1, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('Ask anything or give a command',
              style: GoogleFonts.inter(fontSize: 13, color: C.t2)),
        ]).animate().fadeIn(duration: 600.ms)),
        const SizedBox(height: 28),
        Text('SUGGESTIONS', style: GoogleFonts.rajdhani(
          fontSize: 11, fontWeight: FontWeight.w700, color: C.t3, letterSpacing: 3)),
        const SizedBox(height: 10),
        ...suggestions.asMap().entries.map((e) => GestureDetector(
          onTap: () => onSuggest(e.value),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: C.surface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.border)),
            child: Row(children: [
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: C.blue),
              const SizedBox(width: 10),
              Text(e.value, style: GoogleFonts.inter(fontSize: 14, color: C.t2)),
            ]),
          ).animate().fadeIn(delay: (e.key * 80).ms).slideX(begin: -0.05),
        )),
      ],
    );
  }
}
