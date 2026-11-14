// ignore_for_file: prefer_initializing_formals
import '../core/app_locale.dart';
import '../core/relative_time.dart';
import 'models.dart';

class EncounterEntry {
  const EncounterEntry({
    required this.id,
    required this.status,
    required this.outgoing,
    required this.requester,
    required this.target,
    required String time,
    this.createdAt,
    this.source,
    this.story,
    this.encounterId,
    this.storyRevision,
  }) : _time = time;

  final String id, status;
  final String _time;

  /// Raw timestamp; the label is formatted when shown so it follows the language.
  final DateTime? createdAt;
  String get time => createdAt != null ? relativeTime(createdAt!) : tr(_time);
  final bool outgoing;
  final Person requester, target;
  final Post? source, story;
  final int? encounterId, storyRevision;

  Person get other => outgoing ? target : requester;
  bool get needsReview =>
      story?.storyStatus == 'pending' && story?.mine == false;
  String get statusLabel => switch (status) {
    'accepted' => 'Karşılaşıldı ✓',
    'rejected' => 'Reddedildi',
    'cancelled' => 'İptal edildi',
    _ => 'Onay bekliyor',
  };
}
