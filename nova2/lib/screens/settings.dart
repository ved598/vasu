import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _nameCtrl;
  bool _keyVisible = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _urlCtrl  = TextEditingController(text: s.apiUrl);
    _keyCtrl  = TextEditingController(text: s.apiKey);
    _nameCtrl = TextEditingController(text: s.userName);
  }

  @override
  void dispose() { _urlCtrl.dispose(); _keyCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _testConnection() async {
    setState(() => _checking = true);
    final n = ref.read(settingsProvider.notifier);
    await n.setApiUrl(_urlCtrl.text.trim());
    await n.setApiKey(_keyCtrl.text.trim());
    final api = ref.read(apiProvider);
    api.setBaseUrl(_urlCtrl.text.trim());
    api.setApiKey(_keyCtrl.text.trim());
    final ok = await api.ping();
    final models = ok ? await api.getModels() : [];
    n.setOnline(ok, models);
    setState(() => _checking = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Connected!' : '❌ Cannot reach server',
            style: GoogleFonts.inter(color: C.t1)),
        backgroundColor: ok ? C.green.withOpacity(0.2) : C.red.withOpacity(0.2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final auto = ref.read(automationProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: C.bgGrad),
        child: SafeArea(
          child: Column(children: [
            // bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: C.blue),
                  onPressed: () => context.go('/home'),
                ),
                Text('SETTINGS', style: GoogleFonts.rajdhani(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: C.t1, letterSpacing: 3)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Profile
                  _Hdr('PROFILE'),
                  _Card(children: [
                    _Field('Your Name', _nameCtrl, Icons.person_outline_rounded,
                        onDone: (v) => n.setUserName(v)),
                  ]),

                  // Server
                  _Hdr('SERVER'),
                  _Card(children: [
                    _Field('API Base URL', _urlCtrl, Icons.dns_rounded,
                        keyboard: TextInputType.url,
                        onDone: (v) async { await n.setApiUrl(v.trim()); }),
                    const _Div(),
                    _Field('API Key', _keyCtrl, Icons.key_rounded,
                        obscure: !_keyVisible,
                        suffix: IconButton(
                          icon: Icon(_keyVisible
                              ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 18, color: C.t2),
                          onPressed: () => setState(() => _keyVisible = !_keyVisible),
                        ),
                        onDone: (v) async { await n.setApiKey(v.trim()); }),
                    const _Div(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _checking ? null : _testConnection,
                            icon: _checking
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: C.bg))
                                : const Icon(Icons.bolt_rounded, size: 16),
                            label: Text(_checking ? 'Testing…' : 'Test Connection'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: s.serverOnline ? C.green : C.blue,
                                foregroundColor: C.bg),
                          ),
                        ),
                        if (s.serverOnline) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.check_circle_rounded, color: C.green, size: 22),
                        ],
                      ]),
                    ),
                  ]),

                  // Model
                  _Hdr('AI MODEL'),
                  _Card(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: DropdownButtonFormField<String>(
                        value: (s.models.contains(s.model) ? s.model : null),
                        hint: Text(s.model,
                            style: GoogleFonts.inter(color: C.t1, fontSize: 14)),
                        dropdownColor: C.card,
                        icon: const Icon(Icons.expand_more_rounded, color: C.blue),
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          prefixIcon: Icon(Icons.memory_rounded, size: 18, color: C.blue),
                        ),
                        items: (s.models.isEmpty ? [s.model] : s.models)
                            .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m, style: GoogleFonts.inter(
                                  color: C.t1, fontSize: 14))))
                            .toList(),
                        onChanged: (v) { if (v != null) n.setModel(v); },
                      ),
                    ),
                  ]),

                  // Voice
                  _Hdr('VOICE'),
                  _Card(children: [
                    SwitchListTile(
                      title: Text('Wake Word', style: GoogleFonts.inter(fontSize: 14, color: C.t1)),
                      subtitle: Text('Say "Hey Nova" to activate',
                          style: GoogleFonts.inter(fontSize: 12, color: C.t2)),
                      secondary: const Icon(Icons.record_voice_over_rounded, color: C.blue, size: 20),
                      value: s.wakeWordEnabled,
                      onChanged: n.setWakeWord,
                    ),
                    const _Div(),
                    _Slider('Speech Rate', Icons.speed_rounded, s.ttsRate,
                        0.1, 1.0, s.ttsRate.toStringAsFixed(2),
                        (v) async {
                          await n.setTtsRate(v);
                          ref.read(ttsProvider).setRate(v);
                        }),
                    const _Div(),
                    _Slider('Pitch', Icons.graphic_eq_rounded, s.ttsPitch,
                        0.5, 2.0, s.ttsPitch.toStringAsFixed(2),
                        (v) async {
                          await n.setTtsPitch(v);
                          ref.read(ttsProvider).setPitch(v);
                        }),
                  ]),

                  // Permissions
                  _Hdr('PERMISSIONS'),
                  _Card(children: [
                    _Action('Accessibility Service', 'Required for app automation',
                        Icons.accessibility_new_rounded, C.purple,
                        auto.requestAccessibility),
                    const _Div(),
                    _Action('Battery Optimization', 'Keep NOVA alive in background',
                        Icons.battery_charging_full_rounded, C.green,
                        () => auto.openSettings('battery')),
                  ]),

                  // About
                  _Hdr('ABOUT'),
                  _Card(children: [
                    _Info('Version', '1.0.0'),
                    const _Div(),
                    _Info('Platform', 'Android 8+'),
                    const _Div(),
                    _Info('Engine', 'Flutter'),
                  ]),

                  const SizedBox(height: 40),
                ].animate(interval: 60.ms).fadeIn(duration: 400.ms).slideY(begin: 0.04),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  const _Hdr(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
    child: Text(t, style: GoogleFonts.rajdhani(
      fontSize: 11, fontWeight: FontWeight.w700, color: C.t3, letterSpacing: 3)),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: C.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.border)),
    child: Column(children: children),
  );
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) => const Divider(
    height: 1, thickness: 1, color: C.border, indent: 16, endIndent: 16);
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.ctrl, this.icon, {
    this.keyboard, this.obscure = false, this.suffix, this.onDone});
  final String label; final TextEditingController ctrl;
  final IconData icon; final TextInputType? keyboard;
  final bool obscure; final Widget? suffix;
  final void Function(String)? onDone;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: TextField(
      controller: ctrl, obscureText: obscure,
      keyboardType: keyboard, onSubmitted: onDone,
      style: GoogleFonts.inter(fontSize: 14, color: C.t1),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: C.blue),
        suffixIcon: suffix),
    ),
  );
}

