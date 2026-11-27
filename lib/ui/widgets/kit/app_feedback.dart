import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class AppFeedback {
  const AppFeedback._();

  static void error(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      message: message,
      icon: Icons.error_outline,
      duration: const Duration(seconds: 8),
      backgroundColor: scheme.errorContainer,
      foregroundColor: scheme.onErrorContainer,
      showCloseIcon: true,
    );
  }

  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      duration: const Duration(seconds: 3),
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline,
      duration: const Duration(seconds: 4),
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Duration duration,
    Color? backgroundColor,
    Color? foregroundColor,
    bool showCloseIcon = false,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final foreground =
        foregroundColor ?? Theme.of(context).colorScheme.onInverseSurface;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        showCloseIcon: showCloseIcon,
        closeIconColor: foregroundColor,
        content: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                message,
                style: foregroundColor == null
                    ? null
                    : TextStyle(color: foregroundColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
