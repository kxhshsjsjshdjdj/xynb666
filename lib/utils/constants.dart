import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF5A52D5);
  static const secondary = Color(0xFFFF6584);
  static const bg = Color(0xFF0F0F1A);
  static const bgCard = Color(0xFF1A1A2E);
  static const bgSurface = Color(0xFF16213E);
  static const text = Color(0xFFE8E8F0);
  static const textMuted = Color(0xFF888899);
  static const border = Color(0xFF2A2A4A);
  static const success = Color(0xFF4CAF50);
  static const danger = Color(0xFFF44336);
  static const warning = Color(0xFFFF9800);
}

class AppConfig {
  // ====== 改为你的服务器IP ======
  static const signalServer = 'http://45.207.197.110:3001';
  // ==============================
}

class AppTextStyles {
  static const heading = TextStyle(
    color: AppColors.text,
    fontWeight: FontWeight.w800,
    fontSize: 28,
  );

  static const subheading = TextStyle(
    color: AppColors.text,
    fontWeight: FontWeight.w700,
    fontSize: 18,
  );

  static const body = TextStyle(
    color: AppColors.text,
    fontSize: 15,
  );

  static const muted = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
  );
}
