import 'dart:convert';
import 'dart:typed_data';

class InstalledApp {
  final String packageName;
  final String appName;
  final Uint8List? icon;
  final bool isSystemApp;

  InstalledApp({
    required this.packageName,
    required this.appName,
    required this.icon,
    required this.isSystemApp,
  });

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) {
    final iconBase64 = map['icon'] as String?;
    return InstalledApp(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      icon: iconBase64 != null ? base64Decode(iconBase64) : null,
      isSystemApp: map['isSystemApp'] as bool? ?? false,
    );
  }
}
