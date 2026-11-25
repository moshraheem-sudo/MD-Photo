import 'package:flutter_test/flutter_test.dart';

import 'package:md_photo/main.dart';

void main() {
  testWidgets('shows the Arabic photo-sheet editor', (tester) async {
    await tester.pumpWidget(const MdPhotoApp());
    await tester.pumpAndSettle();

    expect(find.text('رتّب صورك للطباعة'), findsOneWidget);
    expect(find.text('إضافة صور'), findsOneWidget);
    expect(find.textContaining('A4'), findsOneWidget);
  });
}
