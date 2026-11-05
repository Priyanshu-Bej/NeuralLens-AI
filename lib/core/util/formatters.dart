import 'package:intl/intl.dart';

/// "Just now", "5 min ago", "Yesterday", "Mar 4", "Mar 4, 2025".
String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24 && current.day == time.day) {
    return '${diff.inHours} h ago';
  }
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(time.year, time.month, time.day);
  if (today.difference(day).inDays == 1) return 'Yesterday';
  if (time.year == current.year) return DateFormat.MMMd().format(time);
  return DateFormat.yMMMd().format(time);
}
