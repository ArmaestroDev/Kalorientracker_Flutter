import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/chat_message.dart';
import '../../logic/providers/main_provider.dart';
import '../../logic/voice_input_service.dart';
import '../theme/tokens.dart';
import '../widgets/kit/kit.dart';
import 'plans_screen.dart';

class _QuickAction {
  final IconData icon;
  final String label;
  final String prompt;

  const _QuickAction(this.icon, this.label, this.prompt);
}

/// Personal coach: a chat that always knows the user's profile, plans, goals and log
class AssistantScreen extends StatefulWidget {
  final VoidCallback? onOpenProfile;

  const AssistantScreen({super.key, this.onOpenProfile});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _voiceService = VoiceInputService();
  int _lastMessageCount = 0;
  bool _isListening = false;
  String _voiceBaseText = '';

  static const _quickActions = [
    _QuickAction(
      Icons.restaurant_menu_outlined,
      'Was soll ich jetzt essen?',
      'Was soll ich als Nächstes essen? Schlag mir 2–3 konkrete Optionen vor, die zu meinen Plänen (falls vorhanden), meinem restlichen Budget, meinem Proteinziel und meinem Alltag passen. Nenne jeweils ungefähre kcal und Protein.',
    ),
    _QuickAction(
      Icons.account_balance_wallet_outlined,
      'Wochenbudget',
      'Wie viele Kalorien habe ich diese Woche schon gegessen und wie viele bleiben mir noch? Wie verteile ich den Rest sinnvoll auf die übrigen Tage, auch mit Blick aufs Wochenende?',
    ),
    _QuickAction(
      Icons.today_outlined,
      'Tagesrückblick',
      'Gib mir einen kurzen Rückblick auf diesen Tag: Wie stehe ich bei Kalorien und Protein, was lief gut und was mache ich beim nächsten Mal besser?',
    ),
    _QuickAction(
      Icons.nightlight_outlined,
      'Hunger am Abend',
      'Ich habe gerade Hunger. Was kann ich jetzt noch essen, ohne mein Tagesbudget zu sprengen? Sättigend und eiweißreich, bitte mit Mengen.',
    ),
    _QuickAction(
      Icons.calendar_view_week_outlined,
      'Wochenrückblick',
      'Analysiere meine letzten 7 Tage: durchschnittliche Kalorien und Protein im Vergleich zu meinen Zielen, Muster (z. B. Wochenende, Abende), Gewichtstrend und die 3 wichtigsten Stellschrauben für nächste Woche.',
    ),
    _QuickAction(
      Icons.calendar_month_outlined,
      'Monatsrückblick',
      'Analysiere meine letzten 30 Tage wochenweise: Bin ich auf Kurs zu meinem Ziel? Welche Lebensmittel liefern die meisten Kalorien, was sind wiederkehrende Muster, wie konsequent logge ich, und was sollte ich ändern?',
    ),
  ];

  @override
  void dispose() {
    _voiceService.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(MainProvider provider, String text, {String? displayText}) {
    if (text.trim().isEmpty || provider.assistantBusy) return;
    if (_isListening) _voiceService.stop();
    if (displayText == null) _inputController.clear();
    provider.sendAssistantMessage(text, displayText: displayText);
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _voiceService.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    _voiceBaseText = _inputController.text.trim();
    await _voiceService.startListening(
      onListeningChanged: (active) {
        if (mounted) setState(() => _isListening = active);
      },
      onResult: (words, _) {
        if (!mounted || words.trim().isEmpty) return;
        final combined = _voiceBaseText.isEmpty
            ? words
            : '$_voiceBaseText $words';
        _inputController.value = TextEditingValue(
          text: combined,
          selection: TextSelection.collapsed(offset: combined.length),
        );
      },
      onError: (msg) {
        if (!mounted) return;
        AppFeedback.error(context, msg);
      },
    );
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

  void _openPlans() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlansScreen()));
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppFeedback.success(context, 'Kopiert');
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

