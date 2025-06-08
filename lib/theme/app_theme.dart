// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF1976D2); // Blue 700
  static const Color secondaryColor = Color(0xFF42A5F5); // Blue 400
  static const Color backgroundColor = Color(0xFFF5F5F5); // Grey 100
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFE53E3E);
  static const Color successColor = Color(0xFF38A169);
  static const Color warningColor = Color(0xFFED8936);
  static const Color infoColor = Color(0xFF3182CE);

  // Grey shades
  static final Color grey50 = Colors.grey.shade50;
  static final Color grey100 = Colors.grey.shade100;
  static final Color grey200 = Colors.grey.shade200;
  static final Color grey300 = Colors.grey.shade300;
  static final Color grey400 = Colors.grey.shade400;
  static final Color grey500 = Colors.grey.shade500;
  static final Color grey600 = Colors.grey.shade600;
  static final Color grey700 = Colors.grey.shade700;
  static final Color grey800 = Colors.grey.shade800;
  static final Color grey900 = Colors.grey.shade900;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border radius
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;

  // Elevation
  static const double elevationSM = 2.0;
  static const double elevationMD = 4.0;
  static const double elevationLG = 8.0;

  // Text Styles
  static TextStyle get headingLarge => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: grey800,
      );

  static TextStyle get headingMedium => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: grey800,
      );

  static TextStyle get headingSmall => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: grey800,
      );

  static TextStyle get bodyLarge => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: grey700,
      );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: grey700,
      );

  static TextStyle get bodySmall => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: grey600,
      );

  static TextStyle get buttonText => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get captionText => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: grey500,
      );

  // Shadow
  static List<BoxShadow> get shadowSM => [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          offset: const Offset(0, 2),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowMD => [
        BoxShadow(
          color: Colors.grey.withOpacity(0.15),
          offset: const Offset(0, 4),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowLG => [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          offset: const Offset(0, 8),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];

  // Input decoration
  static InputDecoration getInputDecoration({
    required String hint,
    required IconData icon,
    String? label,
    Color? fillColor,
    Color? iconColor,
  }) {
    return InputDecoration(
      hintText: hint,
      labelText: label,
      hintStyle: GoogleFonts.poppins(color: grey400, fontSize: 14),
      labelStyle: GoogleFonts.poppins(color: grey700, fontSize: 14),
      prefixIcon: Container(
        margin: const EdgeInsets.only(left: 4, right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: iconColor?.withOpacity(0.1) ?? grey100,
          borderRadius: BorderRadius.circular(radiusSM),
        ),
        child: Icon(icon, color: iconColor ?? grey600, size: 20),
      ),
      filled: true,
      fillColor: fillColor ?? surfaceColor,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide(color: grey200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      errorStyle: GoogleFonts.poppins(
        fontSize: 12,
        color: errorColor,
      ),
    );
  }

  // Card decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radiusLG),
        boxShadow: shadowSM,
      );

  // Button styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: elevationSM,
        shadowColor: primaryColor.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: buttonText,
      );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: buttonText.copyWith(color: primaryColor),
      );

  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
        foregroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSM),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w500),
      );

  // Background Colors (Global)
  static const Color screenBackgroundColor =
      Color(0xFFF5F5F5); // Grey 100 - Same as backgroundColor
  static final Color screenBackgroundLight =
      Colors.grey.shade50; // For cards and sections
  static const Color modalBackgroundColor =
      Colors.transparent; // For modal overlays
  static const Color overlayBackgroundColor =
      Color(0x80000000); // Semi-transparent overlay

  // Action Sheet Colors
  static const Color actionSheetBackground = Colors.white;
  static final Color actionSheetHandleColor = Colors.grey.shade300;
  static final Color actionSheetItemBackground = Colors.grey.shade50;
  static final Color actionSheetBorderColor = Colors.grey.shade200;

  // Common UI Components Constants
  static const double actionSheetBorderRadius = 24.0;
  static const double actionSheetHandleWidth = 40.0;
  static const double actionSheetHandleHeight = 4.0;
  static const EdgeInsets actionSheetPadding = EdgeInsets.all(20.0);
  static const EdgeInsets actionSheetItemPadding = EdgeInsets.all(16.0);
}
