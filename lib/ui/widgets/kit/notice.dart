import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

enum NoticeTone { info, success, error }

class Notice extends StatelessWidget {
  final String message;
  final NoticeTone tone;
  final String? title;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  const Notice({
    super.key,
    required this.message,
    this.tone = NoticeTone.info,
    this.title,
    this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);

    final Color background;
    final Color foreground;
    final Color iconColor;
    final IconData icon;
    switch (tone) {
      case NoticeTone.info:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        iconColor = scheme.onSecondaryContainer;
        icon = Icons.info_outline;
      case NoticeTone.success:
        background = colors.success.withValues(alpha: 0.15);
        foreground = scheme.onSurface;
        iconColor = colors.success;
        icon = Icons.check_circle_outline;
      case NoticeTone.error:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        iconColor = scheme.onErrorContainer;
        icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Corner.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: Space.xxs),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: Space.xs),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
              color: foreground,
              tooltip: 'Schließen',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
