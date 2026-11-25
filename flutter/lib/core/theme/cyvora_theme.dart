import 'package:material_ui/material_ui.dart';

/// Official Cyvora violet design tokens.
abstract final class CyvoraColors {
  static const primary = Color(0xFF7C3AED);
  static const electric = Color(0xFF8B5CF6);
  static const light = Color(0xFFA78BFA);
  static const deep = Color(0xFF2E1065);
  static const background = Color(0xFF10051F);
  static const backgroundMid = Color(0xFF1A0833);
  static const surface = Color(0xFF211044);
  static const surfaceSecondary = Color(0xFF291451);
  static const border = Color(0xFF452477);
  static const text = Color(0xFFFFFFFF);
  static const secondaryText = Color(0xFFC4B5FD);
  static const muted = Color(0xFFA78BFA);
  static const safe = Color(0xFFA78BFA);
  static const warning = Color(0xFFFFC46B);
  static const danger = Color(0xFFFF6969);
  static const info = Color(0xFF60A5FA);
  static const onPrimary = Color(0xFFFFFFFF);
}

abstract final class CyvoraGradients {
  static const primary = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFA855F7), Color(0xFF7C3AED), Color(0xFF6D28D9)],
  );

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      CyvoraColors.background,
      CyvoraColors.backgroundMid,
      CyvoraColors.deep,
    ],
  );
}

abstract final class CyvoraRadii {
  static const input = 16.0;
  static const card = 22.0;
  static const button = 28.0;
  static const sheet = 24.0;
}

abstract final class CyvoraSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

ThemeData cyvoraTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: CyvoraColors.electric,
    onPrimary: CyvoraColors.onPrimary,
    secondary: CyvoraColors.light,
    onSecondary: CyvoraColors.background,
    error: CyvoraColors.danger,
    onError: CyvoraColors.text,
    surface: CyvoraColors.surface,
    onSurface: CyvoraColors.text,
  );

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(CyvoraRadii.input),
    borderSide: const BorderSide(color: CyvoraColors.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: CyvoraColors.background,
    canvasColor: CyvoraColors.background,
    dividerColor: CyvoraColors.border,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: CyvoraColors.text,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineSmall: TextStyle(
        color: CyvoraColors.text,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: CyvoraColors.text,
        fontWeight: FontWeight.w800,
      ),
      bodyMedium: TextStyle(color: CyvoraColors.text, height: 1.4),
      bodySmall: TextStyle(color: CyvoraColors.secondaryText),
    ),
    iconTheme: const IconThemeData(color: CyvoraColors.secondaryText),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CyvoraColors.surfaceSecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: CyvoraColors.muted),
      labelStyle: const TextStyle(color: CyvoraColors.secondaryText),
      prefixIconColor: CyvoraColors.secondaryText,
      suffixIconColor: CyvoraColors.secondaryText,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: CyvoraColors.electric, width: 1.6),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: CyvoraColors.danger),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: CyvoraColors.danger, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CyvoraColors.electric,
        foregroundColor: CyvoraColors.onPrimary,
        disabledBackgroundColor: CyvoraColors.deep,
        disabledForegroundColor: CyvoraColors.muted,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CyvoraRadii.button),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CyvoraColors.secondaryText,
        side: const BorderSide(color: CyvoraColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CyvoraRadii.button),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: CyvoraColors.light),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: CyvoraColors.light),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CyvoraColors.electric
            : null,
      ),
      checkColor: const WidgetStatePropertyAll(CyvoraColors.onPrimary),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CyvoraColors.light
            : CyvoraColors.secondaryText,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CyvoraColors.primary
            : CyvoraColors.surfaceSecondary,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: CyvoraColors.surface,
      titleTextStyle: const TextStyle(
        color: CyvoraColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: CyvoraColors.secondaryText,
        height: 1.45,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CyvoraRadii.sheet),
        side: const BorderSide(color: CyvoraColors.border),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: CyvoraColors.surfaceSecondary,
      contentTextStyle: TextStyle(color: CyvoraColors.text),
    ),
    cardTheme: CardThemeData(
      color: CyvoraColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CyvoraRadii.card),
        side: const BorderSide(color: CyvoraColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: CyvoraColors.surface,
      indicatorColor: CyvoraColors.primary.withValues(alpha: 0.45),
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? CyvoraColors.light : CyvoraColors.muted,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CyvoraColors.electric,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: CyvoraColors.electric,
      selectionColor: Color(0x558B5CF6),
      selectionHandleColor: CyvoraColors.electric,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: CyvoraColors.electric,
      foregroundColor: CyvoraColors.onPrimary,
    ),
  );
}
