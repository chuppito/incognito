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

class _HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
  final _channel = IncognitoChannel.instance;

  List<NotificationItem> _items = [];

  /// Toutes les applications installées, indexées par package.
  Map<String, InstalledApp> _installedAppsByPackage = {};

  /// Applications actuellement sélectionnées dans
  /// "Applications à écouter".
  Set<String> _listenedApps = {};

  bool _loading = true;
  String _query = '';
  String? _error;
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
        _items = [item, ..._items.where((e) => e.id != item.id)];
      });
    });

    _init();
  }

  Future<void> _init() async {
    try {
      await _loadApps();
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les applications. Réessaie.';
      });
    }
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

    final originalIds = _items.map((e) => e.id).toSet();
    try {
      final history = <NotificationItem>[];
      var offset = 0;
      while (true) {
        final page = await _channel.getHistory(limit: 500, offset: offset);
        history.addAll(page);
        if (page.length < 500) break;
        offset += page.length;
      }
      final granted = await _channel.isNotificationAccessGranted();
      if (!mounted) return;
      setState(() {
        // Conserver les arrivées reçues pendant le chargement.
        final merged = {for (final item in history) item.id: item};
        for (final item in _items) {
          if (!originalIds.contains(item.id)) {
            merged[item.id] = item;
          }
        }
        _items = merged.values.toList();
        _accessGranted = granted;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger l’historique. Réessaie.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.clearOnNotificationReceived();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
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
        bottom: const PreferredSize(preferredSize: Size.fromHeight(20),
          child: Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Version 2.0.0'))),
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
    final filtered = _filteredItems;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher un contact ou un message',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        if (_error != null)
          ListTile(title: Text(_error!), trailing: IconButton(
            icon: const Icon(Icons.refresh), onPressed: _refresh)),
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

        if (tabs.isNotEmpty)
          const Divider(height: 1),

        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : _buildConversationList(filtered),
        ),
      ],
    );
  }

  /// Vue groupée par contact/conversation.
  /// Elle est utilisée aussi dans l'onglet "Tout" : chaque conversation reste
  /// séparée par application grâce à la clé package + conversation.

  Widget _buildConversationList(List<NotificationItem> filtered) {
    final query = _query.trim().toLowerCase();
    final conversations = buildConversations(filtered).where((conversation) =>
      query.isEmpty || conversation.contactName.toLowerCase().contains(query) ||
      conversation.appName.toLowerCase().contains(query) ||
      conversation.items.any((item) => item.text.toLowerCase().contains(query) ||
        item.sender.toLowerCase().contains(query))).toList();
    if (conversations.isEmpty) {
      return const Center(child: Text('Aucun résultat pour cette recherche.'));
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conversation = conversations[index];

        return ConversationTile(
          conversation: conversation,
          appIcon: _installedAppsByPackage[conversation.packageName]?.icon,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConversationThreadScreen(
                    conversation: conversation,
                    appIcon: _installedAppsByPackage[conversation.packageName]?.icon,
                  ),
              ),
            );
            await _refresh();
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
        message =
            'Aucune notification capturée pour l\'instant.\n\n'
            'Les notifications des applications surveillées '
            'apparaîtront ici.';
      } else {
        message =
            'Aucune application surveillée.\n\n'
            'Sélectionne les applications à écouter via '
            'l\'icône de réglages en haut.';
      }
    } else if (_selectedPackage != null) {
      final selectedApp =
          _installedAppsByPackage[_selectedPackage];

      message =
          'Aucune notification pour '
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

