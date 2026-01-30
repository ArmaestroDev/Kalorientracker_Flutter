import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../data/models/ai_analysis_type.dart';
import '../../../logic/providers/main_provider.dart';

class AiAssistantDialog extends StatefulWidget {
  const AiAssistantDialog({super.key});

  @override
  State<AiAssistantDialog> createState() => _AiAssistantDialogState();
}

class _AiAssistantDialogState extends State<AiAssistantDialog> {
  String? _result;
  bool _isLoading = false;

  void _runAnalysis(BuildContext context, AiAnalysisType type) async {
    setState(() {
      _isLoading = true;
      _result = null;
    });

    final provider = context.read<MainProvider>();
    final result = await provider.performAiAnalysis(type);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _result = result;
    });

    if (result == null && provider.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Assistant',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Die KI analysiert deine Daten...'),
                    ],
                  ),
                ),
              )
            else if (_result != null)
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: Markdown(data: _result!)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Neue Analyse wählen'),
                      onPressed: () {
                        setState(() {
                          _result = null;
                        });
                      },
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Wähle eine Option:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildOptionTile(
                        icon: Icons.today,
                        title: 'Tages-Rückblick',
                        subtitle:
                            'Zusammenfassung des heutigen Tages und Empfehlungen.',
                        onTap: () =>
                            _runAnalysis(context, AiAnalysisType.dayReview),
                      ),
                      const SizedBox(height: 12),
                      _buildOptionTile(
                        icon: Icons.restaurant_menu,
                        title: 'Mahlzeit-Vorschlag',
                        subtitle:
                            'Was soll ich als nächstes essen? Basiert auf deinen Zielen.',
                        onTap: () =>
                            _runAnalysis(context, AiAnalysisType.nextMeal),
                      ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        leading: const Icon(Icons.analytics),
                        title: const Text('Langzeit-Analyse'),
                        subtitle: const Text('Woche, Monat oder Jahr'),
                        children: [
                          ListTile(
                            leading: const Icon(Icons.calendar_view_week),
                            title: const Text('Wochen-Rückblick'),
                            onTap: () => _runAnalysis(
                              context,
                              AiAnalysisType.weekReview,
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_view_month),
                            title: const Text('Monats-Rückblick'),
                            onTap: () => _runAnalysis(
                              context,
                              AiAnalysisType.monthReview,
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_month),
                            title: const Text('Jahres-Rückblick'),
                            onTap: () => _runAnalysis(
                              context,
                              AiAnalysisType.yearReview,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
