import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/user_plan.dart';
import '../../logic/providers/main_provider.dart';
import '../theme/tokens.dart';
import '../widgets/app_text_field.dart';
import '../widgets/kit/kit.dart';

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
        if (mounted) AppFeedback.error(context, 'PDF konnte nicht gelesen werden.');
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
        AppFeedback.error(context, '$e');
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
              const SizedBox(height: Space.lg),
              DropdownButtonFormField<PlanType>(
                initialValue: selectedType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Art des Plans'),
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
                const SizedBox(height: Space.md),
                DropdownButtonFormField<PlanType>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Art des Plans'),
                  items: [
                    for (final t in PlanType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
                const SizedBox(height: Space.md),
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

  static IconData _iconFor(PlanType type) => switch (type) {
    PlanType.meal => Icons.restaurant_menu_outlined,
    PlanType.training => Icons.fitness_center_outlined,
    PlanType.combined => Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd.MM.yyyy', 'de_DE');

    return Consumer<MainProvider>(
      builder: (context, provider, _) {
        final plans = provider.plans;

        return Scaffold(
          appBar: AppBar(title: const Text('Ernährungs- & Trainingspläne')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.screenX,
              Space.sm,
              Space.screenX,
              Space.xxl,
            ),
            children: [
              const Notice(
                message:
                    'Aktive Pläne werden bei jeder Coach-Antwort automatisch berücksichtigt.',
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _extracting ? null : _pickPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF hochladen'),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _extracting ? null : () => _openPlanEditor(),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Text eingeben'),
                    ),
                  ),
                ],
              ),
              if (_extracting) ...[
                const SizedBox(height: Space.lg),
                const LinearProgressIndicator(),
                const SizedBox(height: Space.sm),
                Text(
                  'PDF wird ausgelesen …',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: Space.lg),
              if (plans.isEmpty)
                const EmptyState(
                  icon: Icons.description_outlined,
                  title: 'Noch keine Pläne hinterlegt',
                  message:
                      'Lade deinen Ernährungs- oder Trainingsplan als PDF hoch, damit dein Coach sich immer daran orientiert.',
                )
              else
                for (final plan in plans) ...[
                  _PlanCard(
                    plan: plan,
                    icon: _iconFor(plan.type),
                    dateLabel: dateFmt.format(plan.updatedAt),
                    onToggle: () => provider.togglePlanActive(plan),
                    onEdit: () => _openPlanEditor(initialPlan: plan),
                    onDelete: () => _confirmDelete(plan),
                  ),
                  const SizedBox(height: Space.md),
                ],
            ],
          ),
        );
      },
    );
  }
}

enum _PlanAction { edit, delete }

class _PlanCard extends StatelessWidget {
  final UserPlan plan;
  final IconData icon;
  final String dateLabel;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlanCard({
    required this.plan,
    required this.icon,
    required this.dateLabel,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: plan.isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${plan.type.label} · $dateLabel'
                      '${plan.fileName != null ? ' · ${plan.fileName}' : ''}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_PlanAction>(
                tooltip: 'Plan-Aktionen',
                onSelected: (action) => switch (action) {
                  _PlanAction.edit => onEdit(),
                  _PlanAction.delete => onDelete(),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _PlanAction.edit,
                    child: Text('Bearbeiten'),
                  ),
                  PopupMenuItem(
                    value: _PlanAction.delete,
                    child: Text('Löschen'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            plan.content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.isActive ? 'Aktiv' : 'Inaktiv',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Switch(
                value: plan.isActive,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
