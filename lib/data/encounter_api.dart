import 'models.dart';

class EncounterEntry {
  const EncounterEntry({
    required this.id,
    required this.status,
    required this.outgoing,
    required this.requester,
    required this.target,
    required this.time,
    this.source,
    this.story,
    this.encounterId,
    this.storyRevision,
  });

  final String id, status, time;
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
