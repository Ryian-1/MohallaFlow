import 'package:flutter/material.dart';

// MOHALLAFLOW_PREMIUM_APPLE_INSPIRED_UI_V2
/// MohallaFlow's shared premium design system.
///
/// Design direction: Apple-inspired restraint, generous whitespace, crisp
/// system typography, soft neutral surfaces, precise controls and quiet depth.
/// This is an original MohallaFlow design using its established navy/white/grey
/// palette. Flutter uses the platform's default system font stack (SF on iOS,
/// the native system sans-serif on Android) rather than bundling a font.
class AppTheme {
  // Existing brand tokens are intentionally preserved for all feature screens.
  static const Color navyBlue = Color(0xFF172B4D);
  static const Color secondaryNavy = Color(0xFF29476A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF5F7FA);
  static const Color borderGrey = Color(0xFFE7EBF0);
  static const Color textDark = Color(0xFF172033);
  static const Color textGrey = Color(0xFF687386);

  // Premium surface and interaction tokens.
  static const Color deepNavy = Color(0xFF101D34);
  static const Color softNavy = Color(0xFFEDF2F8);
  static const Color subduedSurface = Color(0xFFFAFBFC);
  static const Color disabledSurface = Color(0xFFE9EDF2);
  static const Color disabledText = Color(0xFF98A2B3);
  static const Color error = Color(0xFFB42318);
  static const Color successInk = Color(0xFF344054);

  static const double pageRadius = 22;
  static const double cardRadius = 20;
  static const double controlRadius = 15;
  static const double smallRadius = 11;
  static const double pageHorizontalPadding = 22;
  static const double controlHeight = 50;

  static const BorderRadius pageBorderRadius = BorderRadius.all(
    Radius.circular(pageRadius),
  );
  static const BorderRadius cardBorderRadius = BorderRadius.all(
    Radius.circular(cardRadius),
  );
  static const BorderRadius controlBorderRadius = BorderRadius.all(
    Radius.circular(controlRadius),
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[deepNavy, navyBlue, secondaryNavy],
    stops: <double>[0, 0.58, 1],
  );

