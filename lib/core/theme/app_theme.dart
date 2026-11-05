import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData get dark => _build(Brightness.dark, NeuralLensColors.dark);
  static ThemeData get light =>
      _build(Brightness.light, NeuralLensColors.light);

  static ThemeData _build(Brightness brightness, NeuralLensColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accentText,
      onSecondary: c.onAccent,
      tertiary: c.accent2,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surfaceRaised,
      surfaceContainerHigh: c.surfaceHigh,
      surfaceContainerHighest: c.surfaceHigh,
      outline: c.borderStrong,
      outlineVariant: c.border,
    );

    final text = _textTheme(c);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: Fonts.sans,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: text,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.textSecondary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
        systemOverlayStyle: _overlay(brightness),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textPrimary,
          highlightColor: c.accentSoft,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: Shapes.of(Radii.md, side: BorderSide(color: c.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        hintStyle: text.bodyLarge!.copyWith(color: c.textMuted),
        prefixIconColor: c.textMuted,
        suffixIconColor: c.textMuted,
        counterStyle: TextStyle(
          fontFamily: Fonts.mono,
          fontSize: 11,
          color: c.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg + 2,
          vertical: Space.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(
            color: c.accentText.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceRaised,
        selectedColor: c.accentSoft,
        side: BorderSide(color: c.border),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge!.copyWith(color: c.textSecondary),
        secondaryLabelStyle: text.labelLarge!.copyWith(color: c.textPrimary),
        iconTheme: IconThemeData(color: c.textSecondary, size: 16),
        checkmarkColor: c.accentText,
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.surfaceHigh,
        thumbColor: c.accent,
        overlayColor: c.accentSoft,
        trackHeight: 6,
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        valueIndicatorColor: c.surfaceHigh,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: Fonts.mono,
          color: c.textPrimary,
        ),
        // ignore: deprecated_member_use
        year2023: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : c.borderStrong,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceHigh,
        circularTrackColor: c.surfaceHigh,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceHigh,
        elevation: 0,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.textPrimary),
        actionTextColor: c.accentText,
        shape: Shapes.of(Radii.md, side: BorderSide(color: c.borderStrong)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: Shapes.of(Radii.xl, side: BorderSide(color: c.border)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(36, 4),
        shape: RoundedSuperellipseBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.xl),
          ),
          side: BorderSide(color: c.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: Shapes.of(Radii.md, side: BorderSide(color: c.border)),
        textStyle: text.bodyMedium!.copyWith(color: c.textPrimary),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surfaceHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            Shapes.of(Radii.md, side: BorderSide(color: c.border)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: Space.sm),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall!.copyWith(color: c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accentText : c.textMuted,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: c.surfaceHigh,
          shape: Shapes.of(Radii.xs, side: BorderSide(color: c.border)),
        ),
        textStyle: text.labelMedium!.copyWith(color: c.textPrimary),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentText,
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accentText,
        selectionColor: c.accentSoft,
        selectionHandleColor: c.accentText,
      ),
    );
  }

  static SystemUiOverlayStyle _overlay(Brightness b) =>
      (b == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          );

  static TextTheme _textTheme(NeuralLensColors c) {
    TextStyle s(double size, FontWeight w, {double ls = 0, double h = 1.3}) =>
        TextStyle(
          fontFamily: Fonts.sans,
          fontSize: size,
          fontWeight: w,
          letterSpacing: ls,
          height: h,
          color: c.textPrimary,
        );
    return TextTheme(
      displayLarge: s(52, FontWeight.w600, ls: -2.4, h: 1.02),
      displayMedium: s(42, FontWeight.w600, ls: -1.8, h: 1.05),
      displaySmall: s(34, FontWeight.w600, ls: -1.3, h: 1.1),
      headlineMedium: s(27, FontWeight.w600, ls: -0.9, h: 1.15),
      headlineSmall: s(22, FontWeight.w600, ls: -0.6, h: 1.2),
      titleLarge: s(19, FontWeight.w600, ls: -0.4, h: 1.25),
      titleMedium: s(16, FontWeight.w600, ls: -0.25),
      titleSmall: s(14.5, FontWeight.w600, ls: -0.15),
      bodyLarge: s(16, FontWeight.w400, ls: -0.1, h: 1.55),
      bodyMedium: s(
        14,
        FontWeight.w400,
        h: 1.5,
      ).copyWith(color: c.textSecondary),
      bodySmall: s(12.5, FontWeight.w400, h: 1.45).copyWith(color: c.textMuted),
      labelLarge: s(14, FontWeight.w600, ls: -0.1),
      labelMedium: s(12, FontWeight.w500),
      // Eyebrow labels are monospaced, uppercase and tracked.
      labelSmall: s(
        11,
        FontWeight.w500,
        ls: 1.4,
      ).copyWith(fontFamily: Fonts.mono, color: c.textMuted),
    );
  }
}
