import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models/sheet_config.dart';
import '../services/pdf_export_service.dart';

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    required this.config,
    required this.photos,
    super.key,
  });

  final SheetConfig config;
  final List<SlotPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final pageFormat = PdfPageFormat(
      config.paperWidthMm * PdfPageFormat.mm,
      config.paperHeightMm * PdfPageFormat.mm,
      marginAll: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة ملف الطباعة'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(
              child: Text(
                '${config.paperWidthMm.round()} × '
                '${config.paperHeightMm.round()} مم',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => PdfExportService.createPdf(config, photos),
        initialPageFormat: pageFormat,
        pageFormats: {'المقاس المحدد': pageFormat},
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: 'md-photo-sheet.pdf',
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('تعذر إنشاء المعاينة: $error'),
          ),
        ),
      ),
    );
  }
}
