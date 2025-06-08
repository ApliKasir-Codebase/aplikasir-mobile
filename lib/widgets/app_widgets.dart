// lib/widgets/app_widgets.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Global App Scaffold dengan background yang konsisten
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  const AppScaffold({
    Key? key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppTheme.backgroundColor,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

/// Global App Bar dengan styling yang konsisten
class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool centerTitle;

  const AppBarWidget({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 1,
    this.centerTitle = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: AppTheme.headingSmall.copyWith(
          color: foregroundColor ?? AppTheme.grey800,
        ),
      ),
      backgroundColor: backgroundColor ?? AppTheme.surfaceColor,
      surfaceTintColor: backgroundColor ?? AppTheme.surfaceColor,
      shadowColor: AppTheme.grey200,
      iconTheme: IconThemeData(color: foregroundColor ?? AppTheme.grey700),
      elevation: elevation,
      centerTitle: centerTitle,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Global Action Sheet untuk memilih sumber gambar
class ImageSourceActionSheet {
  static void show({
    required BuildContext context,
    required VoidCallback onGalleryTap,
    required VoidCallback onCameraTap,
    String title = 'Pilih Sumber Gambar',
    String galleryTitle = 'Pilih dari Galeri',
    String gallerySubtitle = 'Ambil gambar dari galeri foto',
    String cameraTitle = 'Ambil Foto',
    String cameraSubtitle = 'Gunakan kamera untuk mengambil foto',
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXXL)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.grey300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Title
                  Text(
                    title,
                    style: AppTheme.headingSmall,
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Gallery option
                  _ImageSourceOption(
                    icon: Icons.photo_library_outlined,
                    title: galleryTitle,
                    subtitle: gallerySubtitle,
                    onTap: onGalleryTap,
                    color: Colors.blue,
                  ),

                  const SizedBox(height: AppTheme.spacingMD),

                  // Camera option
                  _ImageSourceOption(
                    icon: Icons.camera_alt_outlined,
                    title: cameraTitle,
                    subtitle: cameraSubtitle,
                    onTap: onCameraTap,
                    color: Colors.green,
                  ),

                  const SizedBox(height: AppTheme.spacingMD),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _ImageSourceOption({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.grey200),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTheme.bodySmall),
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
}

/// Global Card Widget dengan styling yang konsisten
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const AppCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacingLG),
    this.margin,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppTheme.surfaceColor,
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: elevation != null
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  offset: Offset(0, elevation! / 2),
                  blurRadius: elevation! * 2,
                )
              ]
            : AppTheme.shadowSM,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              borderRadius ?? BorderRadius.circular(AppTheme.radiusLG),
          onTap: onTap,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// Global Section Header Widget
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final String? subtitle;

  const SectionHeader({
    Key? key,
    required this.title,
    this.icon,
    this.trailing,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppTheme.grey600, size: 20),
          const SizedBox(width: AppTheme.spacingSM),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.bodyLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Global Loading Widget
class AppLoading extends StatelessWidget {
  final String? message;
  final Color? color;

  const AppLoading({
    Key? key,
    this.message,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: color ?? AppTheme.primaryColor,
          ),
          if (message != null) ...[
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              message!,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Global Empty State Widget
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const AppEmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppTheme.grey400,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(title,
                style: AppTheme.headingMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingSM),
            Text(subtitle,
                style: AppTheme.bodyMedium, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: AppTheme.spacingLG),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Global Snackbar Helper
class AppSnackbar {
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message,
      Icons.check_circle_outline,
      AppTheme.successColor,
      duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _showSnackbar(
      context,
      message,
      Icons.error_outline,
      AppTheme.errorColor,
      duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showSnackbar(
      context,
      message,
      Icons.info_outline,
      AppTheme.infoColor,
      duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message,
      Icons.warning_outlined,
      AppTheme.warningColor,
      duration,
    );
  }

  static void _showSnackbar(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
    Duration duration,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        margin: const EdgeInsets.all(AppTheme.spacingMD),
        duration: duration,
      ),
    );
  }
}
