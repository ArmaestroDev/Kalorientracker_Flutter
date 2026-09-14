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
    final amount = food.amount != null && food.unit != null
        ? '${formatLocalizedNumber(food.amount!)} ${food.unit} · '
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onEdit,
        title: Text(food.name),
        subtitle: Text(
          '${amount}P ${food.protein} g · K ${food.carbs} g · F ${food.fat} g',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${food.calories} kcal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
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
