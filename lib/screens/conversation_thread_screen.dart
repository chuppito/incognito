import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/conversation_summary.dart';
import '../models/notification_item.dart';
import '../services/incognito_channel.dart';

class ConversationThreadScreen extends StatefulWidget {
  final ConversationSummary conversation;
  final Uint8List? appIcon;

  const ConversationThreadScreen({
    super.key,
    required this.conversation,
    required this.appIcon,
  });

  @override
  State<ConversationThreadScreen> createState() => _ConversationThreadScreenState();
}

class _ConversationThreadScreenState extends State<ConversationThreadScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  StreamSubscription<NotificationItem>? _subscription;
  late List<NotificationItem> _items;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _items = [...widget.conversation.items];
    _subscription = IncognitoChannel.instance.notifications.listen((item) {
      if (!mounted || !_belongs(item)) return;
      final atBottom = !_scroll.hasClients || _scroll.offset < 100;
      setState(() {
        _items.removeWhere((e) => e.id == item.id);
        _items.add(item);
      });
      if (atBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
          }
        });
      }
    });
  }

  bool _belongs(NotificationItem item) {
    final conversation = widget.conversation;
    if (item.packageName != conversation.packageName) return false;
    final key = conversation.latest.conversationKey;
    if (key.isNotEmpty && item.conversationKey.isNotEmpty) {
      return key == item.conversationKey;
    }
    return cleanContactName(item.title).toLowerCase() == conversation.contactName.toLowerCase();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final history = <NotificationItem>[];
    final originalIds = _items.map((e) => e.id).toSet();
    try {
      var offset = 0;
      while (true) {
        final page = await IncognitoChannel.instance.getHistory(limit: 500, offset: offset);
        history.addAll(page.where(_belongs));
        if (page.length < 500) break;
        offset += page.length;
      }
      if (!mounted) return;
      setState(() {
        final merged = {for (final item in history) item.id: item};
        for (final item in _items.where((e) => !originalIds.contains(e.id))) {
          merged[item.id] = item;
        }
        _items = merged.values.toList();
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’actualiser les messages.')));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final messages = _items.where((e) => query.isEmpty ||
      e.text.toLowerCase().contains(query) || e.sender.toLowerCase().contains(query)).toList()
      ..sort((a, b) {
        final time = b.timestamp.compareTo(a.timestamp);
        return time != 0 ? time : b.id.compareTo(a.id);
      });
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (widget.appIcon != null)
            ClipOval(child: Image.memory(widget.appIcon!, width: 32, height: 32,
              errorBuilder: (_, __, ___) => const Icon(Icons.forum_outlined)))
          else const Icon(Icons.forum_outlined),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.conversation.contactName, overflow: TextOverflow.ellipsis),
            Text('${widget.conversation.appName} • ${_items.length} ${_items.length == 1 ? 'message' : 'messages'}',
              style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Rechercher dans la conversation',
              prefixIcon: Icon(Icons.search), isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)))),
            onChanged: (value) => setState(() => _query = value),
          )),
        Expanded(child: messages.isEmpty
          ? const Center(child: Text('Aucun message à afficher.'))
          : RefreshIndicator(onRefresh: _reload, child: ListView.builder(
              controller: _scroll,
              reverse: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final item = messages[index];
                final showDate = index == messages.length - 1 ||
                  DateUtils.dateOnly(item.timestamp) != DateUtils.dateOnly(messages[index + 1].timestamp);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (showDate) Center(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Chip(label: Text(DateFormat('dd/MM/yyyy').format(item.timestamp))),
                  )),
                  Align(alignment: Alignment.centerLeft, child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10, right: 20),
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                      decoration: BoxDecoration(color: colors.surfaceContainerHighest,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4),
                          topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (item.sender.isNotEmpty) Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(item.sender, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
                        ),
                        SelectableText(item.text.isEmpty ? 'Notification sans texte.' : item.text,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4)),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(DateFormat('HH:mm').format(item.timestamp),
                            style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            tooltip: 'Actions du message',
                            iconSize: 18,
                            onSelected: (action) => _messageAction(item, action),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'copy', child: Text('Copier le message')),
                              PopupMenuItem(value: 'delete', child: Text('Supprimer de l’historique')),
                            ],
                          ),
                        ]),
                      ]),
                    ),
                  )),
                ]);
              },
            ))),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _openSourceApp, icon: const Icon(Icons.open_in_new),
            label: Text('Ouvrir ${widget.conversation.appName}'),
          )))),
      ]),
    );
  }

  Future<void> _messageAction(NotificationItem item, String action) async {
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: item.text));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message copié.')));
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Supprimer ce message ?'),
      content: const Text('Il sera retiré uniquement de l’historique Incognito.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
      ],
    ));
    if (confirmed != true) return;
    try {
      await IncognitoChannel.instance.deleteNotification(item.id);
      if (mounted) setState(() => _items.removeWhere((e) => e.id == item.id));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer ce message.')));
    }
  }

  Future<void> _openSourceApp() async {
    try {
      final opened = await IncognitoChannel.instance.openApp(widget.conversation.packageName);
      if (!mounted || opened) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.conversation.appName} est introuvable.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir l’application.')));
    }
  }
}
