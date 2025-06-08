// lib/utils/ui_utils.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class UIUtils {
  // Show custom snackbar with consistent styling
  static void showCustomSnackbar(
    BuildContext context, {
    required String message,
    required SnackBarType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    IconData icon;
    Color backgroundColor;

    switch (type) {
      case SnackBarType.success:
        icon = Icons.check_circle_outline;
        backgroundColor = AppTheme.successColor;
        break;
      case SnackBarType.error:
        icon = Icons.error_outline;
        backgroundColor = AppTheme.errorColor;
        break;
      case SnackBarType.warning:
        icon = Icons.warning_outlined;
        backgroundColor = AppTheme.warningColor;
        break;
      case SnackBarType.info:
        icon = Icons.info_outline;
        backgroundColor = AppTheme.infoColor;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        margin: const EdgeInsets.all(AppTheme.spacingMD),
        duration: duration,
      ),
    );
  }

  // Show global action sheet for image source selection
  static void showImageSourceActionSheet(
    BuildContext context, {
    required VoidCallback onCameraSelected,
    required VoidCallback onGallerySelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.modalBackgroundColor,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.actionSheetBackground,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.actionSheetBorderRadius),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: AppTheme.actionSheetPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: AppTheme.actionSheetHandleWidth,
                    height: AppTheme.actionSheetHandleHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.actionSheetHandleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Title
                  Text(
                    'Pilih Sumber Gambar',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey800,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Gallery option
                  _buildActionSheetOption(
                    icon: Icons.photo_library_outlined,
                    title: 'Pilih dari Galeri',
                    subtitle: 'Ambil gambar dari galeri foto',
                    onTap: onGallerySelected,
                    color: Colors.blue,
                  ),

                  const SizedBox(height: AppTheme.spacingSM + 4),

                  // Camera option
                  _buildActionSheetOption(
                    icon: Icons.camera_alt_outlined,
                    title: 'Ambil Foto',
                    subtitle: 'Gunakan kamera untuk mengambil foto',
                    onTap: onCameraSelected,
                    color: Colors.green,
                  ),

                  const SizedBox(height: AppTheme.spacingSM + 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build action sheet option item
  static Widget _buildActionSheetOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        onTap: onTap,
        child: Container(
          padding: AppTheme.actionSheetItemPadding,
          decoration: BoxDecoration(
            color: AppTheme.actionSheetItemBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.grey400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show confirmation dialog with consistent styling
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Ya',
    String cancelText = 'Batal',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey800,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.grey600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: AppTheme.textButtonStyle,
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: isDestructive
                  ? ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                      foregroundColor: Colors.white,
                    )
                  : AppTheme.primaryButtonStyle,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  // Create consistent card widget
  static Widget buildCard({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? elevation,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: elevation != null
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  offset: const Offset(0, 2),
                  blurRadius: elevation,
                ),
              ]
            : AppTheme.shadowSM,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppTheme.spacingLG),
        child: child,
      ),
    );
  }

  // Create section header widget
  static Widget buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? AppTheme.grey600, size: 20),
        const SizedBox(width: AppTheme.spacingSM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Create loading overlay
  static Widget buildLoadingOverlay({
    String? message,
    Color? backgroundColor,
  }) {
    return Container(
      color: backgroundColor ?? AppTheme.overlayBackgroundColor,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            boxShadow: AppTheme.shadowMD,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
              if (message != null) ...[
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.grey700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Create consistent AppBar
  static PreferredSizeWidget buildAppBar({
    required String title,
    List<Widget>? actions,
    Widget? leading,
    bool automaticallyImplyLeading = true,
    bool centerTitle = true,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return AppBar(
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: foregroundColor ?? AppTheme.grey800,
          fontSize: 18,
        ),
      ),
      backgroundColor: backgroundColor ?? Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: AppTheme.grey200,
      iconTheme: IconThemeData(color: foregroundColor ?? AppTheme.grey700),
      elevation: 1,
      centerTitle: centerTitle,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      actions: actions,
    );
  }

  // Create gradient save button for AppBar
  static Widget buildGradientSaveButton({
    required VoidCallback? onPressed,
    bool isLoading = false,
    String text = 'Simpan',
    String loadingText = 'Menyimpan...',
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.save_alt_outlined,
                      color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  isLoading ? loadingText : text,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Enum for snackbar types
enum SnackBarType {
  success,
  error,
  warning,
  info,
}
