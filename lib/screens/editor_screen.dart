import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../models/sheet_config.dart';
import '../services/pdf_export_service.dart';
import '../widgets/sheet_preview.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

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
    _config = const SheetConfig();
    _photos = List<SlotPhoto>.generate(
      _config.slotCount,
      (_) => const SlotPhoto(image: null),
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

  void _updateSelectedPhoto(SlotPhoto updated) {
    final index = _selectedIndex;
    if (index == null) return;
    _saveUndoPoint();
    setState(() => _photos[index] = updated);
  }

  void _removeSelectedPhoto() {
    final index = _selectedIndex;
    if (index == null) return;
    _saveUndoPoint();
    setState(() {
      _photos[index] = const SlotPhoto(image: null);
      _selectedIndex = null;
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presets.map((preset) {
                  final selected =
                      _config.rows == preset.rows &&
                      _config.columns == preset.columns;
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: selected,
                    onSelected: (_) {
                      _applyConfig(
                        _config.copyWith(
                          rows: preset.rows,
                          columns: preset.columns,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
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
                const SizedBox(height: 18),
                Text(
                  'حجم الورق',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('A4'),
                      selected: pending.paperSize == PaperSize.a4,
                      onSelected: (_) => updateSheet(
                        () =>
                            pending = pending.copyWith(paperSize: PaperSize.a4),
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('A5'),
                      selected: pending.paperSize == PaperSize.a5,
                      onSelected: (_) => updateSheet(
                        () =>
                            pending = pending.copyWith(paperSize: PaperSize.a5),
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('مخصص'),
                      selected: pending.paperSize == PaperSize.custom,
                      onSelected: (_) async {
                        final size = await _askCustomSize(
                          pending.customWidthMm,
                          pending.customHeightMm,
                        );
                        if (size != null) {
                          updateSheet(
                            () => pending = pending.copyWith(
                              paperSize: PaperSize.custom,
                              customWidthMm: size.$1,
                              customHeightMm: size.$2,
                            ),
                          );
                        }
                      },
                    ),
                  ],
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
                const SizedBox(height: 18),
                Text(
                  'التخطيط · ${pending.rows} × ${pending.columns}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.map((preset) {
                    final selected =
                        pending.rows == preset.rows &&
                        pending.columns == preset.columns;
                    return ChoiceChip(
                      label: Text(preset.label),
                      selected: selected,
                      onSelected: (_) => updateSheet(
                        () => pending = pending.copyWith(
                          rows: preset.rows,
                          columns: preset.columns,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
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
    final selectedPhoto = _selectedIndex == null
        ? null
        : _photos[_selectedIndex!];
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
                      onSlotTap: (index) {
                        final photo = _photos[index];
                        if (photo.image == null) {
                          setState(() => _selectedIndex = index);
                          _pickOne(slotIndex: index);
                        } else {
                          setState(() => _selectedIndex = index);
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
                    const SizedBox(height: 16),
                    _buildMainActions(context),
                    if (selectedPhoto?.image != null) ...[
                      const SizedBox(height: 12),
                      _buildPhotoControls(context, selectedPhoto!),
                    ],
                    const SizedBox(height: 12),
                    _buildLayoutAndSettings(context),
                    const SizedBox(height: 14),
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
                'اختر الصور، اضبط التخطيط، وصدّرها بدقة عالية.',
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

  void _clearSheet() {
    if (_filledSlots == 0) return;
    _saveUndoPoint();
    setState(() {
      _photos = List<SlotPhoto>.generate(
        _config.slotCount,
        (_) => const SlotPhoto(image: null),
      );
      _selectedIndex = null;
    });
  }

  Widget _buildPhotoControls(BuildContext context, SlotPhoto photo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تعديل الصورة ${(_selectedIndex ?? 0) + 1}',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _updateSelectedPhoto(
                    photo.copyWith(
                      fit: photo.fit == PhotoFit.cover
                          ? PhotoFit.contain
                          : PhotoFit.cover,
                    ),
                  ),
                  icon: Icon(
                    photo.fit == PhotoFit.cover
                        ? Icons.fit_screen_outlined
                        : Icons.crop_rounded,
                  ),
                  label: Text(
                    photo.fit == PhotoFit.cover
                        ? 'احتواء الصورة'
                        : 'ملء الإطار',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _updateSelectedPhoto(
                    photo.copyWith(quarterTurns: (photo.quarterTurns + 1) % 4),
                  ),
                  icon: const Icon(Icons.rotate_right_rounded),
                  label: const Text('تدوير'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickOne(slotIndex: _selectedIndex!),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('استبدال'),
                ),
                IconButton(
                  tooltip: 'حذف الصورة',
                  onPressed: _removeSelectedPhoto,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Theme.of(context).colorScheme.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutAndSettings(BuildContext context) {
    final selected = _presets.where(
      (preset) =>
          preset.rows == _config.rows && preset.columns == _config.columns,
    );
    final label = selected.isEmpty ? 'مخصص' : selected.first.label;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showLayoutPicker,
            icon: const Icon(Icons.grid_view_rounded),
            label: Text(label, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showSettings,
            icon: const Icon(Icons.straighten_rounded),
            label: const Text('إعدادات الورق'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: _isExporting ? null : _showExportOptions,
      icon: _isExporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(_isExporting ? 'جارٍ تجهيز الملف…' : 'تصدير PDF أو طباعة'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF163A35),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
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
