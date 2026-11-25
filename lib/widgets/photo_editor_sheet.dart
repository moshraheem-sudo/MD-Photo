import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/sheet_config.dart';
import 'photo_image_view.dart';

class PhotoEditorSheet extends StatefulWidget {
  const PhotoEditorSheet({
    required this.photo,
    required this.slotNumber,
    required this.slotAspectRatio,
    required this.onPickReplacement,
    super.key,
  });

  final SlotPhoto photo;
  final int slotNumber;
  final double slotAspectRatio;
  final Future<XFile?> Function(ImageSource source) onPickReplacement;

  @override
  State<PhotoEditorSheet> createState() => _PhotoEditorSheetState();
}

class _PhotoEditorSheetState extends State<PhotoEditorSheet> {
  late SlotPhoto _photo;
  late double _gestureScale;
  late Offset _gestureOffset;
  late Offset _gestureFocalPoint;

  @override
  void initState() {
    super.initState();
    _photo = widget.photo;
    _gestureScale = _photo.scale;
    _gestureOffset = Offset(_photo.offsetX, _photo.offsetY);
    _gestureFocalPoint = Offset.zero;
  }

  void _edit(VoidCallback update) => setState(update);

  void _save() => Navigator.of(context).pop(_photo);

  Future<void> _replace(ImageSource source) async {
    final image = await widget.onPickReplacement(source);
    if (image == null || !mounted) return;
    _edit(() {
      _photo = SlotPhoto(image: image);
      _gestureScale = 1;
      _gestureOffset = Offset.zero;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('حذف الصورة؟'),
        content: const Text('ستُحذف هذه الصورة من خانتها فقط.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إبقاء الصورة'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const SlotPhoto(image: null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: height * 0.9,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تعديل الصورة ${widget.slotNumber}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'اسحب لتحريك الصورة، وقرّب بإصبعين.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 360,
                          maxHeight: 320,
                        ),
                        child: AspectRatio(
                          aspectRatio: widget.slotAspectRatio
                              .clamp(0.55, 1.8)
                              .toDouble(),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF202725),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onScaleStart: (details) {
                                      _gestureScale = _photo.scale;
                                      _gestureOffset = Offset(
                                        _photo.offsetX,
                                        _photo.offsetY,
                                      );
                                      _gestureFocalPoint =
                                          details.localFocalPoint;
                                    },
                                    onScaleUpdate: (details) {
                                      _edit(() {
                                        _photo = _photo.copyWith(
                                          scale: _gestureScale * details.scale,
                                          offsetX:
                                              _gestureOffset.dx +
                                              (details.localFocalPoint.dx -
                                                      _gestureFocalPoint.dx) /
                                                  constraints.maxWidth,
                                          offsetY:
                                              _gestureOffset.dy +
                                              (details.localFocalPoint.dy -
                                                      _gestureFocalPoint.dy) /
                                                  constraints.maxHeight,
                                        );
                                      });
                                    },
                                    child: PhotoImageView(photo: _photo),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'طريقة ملاءمة الصورة',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<PhotoFit>(
                      segments: const [
                        ButtonSegment(
                          value: PhotoFit.cover,
                          icon: Icon(Icons.crop_rounded),
                          label: Text('قص وملء'),
                        ),
                        ButtonSegment(
                          value: PhotoFit.contain,
                          icon: Icon(Icons.fit_screen_outlined),
                          label: Text('إظهار كاملة'),
                        ),
                      ],
                      selected: {_photo.fit},
                      onSelectionChanged: (selection) => _edit(
                        () => _photo = _photo.copyWith(fit: selection.first),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'التكبير · ${(_photo.scale * 100).round()}٪',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'إعادة ضبط الموضع',
                          onPressed:
                              _photo.scale == 1 &&
                                  _photo.offsetX == 0 &&
                                  _photo.offsetY == 0
                              ? null
                              : () => _edit(() {
                                  _photo = _photo.copyWith(
                                    scale: 1,
                                    offsetX: 0,
                                    offsetY: 0,
                                  );
                                }),
                          icon: const Icon(Icons.center_focus_strong_rounded),
                        ),
                      ],
                    ),
                    Slider(
                      value: _photo.scale,
                      min: 1,
                      max: 3,
                      divisions: 20,
                      label: '${(_photo.scale * 100).round()}٪',
                      onChanged: (value) =>
                          _edit(() => _photo = _photo.copyWith(scale: value)),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _edit(
                            () => _photo = _photo.copyWith(
                              quarterTurns: (_photo.quarterTurns + 1) % 4,
                            ),
                          ),
                          icon: const Icon(Icons.rotate_right_rounded),
                          label: const Text('تدوير'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _replace(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('استبدال من المعرض'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _replace(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('التقاط صورة'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _delete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      'حذف الصورة',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('حفظ التعديل'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
