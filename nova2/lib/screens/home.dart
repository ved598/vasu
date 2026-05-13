import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers.dart';
import '../theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeState();
}

class _HomeState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _orb;
  late AnimationController _pulse;
  late AnimationController _ripple;

  @override
  void initState() {
    super.initState();
    _orb   = AnimationController(vsync: this, duration: 8.seconds)..repeat();
    _pulse = AnimationController(vsync: this, duration: 2.seconds)..repeat(reverse: true);
    _ripple = AnimationController(vsync: this, duration: 1.2.seconds);
  }

  @override
  void dispose() { _orb.dispose(); _pulse.dispose(); _ripple.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final voice    = ref.watch(voiceProvider);
    final settings = ref.watch(settingsProvider);
    final partial  = ref.watch(transcriptProvider).valueOrNull ?? '';
    final now      = DateTime.now();

    final isListening  = voice == VoiceMode.listening;
    final isProcessing = voice == VoiceMode.processing;

    if (isListening) {
      if (!_ripple.isAnimating) _ripple.repeat();
    } else {
      _ripple.stop();
      _ripple.reset();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: C.bgGrad),
        child: SafeArea(
          child: Column(children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('NOVA AI', style: GoogleFonts.rajdhani(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: C.blue, letterSpacing: 4)),
                  Text('ONLINE', style: GoogleFonts.rajdhani(
                    fontSize: 9, color: C.green, letterSpacing: 3,
                    fontWeight: FontWeight.w700)),
                ]),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: C.t2),
                  onPressed: () => context.go('/chat'),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: C.t2),
                  onPressed: () => context.go('/settings'),
                ),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [

                  // ── Time ───────────────────────────────────────────────
                  Column(children: [
                    Text(DateFormat('EEEE, MMMM d').format(now),
                        style: GoogleFonts.inter(fontSize: 12, color: C.t2)),
                    const SizedBox(height: 2),
                    Text(DateFormat('HH:mm').format(now),
                        style: GoogleFonts.rajdhani(
                          fontSize: 48, fontWeight: FontWeight.w300,
                          color: C.t1, letterSpacing: 2)),
                    Text(_greeting(now.hour),
                        style: GoogleFonts.inter(fontSize: 13, color: C.t2)),
                  ]).animate().fadeIn(duration: 600.ms),

                  const SizedBox(height: 24),

                  // ── ORB ────────────────────────────────────────────────
                  GestureDetector(
                    onTap: () => ref.read(voiceProvider.notifier).toggle(),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_orb, _pulse, _ripple]),
                      builder: (_, __) {
                        final scale = isListening
                            ? 0.92 + 0.08 * _pulse.value
                            : 0.96 + 0.04 * _pulse.value;
                        return SizedBox(
                          width: 260, height: 260,
                          child: Stack(alignment: Alignment.center, children: [
                            // ripple rings
                            if (isListening)
                              ...List.generate(3, (i) {
                                final t = (_ripple.value + i / 3) % 1.0;
                                return Container(
                                  width: 150 + 80 * t,
                                  height: 150 + 80 * t,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: C.cyan.withOpacity((1 - t) * 0.4),
                                      width: 1.5),
                                  ),
                                );
                              }),
                            // orbit ring
                            Transform.rotate(
                              angle: _orb.value * 2 * math.pi,
                              child: _DashedRing(size: 190, color: C.blue.withOpacity(0.4)),
                            ),
                            Transform.rotate(
                              angle: -_orb.value * 1.4 * math.pi,
                              child: _DashedRing(size: 210, color: C.purple.withOpacity(0.25), dashes: 12),
                            ),
                            // core
                            Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 160, height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: isListening
                                        ? [C.cyan.withOpacity(0.9), C.blue, C.purple, C.bg]
                                        : isProcessing
                                            ? [C.orange.withOpacity(0.8), C.blue, C.bg]
                                            : [C.blue.withOpacity(0.8), C.purple, C.bg],
                                    stops: isListening
                                        ? const [0.0, 0.3, 0.65, 1.0]
                                        : const [0.0, 0.5, 1.0],
                                  ),
                                  boxShadow: C.glow(
                                    isListening ? C.cyan : C.blue,
                                    intensity: isListening ? 0.5 : 0.25 + 0.15 * _pulse.value,
                                  ),
                                ),
                                child: Icon(
                                  isListening  ? Icons.mic_rounded
                                  : isProcessing ? Icons.memory_rounded
                                  : Icons.blur_on_rounded,
                                  size: 60, color: Colors.white,
                                ),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 12),

                  // status text
                  AnimatedSwitcher(
                    duration: 300.ms,
                    child: Text(
                      key: ValueKey(voice),
                      isListening  ? (partial.isEmpty ? 'Listening...' : partial)
                      : isProcessing ? 'Processing...'
                      : 'Tap orb or say "Hey Nova"',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isListening ? C.cyan : C.t2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // wake word pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: C.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: C.green.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6,
                          decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Wake Word Active',
                          style: GoogleFonts.inter(fontSize: 11, color: C.green, fontWeight: FontWeight.w500)),
                    ]),
                  ),

                  const SizedBox(height: 28),

                  // status pills
                  Row(children: [
                    _Pill(Icons.cloud_rounded,  settings.serverOnline ? 'ONLINE' : 'OFFLINE',
                        settings.serverOnline ? C.green : C.red),
                    const SizedBox(width: 10),
                    _Pill(Icons.memory_rounded, settings.model.length > 12
                        ? '${settings.model.substring(0, 11)}…' : settings.model, C.blue),
                    const SizedBox(width: 10),
                    _Pill(Icons.mic_rounded, 'VOICE', C.purple),
                  ]).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 24),

                  // Chat button
                  GestureDetector(
                    onTap: () => context.go('/chat'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [C.blue, C.purple]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: C.glow(C.blue, intensity: 0.2),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text('OPEN CHAT', style: GoogleFonts.rajdhani(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 2)),
                      ]),
                    ),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 28),

                  // Quick actions
                  _QuickActions(),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _greeting(int h) {
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label, this.color);
  final IconData icon; final String label; final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: GoogleFonts.rajdhani(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: color, letterSpacing: 1),
          overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auto = ref.read(automationProvider);
    final actions = [
      ('Chrome',   Icons.language_rounded,       C.blue,                () => auto.openApp('com.android.chrome')),
      ('YouTube',  Icons.play_circle_rounded,    C.red,                 () => auto.openApp('com.google.android.youtube')),
      ('Maps',     Icons.map_rounded,            C.green,               () => auto.openApp('com.google.android.apps.maps')),
      ('Spotify',  Icons.music_note_rounded,     const Color(0xFF1DB954), () => auto.openApp('com.spotify.music')),
      ('Settings', Icons.settings_rounded,       C.t2,                  () => auto.openSettings('main')),
      ('Wi-Fi',    Icons.wifi_rounded,           C.cyan,                () => auto.openSettings('wifi')),
      ('Search',   Icons.search_rounded,         C.purple,              () => auto.openUrl('https://google.com')),
      ('Camera',   Icons.camera_alt_rounded,     C.orange,              () => auto.openApp('com.android.camera2')),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('QUICK ACTIONS', style: GoogleFonts.rajdhani(
        fontSize: 11, fontWeight: FontWeight.w700, color: C.t3, letterSpacing: 3)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 12,
          mainAxisSpacing: 12, childAspectRatio: 0.85),
        itemCount: actions.length,
        itemBuilder: (ctx, i) {
          final a = actions[i];
          return GestureDetector(
            onTap: a.$4,
            child: Container(
              decoration: BoxDecoration(
                color: a.$3.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: a.$3.withOpacity(0.2)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: a.$3.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(a.$2, color: a.$3, size: 20)),
                const SizedBox(height: 6),
                Text(a.$1, style: GoogleFonts.inter(fontSize: 10, color: C.t2),
                    overflow: TextOverflow.ellipsis),
              ]),
            ).animate().fadeIn(delay: (i * 50).ms).scale(begin: const Offset(0.85, 0.85)),
          );
        },
      ),
    ]);
  }
}

class _DashedRing extends StatelessWidget {
  const _DashedRing({required this.size, required this.color, this.dashes = 8});
  final double size; final Color color; final int dashes;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size),
    painter: _RingPainter(color: color, dashes: dashes),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color, required this.dashes});
  final Color color; final int dashes;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;
    const gap = math.pi / 24;
    for (int i = 0; i < dashes; i++) {
      final start = (2 * math.pi / dashes) * i;
      final sweep = (2 * math.pi / dashes) - gap;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, false, p);
    }
  }
  @override bool shouldRepaint(_RingPainter o) => o.color != color;
}