  static const List<BoxShadow> quietCardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x09172B4D), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static ThemeData get lightTheme {
    const textTheme = TextTheme(
      displayLarge: TextStyle(
        color: textDark,
        fontSize: 40,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.45,
      ),
      displayMedium: TextStyle(
        color: textDark,
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.05,
      ),
      displaySmall: TextStyle(
        color: textDark,
        fontSize: 29,
        height: 1.14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.75,
      ),
      headlineLarge: TextStyle(
        color: textDark,
        fontSize: 25,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.55,
      ),
      headlineMedium: TextStyle(
        color: textDark,
        fontSize: 22,
        height: 1.22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      headlineSmall: TextStyle(
        color: textDark,
        fontSize: 19,
        height: 1.28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        color: textDark,
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
      ),
      titleMedium: TextStyle(
        color: textDark,
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: TextStyle(
        color: textDark,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: textDark,
        fontSize: 16,
        height: 1.52,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: textGrey,
        fontSize: 14,
        height: 1.48,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: textGrey,
        fontSize: 12,
        height: 1.42,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        color: textDark,
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        color: textGrey,
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        color: textGrey,
        fontSize: 11,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
    );

    const colorScheme = ColorScheme.light(
      primary: navyBlue,
      onPrimary: white,
      primaryContainer: softNavy,
      onPrimaryContainer: navyBlue,
      secondary: secondaryNavy,
      onSecondary: white,
      secondaryContainer: subduedSurface,
      onSecondaryContainer: textDark,
      surface: white,
      onSurface: textDark,
      onSurfaceVariant: textGrey,
      outline: borderGrey,
      outlineVariant: borderGrey,
      error: error,
      onError: white,
    );

    final roundedControl = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    final roundedCard = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardRadius),
      side: const BorderSide(color: borderGrey, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightGrey,
      canvasColor: white,
      cardColor: white,
      dividerColor: borderGrey,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: secondaryNavy, size: 21),
      splashColor: softNavy,
      highlightColor: softNavy.withValues(alpha: 0.45),
      hoverColor: softNavy,
      focusColor: softNavy,

      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: navyBlue,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 68,
        centerTitle: false,
        titleSpacing: 22,
        iconTheme: IconThemeData(color: navyBlue, size: 21),
        actionsIconTheme: IconThemeData(color: navyBlue, size: 20),
        titleTextStyle: TextStyle(
          color: navyBlue,
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
      ),

      cardTheme: CardThemeData(
        color: white,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x09172B4D),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: roundedCard,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navyBlue,
          foregroundColor: white,
          disabledBackgroundColor: disabledSurface,
          disabledForegroundColor: disabledText,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
          shape: roundedControl,
          textStyle: const TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navyBlue,
          foregroundColor: white,
          disabledBackgroundColor: disabledSurface,
          disabledForegroundColor: disabledText,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: roundedControl,
          textStyle: const TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navyBlue,
          backgroundColor: white,
          disabledForegroundColor: disabledText,
          disabledBackgroundColor: subduedSurface,
          side: const BorderSide(color: borderGrey, width: 1),
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: roundedControl,
          textStyle: const TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: navyBlue,
          disabledForegroundColor: disabledText,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: roundedControl,
          textStyle: const TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: navyBlue,
          disabledForegroundColor: disabledText,
          hoverColor: softNavy,
          focusColor: softNavy,
          highlightColor: softNavy,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.all(10),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: roundedControl,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          color: textGrey,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: textGrey,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: navyBlue,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: const TextStyle(color: textGrey, fontSize: 11),
        errorStyle: const TextStyle(color: error, fontSize: 11),
        prefixIconColor: secondaryNavy,
        suffixIconColor: textGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: borderGrey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: borderGrey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: navyBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: const Color(0x1A172B4D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderGrey),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titleTextStyle: const TextStyle(
          color: textDark,
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        contentTextStyle: const TextStyle(
          color: textGrey,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: white,
        modalBackgroundColor: white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        modalElevation: 10,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: softNavy,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? navyBlue : textGrey,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.05,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? navyBlue : textGrey, size: 21);
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: white,
        selectedIconTheme: IconThemeData(color: navyBlue, size: 22),
        unselectedIconTheme: IconThemeData(color: textGrey, size: 21),
        selectedLabelTextStyle: TextStyle(
          color: navyBlue,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: textGrey,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: softNavy,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: navyBlue,
        unselectedLabelColor: textGrey,
        indicatorColor: navyBlue,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: borderGrey,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightGrey,
        selectedColor: softNavy,
        disabledColor: subduedSurface,
        secondarySelectedColor: softNavy,
        labelStyle: const TextStyle(
          color: textDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: navyBlue,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        side: const BorderSide(color: borderGrey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: secondaryNavy,
        textColor: textDark,
        contentPadding: EdgeInsets.symmetric(horizontal: 17, vertical: 5),
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderGrey,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: textGrey, width: 1.2),
      ),
      radioTheme: const RadioThemeData(
        fillColor: WidgetStatePropertyAll<Color>(navyBlue),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return white;
          return subduedSurface;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return navyBlue;
          return borderGrey;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: navyBlue,
        linearTrackColor: borderGrey,
        circularTrackColor: borderGrey,
        refreshBackgroundColor: white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: deepNavy,
        contentTextStyle: const TextStyle(
          color: white,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 5,
        showCloseIcon: true,
        closeIconColor: white,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x1A172B4D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderGrey),
        ),
        textStyle: const TextStyle(
          color: textDark,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: deepNavy,
          borderRadius: BorderRadius.circular(9),
        ),
        textStyle: const TextStyle(
          color: white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(seconds: 3),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: navyBlue,
        foregroundColor: white,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: navyBlue,
        headerForegroundColor: white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        todayBorder: const BorderSide(color: navyBlue),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll<Color>(subduedSurface),
        headingTextStyle: TextStyle(
          color: textDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(
          color: textDark,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        dividerThickness: 1,
        horizontalMargin: 18,
        columnSpacing: 22,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(
          secondaryNavy.withValues(alpha: 0.32),
        ),
        radius: const Radius.circular(20),
        thickness: const WidgetStatePropertyAll<double>(6),
        interactive: true,
      ),
    );
  }
}
