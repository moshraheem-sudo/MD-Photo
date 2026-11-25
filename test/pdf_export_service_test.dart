import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
}
