import 'package:flutter/services.dart';

import '../models/installed_app.dart';
import '../models/notification_item.dart';

/// Encapsule tous les échanges avec le code natif Android (MainActivity.kt)
/// via un seul MethodChannel.
class IncognitoChannel {
  IncognitoChannel._();
  static final IncognitoChannel instance = IncognitoChannel._();

  static const _channel = MethodChannel('com.tomtom.incognito/notifications');

  /// Notifie l'UI en direct quand une notification arrive pendant que
  /// l'app est ouverte (voir NotificationListener.kt côté natif).
  void setOnNotificationReceived(void Function(NotificationItem item) onReceived) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationReceived') {
        final map = Map<dynamic, dynamic>.from(call.arguments as Map);
        onReceived(NotificationItem.fromMap(map));
      }
    });
  }

  Future<bool> isNotificationAccessGranted() async {
    final granted = await _channel.invokeMethod<bool>('isNotificationAccessGranted');
    return granted ?? false;
  }

  Future<void> openNotificationAccessSettings() async {
    await _channel.invokeMethod('openNotificationAccessSettings');
  }

  Future<List<InstalledApp>> getInstalledApps() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    return (raw ?? [])
        .map((e) => InstalledApp.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Set<String>> getListenedApps() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getListenedApps');
    return (raw ?? []).cast<String>().toSet();
  }

  Future<void> setListenedApps(Set<String> packages) async {
    await _channel.invokeMethod('setListenedApps', packages.toList());
  }

  Future<Set<String>> getSilentApps() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getSilentApps');
    return (raw ?? []).cast<String>().toSet();
  }

  Future<void> setSilentApps(Set<String> packages) async {
    await _channel.invokeMethod('setSilentApps', packages.toList());
  }

  Future<List<NotificationItem>> getHistory({int limit = 200, int offset = 0}) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getHistory', {
      'limit': limit,
      'offset': offset,
    });
    return (raw ?? [])
        .map((e) => NotificationItem.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> deleteNotification(int id) async {
    await _channel.invokeMethod('deleteNotification', id);
  }

  Future<void> clearHistory() async {
    await _channel.invokeMethod('clearHistory');
  }

  Future<void> clearHistoryForPackage(String packageName) async {
    await _channel.invokeMethod('clearHistoryForPackage', packageName);
  }

  /// Ouvre l'app source (ex. WhatsApp) pour que l'utilisateur puisse répondre.
  /// Retourne false si l'app n'est plus installée.
  Future<bool> openApp(String packageName) async {
    final opened = await _channel.invokeMethod<bool>('openApp', packageName);
    return opened ?? false;
  }
}
