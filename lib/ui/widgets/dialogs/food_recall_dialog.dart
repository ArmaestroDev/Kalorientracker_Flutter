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

class _FoodRecallDialogState extends State<FoodRecallDialog>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _items = [];
  bool _isLoading = true;
  TabController? _tabController;

  // Category Navigation State
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadRecentItems() async {
    setState(() => _isLoading = true);
    final provider = context.read<MainProvider>();
    final items = await provider.getRecentFoodItems();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchItems(String query) async {
    if (query.isEmpty) {
      _loadRecentItems();
      return;
    }
    setState(() => _isLoading = true);
    final provider = context.read<MainProvider>();
    final items = await provider.searchFoodItems(query);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
        // Reset category selection on search to avoid confusion?
        // Or keep it? Let's keep it simple for now.
      });
    }
  }

  List<String> get _uniqueCategories {
    return _items.map((e) => e.category).toSet().toList()..sort();
  }

  Widget _buildHistoryList(List<FoodItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('Keine Einträge gefunden'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          title: Text(item.name),
          subtitle: Text(
            '${item.caloriesPer100g.toInt()} kcal/100g • ${item.category}',
          ),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () {
            Navigator.of(context).pop();
            Future.microtask(() {
              widget.onItemSelected(item);
            });
          },
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    if (_selectedCategory != null) {
      // Drill-down view: Items in selected category
      final categoryItems = _items
          .where((i) => i.category == _selectedCategory)
          .toList();
      return Column(
        children: [
          ListTile(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                });
              },
            ),
            title: Text(
              _selectedCategory!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildHistoryList(categoryItems)),
        ],
      );
    } else {
      // Root view: List of categories
      final categories = _uniqueCategories;
      if (categories.isEmpty) {
        return const Center(child: Text('Keine Kategorien verfügbar'));
      }
      return ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final count = _items.where((i) => i.category == category).length;
          return ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(category),
            trailing: Chip(label: Text(count.toString())),
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
          );
        },
      );
    }
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
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: const [
                        Tab(text: 'Verlauf'),
                        Tab(text: 'Kategorien'),
                      ],
                      onTap: (index) {
                        // Optional: reset category selection when switching tabs?
                        // setState(() => _selectedCategory = null);
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildHistoryList(_items),
                          _buildCategoriesTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
