import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers.dart';
import '../theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardState();
}

class _OnboardState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _idx = 0;
  bool _micOk = false;
  final _nameCtrl = TextEditingController(text: 'User');
  final _urlCtrl  = TextEditingController(text: 'http://10.0.2.2:8000');

  @override
  void dispose() { _page.dispose(); _nameCtrl.dispose(); _urlCtrl.dispose(); super.dispose(); }

  void _next() {
    if (_idx < 2) {
      _page.nextPage(duration: 400.ms, curve: Curves.easeOutCubic);
    } else _finish();
  }

  Future<void> _finish() async {
    final prefs = ref.read(prefsProvider);
    await prefs.setBool('onboarded', true);
    await prefs.setString('userName', _nameCtrl.text.trim());
    final n = ref.read(settingsProvider.notifier);
    await n.setUserName(_nameCtrl.text.trim());
    await n.setApiUrl(_urlCtrl.text.trim());
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: C.bgGrad),
        child: SafeArea(
          child: Column(
            children: [
              // progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: List.generate(3, (i) => Expanded(
                    child: AnimatedContainer(
                      duration: 300.ms,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _idx ? C.blue : C.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  )),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _idx = i),
                  children: [_page0(), _page1(), _page2()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page0() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 110, height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [C.blue, C.purple, C.bg], stops: [0.0, 0.6, 1.0]),
          boxShadow: C.glow(C.blue),
        ),
        child: const Icon(Icons.blur_on_rounded, size: 52, color: Colors.white),
      ).animate().scale(duration: 700.ms, curve: Curves.elasticOut),
      const SizedBox(height: 32),
      Text('Meet NOVA', style: GoogleFonts.rajdhani(
        fontSize: 38, fontWeight: FontWeight.w700, color: C.blue, letterSpacing: 4,
      )).animate().fadeIn(delay: 300.ms),
      const SizedBox(height: 10),
      Text('Your Neural Voice Assistant', textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 15, color: C.t2))
          .animate().fadeIn(delay: 500.ms),
      const SizedBox(height: 40),
      ...[
        (Icons.mic_rounded,           'Voice Commands',   'Hands-free control'),
        (Icons.smart_toy_rounded,     'AI Intelligence',  'GPT, Claude, Gemini'),
        (Icons.phone_android_rounded, 'App Automation',   'Open apps & search'),
      ].asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(
              color: C.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.blue.withOpacity(0.2))),
            child: Icon(e.value.$1, color: C.blue, size: 20)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.value.$2, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: C.t1)),
            Text(e.value.$3, style: GoogleFonts.inter(fontSize: 12, color: C.t2)),
          ]),
        ]).animate().fadeIn(delay: (400 + e.key * 100).ms).slideX(begin: -0.05),
      )),
      const SizedBox(height: 32),
      _Btn(label: 'Get Started', onTap: _next),
    ]),
  );

  Widget _page1() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text('Permissions', style: GoogleFonts.rajdhani(
        fontSize: 30, fontWeight: FontWeight.w700, color: C.t1)),
      const SizedBox(height: 8),
      Text('NOVA needs microphone access', style: GoogleFonts.inter(fontSize: 14, color: C.t2)),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _micOk ? C.green.withOpacity(0.3) : C.border)),
        child: Row(children: [
          Icon(Icons.mic_rounded, color: _micOk ? C.green : C.blue, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Microphone', style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: C.t1)),
            Text('For voice commands & wake word',
                style: GoogleFonts.inter(fontSize: 12, color: C.t2)),
          ])),
          _micOk
              ? const Icon(Icons.check_circle_rounded, color: C.green, size: 22)
              : TextButton(
                  onPressed: () async {
                    final ok = await Permission.microphone.request().isGranted;
                    setState(() => _micOk = ok);
                  },
                  child: Text('Allow', style: GoogleFonts.inter(
                      color: C.blue, fontWeight: FontWeight.w600))),
        ]),
      ),
      const Spacer(),
      _Btn(label: _micOk ? 'Continue' : 'Skip for now', onTap: _next),
    ]),
  );

  Widget _page2() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text('Setup NOVA', style: GoogleFonts.rajdhani(
        fontSize: 30, fontWeight: FontWeight.w700, color: C.t1)),
      const SizedBox(height: 32),
      TextField(
        controller: _nameCtrl,
        style: const TextStyle(color: C.t1),
        decoration: const InputDecoration(
          labelText: 'Your Name',
          prefixIcon: Icon(Icons.person_outline_rounded, color: C.blue),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _urlCtrl,
        keyboardType: TextInputType.url,
        style: const TextStyle(color: C.t1),
        decoration: const InputDecoration(
          labelText: 'Backend URL',
          prefixIcon: Icon(Icons.dns_rounded, color: C.blue),
          hintText: 'http://10.0.2.2:8000',
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.blue.withOpacity(0.2))),
        child: Text(
          'Use 10.0.2.2 for emulator. On a real device, use your PC\'s local IP address.',
          style: GoogleFonts.inter(fontSize: 12, color: C.t2)),
      ),
      const Spacer(),
      _Btn(label: 'Launch NOVA 🚀', onTap: _finish),
    ]),
  );
}

class _Btn extends StatelessWidget {
  const _Btn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(onPressed: onTap, child: Text(label)),
  );
}
