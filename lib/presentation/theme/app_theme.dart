import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's look in ONE place: colors, text styles, sizes, corner radii.
/// Inspired by Apple Music on iOS 26 (dark only), see
/// apple_music_design_profile.json. Sizes are Flutter points.
///
/// Screens should use these names instead of writing colors or sizes again,
/// so the whole app can be re-styled from this file.
class AppColors {
  const AppColors._();

  static const background = Color(0xFF000000);
  static const surface = Color(0xFF1C1C1E);
  static const surfaceRaised = Color(0xFF2C2C2E);
  static const surfaceHighest = Color(0xFF3A3A3C);
  static const separator = Color(0xFF38383A);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color.fromRGBO(235, 235, 245, 0.60);
  static const textTertiary = Color.fromRGBO(235, 235, 245, 0.30);

  /// The one accent (Apple Music red / pink). Used sparingly: the current
  /// song, active buttons, the main button.
  static const accent = Color(0xFFFA2D48);
  static const favoriteOn = Color(0xFFFF3B30);
  static const destructive = Color(0xFFFF453A);

  // "Glass": a translucent fill over a blurred background.
  static const glassFill = Color.fromRGBO(255, 255, 255, 0.10);
  static const glassFillStrong = Color.fromRGBO(255, 255, 255, 0.16);
  static const glassBorder = Color.fromRGBO(255, 255, 255, 0.18);

  static const chipUnselected = Color.fromRGBO(255, 255, 255, 0.12);
  static const chipSelected = Color.fromRGBO(255, 255, 255, 0.88);

  static const progressPlayed = Color.fromRGBO(255, 255, 255, 0.85);
  static const progressTrack = Color.fromRGBO(255, 255, 255, 0.25);

  // The loop editor's handles keep their (already tested) colors.
  static const loopHandleStart = Color(0xFF2E9E4F);
  static const loopHandleEnd = Color(0xFFD64545);

  // Now Playing background when a song has no artwork (top, bottom).
  static const nowPlayingGradientTop = Color(0xFF4A3238);
  static const nowPlayingGradientBottom = Color(0xFF241A1D);
}

class AppSpacing {
  const AppSpacing._();

  static const double pageMargin = 20;
  static const double sectionGap = 28;
  static const double rowHeight = 64;
  static const double rowArtwork = 48;
  static const double listTextInset = 76;
  static const double minTouchTarget = 44;
}

class AppRadius {
  const AppRadius._();

  static const double rowArtwork = 6;
  static const double cardArtwork = 12;
  static const double nowPlayingArtwork = 14;
  static const double searchField = 12;
  static const double bottomSheetTop = 28;
  static const double dialog = 14;
  static const double glassMiniPlayer = 30;
}

class AppText {
  const AppText._();

  static const largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );
  static const sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const nowPlayingTitle = sectionTitle;
  static const nowPlayingArtist = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const rowTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const rowSubtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
  static const buttonLabel = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
}

/// The theme for the whole app (dark only). Applied in main.dart.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    tertiary: AppColors.accent,
    error: AppColors.destructive,
    surface: AppColors.background,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.background,
    surfaceContainerLow: AppColors.background,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceRaised,
    surfaceContainerHighest: AppColors.surfaceHighest,
    primaryContainer: const Color(0xFF5A1620),
    onPrimaryContainer: Colors.white,
    secondaryContainer: AppColors.surfaceRaised,
    onSecondaryContainer: Colors.white,
    outline: AppColors.textTertiary,
    outlineVariant: AppColors.separator,
  );

  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final applied = base.textTheme.apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );
  final textTheme = applied.copyWith(
    headlineLarge: AppText.largeTitle,
    headlineSmall: AppText.sectionTitle,
    titleLarge: AppText.sectionTitle,
    titleMedium: AppText.rowTitle,
    bodyLarge: applied.bodyLarge?.copyWith(fontSize: 17),
    bodyMedium: applied.bodyMedium?.copyWith(fontSize: 15),
    bodySmall: AppText.caption,
  );

  const sheetShape = RoundedRectangleBorder(
    borderRadius:
        BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheetTop)),
  );
  final roundedDialog =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog));

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    textTheme: textTheme,
    appBarTheme: const AppBarThemeData(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.separator,
      thickness: 0.5,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textPrimary,
      textColor: AppColors.textPrimary,
      titleTextStyle: AppText.rowTitle,
      subtitleTextStyle: AppText.rowSubtitle,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: roundedDialog,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 15,
        color: AppColors.textSecondary,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: sheetShape,
      dragHandleColor: Color.fromRGBO(255, 255, 255, 0.35),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle:
          const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      shape: roundedDialog,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: roundedDialog,
      textStyle: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: const Color.fromRGBO(255, 255, 255, 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.searchField),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.searchField),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.searchField),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.searchField),
        borderSide: BorderSide.none,
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.searchField),
        borderSide: const BorderSide(color: AppColors.destructive, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: const WidgetStatePropertyAll(AppColors.chipUnselected),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.searchField))),
      constraints: const BoxConstraints(minHeight: 40),
      textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 17, color: AppColors.textPrimary)),
      hintStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 17, color: AppColors.textSecondary)),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 6,
      activeTrackColor: AppColors.progressPlayed,
      inactiveTrackColor: AppColors.progressTrack,
      thumbColor: Colors.white,
      overlayColor: Colors.transparent,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    // Only shape and text here: colors come from the color scheme, so the
    // normal button is accent red and the tonal button is the raised grey.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(64, AppSpacing.minTouchTarget),
        textStyle: AppText.buttonLabel,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: AppText.buttonLabel,
      ),
    ),
  );
}
