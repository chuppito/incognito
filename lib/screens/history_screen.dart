import 'package:flutter/material.dart';

import '../models/installed_app.dart';
import '../models/conversation_summary.dart';
import '../models/notification_item.dart';
import '../services/incognito_channel.dart';
import '../widgets/app_filter_tabs.dart';
import '../widgets/conversation_tile.dart';
import 'conversation_thread_screen.dart';
import 'settings_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  final _history = ValueNotifier<List<NotificationItem>>([]);
  String _query = '';
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _error;
  final _channel = IncognitoChannel.instance;

  List<NotificationItem> _items = [];

  /// Toutes les applications installées, indexées par package.
  Map<String, InstalledApp> _installedAppsByPackage = {};

  /// Applications actuellement sélectionnées dans
  /// "Applications à écouter".
  Set<String> _listenedApps = {};

  bool _loading = true;
  bool? _accessGranted;

  /// null = "Tout"
  String? _selectedPackage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _channel.setOnNotificationReceived((item) {
      if (!mounted) return;

      setState(() {
        _items = [item, ..._items.where((e) => e.id != item.id)]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _history.value = List.of(_items);
      });
    });

    _init();
  }

  Future<void> _init() async {
    final granted = await _channel.isNotificationAccessGranted();

    if (!mounted) return;

    setState(() {
      _accessGranted = granted;
    });

    await _loadApps();
    await _refresh();
  }

  /// Charge les applications installées ainsi que celles
  /// actuellement surveillées.
  Future<void> _loadApps() async {
    final results = await Future.wait([
      _channel.getInstalledApps(),
      _channel.getListenedApps(),
    ]);

    if (!mounted) return;

    final apps = results[0] as List<InstalledApp>;
    final listened = results[1] as Set<String>;

    setState(() {
      _installedAppsByPackage = {
        for (final app in apps) app.packageName: app,
      };

      _listenedApps = listened;

      // Si l'application actuellement sélectionnée
      // n'est plus surveillée, retour à "Tout".
      if (_selectedPackage != null &&
          !_listenedApps.contains(_selectedPackage)) {
        _selectedPackage = null;
      }
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final history = await _channel.getHistory();
      final granted = await _channel.isNotificationAccessGranted();
      if (!mounted) return;
      setState(() {
        _items = history;
        _history.value = List.of(_items);
        _accessGranted = granted;
        _hasMore = history.length == 200;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger l’historique. Réessaie.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _channel.getHistory(offset: _items.length);
      if (!mounted) return;
      setState(() {
        final ids = _items.map((e) => e.id).toSet();
        _items.addAll(page.where((e) => !ids.contains(e.id)));
        _history.value = List.of(_items);
        _hasMore = page.length == 200;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger la suite')));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setOnNotificationReceived((_) {});
    _history.dispose();
    super.dispose();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tout effacer ?'),
        content: const Text(
          'L\'historique des notifications capturées '
          'sera définitivement supprimé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _channel.clearHistory();

      if (!mounted) return;

      setState(() {
        _items = [];
        _history.value = [];
        _hasMore = false;
        _selectedPackage = null;
      });
    }
  }

  /// Construit la liste des filtres à partir des applications
  /// SURVEILLÉES, et non plus à partir de l'historique.
  ///
  /// Cela signifie qu'une application surveillée apparaît
  /// même si elle n'a encore reçu aucune notification.
  List<AppFilterEntry> get _appTabs {
    final entries = <AppFilterEntry>[];

    // On parcourt les applications installées afin de conserver
    // leur ordre naturel et leurs informations complètes.
    for (final app in _installedAppsByPackage.values) {
      if (!_listenedApps.contains(app.packageName)) {
        continue;
      }

      entries.add(
        AppFilterEntry(
          packageName: app.packageName,
          appName: app.appName,
          icon: app.icon,
        ),
      );
    }

    return entries;
  }

  List<NotificationItem> get _filteredItems {
    if (_selectedPackage == null) {
      return _items;
    }

    return _items
        .where(
          (item) => item.packageName == _selectedPackage,
        )
        .toList();
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
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );

              // Recharge les applications surveillées après
              // le retour des réglages.
              await _loadApps();
              await _refresh();
            },
          ),
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_outlined,
              ),
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_accessGranted == false) {
      return _AccessRequestBanner(
        onOpenSettings: () async {
          await _channel.openNotificationAccessSettings();
        },
      );
    }

    final tabs = _appTabs;
    final filtered = _filteredItems
        .where((item) =>
            '${item.title} ${item.sender} ${item.text} ${item.appName}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher un contact ou un message',
                    border: OutlineInputBorder(),
                    isDense: true))),
        // Les applications surveillées sont affichées même
        // lorsqu'il n'existe encore aucune notification.
        if (tabs.isNotEmpty)
          AppFilterTabs(
            apps: tabs,
            selectedPackage: _selectedPackage,
            onSelected: (pkg) {
              setState(() {
                _selectedPackage = pkg;
              });
            },
          ),

        if (tabs.isNotEmpty) const Divider(height: 1),

        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(onPressed: _refresh, child: Text(_error!))),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : _buildConversationList(filtered),
        ),
        if (_hasMore)
          TextButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: const Icon(Icons.expand_more),
              label: Text(_loadingMore
                  ? 'Chargement…'
                  : 'Charger les messages plus anciens')),
      ],
    );
  }

  /// Vue groupée par contact/conversation.
  /// Elle est utilisée aussi dans l'onglet "Tout" : chaque conversation reste
  /// séparée par application grâce à la clé package + conversation.

  Widget _buildConversationList(List<NotificationItem> filtered) {
    final conversations = buildConversations(filtered);

    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conversation = conversations[index];

        return ConversationTile(
          conversation: conversation,
          appIcon: _installedAppsByPackage[conversation.packageName]?.icon,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConversationThreadScreen(
                  conversation: conversation,
                  history: _history,
                  appIcon:
                      _installedAppsByPackage[conversation.packageName]?.icon,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final hasApps = _appTabs.isNotEmpty;

    String message;

    if (_items.isEmpty) {
      if (hasApps) {
        message = 'Aucune notification capturée pour l\'instant.\n\n'
            'Les notifications des applications surveillées '
            'apparaîtront ici.';
      } else {
        message = 'Aucune application surveillée.\n\n'
            'Sélectionne les applications à écouter via '
            'l\'icône de réglages en haut.';
      }
    } else if (_selectedPackage != null) {
      final selectedApp = _installedAppsByPackage[_selectedPackage];

      message = 'Aucune notification pour '
          '${selectedApp?.appName ?? 'cette application'}.';
    } else {
      message = 'Aucune notification capturée pour l\'instant.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _AccessRequestBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _AccessRequestBanner({
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Incognito a besoin de l\'accès aux notifications '
              'pour fonctionner.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Active "Incognito" dans la liste des accès '
              'aux notifications.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
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
