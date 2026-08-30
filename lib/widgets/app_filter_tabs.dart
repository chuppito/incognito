import 'dart:typed_data';

import 'package:flutter/material.dart';

class AppFilterEntry {
  final String packageName;
  final String appName;
  final Uint8List? icon;

  AppFilterEntry({required this.packageName, required this.appName, required this.icon});
}

class AppFilterTabs extends StatelessWidget {
  final List<AppFilterEntry> apps;
  final String? selectedPackage; // null = "Tout"
  final ValueChanged<String?> onSelected;

  const AppFilterTabs({
    super.key,
    required this.apps,
    required this.selectedPackage,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _FilterTab(
            label: 'Tout',
            selected: selectedPackage == null,
            onTap: () => onSelected(null),
            child: const Icon(Icons.all_inbox_rounded, color: Colors.white, size: 22),
          ),
          for (final app in apps)
            _FilterTab(
              label: app.appName,
              selected: selectedPackage == app.packageName,
              onTap: () => onSelected(app.packageName),
              child: app.icon != null
                  ? ClipOval(child: Image.memory(app.icon!, width: 40, height: 40, fit: BoxFit.cover))
                  : Text(
                      app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.grey.shade400,
                border: selected
                    ? Border.all(color: color, width: 2)
                    : null,
              ),
              child: child,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? color : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
