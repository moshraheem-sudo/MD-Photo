import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:md_photo/models/sheet_config.dart';
import 'package:md_photo/screens/editor_screen.dart';

void main() {
  testWidgets('tapping an attached photo opens the editor and saves changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          initialConfig: const SheetConfig(rows: 1, columns: 1),
          initialPhotos: [SlotPhoto(image: XFile('test-photo.png'))],
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('photo-slot-0')));
    await tester.pumpAndSettle();

    expect(find.text('تعديل الصورة 1'), findsOneWidget);
    expect(find.text('حذف الصورة'), findsOneWidget);
    expect(find.text('إظهار كاملة'), findsOneWidget);

    await tester.tap(find.text('إظهار كاملة'));
    await tester.ensureVisible(find.text('تدوير'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تدوير'));
    await tester.tap(find.text('حفظ التعديل'));
    await tester.pumpAndSettle();

    expect(find.text('تعديل الصورة 1'), findsNothing);
    expect(find.byKey(const ValueKey('photo-slot-0')), findsOneWidget);
  });

  testWidgets('deleting from the photo editor empties that slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          initialConfig: const SheetConfig(rows: 1, columns: 1),
          initialPhotos: [SlotPhoto(image: XFile('test-photo.png'))],
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('photo-slot-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الصورة'));
    await tester.pumpAndSettle();

    expect(find.text('حذف الصورة؟'), findsOneWidget);
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    expect(find.text('تعديل الصورة 1'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
