import 'package:flutter/material.dart';

abstract final class AppColors {
  // Functional Primary - Mavi (Uygulama Ana Rengi)
  static const primary = Color(0xFF0877E8);
  static const primaryBright = Color(0xFF19AEFF);
  static const primaryHover = Color(0xFF0567CA);
  static const primaryBlue = primary;
  static const primaryBlueDark = primaryHover;
  static const surfaceBlue = Color(0xFFEDF6FF);

  // Brand Accent - Mor / Lila (Marka Karakteri / Logo / Vurgular)
  static const brandPurple = Color(0xFF7C20D4);
  static const brandLilac = Color(0xFFA855F7);
  static const brandPurpleDeep = Color(0xFF5413A5);
  static const surfaceLilac = Color(0xFFF5EEFF);
  static const borderLilac = Color(0xFFE9D5FF);

  // Text
  static const navy = Color(0xFF0B1F44);
  static const navyText = navy;
  static const textSecondary = Color(0xFF667085);
  static const textMuted = Color(0xFF98A2B3);

  // Surfaces & Borders
  static const surface = Colors.white;
  static const surfaceSecondary = Color(0xFFF7F9FC);
  static const surfaceIcon = Color(0xFFF3F5FC);
  static const surfaceSelectedLilac = Color(0xFFF6EFFF);
  static const neutralSurface = surfaceSecondary;
  static const border = Color(0xFFE3E8F0);
  static const borderSoft = border;
  static const line = border;
  static const borderStrong = Color(0xFFCBD5E1);

  // Semantic
  static const green = Color(0xFF16A368);
  static const warning = Color(0xFFD97706);
  static const red = Color(0xFFDC2626);
  static const danger = red;
  static const encounterPink = Color(0xFFF43F5E);

  // Primary active interactive color (MAVİ)
  static const action = primaryHover;
  static const blue = primary;
  static const cyan = Color(0xFF00A8E8);
  static const muted = textSecondary;
  static const pale = surfaceBlue;
}

abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const wide = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = EdgeInsets.all(lg);
}

abstract final class AppShape {
  static const radius = 16.0;
  static const small = 12.0;
  static const compact = 8.0;
  static const large = 20.0;
  static const pill = 999.0;
  static final control = BorderRadius.circular(small);
  static final rounded = BorderRadius.circular(radius);
  static final largeRounded = BorderRadius.circular(large);

