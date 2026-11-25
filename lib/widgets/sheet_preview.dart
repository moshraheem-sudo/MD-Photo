import 'package:flutter/material.dart';

import '../models/sheet_config.dart';
import 'photo_image_view.dart';

class SheetPreview extends StatelessWidget {
  const SheetPreview({
    required this.config,
    required this.photos,
    required this.selectedIndex,
    required this.onSlotTap,
    required this.onSlotReorder,
    super.key,
  });

  final SheetConfig config;
  final List<SlotPhoto> photos;
  final int? selectedIndex;
  final ValueChanged<int> onSlotTap;
  final void Function(int fromIndex, int toIndex) onSlotReorder;

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
                                    index: index,
                                    photo: index < photos.length
                                        ? photos[index]
                                        : null,
                                    selected: selectedIndex == index,
                                    showCutLines: config.showCutLines,
                                    onTap: () => onSlotTap(index),
                                    onReorder: onSlotReorder,
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
    required this.index,
    required this.photo,
    required this.selected,
    required this.showCutLines,
    required this.onTap,
    required this.onReorder,
  });

  final int index;
  final SlotPhoto? photo;
  final bool selected;
  final bool showCutLines;
  final VoidCallback onTap;
  final void Function(int fromIndex, int toIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo?.image != null;
    return LayoutBuilder(
      builder: (context, constraints) => DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) => onReorder(details.data, index),
        builder: (context, candidates, _) {
          final isDropTarget = candidates.isNotEmpty;
          final borderColor = selected || isDropTarget
              ? Theme.of(context).colorScheme.primary
              : showCutLines
              ? const Color(0x995B6864)
              : const Color(0xFFE7ECEA);
          final tile = GestureDetector(
            onTap: onTap,
            child: DecoratedBox(
              key: ValueKey('photo-slot-$index'),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F6),
                border: Border.all(
                  color: borderColor,
                  width: selected || isDropTarget ? 2 : 0.8,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPhoto)
                    PhotoImageView(photo: photo!)
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
                  if (isDropTarget)
                    const Center(
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                ],
              ),
            ),
          );
          return LongPressDraggable<int>(
            data: index,
            maxSimultaneousDrags: hasPhoto ? 1 : 0,
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: constraints.maxWidth.clamp(72, 180).toDouble(),
                height: constraints.maxHeight.clamp(72, 220).toDouble(),
                child: PhotoImageView(photo: photo!),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: tile),
            child: tile,
          );
        },
      ),
    );
  }
}
