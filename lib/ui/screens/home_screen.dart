import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../data/models/activity_entry.dart';
import '../../data/models/food_entry.dart';
import '../../data/models/food_item.dart';
import '../../logic/number_format.dart';
import '../../logic/providers/main_provider.dart';
import '../../logic/widget_bridge.dart';
import '../theme/tokens.dart';
import '../widgets/activity_item_row.dart';
import '../widgets/app_text_field.dart';
import '../widgets/food_item_row.dart';
import '../widgets/goals_summary_card.dart';
import '../widgets/kit/kit.dart';
import '../widgets/weight_card.dart';
import '../widgets/dialogs/add_entry_dialog.dart';
import '../widgets/dialogs/barcode_scanner_dialog.dart';
import '../widgets/dialogs/delete_confirmation_dialog.dart';
import '../widgets/dialogs/edit_activity_dialog.dart';
import '../widgets/dialogs/edit_food_dialog.dart';
import '../widgets/dialogs/food_recall_dialog.dart';
import '../widgets/dialogs/unified_input_dialog.dart';
import 'photo_input_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenHistory;
  final String? pendingWidgetAction;
  final VoidCallback? onWidgetActionHandled;

  const HomeScreen({
    super.key,
    this.onOpenHistory,
    this.pendingWidgetAction,
    this.onWidgetActionHandled,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final _headerDateFormat = DateFormat('EEEE, d. MMMM', 'de_DE');
  static final _shortDateFormat = DateFormat('EEE, d. MMM', 'de_DE');
  static final _thousands = NumberFormat.decimalPattern('de_DE');

  String? _lastHandledWidgetAction;

  @override
  void initState() {
    super.initState();
    _scheduleWidgetAction();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingWidgetAction != oldWidget.pendingWidgetAction) {
      _scheduleWidgetAction();
    }
  }

  void _scheduleWidgetAction() {
    final action = widget.pendingWidgetAction;
    if (action == null || action == _lastHandledWidgetAction) return;
    _lastHandledWidgetAction = action;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onWidgetActionHandled?.call();
      _lastHandledWidgetAction = null;
      switch (action) {
        case WidgetLaunchAction.addText:
          _showUnifiedInputDialog(initialVoiceMode: false);
        case WidgetLaunchAction.addVoice:
          _showUnifiedInputDialog(initialVoiceMode: true);
        case WidgetLaunchAction.addPhoto:
          _openPhotoInput();
      }
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _showAddEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => AddEntryDialog(
        onPhotoSelected: _openPhotoInput,
        onManualSelected: () => _showUnifiedInputDialog(),
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
                  const SizedBox(height: Space.lg),
                  AppTextField.number(
                    controller: amountController,
                    label: isPerUnit ? 'Anzahl' : 'Menge',
                    suffix: unit,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    onSubmitted: (_) => submit(),
                  ),
                  if (factor != null) ...[
                    const SizedBox(height: Space.md),
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
            const SizedBox(height: Space.lg),
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
    final provider = context.read<MainProvider>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoInputScreen(
          onBarcodeScanned: (barcode) {
            provider.fetchFoodInfoByBarcode(barcode);
          },
          onLookupBarcode: provider.lookupBarcodeSilently,
          onBarcodeProductFound: provider.setScannedFoodInfo,
          onPhotoTaken: (imageBytes, description) {
            return provider.addFoodFromImage(imageBytes, description);
          },
        ),
      ),
    );
  }

  void _showUnifiedInputDialog({bool initialVoiceMode = false}) {
    final provider = context.read<MainProvider>();
    showDialog(
      context: context,
      builder: (context) => UnifiedInputDialog(
        initialVoiceMode: initialVoiceMode,
        missingApiKeyMessage: provider.missingApiKeyMessage,
        initialName: provider.entryDraftName,
        initialDescription: provider.entryDraftDescription,
        onDraftChanged: provider.saveEntryDraft,
        onClear: () => provider.saveEntryDraft('', ''),
        onSubmit: (name, description) {
          provider.addUnifiedEntry(name, description);
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = provider.selectedDate;
    final initial = selected.isAfter(today)
        ? today
        : DateTime(selected.year, selected.month, selected.day);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: today,
    );
    if (date != null) {
      provider.changeDate(date);
    }
  }

  Widget _entriesCard(List<Widget> rows) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MainProvider>(
      builder: (context, provider, child) {
        final scannedFoodInfo = provider.scannedFoodInfo;
        if (scannedFoodInfo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || provider.scannedFoodInfo != scannedFoodInfo) return;
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

        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final isToday = _isToday(provider.selectedDate);
        final trailingStyle = textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );

        final foodRows = <Widget>[
          for (final food in provider.foodEntries)
            FoodItemRow(
              food: food,
              onEdit: () => _showEditFoodDialog(food),
              onDelete: () => _showDeleteFoodDialog(food),
            ),
        ];
        final activityRows = <Widget>[
          for (final activity in provider.activityEntries)
            ActivityItemRow(
              activity: activity,
              onEdit: () => _showEditActivityDialog(activity),
              onDelete: () => _showDeleteActivityDialog(activity),
            ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isToday
                  ? 'Heute'
                  : _headerDateFormat.format(provider.selectedDate),
            ),
          ),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Space.screenX,
                  Space.sm,
                  Space.screenX,
                  96,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Vorheriger Tag',
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => _changeDate(-1),
                        ),
                        Expanded(
                          child: Center(
                            child: TextButton(
                              onPressed: _showDatePicker,
                              child: Text(
                                _shortDateFormat.format(provider.selectedDate),
                                style: textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Nächster Tag',
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: isToday ? null : () => _changeDate(1),
                        ),
                      ],
                    ),
                    if (provider.isLoading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: Space.sm),
                      Text(
                        provider.loadingLabel ?? 'Lädt…',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.md),
                    ],
                    GoalsSummaryCard(
                      eatenCalories: provider.totalCalories,
                      calorieBudget: provider.calorieBudget,
                      burnedCalories: provider.totalBurned,
                      activityAddedToBudget:
                          provider.userProfile.eatBackActivityCalories,
                      totalProtein: provider.totalProtein,
                      totalCarbs: provider.totalCarbs,
                      totalFat: provider.totalFat,
                      goals: provider.goals,
                      week: provider.weekStatus,
                      onOpenHistory: widget.onOpenHistory,
                    ),
                    const SizedBox(height: Space.md),
                    WeightCard(
                      weightOnSelectedDate: provider.weightOnSelectedDate,
                      averageThisWeek: provider.weightAverage7Days,
                      averagePreviousWeek:
                          provider.weightAveragePrevious7Days,
                      lowerIsBetter:
                          provider.userProfile.goal.calorieModifier == 0
                          ? null
                          : provider.userProfile.goal.isDeficit,
                      onTap: _showWeightDialog,
                    ),
                    SectionHeader(
                      'Mahlzeiten',
                      trailing: Text(
                        '${_thousands.format(provider.totalCalories)} kcal',
                        style: trailingStyle,
                      ),
                    ),
                    if (foodRows.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.restaurant_outlined,
                          title: 'Noch nichts gegessen',
                          message:
                              'Tippe auf „Eintrag“, um eine Mahlzeit hinzuzufügen.',
                        ),
                      )
                    else
                      _entriesCard(foodRows),
                    SectionHeader(
                      'Aktivitäten',
                      trailing: Text(
                        '-${_thousands.format(provider.totalBurned)} kcal',
                        style: trailingStyle,
                      ),
                    ),
                    if (activityRows.isEmpty)
                      const AppCard(
                        child: EmptyState(
                          icon: Icons.directions_run_outlined,
                          title: 'Keine Aktivitäten',
                          message:
                              'Erfasste Bewegung erscheint hier und wird auf dein Tagesbudget angerechnet.',
                        ),
                      )
                    else
                      _entriesCard(activityRows),
                  ]),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'add_entry_fab',
            onPressed: provider.isLoading ? null : _showAddEntryDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Eintrag'),
          ),
        );
      },
    );
  }
}
