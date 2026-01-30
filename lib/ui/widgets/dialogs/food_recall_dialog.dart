import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/providers/main_provider.dart';
import '../../../data/models/food_item.dart';

class FoodRecallDialog extends StatefulWidget {
  final Function(FoodItem) onItemSelected;

  const FoodRecallDialog({super.key, required this.onItemSelected});

  @override
  State<FoodRecallDialog> createState() => _FoodRecallDialogState();
}

class _FoodRecallDialogState extends State<FoodRecallDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentItems();
  }

  Future<void> _loadRecentItems() async {
    setState(() => _isLoading = true);
    final provider = context.read<MainProvider>();
    final items = await provider.getRecentFoodItems();
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _searchItems(String query) async {
    if (query.isEmpty) {
      _loadRecentItems();
      return;
    }
    setState(() => _isLoading = true);
    final provider = context.read<MainProvider>();
    final items = await provider.searchFoodItems(query);
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Verlauf durchsuchen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Suche nach Essen...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _searchItems,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(child: Text('Keine Einträge gefunden'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.caloriesPer100g.toInt()} kcal/100g • ${item.category}',
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () async {
                            // Close the recall dialog FIRST
                            Navigator.of(context).pop();

                            // Then trigger the callback which might open a new dialog
                            // Use a microtask to ensure the first dialog is fully disposed/popped
                            // before the next one tries to show.
                            Future.microtask(() {
                              widget.onItemSelected(item);
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
