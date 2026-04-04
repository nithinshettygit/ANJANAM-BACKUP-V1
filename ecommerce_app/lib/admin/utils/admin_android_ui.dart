import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// True on Android native builds only — web and desktop keep full admin chrome.
bool get kAdminAndroidCompactChrome =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

TextStyle adminSectionTitleStyle(ThemeData theme) {
  if (kAdminAndroidCompactChrome) {
    return theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          height: 1.2,
        ) ??
        const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2);
  }
  return const TextStyle(fontSize: 22, fontWeight: FontWeight.w700);
}

double get adminChromeGapAfterTitle => kAdminAndroidCompactChrome ? 4 : 8;

double get adminChromeGapBeforeList => kAdminAndroidCompactChrome ? 6 : 12;

EdgeInsets get adminFilterCardPadding => kAdminAndroidCompactChrome
    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
    : const EdgeInsets.all(12);

/// Dense icon control for Android admin toolbars (does not affect web).
Widget adminAndroidToolbarIconButton({
  required IconData icon,
  required String tooltip,
  required VoidCallback onPressed,
  Color? color,
}) {
  return IconButton(
    tooltip: tooltip,
    icon: Icon(icon, size: 22, color: color),
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.all(4),
    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    style: IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: color,
    ),
    onPressed: onPressed,
  );
}
