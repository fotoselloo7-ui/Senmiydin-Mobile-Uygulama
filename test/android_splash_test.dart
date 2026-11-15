import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The native Android splash is configuration, so it is checked from the files: SplashScreen API theme, a light
/// surface, the icon-only mark at the Android 12 icon canvas size, and nothing that brings back a boxed artwork.
void main() {
  final res = 'android/app/src/main/res';
  String read(String path) => File(path).readAsStringSync();

  test('LaunchTheme uses the SplashScreen API with the icon-only mark and a light surface', () {
    final styles = read('$res/values/styles.xml');
    expect(styles, contains('name="LaunchTheme" parent="Theme.SplashScreen"'));
    expect(styles, contains('name="windowSplashScreenBackground">@color/launch_background'));
    expect(styles, contains('name="windowSplashScreenAnimatedIcon">@drawable/native_splash_icon'));
    expect(styles, contains('name="postSplashScreenTheme">@style/NormalTheme'));
    expect(read('$res/values/colors.xml'), contains('<color name="launch_background">#FFFFFF</color>'));
  });

  test('There are no older splash overrides that bring back a boxed artwork or a dark surface', () {
    expect(Directory('$res/values-v31').existsSync(), isFalse);
    expect(Directory('$res/values-night').existsSync(), isFalse);
    expect(File('$res/drawable/launch_background.xml').existsSync(), isFalse);
    expect(File('$res/drawable-v21/launch_background.xml').existsSync(), isFalse);
  });

  test('The splash icon is a 1152 px (288 dp) transparent PNG whose artwork stays inside the 192 dp mask circle', () {
    final bytes = File('$res/drawable-nodpi/native_splash_icon.png').readAsBytesSync();
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    expect(data.getUint32(16), 1152);
    expect(data.getUint32(20), 1152);
    expect(data.getUint8(25), 6, reason: 'RGBA colour type (a transparent background, no boxed art)');
  });

  test('MainActivity installs the splash screen before onCreate and the dependency is declared', () {
    final activity = read('android/app/src/main/kotlin/com/senmiydin/senmiydin/MainActivity.kt');
    expect(activity.indexOf('installSplashScreen()'), lessThan(activity.indexOf('super.onCreate(savedInstanceState)')));
    expect(read('android/app/build.gradle.kts'), contains('androidx.core:core-splashscreen'));
  });
}
