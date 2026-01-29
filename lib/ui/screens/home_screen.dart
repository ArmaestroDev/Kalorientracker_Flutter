import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../logic/providers/main_provider.dart';
import '../../data/models/food_entry.dart';
import '../../data/models/activity_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/goals_summary_card.dart';
import '../widgets/food_item_row.dart';
import '../widgets/activity_item_row.dart';
import '../widgets/dialogs/add_entry_dialog.dart';
import '../widgets/dialogs/unified_input_dialog.dart';
import '../widgets/dialogs/edit_food_dialog.dart';
import '../widgets/dialogs/edit_activity_dialog.dart';
import '../widgets/dialogs/barcode_scanner_dialog.dart';
import '../widgets/dialogs/delete_confirmation_dialog.dart';
import 'profile_screen.dart';
import 'photo_input_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MainProvider>().loadInitialData();
    });
  }

  void _showAddEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => AddEntryDialog(
        onPhotoSelected: _openPhotoInput,
        onManualSelected: _showUnifiedInputDialog,
      ),
    );
  }

  void _openPhotoInput() {
    // Capture provider reference BEFORE navigation to avoid deactivated context error
    final provider = context.read<MainProvider>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoInputScreen(
          onBarcodeScanned: (barcode) {
            provider.fetchFoodInfoByBarcode(barcode);
          },
          onPhotoTaken: (imageBytes, description) {
            provider.addFoodFromImage(imageBytes, description);
          },
        ),
      ),
    );
  }

  void _showUnifiedInputDialog() {
    showDialog(
      context: context,
      builder: (context) => UnifiedInputDialog(
        onSubmit: (name, description) {
          context.read<MainProvider>().addUnifiedEntry(name, description);
        },
      ),
    );
  }

  void _showEditFoodDialog(FoodEntry food) {
    showDialog(
      context: context,
      builder: (context) => EditFoodDialog(
        foodEntry: food,
        onSaveManual: (updated) {
          context.read<MainProvider>().updateFoodItemManual(updated);
        },
        onRecalculate: (entry) {
          context.read<MainProvider>().reFetchFoodItem(entry);
        },
      ),
    );
  }

  void _showEditActivityDialog(ActivityEntry activity) {
    showDialog(
      context: context,
      builder: (context) => EditActivityDialog(
        activityEntry: activity,
        onSaveManual: (updated) {
          context.read<MainProvider>().updateActivityItemManual(updated);
        },
        onRecalculate: (entry) {
          context.read<MainProvider>().reFetchActivityItem(entry);
        },
      ),
    );
  }

  void _showDeleteFoodDialog(FoodEntry food) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        itemName: food.name,
        onConfirm: () {
          context.read<MainProvider>().deleteFoodItem(food);
        },
      ),
    );
  }

  void _showDeleteActivityDialog(ActivityEntry activity) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        itemName: activity.name,
        onConfirm: () {
          context.read<MainProvider>().deleteActivityItem(activity);
        },
      ),
    );
  }

  void _changeDate(int days) {
    final provider = context.read<MainProvider>();
    final newDate = provider.selectedDate.add(Duration(days: days));
    provider.changeDate(newDate);
  }

  Future<void> _showDatePicker() async {
    final provider = context.read<MainProvider>();
    final date = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      provider.changeDate(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MainProvider>(
      builder: (context, provider, child) {
        // Show barcode scanner dialog when scanned food info is available
        if (provider.scannedFoodInfo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (ctx) => BarcodeScannerResultDialog(
                foodInfo: provider.scannedFoodInfo!,
                onConfirm: (grams) {
                  provider.addScannedFoodItem(provider.scannedFoodInfo!, grams);
                  provider.clearScannedFoodInfo();
                },
                onDismiss: () {
                  provider.clearScannedFoodInfo();
                },
              ),
            );
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Kalorientracker'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.palette),
                onSelected: (theme) => provider.changeTheme(theme),
                itemBuilder: (context) => AppTheme.themes.keys
                    .map(
                      (theme) =>
                          PopupMenuItem(value: theme, child: Text(theme)),
                    )
                    .toList(),
              ),
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        initialProfile: provider.userProfile,
                        onSave: (profile) {
                          provider.saveUserProfileAndRecalculateGoals(profile);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Date Navigation Header
                  SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new),
                              onPressed: () => _changeDate(-1),
                            ),
                            GestureDetector(
                              onTap: _showDatePicker,
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat.yMMMMd(
                                      'de_DE',
                                    ).format(provider.selectedDate),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: () => _changeDate(1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Goals Summary Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GoalsSummaryCard(
                        netCalories: provider.netCalories,
                        totalProtein: provider.totalProtein,
                        totalCarbs: provider.totalCarbs,
                        totalFat: provider.totalFat,
                        goals: provider.goals,
                      ),
                    ),
                  ),

                  // Food Entries Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.restaurant, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Mahlzeiten',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${provider.totalCalories} kcal',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (provider.foodEntries.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('Noch keine Mahlzeiten hinzugefügt'),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final food = provider.foodEntries[index];
                        return FoodItemRow(
                          food: food,
                          onEdit: () => _showEditFoodDialog(food),
                          onDelete: () => _showDeleteFoodDialog(food),
                        );
                      }, childCount: provider.foodEntries.length),
                    ),

                  // Activity Entries Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_run, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Aktivitäten',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '-${provider.totalBurned} kcal',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (provider.activityEntries.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('Noch keine Aktivitäten hinzugefügt'),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final activity = provider.activityEntries[index];
                        return ActivityItemRow(
                          activity: activity,
                          onEdit: () => _showEditActivityDialog(activity),
                          onDelete: () => _showDeleteActivityDialog(activity),
                        );
                      }, childCount: provider.activityEntries.length),
                    ),

                  // Bottom padding for FAB
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),

              // Loading indicator
              if (provider.isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),

              // Error snackbar
              if (provider.errorMessage != null)
                Positioned(
                  bottom: 100,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: provider.dismissError,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddEntryDialog,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
