import 'package:flutter/material.dart';

import '../models/installed_app.dart';
import '../services/incognito_channel.dart';
import '../widgets/app_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _channel = IncognitoChannel.instance;

  List<InstalledApp> _apps = [];
  Set<String> _listened = {};
  Set<String> _silent = {};
  bool _loading = true;
  String _query = '';
  bool _hideSystemApps = true;
  bool _incognitoNotifications = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _channel.getInstalledApps(),
      _channel.getListenedApps(),
      _channel.getSilentApps(),
      _channel.isIncognitoNotificationsEnabled(),
    ]);
    setState(() {
      _apps = results[0] as List<InstalledApp>;
      _listened = results[1] as Set<String>;
      _silent = results[2] as Set<String>;
      _incognitoNotifications = results[3] as bool;
      _loading = false;
    });
  }

  Future<void> _toggleListened(InstalledApp app, bool value) async {
    setState(() {
      if (value) {
        _listened.add(app.packageName);
      } else {
        _listened.remove(app.packageName);
      }
    });
    await _channel.setListenedApps(_listened);
  }

  Future<void> _toggleNotify(InstalledApp app, bool showNotification) async {
    setState(() {
      if (showNotification) {
        _silent.remove(app.packageName);
      } else {
        _silent.add(app.packageName);
      }
    });
    await _channel.setSilentApps(_silent);
  }

  Future<void> _toggleIncognitoNotifications(bool value) async {
    setState(() => _incognitoNotifications = value);
    await _channel.setIncognitoNotificationsEnabled(value);

    if (!mounted) return;
    if (value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Autorise les notifications si Android affiche une demande.',
          ),
        ),
      );
    }
  }

  List<InstalledApp> get _filteredApps {
    return _apps.where((a) {
      if (_hideSystemApps && a.isSystemApp) return false;
      if (_query.isEmpty) return true;
      return a.appName.toLowerCase().contains(_query.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications à écouter'),
        actions: [
          IconButton(
            icon: Icon(_hideSystemApps ? Icons.filter_alt : Icons.filter_alt_off),
            tooltip: 'Afficher / masquer les apps système',
            onPressed: () => setState(() => _hideSystemApps = !_hideSystemApps),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Notifications Incognito'),
                    subtitle: const Text(
                      'Affiche une notification lorsqu’un nouveau message surveillé est capturé.',
                    ),
                    value: _incognitoNotifications,
                    onChanged: _toggleIncognitoNotifications,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher une application',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Écouter : capture dans l\'historique. Notif. : affiche aussi une notification Incognito.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = _filteredApps[index];
                        final isListened = _listened.contains(app.packageName);
                        final showsNotif = !_silent.contains(app.packageName);
                        return AppTile(
                          app: app,
                          isListened: isListened,
                          showsSystemNotification: showsNotif,
                          onListenedChanged: (v) => _toggleListened(app, v),
                          onNotifyChanged: (v) => _toggleNotify(app, v),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
