import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:md_photo/models/sheet_config.dart';
import 'package:md_photo/services/pdf_export_service.dart';

void main() {
  test('creates a print-sized A4 PDF page', () async {
    const config = SheetConfig(
      rows: 1,
      columns: 1,
      marginMm: 0,
      spacingMm: 0,
      showCutLines: false,
    );
    final bytes = await PdfExportService.createPdf(config, const [
      SlotPhoto(image: null),
    ]);
    final pdfSource = latin1.decode(bytes);

    expect(pdfSource, startsWith('%PDF-'));
    expect(pdfSource, contains('/MediaBox'));
    expect(pdfSource, contains('595.27559'));
    expect(pdfSource, contains('841.88976'));
  });

  test('renders edited photo transforms into the PDF', () async {
    const config = SheetConfig(
      rows: 1,
      columns: 1,
      marginMm: 0,
      spacingMm: 0,
      showCutLines: false,
    );
    final bytes = await PdfExportService.createPdf(config, [
      SlotPhoto(
        image: XFile('android/app/src/main/res/mipmap-mdpi/ic_launcher.png'),
        quarterTurns: 1,
        scale: 1.8,
        offsetX: 0.1,
        offsetY: -0.1,
      ),
    ]);

    expect(latin1.decode(bytes), contains('/MediaBox'));
    expect(bytes.length, greaterThan(1000));
  });
}
