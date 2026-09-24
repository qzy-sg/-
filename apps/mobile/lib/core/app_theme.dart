import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF14352F);
  static const primarySoft = Color(0xFFE7F1EE);
  static const mint = Color(0xFFD7EBE6);
  static const page = Color(0xFFF6F3EE);
  static const card = Colors.white;
  static const line = Color(0xFFE7E2DA);
  static const text = Color(0xFF161918);
  static const sub = Color(0xFF5A615E);
  static const muted = Color(0xFF8C908C);
  static const ink = Color(0xFF101614);
  static const brass = Color(0xFFC6A36A);
  static const warnBg = Color(0xFFFFF6E8);
  static const warnText = Color(0xFF8A5A1A);
  static const warnLine = Color(0xFFF0D7A4);
  static const pendingBg = Color(0xFFFFF1E4);
  static const pending = Color(0xFFC56A1A);
  static const dangerBg = Color(0xFFFDEEEC);
  static const danger = Color(0xFFC4554A);
  static const chip = Color(0xFFF1EEE8);
  static const input = Color(0xFFF3F0EA);
  static const shadow = [BoxShadow(color: Color(0x120F1C18), blurRadius: 28, offset: Offset(0, 10))];
}

class AppTheme {
  /// 不走 fonts.gstatic.com，避免 Chrome Web 拉取失败。
  static const _fallback = [
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei',
    'Noto Sans SC',
    'Source Han Sans SC',
    'sans-serif',
  ];

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.page,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
      fontFamily: 'PingFang SC',
      fontFamilyFallback: _fallback,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
        fontFamily: 'PingFang SC',
        fontFamilyFallback: _fallback,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.2)),
      ),
    );
  }
}