  static const blueGradient = LinearGradient(
    colors: [Color(0xFF0877E8), Color(0xFF19AEFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const purpleGradient = LinearGradient(
    colors: [Color(0xFF7C20D4), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const bannerGradient = LinearGradient(
    colors: [Color(0xFF0877E8), Color(0xFF19AEFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const activeTabGradient = LinearGradient(
    colors: [Color(0xFF0877E8), Color(0xFF19AEFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const encounterSurfaceGradient = LinearGradient(
    colors: [Color(0xFFFFF4F8), Color(0xFFF5EEFF), Color(0xFFEDF6FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final shadow = [
    BoxShadow(
      color: const Color(0xFF0B1F44).withValues(alpha: .05),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static final bannerShadow = [
    BoxShadow(
      color: const Color(0xFF0877E8).withValues(alpha: .24),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static BoxDecoration card({
    Color color = Colors.white,
    Color? borderColor,
    bool elevated = false,
  }) => BoxDecoration(
    color: color,
    borderRadius: rounded,
    border: Border.all(color: borderColor ?? AppColors.line),
    boxShadow: elevated ? shadow : null,
  );

  static BoxDecoration encounterCard() => BoxDecoration(
    gradient: encounterSurfaceGradient,
    borderRadius: rounded,
    border: Border.all(color: const Color(0xFFF0D4E7)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF7C20D4).withValues(alpha: .07),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

abstract final class AppDimensions {
  static const touch = 48.0;
  static const input = 50.0;
  static const button = 50.0;
  static const secondaryButton = 46.0;
  static const topBar = 56.0;
  static const bottomNav = 68.0;

  // Global Icon Size Tokens (Standardized)
  static const iconXS = 16.0;
  static const iconSM = 18.0;
  static const iconMD = 22.0;
  static const iconLG = 24.0;
  static const iconXL = 28.0;
  static const icon = iconMD;

  // Standard Icon Container Sizes
  static const iconContainerSM = 36.0;
  static const iconContainerMD = 42.0;
  static const iconContainerLG = 48.0;
}

abstract final class AppTypography {
  static const pageTitle = TextStyle(
    fontFamily: 'NunitoSans',
    fontSize: 19,
    height: 1.25,
    color: AppColors.navy,
    fontWeight: FontWeight.w700,
    letterSpacing: -.2,
  );
  static const section = TextStyle(
    fontFamily: 'NunitoSans',
    fontSize: 16,
    height: 1.3,
    color: AppColors.navy,
    fontWeight: FontWeight.w700,
    letterSpacing: -.15,
  );
  static const cardTitle = TextStyle(
    fontFamily: 'NunitoSans',
    fontSize: 15,
    height: 1.32,
    color: AppColors.navy,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(
    fontFamily: 'NunitoSans',
    fontSize: 15,
    height: 1.5,
    color: AppColors.navy,
    fontWeight: FontWeight.w400,
  );
  static const secondaryBody = TextStyle(
    fontFamily: 'NunitoSans',
    fontSize: 14,
    height: 1.45,
    color: AppColors.muted,
    fontWeight: FontWeight.w400,
  );
  static const metadata = TextStyle(
    fontFamily: 'NunitoSans',
    fontSize: 12,
    height: 1.4,
    color: AppColors.muted,
    fontWeight: FontWeight.w500,
  );
  static const button = TextStyle(
    fontFamily: 'NunitoSans',
    fontSize: 14.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
  static const caption = TextStyle(
    fontFamily: 'NunitoSans',
    fontSize: 11.5,
    height: 1.35,
    color: AppColors.muted,
    fontWeight: FontWeight.w500,
  );
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.brandPurple,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.primary,
        secondary: AppColors.primaryBright,
        onSurface: AppColors.navy,
        surface: Colors.white,
        surfaceContainerHighest: AppColors.surfaceBlue,
        outline: AppColors.line,
        error: AppColors.danger,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'NunitoSans',
  );
  return base.copyWith(
    scaffoldBackgroundColor: Colors.white,
    textTheme: base.textTheme
        .apply(bodyColor: AppColors.navy, displayColor: AppColors.navy)
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -.4,
          ),
          headlineMedium: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            height: 1.24,
            letterSpacing: -.3,
          ),
          titleLarge: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.3,
            letterSpacing: -.2,
          ),
          titleMedium: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            height: 1.32,
          ),
          bodyLarge: const TextStyle(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
          bodySmall: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(
          fontFamily: 'NunitoSans',
          bodyColor: AppColors.navy,
          displayColor: AppColors.navy,
        )
        .copyWith(
          bodySmall: const TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 12,
            height: 1.4,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppDimensions.touch),
        iconSize: AppDimensions.icon,
        foregroundColor: AppColors.navy,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(AppDimensions.touch, 44),
        foregroundColor: AppColors.action,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(borderRadius: AppShape.control),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(
        color: AppColors.muted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: const TextStyle(
        color: AppColors.muted,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.action, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppDimensions.button),
        backgroundColor: AppColors.action,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: AppTypography.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppDimensions.secondaryButton),
        foregroundColor: AppColors.navy,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: AppTypography.button,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.action,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: const TextStyle(
        color: AppColors.navy,
        fontFamily: 'NunitoSans',
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.action,
    ),
    tooltipTheme: const TooltipThemeData(preferBelow: false),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      shape: RoundedRectangleBorder(borderRadius: AppShape.control),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      showDragHandle: true,
      dragHandleColor: AppColors.borderStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppShape.large),
        ),
      ),
    ),
  );
}
