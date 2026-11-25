import 'package:image_picker/image_picker.dart';

enum PaperSize { a4, a5, custom }

enum PhotoFit { cover, contain }

class SheetConfig {
  const SheetConfig({
    this.paperSize = PaperSize.a4,
    this.landscape = false,
    this.customWidthMm = 210,
    this.customHeightMm = 297,
    this.rows = 2,
    this.columns = 2,
    this.marginMm = 8,
    this.spacingMm = 3,
    this.showCutLines = true,
  });

  final PaperSize paperSize;
  final bool landscape;
  final double customWidthMm;
  final double customHeightMm;
  final int rows;
  final int columns;
  final double marginMm;
  final double spacingMm;
  final bool showCutLines;

  double get paperWidthMm {
    final width = switch (paperSize) {
      PaperSize.a4 => 210.0,
      PaperSize.a5 => 148.0,
      PaperSize.custom => customWidthMm,
    };
    final height = switch (paperSize) {
      PaperSize.a4 => 297.0,
      PaperSize.a5 => 210.0,
      PaperSize.custom => customHeightMm,
    };
    return landscape ? height : width;
  }

  double get paperHeightMm {
    final width = switch (paperSize) {
      PaperSize.a4 => 210.0,
      PaperSize.a5 => 148.0,
      PaperSize.custom => customWidthMm,
    };
    final height = switch (paperSize) {
      PaperSize.a4 => 297.0,
      PaperSize.a5 => 210.0,
      PaperSize.custom => customHeightMm,
    };
    return landscape ? width : height;
  }

  int get slotCount => rows * columns;

  double get slotWidthMm =>
      (paperWidthMm - (2 * marginMm) - ((columns - 1) * spacingMm)) / columns;

  double get slotHeightMm =>
      (paperHeightMm - (2 * marginMm) - ((rows - 1) * spacingMm)) / rows;

  List<SlotBounds> get slotBounds => List<SlotBounds>.generate(slotCount, (i) {
    final row = i ~/ columns;
    final column = i % columns;
    return SlotBounds(
      leftMm: marginMm + column * (slotWidthMm + spacingMm),
      topMm: marginMm + row * (slotHeightMm + spacingMm),
      widthMm: slotWidthMm,
      heightMm: slotHeightMm,
    );
  });

  SheetConfig copyWith({
    PaperSize? paperSize,
    bool? landscape,
    double? customWidthMm,
    double? customHeightMm,
    int? rows,
    int? columns,
    double? marginMm,
    double? spacingMm,
    bool? showCutLines,
  }) {
    return SheetConfig(
      paperSize: paperSize ?? this.paperSize,
      landscape: landscape ?? this.landscape,
      customWidthMm: customWidthMm ?? this.customWidthMm,
      customHeightMm: customHeightMm ?? this.customHeightMm,
      rows: (rows ?? this.rows).clamp(1, 8),
      columns: (columns ?? this.columns).clamp(1, 8),
      marginMm: (marginMm ?? this.marginMm).clamp(0, 30),
      spacingMm: (spacingMm ?? this.spacingMm).clamp(0, 20),
      showCutLines: showCutLines ?? this.showCutLines,
    );
  }
}

class SlotBounds {
  const SlotBounds({
    required this.leftMm,
    required this.topMm,
    required this.widthMm,
    required this.heightMm,
  });

  final double leftMm;
  final double topMm;
  final double widthMm;
  final double heightMm;
}

class SlotPhoto {
  const SlotPhoto({
    required this.image,
    this.fit = PhotoFit.cover,
    this.quarterTurns = 0,
  });

  final XFile? image;
  final PhotoFit fit;
  final int quarterTurns;

  SlotPhoto copyWith({
    XFile? image,
    PhotoFit? fit,
    int? quarterTurns,
    bool clearImage = false,
  }) {
    return SlotPhoto(
      image: clearImage ? null : image ?? this.image,
      fit: fit ?? this.fit,
      quarterTurns: quarterTurns ?? this.quarterTurns,
    );
  }
}
