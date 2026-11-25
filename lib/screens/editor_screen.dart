import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../models/sheet_config.dart';
import '../services/pdf_export_service.dart';
import 'pdf_preview_screen.dart';
import '../widgets/photo_editor_sheet.dart';
import '../widgets/sheet_preview.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    this.initialConfig = const SheetConfig(),
    this.initialPhotos = const [],
  });

  final SheetConfig initialConfig;
  final List<SlotPhoto> initialPhotos;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const _presets = <_LayoutPreset>[
    _LayoutPreset('صورة كاملة', 1, 1),
    _LayoutPreset('صورتان', 1, 2),
    _LayoutPreset('صورتان طوليًا', 2, 1),
    _LayoutPreset('٤ صور', 2, 2),
    _LayoutPreset('٦ صور', 3, 2),
    _LayoutPreset('٨ صور', 4, 2),
    _LayoutPreset('١٢ صورة', 4, 3),
    _LayoutPreset('١٦ صورة', 4, 4),
  ];

  final ImagePicker _picker = ImagePicker();
  final List<_Draft> _undoStack = [];
  final List<_Draft> _redoStack = [];
  late SheetConfig _config;
  late List<SlotPhoto> _photos;
  int? _selectedIndex;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _photos = List<SlotPhoto>.generate(
      _config.slotCount,
      (index) => index < widget.initialPhotos.length
          ? widget.initialPhotos[index]
          : const SlotPhoto(image: null),
    );
  }

  int get _filledSlots => _photos.where((photo) => photo.image != null).length;

  void _saveUndoPoint() {
    _undoStack.add(_Draft(_config, List<SlotPhoto>.of(_photos)));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_Draft(_config, List<SlotPhoto>.of(_photos)));
      final previous = _undoStack.removeLast();
      _config = previous.config;
      _photos = previous.photos;
      _selectedIndex = null;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_Draft(_config, List<SlotPhoto>.of(_photos)));
      final next = _redoStack.removeLast();
      _config = next.config;
      _photos = next.photos;
      _selectedIndex = null;
    });
  }

  void _applyConfig(SheetConfig next) {
    _saveUndoPoint();
    setState(() {
      _config = next;
      _photos = List<SlotPhoto>.generate(
        next.slotCount,
        (index) => index < _photos.length
            ? _photos[index]
            : const SlotPhoto(image: null),
      );
      if (_selectedIndex != null && _selectedIndex! >= next.slotCount) {
        _selectedIndex = null;
      }
    });
  }

  Future<void> _pickOne({
    required int slotIndex,
    ImageSource source = ImageSource.gallery,
    bool fillAll = false,
  }) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 94,
        maxWidth: 3200,
      );
      if (image == null || !mounted) return;
      _saveUndoPoint();
      setState(() {
        if (fillAll) {
          _photos = List<SlotPhoto>.generate(
            _photos.length,
            (_) => SlotPhoto(image: image),
          );
        } else {
          _photos[slotIndex] = SlotPhoto(image: image);
          _selectedIndex = slotIndex;
        }
      });
    } catch (error) {
      if (mounted) _showMessage('تعذر فتح الصورة: $error');
    }
  }

  Future<void> _pickMultiple() async {
    final start =
        _selectedIndex ?? _photos.indexWhere((photo) => photo.image == null);
    if (start < 0 || start >= _photos.length) {
      _showMessage('لا توجد خانات فارغة. اختر خانة لاستبدال صورتها.');
      return;
    }

    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 94,
        maxWidth: 3200,
      );
      if (images.isEmpty || !mounted) return;
      final end = math.min(start + images.length, _photos.length);
      if (end <= start) {
        _showMessage('لا توجد خانات متاحة. غيّر تخطيط الورقة أولاً.');
        return;
      }

      _saveUndoPoint();
      setState(() {
        for (var index = start; index < end; index++) {
          _photos[index] = SlotPhoto(image: images[index - start]);
        }
        _selectedIndex = start;
      });
      if (images.length > end - start) {
        _showMessage(
          'أُضيفت ${end - start} صور؛ بقية الصور لم تتسع لها الخانات.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage('تعذر اختيار الصور: $error');
    }
  }

  Future<XFile?> _pickPhotoForEditor(ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        imageQuality: 94,
        maxWidth: 3200,
      );
    } catch (error) {
      if (mounted) _showMessage('تعذر فتح الصورة: $error');
      return null;
    }
  }

  Future<void> _openPhotoEditor(int index) async {
    setState(() => _selectedIndex = index);
    final editedPhoto = await showModalBottomSheet<SlotPhoto>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => PhotoEditorSheet(
        photo: _photos[index],
        slotNumber: index + 1,
        slotAspectRatio: (_config.slotWidthMm / _config.slotHeightMm)
            .clamp(0.55, 1.8)
            .toDouble(),
        onPickReplacement: _pickPhotoForEditor,
      ),
    );
    if (editedPhoto == null || !mounted) return;

    _saveUndoPoint();
    setState(() {
      _photos[index] = editedPhoto;
      _selectedIndex = editedPhoto.image == null ? null : index;
    });
  }

  void _reorderPhotos(int fromIndex, int toIndex) {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= _photos.length ||
        toIndex >= _photos.length) {
      return;
    }

    _saveUndoPoint();
    setState(() {
      final movedPhoto = _photos.removeAt(fromIndex);
      _photos.insert(toIndex, movedPhoto);
      final selectedIndex = _selectedIndex;
      if (selectedIndex != null) {
        if (selectedIndex == fromIndex) {
          _selectedIndex = toIndex;
        } else if (fromIndex < selectedIndex && toIndex >= selectedIndex) {
          _selectedIndex = selectedIndex - 1;
        } else if (fromIndex > selectedIndex && toIndex <= selectedIndex) {
          _selectedIndex = selectedIndex + 1;
        }
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLayoutPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تقسيم الورقة',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'اختر عدد الصور وطريقة ترتيبها.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _presets.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.45,
                ),
                itemBuilder: (context, index) {
                  final preset = _presets[index];
                  final selected =
                      _config.rows == preset.rows &&
                      _config.columns == preset.columns;
                  final colors = Theme.of(context).colorScheme;
                  return Material(
                    color: selected ? colors.primaryContainer : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: selected
                            ? colors.primary
                            : const Color(0xFFE2E9E7),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        _applyConfig(
                          _config.copyWith(
                            rows: preset.rows,
                            columns: preset.columns,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 38,
                              height: 36,
                              child: GridView.count(
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: preset.columns,
                                crossAxisSpacing: 2,
                                mainAxisSpacing: 2,
                                children: List<Widget>.generate(
                                  preset.rows * preset.columns,
                                  (_) => DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? colors.primary
                                          : colors.primary.withValues(
                                              alpha: 0.18,
                                            ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: selected
                                              ? colors.onPrimaryContainer
                                              : colors.onSurface,
                                        ),
                                  ),
                                  Text(
                                    '${preset.rows} × ${preset.columns}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: colors.primary,
                                size: 19,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSettings() async {
    var pending = _config;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات الطباعة',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'اضبط حجم الصفحة واتجاهها وهوامش الطباعة.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'حجم الورق',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<PaperSize>(
                  segments: const [
                    ButtonSegment(value: PaperSize.a4, label: Text('A4')),
                    ButtonSegment(value: PaperSize.a5, label: Text('A5')),
                    ButtonSegment(value: PaperSize.custom, label: Text('مخصص')),
                  ],
                  selected: {pending.paperSize},
                  onSelectionChanged: (selection) async {
                    final size = selection.first;
                    if (size != PaperSize.custom) {
                      updateSheet(
                        () => pending = pending.copyWith(paperSize: size),
                      );
                      return;
                    }

                    final dimensions = await _askCustomSize(
                      pending.customWidthMm,
                      pending.customHeightMm,
                    );
                    if (dimensions != null) {
                      updateSheet(
                        () => pending = pending.copyWith(
                          paperSize: PaperSize.custom,
                          customWidthMm: dimensions.$1,
                          customHeightMm: dimensions.$2,
                        ),
                      );
                    }
                  },
                ),
                if (pending.paperSize == PaperSize.custom)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${pending.customWidthMm.toStringAsFixed(0)} × '
                      '${pending.customHeightMm.toStringAsFixed(0)} مم',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  'اتجاه الورق',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('عمودي')),
                    ButtonSegment(value: true, label: Text('أفقي')),
                  ],
                  selected: {pending.landscape},
                  onSelectionChanged: (value) => updateSheet(
                    () => pending = pending.copyWith(landscape: value.first),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _SettingSlider(
                  title: 'الهامش · ${pending.marginMm.toStringAsFixed(0)} مم',
                  value: pending.marginMm,
                  max: 20,
                  onChanged: (value) => updateSheet(
                    () => pending = pending.copyWith(marginMm: value),
                  ),
                ),
                _SettingSlider(
                  title:
                      'المسافة بين الصور · '
                      '${pending.spacingMm.toStringAsFixed(0)} مم',
                  value: pending.spacingMm,
                  max: 12,
                  onChanged: (value) => updateSheet(
                    () => pending = pending.copyWith(spacingMm: value),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إظهار خطوط القص'),
                  value: pending.showCutLines,
                  onChanged: (value) => updateSheet(
                    () => pending = pending.copyWith(showCutLines: value),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      _applyConfig(pending);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('تطبيق الإعدادات'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<(double, double)?> _askCustomSize(
    double initialWidth,
    double initialHeight,
  ) async {
    final widthController = TextEditingController(
      text: initialWidth.toStringAsFixed(0),
    );
    final heightController = TextEditingController(
      text: initialHeight.toStringAsFixed(0),
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<(double, double)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مقاس مخصص'),
        content: Form(
          key: formKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'العرض مم'),
                  validator: _validateDimension,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'الارتفاع مم'),
                  validator: _validateDimension,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, (
                double.parse(widthController.text),
                double.parse(heightController.text),
              ));
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    widthController.dispose();
    heightController.dispose();
    return result;
  }

  String? _validateDimension(String? value) {
    final dimension = double.tryParse(value ?? '');
    if (dimension == null || dimension < 50 || dimension > 1000) {
      return 'أدخل قيمة من 50 إلى 1000';
    }
    return null;
  }

  Future<void> _showExportOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تصدير الورقة',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('PDF بالحجم الفعلي للورق، جاهز للطباعة أو المشاركة.'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.preview_outlined),
                title: const Text('معاينة ملف الطباعة'),
                subtitle: const Text('راجع شكل الورقة قبل الحفظ أو الطباعة'),
                onTap: () {
                  Navigator.pop(context);
                  _previewPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: const Text('طباعة'),
                subtitle: const Text('اختر الطابعة وإعدادات الطباعة'),
                onTap: () {
                  Navigator.pop(context);
                  _printPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('مشاركة PDF'),
                subtitle: const Text('حفظ الملف أو إرساله إلى تطبيق آخر'),
                onTap: () {
                  Navigator.pop(context);
                  _sharePdf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _previewPdf() async {
    if (_filledSlots == 0) {
      _showMessage('أضف صورة واحدة على الأقل لمعاينة ملف الطباعة.');
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PdfPreviewScreen(
          config: _config,
          photos: List<SlotPhoto>.of(_photos),
        ),
      ),
    );
  }

  Future<void> _printPdf() async {
    if (_filledSlots == 0) {
      _showMessage('أضف صورة واحدة على الأقل قبل الطباعة.');
      return;
    }
    final config = _config;
    final photos = List<SlotPhoto>.of(_photos);
    setState(() => _isExporting = true);
    try {
      await Printing.layoutPdf(
        name: 'md-photo-sheet.pdf',
        onLayout: (_) => PdfExportService.createPdf(config, photos),
      );
    } catch (error) {
      if (mounted) _showMessage('تعذرت الطباعة: $error');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_filledSlots == 0) {
      _showMessage('أضف صورة واحدة على الأقل قبل التصدير.');
      return;
    }
    final config = _config;
    final photos = List<SlotPhoto>.of(_photos);
    setState(() => _isExporting = true);
    try {
      final bytes = await PdfExportService.createPdf(config, photos);
      await Printing.sharePdf(bytes: bytes, filename: 'md-photo-sheet.pdf');
    } catch (error) {
      if (mounted) _showMessage('تعذر إنشاء ملف PDF: $error');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.photo_size_select_large_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MD Photo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'استوديو تجهيز الصور للطباعة',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تراجع',
            onPressed: _undoStack.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'إعادة',
            onPressed: _redoStack.isEmpty ? null : _redo,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: 'إعدادات الورق',
            onPressed: _showSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeading(context),
                    const SizedBox(height: 16),
                    SheetPreview(
                      config: _config,
                      photos: _photos,
                      selectedIndex: _selectedIndex,
                      onSlotReorder: _reorderPhotos,
                      onSlotTap: (index) {
                        final photo = _photos[index];
                        if (photo.image == null) {
                          setState(() => _selectedIndex = index);
                          _pickOne(slotIndex: index);
                        } else {
                          _openPhotoEditor(index);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '$_paperSizeLabel  ·  '
                        '${_config.paperWidthMm.toStringAsFixed(0)} × '
                        '${_config.paperHeightMm.toStringAsFixed(0)} مم',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _filledSlots > 1
                            ? 'اضغط على الصورة لتعديلها · اضغط مطولاً واسحب لترتيبها'
                            : 'اضغط على الصورة لتعديلها',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMainActions(context),
                    const SizedBox(height: 12),
                    _buildLayoutAndSettings(context),
                    const SizedBox(height: 12),
                    _buildExportButton(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _paperSizeLabel => switch (_config.paperSize) {
    PaperSize.a4 => 'A4',
    PaperSize.a5 => 'A5',
    PaperSize.custom => 'مقاس مخصص',
  };

  Widget _buildHeading(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رتّب صورك للطباعة',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'المس أي صورة لتعديل القصّ أو التكبير أو الاتجاه.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$_filledSlots / ${_config.slotCount}',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _pickMultiple,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('إضافة صور'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () {
            final target =
                _selectedIndex ??
                _photos.indexWhere((photo) => photo.image == null);
            if (target < 0) {
              _showMessage('اختر خانة لاستبدال صورتها أو غيّر التخطيط.');
              return;
            }
            _pickOne(slotIndex: target, source: ImageSource.camera);
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(54, 50),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Icon(Icons.camera_alt_outlined),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'خيارات الصور',
          onSelected: (value) {
            if (value == 'repeat') {
              _pickOne(slotIndex: 0, fillAll: true);
            } else if (value == 'clear') {
              _clearSheet();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'repeat',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.copy_all_outlined),
                title: Text('تكرار صورة في كل الخانات'),
              ),
            ),
            PopupMenuItem(
              value: 'clear',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline),
                title: Text('مسح جميع الصور'),
              ),
            ),
          ],
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE0E8E5)),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.more_horiz_rounded),
          ),
        ),
      ],
    );
  }

  Future<void> _clearSheet() async {
    if (_filledSlots == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح جميع الصور؟'),
        content: const Text('سيتم حذف الصور من الورقة، ويمكنك التراجع بعدها.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح الصور'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _saveUndoPoint();
    setState(() {
      _photos = List<SlotPhoto>.generate(
        _config.slotCount,
        (_) => const SlotPhoto(image: null),
      );
      _selectedIndex = null;
    });
  }

  Widget _buildLayoutAndSettings(BuildContext context) {
    final selected = _presets.where(
      (preset) =>
          preset.rows == _config.rows && preset.columns == _config.columns,
    );
    final label = selected.isEmpty ? 'مخصص' : selected.first.label;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.grid_view_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: const Text('تقسيم الصور'),
            subtitle: Text('$label · ${_config.rows} × ${_config.columns}'),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: _showLayoutPicker,
          ),
          const Divider(height: 1, indent: 18, endIndent: 18),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                Icons.straighten_rounded,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: const Text('مقاس الورق والطباعة'),
            subtitle: Text(
              '$_paperSizeLabel · ${_config.landscape ? 'أفقي' : 'عمودي'} · '
              '${_config.marginMm.round()} مم هامش',
            ),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: _showSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _filledSlots == 0 ? null : _previewPdf,
            icon: const Icon(Icons.preview_outlined),
            label: const Text('معاينة PDF'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: _isExporting ? null : _showExportOptions,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            label: Text(_isExporting ? 'جارٍ التجهيز…' : 'حفظ وطباعة'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF163A35),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.title,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        Slider(
          value: value.clamp(0, max),
          min: 0,
          max: max,
          divisions: max.toInt(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _LayoutPreset {
  const _LayoutPreset(this.label, this.rows, this.columns);

  final String label;
  final int rows;
  final int columns;
}

class _Draft {
  const _Draft(this.config, this.photos);

  final SheetConfig config;
  final List<SlotPhoto> photos;
}
