import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../../data/models/chat_message.dart';
import '../../logic/providers/main_provider.dart';
import '../widgets/app_text_field.dart';

class _QuickAction {
  final IconData icon;
  final String label;
  final String prompt;

  const _QuickAction(this.icon, this.label, this.prompt);
}

/// Personal coach: a chat that always knows the user's profile, goals and log
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;

  static const _quickActions = [
    _QuickAction(
      Icons.restaurant_menu,
      'Was soll ich jetzt essen?',
      'Was soll ich als Nächstes essen? Schlag mir 2–3 konkrete Optionen vor, die in mein restliches Budget und zu meinem Proteinziel passen und zu meinem Alltag passen. Nenne jeweils ungefähre kcal und Protein.',
    ),
    _QuickAction(
      Icons.today,
      'Tagesrückblick',
      'Gib mir einen kurzen Rückblick auf diesen Tag: Wie stehe ich bei Kalorien und Protein, was lief gut und was mache ich beim nächsten Mal besser?',
    ),
    _QuickAction(
      Icons.nightlight_round,
      'Hunger am Abend',
      'Ich habe gerade Hunger. Was kann ich jetzt noch essen, ohne mein Tagesbudget zu sprengen? Sättigend und eiweißreich, bitte mit Mengen.',
    ),
    _QuickAction(
      Icons.calendar_view_week,
      'Wochenrückblick',
      'Analysiere meine letzten 7 Tage: durchschnittliche Kalorien und Protein im Vergleich zu meinen Zielen, Muster (z. B. Wochenende, Abende), Gewichtstrend und die 3 wichtigsten Stellschrauben für nächste Woche.',
    ),
    _QuickAction(
      Icons.calendar_month,
      'Monatsrückblick',
      'Analysiere meine letzten 30 Tage: Bin ich auf Kurs zu meinem Ziel? Was sind wiederkehrende Muster, wie konsequent logge ich, und was sollte ich ändern?',
    ),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(MainProvider provider, String text, {String? displayText}) {
    if (text.trim().isEmpty || provider.assistantBusy) return;
    if (displayText == null) _inputController.clear();
    provider.sendAssistantMessage(text, displayText: displayText);
  }

  void _scrollToBottomIfNeeded(int messageCount) {
    if (messageCount == _lastMessageCount) return;
    _lastMessageCount = messageCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _confirmClear(MainProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unterhaltung löschen?'),
        content: const Text(
          'Der Verlauf mit deinem Coach wird gelöscht. Deine Einträge bleiben erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) provider.clearAssistantChat();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MainProvider>(
      builder: (context, provider, _) {
        final messages = provider.assistantMessages;
        final itemCount = messages.length + (provider.assistantBusy ? 1 : 0);
        _scrollToBottomIfNeeded(itemCount);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dein Coach'),
            actions: [
              if (messages.isNotEmpty)
                IconButton(
                  tooltip: 'Unterhaltung löschen',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: provider.assistantBusy
                      ? null
                      : () => _confirmClear(provider),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty && !provider.assistantBusy
                      ? _buildIntro(provider)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            if (index >= messages.length) {
                              return const _TypingBubble();
                            }
                            final message = messages[index];
                            final isLast = index == messages.length - 1;
                            return _MessageBubble(
                              message: message,
                              onRetry: message.isError && isLast
                                  ? provider.retryAssistant
                                  : null,
                            );
                          },
                        ),
                ),
                if (messages.isNotEmpty) _buildQuickActionRow(provider),
                _buildInputBar(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntro(MainProvider provider) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final profile = provider.userProfile;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(Icons.auto_awesome, size: 40, color: colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          'Hi! Ich kenne dein Profil, deine Ziele und dein Ernährungstagebuch.',
          style: textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Frag mich alles rund um Essen, Training und deine Fortschritte.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (provider.missingApiKeyMessage != null || profile.aboutMe.isEmpty)
          Card(
            margin: const EdgeInsets.only(top: 16),
            color: colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                [
                  if (provider.missingApiKeyMessage != null)
                    provider.missingApiKeyMessage!,
                  if (profile.aboutMe.isEmpty)
                    'Tipp: Schreib im Profil unter „Über mich“, wie dein Alltag aussieht (Training, wo du isst, Vorlieben). Dann werden die Vorschläge viel persönlicher.',
                ].join('\n\n'),
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            ),
          ),
        const SizedBox(height: 16),
        for (final action in _quickActions)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(action.icon, color: colorScheme.primary),
              title: Text(action.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  _send(provider, action.prompt, displayText: action.label),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActionRow(MainProvider provider) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _quickActions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = _quickActions[index];
          return ActionChip(
            avatar: Icon(action.icon, size: 18),
            label: Text(action.label),
            onPressed: provider.assistantBusy
                ? null
                : () =>
                      _send(provider, action.prompt, displayText: action.label),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(MainProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AppTextField(
              controller: _inputController,
              hint: 'Frag deinen Coach …',
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              maxLines: 5,
              minLines: 1,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(width: 4),
          ListenableBuilder(
            listenable: _inputController,
            builder: (context, _) => IconButton.filled(
              tooltip: 'Senden',
              icon: const Icon(Icons.send),
              onPressed:
                  provider.assistantBusy || _inputController.text.trim().isEmpty
                  ? null
                  : () => _send(provider, _inputController.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _MessageBubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final background = message.isError
        ? colorScheme.errorContainer
        : isUser
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final foreground = message.isError
        ? colorScheme.onErrorContainer
        : isUser
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUser || message.isError)
                SelectableText(
                  message.displayText ?? message.text,
                  style: TextStyle(color: foreground),
                )
              else
                MarkdownBody(
                  data: message.text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: foreground),
                      ),
                ),
              if (onRetry != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Erneut versuchen'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Denkt nach …',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
