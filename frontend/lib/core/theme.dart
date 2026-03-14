import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _primary = Color(0xFF1A56DB);
  static const _surface = Color(0xFFF8FAFC);
  static const _surfaceCard = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE2E8F0);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _error = Color(0xFFEF4444);
  static const _success = Color(0xFF22C55E);
  static const _warning = Color(0xFFF59E0B);
  static const _sidebarBg = Color(0xFF0F172A);
  static const _sidebarSelected = Color(0xFF1E293B);

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: _primary,
        surface: _surface,
        error: _error,
      ),
      scaffoldBackgroundColor: _surface,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 28, fontWeight: FontWeight.w700, color: _textPrimary,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, color: _textPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12, color: _textSecondary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: _surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: _border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _error),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
        hintStyle: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: _border, thickness: 1, space: 1),
    );
  }

  // Expose these for use across the app
  static const primary = _primary;
  static const surface = _surface;
  static const surfaceCard = _surfaceCard;
  static const border = _border;
  static const textPrimary = _textPrimary;
  static const textSecondary = _textSecondary;
  static const success = _success;
  static const warning = _warning;
  static const error = _error;
  static const sidebarBg = _sidebarBg;
  static const sidebarSelected = _sidebarSelected;
}
