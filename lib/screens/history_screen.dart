import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../services/incognito_channel.dart';
import '../widgets/app_filter_tabs.dart';
import '../widgets/notification_tile.dart';
import 'settings_screen.dart';
import 'notification_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _channel = IncognitoChannel.instance;

  List<NotificationItem> _items = [];
  Map<String, Uint8List?> _iconsByPackage = {};
  bool _loading = true;
  bool? _accessGranted;
  String? _selectedPackage; // null = "Tout"

  @override
  void initState() {
    super.initState();
    _channel.setOnNotificationReceived((item) {
      setState(() => _items = [item, ..._items]);
    });
    _init();
  }

  Future<void> _init() async {
    final granted = await _channel.isNotificationAccessGranted();
    setState(() => _accessGranted = granted);
    await _loadIcons();
    await _refresh();
  }

  Future<void> _loadIcons() async {
    final apps = await _channel.getInstalledApps();
    setState(() {
      _iconsByPackage = {for (final a in apps) a.packageName: a.icon};
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final history = await _channel.getHistory();
    final granted = await _channel.isNotificationAccessGranted();
    setState(() {
      _items = history;
      _accessGranted = granted;
      _loading = false;
      // Si l'app sélectionnée n'a plus aucune notif, on revient sur "Tout"
      if (_selectedPackage != null && !_items.any((i) => i.packageName == _selectedPackage)) {
        _selectedPackage = null;
      }
    });
  }

  Future<void> _deleteItem(NotificationItem item) async {
    await _channel.deleteNotification(item.id);
    setState(() => _items.removeWhere((e) => e.id == item.id));
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tout effacer ?'),
        content: const Text('L\'historique des notifications capturées sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Effacer')),
        ],
      ),
    );
    if (confirmed == true) {
      await _channel.clearHistory();
      setState(() {
        _items = [];
        _selectedPackage = null;
      });
    }
  }

  /// Une entrée par app distincte présente dans l'historique, la plus
  /// récente en premier (les items sont déjà triés desc par timestamp).
  List<AppFilterEntry> get _appTabs {
    final seen = <String>{};
    final entries = <AppFilterEntry>[];
    for (final item in _items) {
      if (seen.add(item.packageName)) {
        entries.add(AppFilterEntry(
          packageName: item.packageName,
          appName: item.appName,
          icon: _iconsByPackage[item.packageName],
        ));
      }
    }
    return entries;
  }

  List<NotificationItem> get _filteredItems {
    if (_selectedPackage == null) return _items;
    return _items.where((i) => i.packageName == _selectedPackage).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incognito'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Applications à écouter',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _loadIcons();
              _refresh();
            },
          ),
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Tout effacer',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_accessGranted == false) {
      return _AccessRequestBanner(onOpenSettings: () async {
        await _channel.openNotificationAccessSettings();
      });
    }

    if (_items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucune notification capturée pour l\'instant.\n'
                  'Sélectionne les apps à écouter via l\'icône de réglages en haut.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final filtered = _filteredItems;

    return Column(
      children: [
        AppFilterTabs(
          apps: _appTabs,
          selectedPackage: _selectedPackage,
          onSelected: (pkg) => setState(() => _selectedPackage = pkg),
        ),
        const Divider(height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Aucune notification pour cette application.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return NotificationTile(
                      item: item,
                      onDelete: () => _deleteItem(item),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationDetailScreen(item: item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AccessRequestBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _AccessRequestBanner({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Incognito a besoin de l\'accès aux notifications pour fonctionner.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Active "Incognito" dans la liste des accès aux notifications.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onOpenSettings,
              child: const Text('Ouvrir les réglages'),
            ),
          ],
        ),
      ),
    );
  }
}
