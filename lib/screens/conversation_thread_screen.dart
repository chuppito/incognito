import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/conversation_summary.dart';
import '../services/incognito_channel.dart';

class ConversationThreadScreen extends StatelessWidget {
  final ConversationSummary conversation;

  const ConversationThreadScreen({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final messages = conversation.items.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(conversation.contactName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              conversation.appName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SelectionArea(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final item = messages[index];
                  final timeLabel = DateFormat('dd/MM HH:mm').format(item.timestamp);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            item.text.isNotEmpty
                                ? item.text
                                : 'Cette notification ne contient pas de texte.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openSourceApp(context),
                  icon: const Icon(Icons.reply_rounded),
                  label: Text('Répondre dans ${conversation.appName}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSourceApp(BuildContext context) async {
    final opened = await IncognitoChannel.instance.openApp(conversation.packageName);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${conversation.appName} est introuvable ou n\'est plus installée.'),
        ),
      );
    }
  }
}
