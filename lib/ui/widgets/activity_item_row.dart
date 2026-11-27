import 'package:flutter/material.dart';

import '../../data/models/activity_entry.dart';
import '../theme/app_theme.dart';

class ActivityItemRow extends StatelessWidget {
  final ActivityEntry activity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ActivityItemRow({
    super.key,
    required this.activity,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: onEdit,
      onLongPress: onDelete,
      title: Text(activity.name, style: textTheme.titleSmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '-${activity.caloriesBurned} kcal',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.of(context).success,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mehr',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Bearbeiten'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Löschen'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
