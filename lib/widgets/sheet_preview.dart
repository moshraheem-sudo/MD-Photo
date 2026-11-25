import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/sheet_config.dart';

class SheetPreview extends StatelessWidget {
  const SheetPreview({
    required this.config,
    required this.photos,
    required this.selectedIndex,
    required this.onSlotTap,
    super.key,
  });

  final SheetConfig config;
  final List<SlotPhoto> photos;
  final int? selectedIndex;
  final ValueChanged<int> onSlotTap;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = config.paperWidthMm / config.paperHeightMm;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final marginX =
                  constraints.maxWidth * config.marginMm / config.paperWidthMm;
              final marginY =
                  constraints.maxHeight *
                  config.marginMm /
                  config.paperHeightMm;
              final gapX =
                  constraints.maxWidth * config.spacingMm / config.paperWidthMm;
              final gapY =
                  constraints.maxHeight *
                  config.spacingMm /
                  config.paperHeightMm;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFD8E1DE)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x180D302A),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    marginX,
                    marginY,
                    marginX,
                    marginY,
                  ),
                  child: Column(
                    children: List<Widget>.generate(config.rows, (row) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: row == config.rows - 1 ? 0 : gapY,
                          ),
                          child: Row(
                            children: List<Widget>.generate(config.columns, (
                              column,
                            ) {
                              final index = row * config.columns + column;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    end: column == config.columns - 1
                                        ? 0
                                        : gapX,
                                  ),
                                  child: _PhotoSlot(
                                    photo: index < photos.length
                                        ? photos[index]
                                        : null,
                                    selected: selectedIndex == index,
                                    showCutLines: config.showCutLines,
                                    onTap: () => onSlotTap(index),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.photo,
    required this.selected,
    required this.showCutLines,
    required this.onTap,
  });

  final SlotPhoto? photo;
  final bool selected;
  final bool showCutLines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo?.image != null;
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : showCutLines
        ? const Color(0x995B6864)
        : const Color(0xFFE7ECEA);

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F6),
          border: Border.all(color: borderColor, width: selected ? 2 : 0.8),
        ),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhoto)
                Transform.rotate(
                  angle: photo!.quarterTurns * math.pi / 2,
                  child: Image.file(
                    File(photo!.image!.path),
                    fit: photo!.fit == PhotoFit.cover
                        ? BoxFit.cover
                        : BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE1E9E6)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        Icons.add_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              if (selected && hasPhoto)
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
