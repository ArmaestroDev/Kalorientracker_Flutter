import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/providers/main_provider.dart';
import '../../../data/models/food_item.dart';
import '../app_text_field.dart';

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
  List<String> _categories = [];
  List<FoodItem> _categoryItems = [];
  bool _isLoading = true;
  bool _loadingCategory = false;
  TabController? _tabController;
  Timer? _searchDebounce;
  int _loadToken = 0;

  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitial();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final token = ++_loadToken;
    setState(() => _isLoading = true);
    final provider = context.read<MainProvider>();
    final items = await provider.getRecentFoodItems();
    final categories = await provider.getFoodCategories();
    if (mounted && token == _loadToken) {
      setState(() {
        _items = items;
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _selectedCategory = null);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      _searchItems(query);
    });
  }

  Future<void> _searchItems(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      await _loadInitial();
      return;
    }
    final token = ++_loadToken;
    setState(() => _isLoading = true);
    final provider = context.read<MainProvider>();
    final items = await provider.searchFoodItems(trimmed);
    if (mounted && token == _loadToken) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _openCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _loadingCategory = true;
    });
    final items = await context.read<MainProvider>().getFoodItemsByCategory(
      category,
    );
    if (mounted && _selectedCategory == category) {
      setState(() {
        _categoryItems = items;
        _loadingCategory = false;
      });
    }
  }

  Future<void> _deleteHistoryItem(FoodItem item) async {
    final provider = context.read<MainProvider>();
    await provider.deleteFoodItemFromHistory(item.id);
    if (!mounted) return;
    setState(() {
      _items.removeWhere((i) => i.id == item.id);
      _categoryItems.removeWhere((i) => i.id == item.id);
    });
    final categories = await provider.getFoodCategories();
    if (mounted) {
      setState(() => _categories = categories);
    }
  }

  static String _unitLabel(FoodItem item) => switch (item.defaultUnit) {
    'Portion' => 'pro Portion',
    'Stk' => 'pro Stück',
    'ml' => 'pro 100 ml',
    _ => 'pro 100 g',
  };

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
            '${item.caloriesPer100g.round()} kcal ${_unitLabel(item)} · ${item.category}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Aus Verlauf entfernen',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _deleteHistoryItem(item),
              ),
              const Icon(Icons.add_circle_outline),
            ],
          ),
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
      final query = _searchController.text.trim().toLowerCase();
      final filtered = query.isEmpty
          ? _categoryItems
          : _categoryItems
                .where((i) => i.name.toLowerCase().contains(query))
                .toList();
      return Column(
        children: [
          ListTile(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                  _categoryItems = [];
                });
              },
            ),
            title: Text(
              _selectedCategory!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingCategory
                ? const Center(child: CircularProgressIndicator())
                : _buildHistoryList(filtered),
          ),
        ],
      );
    }

    final categories = _searchController.text.trim().isEmpty
        ? _categories
        : (_items.map((e) => e.category).toSet().toList()..sort());
    if (categories.isEmpty) {
      return const Center(child: Text('Keine Kategorien verfügbar'));
    }
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return ListTile(
          leading: const Icon(Icons.folder_open),
          title: Text(category),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openCategory(category),
        );
      },
    );
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
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _searchController,
                    hint: 'Suche nach Essen …',
                    onChanged: _onSearchChanged,
                  ),
                ),
                ListenableBuilder(
                  listenable: _searchController,
                  builder: (context, _) {
                    if (_searchController.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      tooltip: 'Suche leeren',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    );
                  },
                ),
              ],
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
                      tabs: const [
                        Tab(text: 'Verlauf'),
                        Tab(text: 'Kategorien'),
                      ],
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
