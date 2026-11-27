import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/food_item.dart';
import '../../../logic/providers/main_provider.dart';
import '../../theme/tokens.dart';
import '../kit/kit.dart';

class FoodRecallDialog extends StatefulWidget {
  final Function(FoodItem) onItemSelected;

  const FoodRecallDialog({super.key, required this.onItemSelected});

  @override
  State<FoodRecallDialog> createState() => _FoodRecallDialogState();
}

class _FoodRecallDialogState extends State<FoodRecallDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _items = [];
  List<String> _categories = [];
  bool _isLoading = true;
  Timer? _searchDebounce;
  int _loadToken = 0;
  String? _selectedCategory;

  String get _query => _searchController.text.trim();

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await context.read<MainProvider>().getFoodCategories();
    if (mounted) setState(() => _categories = categories);
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    final query = _query;
    final category = _selectedCategory;
    setState(() => _isLoading = true);
    final provider = context.read<MainProvider>();

    List<FoodItem> items;
    if (query.isNotEmpty) {
      items = await provider.searchFoodItems(query);
      if (category != null) {
        items = items.where((item) => item.category == category).toList();
      }
    } else if (category != null) {
      items = await provider.getFoodItemsByCategory(category);
    } else {
      items = await provider.getRecentFoodItems();
    }

    if (mounted && token == _loadToken) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), _load);
    setState(() {});
  }

  void _selectCategory(String? category) {
    _searchDebounce?.cancel();
    setState(() => _selectedCategory = category);
    _load();
  }

  Future<void> _deleteHistoryItem(FoodItem item) async {
    await context.read<MainProvider>().deleteFoodItemFromHistory(item.id);
    if (!mounted) return;
    setState(() => _items.removeWhere((i) => i.id == item.id));
    await _loadCategories();
  }

  void _choose(FoodItem item) {
    Navigator.of(context).pop();
    Future.microtask(() => widget.onItemSelected(item));
  }

  static String _unitLabel(FoodItem item) => switch (item.defaultUnit) {
    'Portion' => 'pro Portion',
    'Stk' => 'pro Stück',
    'ml' => 'pro 100 ml',
    _ => 'pro 100 g',
  };

  Widget _buildBody() {
    if (_isLoading) return const LoadingState();

    if (_items.isEmpty) {
      final title = _query.isNotEmpty
          ? 'Keine Einträge gefunden'
          : _selectedCategory != null
          ? 'Keine Einträge in dieser Kategorie'
          : 'Noch nichts gespeichert';
      return EmptyState(icon: Icons.history_rounded, title: title);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
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
              Icon(
                Icons.add_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          onTap: () => _choose(item),
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Alle'),
            selected: _selectedCategory == null,
            onSelected: (_) => _selectCategory(null),
          ),
          for (final category in _categories) ...[
            const SizedBox(width: Space.sm),
            FilterChip(
              label: Text(category),
              selected: _selectedCategory == category,
              onSelected: (selected) =>
                  _selectCategory(selected ? category : null),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Verlauf durchsuchen',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Suche nach Essen …',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Suche leeren',
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ),
              _buildCategoryChips(),
              const SizedBox(height: Space.sm),
              Flexible(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }
}
