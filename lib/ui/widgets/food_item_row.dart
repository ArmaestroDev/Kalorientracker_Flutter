import 'package:flutter/material.dart';

import '../../data/models/food_entry.dart';
import '../../logic/number_format.dart';

class FoodItemRow extends StatelessWidget {
  final FoodEntry food;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FoodItemRow({
    super.key,
    required this.food,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final amount =
        food.amount != null && food.unit != null && food.unit!.isNotEmpty
        ? '${formatLocalizedNumber(food.amount!)} ${food.unit} · '
        : '';

    return ListTile(
      onTap: onEdit,
      onLongPress: onDelete,
      title: Text(food.name, style: textTheme.titleSmall),
      subtitle: Text(
        '${amount}P ${food.protein} g · K ${food.carbs} g · F ${food.fat} g',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${food.calories} kcal',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
