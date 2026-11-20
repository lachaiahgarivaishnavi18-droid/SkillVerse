part of 'main.dart';

Future<Uint8List> buildCertificatePdf(
  CourseCertificate certificate, {
  String? displayName,
  String? displayCourseTitle,
  DateTime? displayDate,
}) async {
  final name = displayName ?? certificate.studentName;
  final title = displayCourseTitle ?? certificate.courseName;
  final recordedDate = certificate.completionDateKnown
      ? certificate.completedAt.toLocal()
      : null;
  final date = displayDate ?? recordedDate;
  final relabeled = title != certificate.courseName;
  final differentDate =
      date != null && !DateUtils.isSameDay(date, recordedDate);
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final fallback = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: font,
      bold: font,
      fontFallback: [fallback],
    ),
    title: '${certificate.courseName} completion record',
    author: 'Skillverse',
  );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(28),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blue800, width: 2),
        ),
        child: pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Skillverse',
                style: pw.TextStyle(
                  fontSize: 28,
                  color: PdfColors.blue800,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'COURSE COMPLETION RECORD',
                style: const pw.TextStyle(fontSize: 15),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'This certifies that',
                style: const pw.TextStyle(fontSize: 15),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                name,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'completed all lessons and passed the final assessment for the recorded course',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 13),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                relabeled ? 'Display title  $title' : certificate.courseName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 22,
                  color: PdfColors.blue900,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 18),
              if (relabeled)
                pw.Text(
                  'Recorded course  ${certificate.courseName}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              if (differentDate)
                pw.Text(
                  'Display date  ${_formatDate(date)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              pw.Text(
                recordedDate == null
                    ? 'Recorded completion date unavailable'
                    : 'Recorded completion  ${_formatDate(recordedDate)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Skillverse learning record · No external accreditation',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Certificate ID  ${certificate.id}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return doc.save();
}

void _previewCertificate(BuildContext context, AppStore store, Course course) {
  final record = store.certificateFor(course);
  if (record == null) return;
  showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: _sheetMotion(context),
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) =>
        _CertificateEditor(store: store, course: course, record: record),
  );
}

class _CertificateEditor extends StatefulWidget {
  const _CertificateEditor({
    required this.store,
    required this.course,
    required this.record,
  });

  final AppStore store;
  final Course course;
  final CourseCertificate record;

  @override
  State<_CertificateEditor> createState() => _CertificateEditorState();
}

class _CertificateEditorState extends State<_CertificateEditor> {
  static const _channel = MethodChannel('skillverse/certificates');
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.record.studentName);
  late final _title = TextEditingController(text: widget.record.courseName);
  DateTime? _displayDate;
  String? _exported;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  CourseCertificate _currentRecord() {
    final current = widget.store.certificateFor(widget.course);
    if (current == null ||
        current.userId != widget.record.userId ||
        current.id != widget.record.id) {
      throw StateError('The completion record is no longer available.');
    }
    return current;
  }

  Future<Uint8List> _pdf() => buildCertificatePdf(
    _currentRecord(),
    displayName: _name.text.trim(),
    displayCourseTitle: _title.text.trim(),
    displayDate: _displayDate,
  );

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } on StateError {
      _message(
        'This completion record is no longer available. Reopen Certificates and try again.',
      );
    } catch (_) {
      _message(
        'Could not complete the PDF action. Try again or choose a different save location.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _changed() => setState(() => _exported = null);

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final recorded = widget.record.completedAt.toLocal();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: today,
      initialDate:
          _displayDate ??
          (recorded.isAfter(today) || recorded.year < 1900 ? today : recorded),
    );
    if (mounted && selected != null) {
      setState(() {
        _displayDate = selected;
        _exported = null;
      });
    }
  }

  Future<void> _export() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      final bytes = await _pdf();
      final filename = 'skillverse_${widget.record.id}.pdf';
      final String? saved;
      if (_usesAndroidServices) {
        saved = await _channel.invokeMethod<String>('savePdf', {
          'bytes': bytes,
          'filename': filename,
        });
      } else {
        final directory =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        saved = file.path;
      }
      if (saved == null || !mounted) return;
      setState(() => _exported = saved);
      _message('Certificate PDF saved.');
    });
  }

  Future<void> _viewPdf({String? exported}) async {
    if (exported == null && !_form.currentState!.validate()) return;
    await _run(() async {
      _currentRecord();
      final args = exported == null
          ? {'bytes': await _pdf()}
          : {'uri': exported};
      final image = await _channel.invokeMethod<Uint8List>('renderPdf', args);
      if (!mounted || image == null) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  exported == null ? 'PDF preview' : 'Exported certificate',
                ),
                trailing: IconButton(
                  tooltip: 'Close PDF',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.memory(
                    image,
                    fit: BoxFit.contain,
                    semanticLabel: 'Rendered course completion record',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final recorded = widget.record.completionDateKnown
        ? _formatDate(widget.record.completedAt.toLocal())
        : 'Date unavailable';
    final displayed = _displayDate == null
        ? recorded
        : _formatDate(_displayDate!);
    String? validate(String? text) =>
        text == null || text.trim().isEmpty ? 'Enter a value to print.' : null;
    final exported = _exported;
    return _GuardUnsaved(
      dirty:
          exported == null &&
          (_name.text != widget.record.studentName ||
              _title.text != widget.record.courseName ||
              _displayDate != null),
      busy: _busy,
      child: FractionallySizedBox(
        heightFactor: .88,
        child: Form(
          key: _form,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close certificate preview',
                  onPressed: _busy ? null : () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              const _SectionHeading(title: 'Preview certificate'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        color: _blue,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Skillverse course completion record',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(_name.text.trim(), textAlign: TextAlign.center),
                      Text(_title.text.trim(), textAlign: TextAlign.center),
                      Text(displayed),
                      const SizedBox(height: 8),
                      Text(
                        'Recorded course · ${widget.record.courseName}',
                        textAlign: TextAlign.center,
                      ),
                      Text('Recorded completion · $recorded'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Edits change the printed presentation. The PDF also includes the earned course and its recorded completion date.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                enabled: !_busy,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Certificate name',
                ),
                validator: validate,
                onChanged: (_) => _changed(),
              ),
              TextFormField(
                controller: _title,
                textInputAction: TextInputAction.done,
                enabled: !_busy,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Display course title',
                ),
                validator: validate,
                onChanged: (_) => _changed(),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Display completion date'),
                subtitle: Text(displayed),
                trailing: IconButton(
                  tooltip: 'Use recorded date',
                  onPressed: _busy || _displayDate == null
                      ? null
                      : () => setState(() {
                          _displayDate = null;
                          _exported = null;
                        }),
                  icon: const Icon(Icons.restore),
                ),
                onTap: _busy ? null : _pickDate,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_usesAndroidServices)
                    OutlinedButton(
                      onPressed: _busy ? null : _viewPdf,
                      child: const Text('Preview PDF'),
                    ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.download),
                    label: Text(_busy ? 'Working…' : 'Generate and save PDF'),
                  ),
                ],
              ),
              if (exported != null && _usesAndroidServices) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _viewPdf(exported: exported),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Open PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              _currentRecord();
                              await _channel.invokeMethod<void>('sharePdf', {
                                'uri': exported,
                              });
                            }),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share PDF'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