        final theme = Theme.of(context);
        final profile = provider.userProfile;
        final model = profile.modelFor(profile.selectedProvider);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${profile.selectedProvider.label} · $model',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Pläne',
                onPressed: _openPlans,
                icon: Badge.count(
                  count: provider.activePlanCount,
                  isLabelVisible: provider.activePlanCount > 0,
                  child: const Icon(Icons.description_outlined),
                ),
              ),
              IconButton(
                tooltip: 'Chat leeren',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: provider.assistantBusy || messages.isEmpty
                    ? null
                    : () => _confirmClear(provider),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (provider.missingApiKeyMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.screenX,
                      Space.sm,
                      Space.screenX,
                      0,
                    ),
                    child: Notice(
                      tone: NoticeTone.error,
                      title: 'Kein API-Schlüssel',
                      message: provider.missingApiKeyMessage!,
                      actionLabel: widget.onOpenProfile == null
                          ? null
                          : 'Zum Profil',
                      onAction: widget.onOpenProfile,
                    ),
                  ),
                Expanded(
                  child: messages.isEmpty && !provider.assistantBusy
                      ? _buildIntro(provider)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            Space.screenX,
                            Space.sm,
                            Space.screenX,
                            Space.sm,
                          ),
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            if (index >= messages.length) {
                              return _TypingBubble(
                                status: provider.assistantStatus,
                              );
                            }
                            final message = messages[index];
                            final isLast = index == messages.length - 1;
                            return _MessageBubble(
                              message: message,
                              onRetry: message.isError && isLast
                                  ? provider.retryAssistant
                                  : null,
                              onCopy: message.isUser || message.isError
                                  ? null
                                  : () => _copy(message.text),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = provider.userProfile;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.screenX,
            Space.lg,
            Space.screenX,
            Space.lg,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 32,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: Space.lg),
                Text(
                  'Dein Ernährungscoach',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'Frag mich alles zu Ernährung, Training und deinen Zielen. Ich kenne deine Einträge und kann Mahlzeiten für dich eintragen.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.xl),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final action in _quickActions)
                      ActionChip(
                        avatar: Icon(
                          action.icon,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        label: Text(action.label),
                        onPressed: provider.assistantBusy
                            ? null
                            : () => _send(
                                provider,
                                action.prompt,
                                displayText: action.label,
                              ),
                      ),
                  ],
                ),
                if (profile.aboutMe.trim().isEmpty) ...[
                  const SizedBox(height: Space.lg),
                  const Notice(
                    tone: NoticeTone.info,
                    message:
                        'Tipp: Erzähl im Profil unter „Über mich“ etwas über dich – dann werden die Antworten persönlicher.',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionRow(MainProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        Space.screenX,
        Space.sm,
        Space.screenX,
        0,
      ),
      child: Row(
        children: [
          for (final action in _quickActions)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: ActionChip(
                avatar: Icon(action.icon, size: 18),
                label: Text(action.label),
                onPressed: provider.assistantBusy
                    ? null
                    : () => _send(
                        provider,
                        action.prompt,
                        displayText: action.label,
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(MainProvider provider) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.screenX,
            Space.sm,
            Space.screenX,
            Space.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (VoiceInputService.isPlatformSupported) ...[
                if (_isListening)
                  IconButton.filled(
                    tooltip: 'Spracheingabe',
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.errorContainer,
                      foregroundColor: scheme.onErrorContainer,
                    ),
                    icon: const Icon(Icons.stop_rounded),
                    onPressed: provider.assistantBusy ? null : _toggleVoice,
                  )
                else
                  IconButton(
                    tooltip: 'Spracheingabe',
                    icon: const Icon(Icons.mic_none_rounded),
                    onPressed: provider.assistantBusy ? null : _toggleVoice,
                  ),
                const SizedBox(width: Space.xs),
              ],
              Expanded(
                child: TextField(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (value) => _send(provider, value),
                  decoration: InputDecoration(
                    hintText: 'Nachricht an den Coach…',
                    border: UnderlineInputBorder(
                      borderRadius: BorderRadius.circular(Corner.xl),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderRadius: BorderRadius.circular(Corner.xl),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              ListenableBuilder(
                listenable: _inputController,
                builder: (context, _) => IconButton.filled(
                  tooltip: 'Senden',
                  icon: const Icon(Icons.arrow_upward_rounded),
                  onPressed:
                      provider.assistantBusy ||
                          _inputController.text.trim().isEmpty
                      ? null
                      : () => _send(provider, _inputController.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onCopy;

  const _MessageBubble({required this.message, this.onRetry, this.onCopy});

  @override
  Widget build(BuildContext context) {
    if (message.isError) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.8,
            ),
            child: Notice(
              tone: NoticeTone.error,
              message: message.text,
              actionLabel: onRetry == null ? null : 'Erneut versuchen',
              onAction: onRetry,
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = message.isUser;
    final background = isUser ? scheme.primary : scheme.surfaceContainerLowest;
    final foreground = isUser ? scheme.onPrimary : scheme.onSurface;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(Corner.lg),
          topRight: const Radius.circular(Corner.lg),
          bottomLeft: Radius.circular(isUser ? Corner.lg : Corner.xs),
          bottomRight: Radius.circular(isUser ? Corner.xs : Corner.lg),
        ),
      ),
      child: isUser
          ? SelectableText(
              message.displayText ?? message.text,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            )
          : MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(color: foreground),
                h1: theme.textTheme.titleLarge?.copyWith(color: foreground),
                h2: theme.textTheme.titleMedium?.copyWith(color: foreground),
                h3: theme.textTheme.titleSmall?.copyWith(color: foreground),
                blockquoteDecoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Corner.sm),
                ),
                code: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
    );

    final wrapped = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.8,
      ),
      child: onCopy == null
          ? bubble
          : GestureDetector(onLongPress: onCopy, child: bubble),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: wrapped,
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final String? status;

  const _TypingBubble({this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: Space.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Corner.lg),
            topRight: Radius.circular(Corner.lg),
            bottomRight: Radius.circular(Corner.lg),
            bottomLeft: Radius.circular(Corner.xs),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Space.sm),
            Text(
              status ?? 'Denkt nach…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