class _Slider extends StatelessWidget {
  const _Slider(this.label, this.icon, this.value,
      this.min, this.max, this.valLabel, this.onChanged);
  final String label, valLabel; final IconData icon;
  final double value, min, max;
  final void Function(double) onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Column(children: [
      Row(children: [
        Icon(icon, size: 18, color: C.blue),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: C.t1)),
        const Spacer(),
        Text(valLabel, style: GoogleFonts.rajdhani(
            fontSize: 13, color: C.blue, fontWeight: FontWeight.w600)),
      ]),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: C.blue,
          inactiveTrackColor: C.border,
          thumbColor: C.blue,
          overlayColor: C.blue.withOpacity(0.15),
          trackHeight: 2,
        ),
        child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ),
    ]),
  );
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.sub, this.icon, this.color, this.onTap);
  final String label, sub; final IconData icon; final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color, size: 20),
    title: Text(label, style: GoogleFonts.inter(fontSize: 14, color: C.t1)),
    subtitle: Text(sub, style: GoogleFonts.inter(fontSize: 12, color: C.t2)),
    trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: C.t3),
    onTap: onTap,
  );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Text(label, style: GoogleFonts.inter(fontSize: 14, color: C.t2)),
      const Spacer(),
      Text(value, style: GoogleFonts.inter(
          fontSize: 14, color: C.t1, fontWeight: FontWeight.w500)),
    ]),
  );
}
