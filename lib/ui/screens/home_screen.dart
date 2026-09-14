import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../logic/providers/main_provider.dart';
import '../../data/models/food_entry.dart';
import '../../data/models/activity_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/goals_summary_card.dart';
import '../widgets/weight_card.dart';
import '../widgets/food_item_row.dart';
import '../widgets/activity_item_row.dart';
import '../widgets/dialogs/add_entry_dialog.dart';
import '../widgets/dialogs/unified_input_dialog.dart';
import '../widgets/dialogs/edit_food_dialog.dart';
import '../widgets/dialogs/edit_activity_dialog.dart';
import '../widgets/dialogs/barcode_scanner_dialog.dart';
import '../widgets/dialogs/delete_confirmation_dialog.dart';
import '../widgets/dialogs/food_recall_dialog.dart';
import '../../data/models/food_item.dart';
import '../../logic/number_format.dart';
import '../widgets/app_text_field.dart';
import 'assistant_screen.dart';
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
        onHistorySelected: _showFoodRecallDialog,
      ),
    );
  }

  void _showFoodRecallDialog() {
    showDialog(
      context: context,
      builder: (context) => FoodRecallDialog(
        onItemSelected: (FoodItem item) {
          _showSmartScalingDialog(item);
        },
      ),
    );
  }

  void _showSmartScalingDialog(FoodItem item) {
    final provider = context.read<MainProvider>();
    final unit = item.defaultUnit.isEmpty ? 'g' : item.defaultUnit;
    final isPerUnit = unit == 'Portion' || unit == 'Stk';
    final amountController = TextEditingController(text: isPerUnit ? '1' : '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final amount = parseLocalizedNumber(amountController.text);
            final factor = amount == null || amount <= 0
                ? null
                : (isPerUnit ? amount : amount / 100);

            void submit() {
              if (factor == null) return;
              provider.addFoodItemFromHistory(item, amount!);
              Navigator.of(dialogContext).pop();
            }

            return AlertDialog(
              title: Text(item.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isPerUnit
                        ? '${item.caloriesPer100g.round()} kcal pro ${unit == 'Stk' ? 'Stück' : 'Portion'}'
                        : '${item.caloriesPer100g.round()} kcal pro 100 $unit',
                  ),
                  const SizedBox(height: 16),
                  AppTextField.number(
                    controller: amountController,
                    label: isPerUnit ? 'Anzahl' : 'Menge',
                    suffix: unit,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    onSubmitted: (_) => submit(),
                  ),
                  if (factor != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${(item.caloriesPer100g * factor).round()} kcal · '
                      'P ${(item.proteinPer100g * factor).round()} g · '
                      'K ${(item.carbsPer100g * factor).round()} g · '
                      'F ${(item.fatPer100g * factor).round()} g',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: factor == null ? null : submit,
                  child: const Text('Hinzufügen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWeightDialog() {
    final provider = context.read<MainProvider>();
    final existing = provider.weightOnSelectedDate;
    final controller = TextEditingController(
      text: existing?.toStringAsFixed(1).replaceAll('.', ',') ?? '',
    );

    void submit(BuildContext dialogContext) {
      final value = parseLocalizedNumber(controller.text);
      if (value != null && value > 20 && value < 400) {
        provider.saveWeight(value);
        Navigator.of(dialogContext).pop();
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gewicht eintragen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Am besten morgens nach dem Toilettengang wiegen. '
              'Entscheidend ist der 7-Tage-Durchschnitt.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            AppTextField.number(
              controller: controller,
              label: 'Gewicht',
              suffix: 'kg',
              autofocus: true,
              onSubmitted: (_) => submit(dialogContext),
            ),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                provider.deleteWeight();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Löschen'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => submit(dialogContext),
            child: const Text('Speichern'),
          ),
        ],
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
    final current = provider.selectedDate;
    final newDate = DateTime(current.year, current.month, current.day + days);
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
        final scannedFoodInfo = provider.scannedFoodInfo;
        if (scannedFoodInfo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (provider.scannedFoodInfo != scannedFoodInfo) return;
            provider.clearScannedFoodInfo();
            showDialog(
              context: context,
              builder: (ctx) => BarcodeScannerResultDialog(
                foodInfo: scannedFoodInfo,
                onConfirm: (grams) {
                  provider.addScannedFoodItem(scannedFoodInfo, grams);
                },
                onDismiss: () {},
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
                        eatenCalories: provider.totalCalories,
                        calorieBudget: provider.calorieBudget,
                        burnedCalories: provider.totalBurned,
                        activityAddedToBudget:
                            provider.userProfile.eatBackActivityCalories,
                        totalProtein: provider.totalProtein,
                        totalCarbs: provider.totalCarbs,
                        totalFat: provider.totalFat,
                        goals: provider.goals,
                        weekCalorieBalance: provider.weekCalorieBalance,
                        weekLoggedDays: provider.weekLoggedDays,
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: WeightCard(
                        weightOnSelectedDate: provider.weightOnSelectedDate,
                        averageThisWeek: provider.weightAverage7Days,
                        averagePreviousWeek:
                            provider.weightAveragePrevious7Days,
                        lowerIsBetter: provider.userProfile.goal.isDeficit,
                        onTap: _showWeightDialog,
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
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton(
                  heroTag: 'ai_assistant_fab',
                  tooltip: 'Dein Coach',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AssistantScreen(),
                      ),
                    );
                  },
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onTertiaryContainer,
                  child: const Icon(Icons.auto_awesome_outlined),
                ),
                FloatingActionButton(
                  heroTag: 'add_entry_fab',
                  onPressed: _showAddEntryDialog,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
