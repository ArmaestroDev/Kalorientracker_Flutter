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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onEdit,
        leading: Icon(
          Icons.directions_run,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(activity.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '-${activity.caloriesBurned} kcal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.of(context).success,
                fontWeight: FontWeight.bold,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Bearbeiten'),
                    ],
                  ),
                ),
                const PopupMenuItem(
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
      ),
    );
  }
}
