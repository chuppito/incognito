import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/conversation_summary.dart';
import '../models/notification_item.dart';
import '../models/conversation_messages.dart';
import '../services/incognito_channel.dart';
import '../widgets/message_bubble.dart';
import '../widgets/conversation_avatar.dart';

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
  bool _searching = false;

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final query = _query.trim().toLowerCase();
    final messages = expandConversationMessages(_items).where((e) => query.isEmpty ||
      e.text.toLowerCase().contains(query) || e.sender.toLowerCase().contains(query)).toList()
      ..sort((a, b) {
        final time = b.timestamp.compareTo(a.timestamp);
        if (time != 0) return time;
        final id = b.id.compareTo(a.id);
        return id != 0 ? id : b.displayIndex.compareTo(a.displayIndex);
      });
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0B141A) : const Color(0xFFF2EEE5),
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF202C33) : Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(children: [
          ConversationAvatar(name: widget.conversation.contactName, appIcon: widget.appIcon, radius: 21),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.conversation.contactName, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            Text(widget.conversation.appName, style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]),
        actions: [IconButton(tooltip: 'Rechercher dans la conversation',
          icon: Icon(_searching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) _query = '';
          }))],
      ),
      body: Column(children: [
        if (_searching) Container(
          color: dark ? const Color(0xFF202C33) : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: TextField(autofocus: true,
            decoration: const InputDecoration(hintText: 'Nom ou message',
              prefixIcon: Icon(Icons.search), isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)))),
            onChanged: (value) => setState(() => _query = value),
          )),
        Expanded(child: Stack(children: [
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ChatBackground(dark)))),
          if (messages.isEmpty) const Center(child: Text('Aucun message à afficher.'))
          else RefreshIndicator(onRefresh: _reload, child: ListView.builder(
            controller: _scroll,
            reverse: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final item = messages[index];
              final showDate = index == messages.length - 1 ||
                (item.timeKnown != messages[index + 1].timeKnown) ||
                (!item.timeKnown && item.id != messages[index + 1].id) ||
                DateUtils.dateOnly(item.timestamp) != DateUtils.dateOnly(messages[index + 1].timestamp);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (showDate) Center(child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF202C33) : const Color(0xFFFFFEFA),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(item.timeKnown ? _dateLabel(item.timestamp) :
                    'Capture du ${DateFormat("dd/MM HH:mm").format(item.timestamp)}', style: const TextStyle(fontSize: 12)),
                )),
                MessageBubble(item: item, onLongPress: () => _showMessageActions(item)),
              ]);
            },
          )),
        ])),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: SizedBox(width: double.infinity, child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF128C7E), foregroundColor: Colors.white),
            onPressed: _openSourceApp, icon: const Icon(Icons.open_in_new),
            label: Text('Ouvrir ${widget.conversation.appName}'),
          )))),
      ]),
    );
  }

  String _dateLabel(DateTime date) {
    final day = DateUtils.dateOnly(date);
    final today = DateUtils.dateOnly(DateTime.now());
    if (day == today) return 'Aujourd’hui';
    if (day == DateTime(today.year, today.month, today.day - 1)) return 'Hier';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _showMessageActions(NotificationItem item) async {
    final action = await showModalBottomSheet<String>(context: context, builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.copy), title: const Text('Copier le message'),
          onTap: () => Navigator.pop(context, 'copy')),
        ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Supprimer de l’historique'),
          onTap: () => Navigator.pop(context, 'delete')),
      ]),
    ));
    if (!mounted || action == null) return;
    await _messageAction(item, action);
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
      content: Text(_items.any((source) => source.id == item.id && source.text != item.text && source.sender.isEmpty)
        ? 'Ce message appartient à un ancien bloc. La suppression retirera tout ce bloc de l’historique Incognito.'
        : 'Il sera retiré uniquement de l’historique Incognito.'),
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

class _ChatBackground extends CustomPainter {
  final bool dark;
  _ChatBackground(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dark ? const Color(0xFF162329) : const Color(0xFFE7E0D3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double y = -20; y < size.height + 60; y += 80) {
      for (double x = -20; x < size.width + 60; x += 80) {
        final center = Offset(x + ((y / 80).round().isEven ? 20 : 0), y);
        canvas.drawCircle(center, 12, paint);
        canvas.drawLine(center + const Offset(-5, -3), center + const Offset(5, 3), paint);
        final rect = Rect.fromCenter(center: center + const Offset(38, 38), width: 21, height: 17);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), paint);
        canvas.drawLine(Offset(rect.left + 4, rect.bottom), Offset(rect.left, rect.bottom + 5), paint);
        canvas.drawCircle(center + const Offset(3, 45), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBackground oldDelegate) => oldDelegate.dark != dark;
}
