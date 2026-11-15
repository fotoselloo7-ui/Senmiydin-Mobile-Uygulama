# R8 keep rules for the release build.
#
# WorkManager is pulled in by plugins and creates its Room database through reflection (WorkDatabase_Impl).
# Without these rules R8 strips the generated class and the app crashes at start-up in the release build:
#   RuntimeException: Failed to create an instance of androidx.work.impl.WorkDatabase
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.**
