import 'package:flutter_test/flutter_test.dart';
import 'package:md_photo/models/sheet_config.dart';

void main() {
  group('SheetConfig physical layout', () {
    test('uses the exact A4 portrait and landscape dimensions', () {
      const portrait = SheetConfig();
      final landscape = portrait.copyWith(landscape: true);

      expect(portrait.paperWidthMm, 210);
      expect(portrait.paperHeightMm, 297);
      expect(landscape.paperWidthMm, 297);
      expect(landscape.paperHeightMm, 210);
    });

    test('computes evenly spaced slots inside the configured margins', () {
      const config = SheetConfig(
        rows: 2,
        columns: 2,
        marginMm: 10,
        spacingMm: 4,
      );
      final slots = config.slotBounds;

      expect(slots, hasLength(4));
      expect(slots.first.leftMm, 10);
      expect(slots.first.topMm, 10);
      expect(slots.first.widthMm, 93);
      expect(slots.first.heightMm, 136.5);
      expect(slots[1].leftMm, 107);
      expect(slots[2].topMm, 150.5);
    });

    test('supports custom paper and clamps unsafe grid and margin values', () {
      final config = const SheetConfig().copyWith(
        paperSize: PaperSize.custom,
        customWidthMm: 100,
        customHeightMm: 200,
        rows: 100,
        columns: 0,
        marginMm: 40,
      );

      expect(config.paperWidthMm, 100);
      expect(config.paperHeightMm, 200);
      expect(config.rows, 8);
      expect(config.columns, 1);
      expect(config.marginMm, 30);
    });

    test('keeps photo zoom and pan inside safe editing bounds', () {
      final photo = const SlotPhoto(image: null).copyWith(
        scale: 4,
        offsetX: -2,
        offsetY: 2,
      );

      expect(photo.scale, 3);
      expect(photo.offsetX, -0.75);
      expect(photo.offsetY, 0.75);
    });
  });
}
