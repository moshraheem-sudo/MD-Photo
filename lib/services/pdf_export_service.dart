import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/sheet_config.dart';

class PdfExportService {
  const PdfExportService._();

  static Future<Uint8List> createPdf(
    SheetConfig config,
    List<SlotPhoto> photos,
  ) async {
    final photoBytes = <String, Future<Uint8List>>{};
    final pdf = pw.Document();
    const pointsPerMillimeter = PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(
      config.paperWidthMm * pointsPerMillimeter,
      config.paperHeightMm * pointsPerMillimeter,
      marginAll: 0,
    );
    final bounds = config.slotBounds;
    final cells = <pw.Widget>[];

    for (var index = 0; index < bounds.length; index++) {
      final rect = bounds[index];
      final photo = index < photos.length ? photos[index] : null;
      pw.Widget? imageWidget;

      if (photo?.image != null) {
        final image = photo!.image!;
        final bytes = await (photoBytes[image.path] ??= image.readAsBytes());
        imageWidget = pw.ClipRect(
          child: pw.SizedBox(
            width: rect.widthMm * pointsPerMillimeter,
            height: rect.heightMm * pointsPerMillimeter,
            child: pw.Transform.translate(
              offset: PdfPoint(
                photo.offsetX * rect.widthMm * pointsPerMillimeter,
                -photo.offsetY * rect.heightMm * pointsPerMillimeter,
              ),
              child: pw.Transform.scale(
                scale: photo.scale,
                child: pw.Transform.rotate(
                  angle: photo.quarterTurns * math.pi / 2,
                  child: pw.SizedBox(
                    width: rect.widthMm * pointsPerMillimeter,
                    height: rect.heightMm * pointsPerMillimeter,
                    child: pw.Image(
                      pw.MemoryImage(bytes),
                      fit: photo.fit == PhotoFit.cover
                          ? pw.BoxFit.cover
                          : pw.BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      cells.add(
        pw.Positioned(
          left: rect.leftMm * pointsPerMillimeter,
          top: rect.topMm * pointsPerMillimeter,
          child: pw.SizedBox(
            width: rect.widthMm * pointsPerMillimeter,
            height: rect.heightMm * pointsPerMillimeter,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: config.showCutLines
                    ? pw.Border.all(color: PdfColors.grey600, width: 0.45)
                    : null,
              ),
              child: imageWidget,
            ),
          ),
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(children: cells),
      ),
    );
    return pdf.save();
  }
}
