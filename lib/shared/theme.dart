import 'package:flutter/material.dart';

@immutable
class RestoColors extends ThemeExtension<RestoColors> {
  const RestoColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderSubtle,
    required this.inputFill,
    required this.placeholderBg,
    required this.appBarGradient,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderSubtle;
  final Color inputFill;
  final Color placeholderBg;
  final List<Color> appBarGradient;
  final bool isDark;

  static const RestoColors dark = RestoColors(
    background: RestoTheme.darkBg,
    surface: RestoTheme.cardBg,
    textPrimary: RestoTheme.textLight,
    textSecondary: RestoTheme.textMuted,
    borderSubtle: Color(0x14FFFFFF),
    inputFill: Color(0xFF2A2932),
    placeholderBg: RestoTheme.darkBg,
    appBarGradient: [Color(0xFF1A1525), RestoTheme.darkBg],
    isDark: true,
  );

  static const RestoColors light = RestoColors(
    background: RestoTheme.lightBg,
    surface: RestoTheme.lightCardBg,
    textPrimary: RestoTheme.lightText,
    textSecondary: RestoTheme.lightTextMuted,
    borderSubtle: Color(0x14000000),
    inputFill: Color(0xFFECEEF4),
    placeholderBg: Color(0xFFECEEF4),
    appBarGradient: [Colors.white, RestoTheme.lightBg],
    isDark: false,
  );

  @override
  RestoColors copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? borderSubtle,
    Color? inputFill,
    Color? placeholderBg,
    List<Color>? appBarGradient,
    bool? isDark,
  }) {
    return RestoColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      inputFill: inputFill ?? this.inputFill,
      placeholderBg: placeholderBg ?? this.placeholderBg,
      appBarGradient: appBarGradient ?? this.appBarGradient,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  RestoColors lerp(ThemeExtension<RestoColors>? other, double t) {
    if (other is! RestoColors) return this;
    return RestoColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      placeholderBg: Color.lerp(placeholderBg, other.placeholderBg, t)!,
      appBarGradient: t < 0.5 ? appBarGradient : other.appBarGradient,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension RestoThemeContext on BuildContext {
  RestoColors get resto => Theme.of(this).extension<RestoColors>()!;
}

class RestoTheme {
  static const Color darkBg = Color(0xFF0F0E17);
  static const Color cardBg = Color(0xFF1F1E26);
  static const Color lightBg = Color(0xFFF5F6FA);
  static const Color lightCardBg = Colors.white;
  static const Color primary = Color(0xFFFF8906);
  static const Color secondary = Color(0xFFF25F4C);
  static const Color textLight = Color(0xFFFFFEFA);
  static const Color textMuted = Color(0xFFA7A9BE);
  static const Color lightText = Color(0xFF1A1A2E);
  static const Color lightTextMuted = Color(0xFF6B7280);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFD32F2F);
  static const Color info = Color(0xFF0288D1);

  static Color background(bool isDark) => isDark ? darkBg : lightBg;
  static Color surface(bool isDark) => isDark ? cardBg : lightCardBg;
  static Color textPrimary(bool isDark) => isDark ? textLight : lightText;
  static Color textSecondary(bool isDark) => isDark ? textMuted : lightTextMuted;

  static ThemeData themeFor(bool isDark) => isDark ? darkTheme : lightTheme;

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: darkBg,
      primaryColor: primary,
      extensions: const [RestoColors.dark],
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: cardBg,
        error: danger,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: textLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textLight,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2932),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: lightBg,
      primaryColor: primary,
      extensions: const [RestoColors.light],
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: lightCardBg,
        error: danger,
        onSurface: lightText,
      ),
      cardTheme: CardThemeData(
        color: lightCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: lightText,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: lightText),
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textLight,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: lightCardBg,
        selectedItemColor: primary,
        unselectedItemColor: lightTextMuted,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFECEEF4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: lightTextMuted),
        hintStyle: const TextStyle(color: lightTextMuted),
      ),
    );
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'nouvelle':
        return Colors.orange;
      case 'acceptee':
        return Colors.blue;
      case 'enPreparation':
        return Colors.amber;
      case 'prete':
        return Colors.teal;
      case 'servie':
        return Colors.green;
      case 'payee':
        return success;
      case 'annulee':
        return danger;
      case 'libre':
        return Colors.grey;
      case 'occupee':
        return Colors.red;
      case 'enAttenteAddition':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case 'nouvelle':
        return 'Nouvelle';
      case 'acceptee':
        return 'Acceptée';
      case 'enPreparation':
        return 'En Préparation';
      case 'prete':
        return 'Prête';
      case 'servie':
        return 'Servie';
      case 'payee':
        return 'Payée';
      case 'annulee':
        return 'Annulée';
      case 'libre':
        return 'Libre';
      case 'occupee':
        return 'Occupée';
      case 'enAttenteAddition':
        return 'L\'addition demandée';
      default:
        return status;
    }
  }
}
