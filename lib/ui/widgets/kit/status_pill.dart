import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

enum PillTone { neutral, primary, success, warning, danger }

class StatusPill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconData? icon;

  const StatusPill(
    this.label, {
    super.key,
    this.tone = PillTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);

    final Color background;
    final Color foreground;
    switch (tone) {
      case PillTone.neutral:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
      case PillTone.primary:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
      case PillTone.success:
        background = colors.success.withValues(alpha: 0.15);
        foreground = colors.success;
      case PillTone.warning:
        background = colors.warning.withValues(alpha: 0.15);
        foreground = colors.warning;
      case PillTone.danger:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Corner.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: Space.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
