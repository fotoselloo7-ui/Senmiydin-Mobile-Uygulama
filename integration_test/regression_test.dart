import 'location_time_test.dart' as location_time;
import 'account_test.dart' as account;
import 'social_test.dart' as social;
import 'location_test.dart' as location;
import 'encounter_test.dart' as encounter;
import 'communication_test.dart' as communication;
import 'encounter_media_test.dart' as encounter_media;

// Compile one device application so all real API scenarios share the same native target.
void main() {
  account.main();
  social.main();
  location.main();
  encounter.main();
  encounter_media.main();
  communication.main();
  location_time.main();
}
