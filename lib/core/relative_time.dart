import 'app_locale.dart';

/// "5 dk önce" / "5 min ago" for a raw timestamp. Everything that shows a relative time keeps the timestamp and calls
/// this when it builds, so a change of language re-formats what is already on screen.
String relativeTime(DateTime time) {
  final elapsed = DateTime.now().difference(time);
  final text = currentL10n;
  if (elapsed.inMinutes < 1) return text.timeJustNow;
  if (elapsed.inHours < 1) return text.timeMinutesAgo(elapsed.inMinutes);
  if (elapsed.inDays < 1) return text.timeHoursAgo(elapsed.inHours);
  if (elapsed.inDays < 7) return text.timeDaysAgo(elapsed.inDays);
  return '${time.day}.${time.month}.${time.year}';
}
