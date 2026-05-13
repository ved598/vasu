import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  // backgrounds
  static const bg       = Color(0xFF050A14);
  static const card     = Color(0xFF0B1628);
  static const surface  = Color(0xFF0F1E36);
  static const border   = Color(0xFF1A3050);

  // brand
  static const blue     = Color(0xFF00D4FF);
  static const purple   = Color(0xFF7B2FFF);
  static const cyan     = Color(0xFF00FFFF);

  // status
  static const green    = Color(0xFF00FF88);
  static const orange   = Color(0xFFFF9500);
  static const red      = Color(0xFFFF3B5C);

  // text
  static const t1       = Color(0xFFE0E8FF);
  static const t2       = Color(0xFF8A9BBE);
  static const t3       = Color(0xFF445570);

  static const bgGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bg, Color(0xFF070D1C), Color(0xFF060C18)],
  );

  static List<BoxShadow> glow(Color c, {double intensity = 0.35}) => [
    BoxShadow(color: c.withOpacity(intensity), blurRadius: 30, spreadRadius: 3),
    BoxShadow(color: c.withOpacity(0.15), blurRadius: 60, spreadRadius: 8),
  ];
}

class NovaTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: C.bg,
      colorScheme: const ColorScheme.dark(
        primary: C.blue,
        secondary: C.purple,
        surface: C.card,
        onPrimary: C.bg,
        onSurface: C.t1,
        error: C.red,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: C.t1,
        displayColor: C.t1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: C.blue, letterSpacing: 3,
        ),
        iconTheme: const IconThemeData(color: C.blue),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: C.blue,
          foregroundColor: C.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.blue, width: 1.5),
        ),
        hintStyle: const TextStyle(color: C.t3),
        labelStyle: const TextStyle(color: C.t2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardTheme(
        color: C.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: C.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: C.border, thickness: 1),
      iconTheme: const IconThemeData(color: C.blue, size: 22),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? C.blue : C.t3,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? C.blue.withOpacity(0.4)
              : C.border,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: C.card,
        contentTextStyle: const TextStyle(color: C.t1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
