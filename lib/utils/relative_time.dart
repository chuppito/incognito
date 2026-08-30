import 'package:intl/intl.dart';

/// Formate une date en "il y a X minutes/heures", comme Unseen.
/// Passe en date absolue au-delà d'une semaine.
String formatRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);

  if (diff.inSeconds < 60) return 'À l\'instant';

  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return 'Il y a $m minute${m > 1 ? 's' : ''}';
  }

  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'Il y a $h heure${h > 1 ? 's' : ''}';
  }

  if (diff.inDays == 1) return 'Hier';

  if (diff.inDays < 7) {
    final d = diff.inDays;
    return 'Il y a $d jour${d > 1 ? 's' : ''}';
  }

  return DateFormat('dd/MM/yyyy').format(dt);
}
