import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers.dart';
import '../services.dart';
import '../theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashState();
}

class _SplashState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  final List<String> _lines = [];
  final _allLines = [
    'INITIALIZING NEURAL CORE...',
    'LOADING VOICE ENGINE...',
    'SYNCING AI MODULES...',
    'NOVA ONLINE.',
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _boot();
  }

  Future<void> _boot() async {
    // Init TTS
    await ref.read(ttsProvider).init();

    for (final line in _allLines) {
      await Future.delayed(const Duration(milliseconds: 450));
      if (mounted) setState(() => _lines.add(line));
    }
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final prefs = ref.read(prefsProvider);
    final onboarded = prefs.getBool('onboarded') ?? false;
    context.go(onboarded ? '/home' : '/onboard');
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: C.bgGrad),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Orb
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      C.blue.withOpacity(0.9),
                      C.purple,
                      C.bg,
                    ], stops: const [0.0, 0.55, 1.0]),
                    boxShadow: [
                      BoxShadow(
                        color: C.blue.withOpacity(0.25 + 0.2 * _pulse.value),
                        blurRadius: 40 + 20 * _pulse.value,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.blur_on_rounded, size: 60, color: Colors.white),
                ),
              ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),

              const SizedBox(height: 24),

              Text('NOVA', style: GoogleFonts.rajdhani(
                fontSize: 52, fontWeight: FontWeight.w700,
                color: C.blue, letterSpacing: 12,
              )).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

              Text('NEURAL OMNIPRESENT VOICE ASSISTANT',
                  style: GoogleFonts.rajdhani(
                    fontSize: 10, color: C.t2, letterSpacing: 4,
                  )).animate().fadeIn(delay: 600.ms),

              const Spacer(),

              // Boot log
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _lines.map((l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Text('> ', style: GoogleFonts.robotoMono(
                          fontSize: 11, color: C.blue)),
                      Text(l, style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          color: l == 'NOVA ONLINE.' ? C.green : C.t2,
                          fontWeight: l == 'NOVA ONLINE.'
                              ? FontWeight.w700 : FontWeight.w400)),
                    ]).animate().fadeIn(duration: 250.ms).slideX(begin: -0.05),
                  )).toList(),
                ),
              ),

              const SizedBox(height: 40),
              Text('v1.0.0', style: GoogleFonts.rajdhani(
                  fontSize: 11, color: C.t3, letterSpacing: 3))
                  .animate().fadeIn(delay: 1000.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
