import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senmiydin/core/navigation.dart';

void main() {
  testWidgets(
    'Long location disclosure remains readable and actionable with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? accepted;
      final repeatedDisclosure = List.filled(
        12,
        'Konumun sunucuya gönderilir; geçmiş bölgeler ilgili hikâyeleri önermek için kullanılır.',
      ).join('\n');
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  accepted = await confirmAction(
                    context,
                    title: 'Geçtiğim Yerler açılsın mı?',
                    message: '$repeatedDisclosure\nSon açıklama.',
                    action: 'Aç',
                    scrollable: true,
                  );
                },
                child: const Text('Konum tercihi'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Konum tercihi'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scroll = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget);
      await tester.drag(scroll, const Offset(0, -1800));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Aç'));
      await tester.tap(find.widgetWithText(FilledButton, 'Aç'));
      await tester.pumpAndSettle();
      expect(accepted, true);
      expect(tester.takeException(), isNull);
    },
  );
}
