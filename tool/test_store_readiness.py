"""Logic checks for the read-only store audit; no network or account mutations."""
import copy
import json
from pathlib import Path
import unittest

from store_readiness import BAD_SDK, admob_status, aggregate, metadata_errors


class StoreReadinessTests(unittest.TestCase):
    def setUp(self):
        self.metadata=json.loads((Path(__file__).resolve().parents[1]/"docs/store/STORE_METADATA.json").read_text(encoding="utf-8"))

    def test_current_copy_respects_all_limits(self):
        self.assertEqual([],metadata_errors(self.metadata))

    def test_apple_keywords_use_byte_limit_as_well_as_character_limit(self):
        value=copy.deepcopy(self.metadata)
        value["app_store"]["keywords"]="ş"*60
        self.assertIn("app_store.keywords_utf8",metadata_errors(value))

    def test_google_short_description_overflow_is_rejected(self):
        value=copy.deepcopy(self.metadata)
        value["google_play"]["short_description"]="a"*81
        self.assertIn("google_play.short_description",metadata_errors(value))

    def test_missing_or_failed_gate_cannot_report_ready(self):
        self.assertEqual("WAITING",aggregate([{"status":"READY"},{"status":"WAITING"}]))
        self.assertEqual("MISSING",aggregate([{"status":"WAITING"},{"status":"MISSING"}]))
        self.assertEqual("FAIL",aggregate([{"status":"MISSING"},{"status":"FAIL"}]))

    def test_measurement_connector_is_not_reported_as_analytics_engine(self):
        self.assertIsNone(BAD_SDK.search("com.google.firebase:firebase-measurement-connector:19.0.0"))
        self.assertIsNotNone(BAD_SDK.search("com.google.firebase:firebase-analytics:23.0.0"))
        self.assertIsNotNone(BAD_SDK.search("com.google.android.gms:play-services-ads:24.0.0"))

    def test_admob_ids_are_missing_until_real_and_never_google_samples(self):
        self.assertEqual("MISSING",admob_status({})[0])
        self.assertEqual("MISSING",admob_status(None)[0])
        real={"ADMOB_APP_ID_ANDROID":"ca-app-pub-1111111111111111~2222222222","ADMOB_APP_ID_IOS":"ca-app-pub-1111111111111111~3333333333",
              "ADMOB_NATIVE_AD_UNIT_ANDROID":"ca-app-pub-1111111111111111/4444444444","ADMOB_NATIVE_AD_UNIT_IOS":"ca-app-pub-1111111111111111/5555555555"}
        self.assertEqual("WAITING",admob_status(real)[0])
        self.assertEqual("MISSING",admob_status({**real,"ADMOB_NATIVE_AD_UNIT_IOS":""})[0])
        self.assertEqual("FAIL",admob_status({**real,"ADMOB_APP_ID_ANDROID":"ca-app-pub-3940256099942544~3347511713"})[0])
        self.assertEqual("FAIL",admob_status({**real,"ADMOB_NATIVE_AD_UNIT_ANDROID":"not-an-id"})[0])


if __name__=="__main__":
    unittest.main()
