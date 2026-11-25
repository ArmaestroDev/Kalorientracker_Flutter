import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/user_plan.dart';
import '../../logic/providers/main_provider.dart';
import '../widgets/app_text_field.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _extracting = false;

  Future<void> _pickPdf() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (files.isEmpty || !mounted) return;
      final file = files.single;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || !mounted) {
        if (mounted) _showMessage('PDF konnte nicht gelesen werden.');
        return;
      }

      final defaultTitle = file.name.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final selectedType = await _askPlanType(defaultTitle);
      if (selectedType == null || !mounted) return;

      setState(() => _extracting = true);
      final provider = context.read<MainProvider>();
      final extracted = await provider.extractPlanFromPdfBytes(
        bytes,
        selectedType.type,
        file.name,
      );
      if (!mounted) return;
      setState(() => _extracting = false);

      await _openPlanEditor(
        initialPlan: UserPlan(
          type: selectedType.type,
          title: selectedType.title,
          fileName: file.name,
          content: extracted,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _extracting = false);
        _showMessage('$e');
      }
    }
  }

  Future<({PlanType type, String title})?> _askPlanType(
    String initialTitle,
  ) async {
    final titleController = TextEditingController(text: initialTitle);
    var selectedType = PlanType.combined;

    final result = await showDialog<({PlanType type, String title})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('PDF-Plan zuordnen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: titleController,
                label: 'Titel',
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PlanType>(
                initialValue: selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Art des Plans',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in PlanType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => selectedType = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.of(
                  dialogContext,
                ).pop((type: selectedType, title: title));
              },
              child: const Text('Auslesen'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    return result;
  }

  Future<void> _openPlanEditor({UserPlan? initialPlan}) async {
    final isNew = initialPlan == null || initialPlan.fileName != null;
    final titleController = TextEditingController(
      text: initialPlan?.title ?? '',
    );
    final contentController = TextEditingController(
      text: initialPlan?.content ?? '',
    );
    var type = initialPlan?.type ?? PlanType.meal;
    var submitted = false;

    final saved = await showDialog<UserPlan>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            initialPlan == null
                ? 'Neuer Plan'
                : isNew
                ? 'Ausgelesenen Plan prüfen'
                : 'Plan bearbeiten',
          ),
          scrollable: true,
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: titleController,
                  label: 'Titel',
                  hint: 'z. B. Aufbauplan Herbst',
                  textCapitalization: TextCapitalization.sentences,
                  errorText: submitted && titleController.text.trim().isEmpty
                      ? 'Pflichtfeld'
                      : null,
                  onChanged: (_) {
                    if (submitted) setDialogState(() {});
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PlanType>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Art des Plans',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final t in PlanType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: contentController,
                  label: 'Inhalt des Plans',
                  hint: 'Mahlzeiten, Makros, Trainingstage, Übungen …',
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 6,
                  maxLines: 14,
                  errorText: submitted && contentController.text.trim().isEmpty
                      ? 'Pflichtfeld'
                      : null,
                  onChanged: (_) {
                    if (submitted) setDialogState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                setDialogState(() => submitted = true);
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isEmpty || content.isEmpty) return;
                final plan = (initialPlan ?? UserPlan(
                  type: type,
                  title: title,
                  content: content,
                )).copyWith(
                  type: type,
                  title: title,
                  content: content,
                );
                Navigator.of(dialogContext).pop(plan);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    contentController.dispose();
    if (saved != null && mounted) {
      await context.read<MainProvider>().savePlan(saved);
    }
  }

  Future<void> _confirmDelete(UserPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Plan löschen?'),
        content: Text('„${plan.title}“ wird dauerhaft entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<MainProvider>().deletePlan(plan.id);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static IconData _iconFor(PlanType type) => switch (type) {
    PlanType.meal => Icons.restaurant_menu,
    PlanType.training => Icons.fitness_center,
    PlanType.combined => Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat('dd.MM.yyyy', 'de_DE');

    return Consumer<MainProvider>(
      builder: (context, provider, _) {
        final plans = provider.plans;

        return Scaffold(
          appBar: AppBar(title: const Text('Ernährungs- & Trainingspläne')),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Card(
                    color: colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Aktive Pläne werden bei jeder Coach-Antwort automatisch berücksichtigt.',
                              style: TextStyle(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _extracting ? null : _pickPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF hochladen'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _extracting
                              ? null
                              : () => _openPlanEditor(),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Text eingeben'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (plans.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Noch keine Pläne hinterlegt',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lade deinen Ernährungs- oder Trainingsplan als PDF hoch, damit dein Coach sich immer daran orientiert.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final plan in plans)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _iconFor(plan.type),
                                    color: plan.isActive
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan.title,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          '${plan.type.label} · ${dateFmt.format(plan.updatedAt)}'
                                          '${plan.fileName != null ? ' · ${plan.fileName}' : ''}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: plan.isActive,
                                    onChanged: (_) =>
                                        provider.togglePlanActive(plan),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                plan.content,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () =>
                                        _openPlanEditor(initialPlan: plan),
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text('Bearbeiten'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _confirmDelete(plan),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    label: const Text('Löschen'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
              if (_extracting)
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('PDF wird ausgelesen …'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
