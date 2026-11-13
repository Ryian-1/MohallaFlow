// MOHALLAFLOW_DOCUMENT_REPOSITORY_SCREEN_BEGIN
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Secure native Flutter document repository. Governance documents are versioned;
/// resident uploads remain private to their owner and the colony Admin.
class DocumentRepositoryScreen extends StatefulWidget {
  const DocumentRepositoryScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.isAdmin,
    this.isResident = false,
    this.roleKey = 'resident',
    this.adminName,
    this.residentId,
    this.residentName,
  });
  final String colonyId;
  final String colonyName;
  final bool isAdmin;
  final bool isResident;
  final String roleKey;
  final String? adminName;
  final String? residentId;
  final String? residentName;
  @override
  State<DocumentRepositoryScreen> createState() =>
      _DocumentRepositoryScreenState();
}

class _DocumentRepositoryScreenState extends State<DocumentRepositoryScreen> {
  static const int _maxBytes = 5 * 1024 * 1024;
  static const List<String> _extensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'docx',
    'xlsx',
  ];
  static const Color _navy = AppTheme.navyBlue;
  static const Color _grey = AppTheme.textGrey;
  static const Color _border = AppTheme.borderGrey;
  final TextEditingController _search = TextEditingController();
  String _searchText = '';
  bool _busy = false;
  double _progress = 0;
  CollectionReference<Map<String, dynamic>> _records(String name) =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection(name);
  CollectionReference<Map<String, dynamic>> _govVersions(String id) =>
      _records('rwaGovernanceDocuments').doc(id).collection('versions');
  CollectionReference<Map<String, dynamic>> _residentVersions(String id) =>
      _records('residentDocuments').doc(id).collection('versions');
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  String _mime(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  String _safeName(String name) => name
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'^\.+'), 'file');
  String _size(Object? value) {
    final n = value is num ? value.toDouble() : 0.0;
    if (n >= 1024 * 1024) return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (n >= 1024) return '${(n / 1024).toStringAsFixed(0)} KB';
    return '${n.toStringAsFixed(0)} bytes';
  }

  DateTime? _dateValue(Object? value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : null;
  String _date(Object? value) {
    final d = _dateValue(value);
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: child,
  );
  Widget _empty(String title, String note) => _panel(
    Column(
      children: [
        const Icon(Icons.folder_open_outlined, color: _grey, size: 30),
        const SizedBox(height: 8),
        AppText(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _navy),
        ),
        const SizedBox(height: 4),
        AppText(
          note,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _grey, fontSize: 11),
        ),
      ],
    ),
  );
  Widget _status(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.lightGrey,
      borderRadius: BorderRadius.circular(20),
    ),
    child: AppText(
      value.replaceAll('_', ' ').toUpperCase(),
      style: const TextStyle(
        color: _navy,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
  Future<void> _audit(
    String action,
    String documentId,
    String title,
    String summary,
  ) async {
    await _records('documentAuditEvents').add({
      'action': action,
      'documentId': documentId,
      'documentTitle': title,
      'summary': summary,
      'actorUid': _uid,
      'actorName': widget.adminName ?? widget.residentName ?? 'Resident',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Uint8List> _readPickedBytes(PlatformFile file) async {
    final expectedLength = await file.length();
    final bytes = await file.readAsBytes();
    if (expectedLength == null ||
        expectedLength != bytes.length ||
        bytes.isEmpty ||
        bytes.length > _maxBytes) {
      throw StateError(
        'The selected file is empty, incomplete or larger than 5 MB.',
      );
    }
    return bytes;
  }

  Future<PlatformFile?> _pickFile() async {
    try {
      // file_picker 12+ uses static pickFile(), PlatformFile.length() and readAsBytes().
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _extensions,
      );
      if (file == null) return null;
      final length = await file.length();
      if (length == null || length <= 0 || length > _maxBytes) {
        _message('Select a file between 1 byte and 5 MB.');
        return null;
      }
      if (!_extensions.contains((file.extension ?? '').toLowerCase())) {
        _message('This file type is not supported.');
        return null;
      }
      return file;
    } catch (e) {
      _message('File selection failed: $e');
      return null;
    }
  }

  // Firestore-native document storage: 512 KiB immutable chunks.
  static const int _chunkBytes = 512 * 1024;

  CollectionReference<Map<String, dynamic>> _fileChunks(
    DocumentReference<Map<String, dynamic>> versionRef,
  ) => versionRef.collection('chunks');

  String _firestoreFilePath(
    DocumentReference<Map<String, dynamic>> versionRef,
  ) => 'firestore://${versionRef.path}';

  int _chunkCountFor(int size) => (size + _chunkBytes - 1) ~/ _chunkBytes;

  void _appendFileChunks(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> versionRef,
    Uint8List bytes,
  ) {
    if (bytes.isEmpty || bytes.length > _maxBytes) {
      throw StateError('File must be between 1 byte and 5 MB.');
    }

    final chunks = _fileChunks(versionRef);
    var index = 0;

    for (var offset = 0; offset < bytes.length; offset += _chunkBytes) {
      final end = (offset + _chunkBytes < bytes.length)
          ? offset + _chunkBytes
          : bytes.length;

      final part = Uint8List.fromList(bytes.sublist(offset, end));

      batch.set(chunks.doc(index.toString().padLeft(4, '0')), {
        'index': index,
        'payload': Blob(part),
        'byteLength': part.length,
        'createdAt': FieldValue.serverTimestamp(),
      });

      index++;
    }
  }

  Future<Uint8List> _readChunkedFile(
    DocumentReference<Map<String, dynamic>> versionRef,
  ) async {
    final versionSnapshot = await versionRef.get();

    if (!versionSnapshot.exists) {
      throw StateError('Document version not found.');
    }

    final version = versionSnapshot.data()!;

    if (version['status'] != 'available' ||
        version['storageBackend'] != 'firestore_chunks') {
      throw StateError(
        'This version is unavailable. Upload a new document version.',
      );
    }

    final expectedCount = (version['chunkCount'] as num?)?.toInt() ?? 0;
    final expectedSize = (version['sizeBytes'] as num?)?.toInt() ?? 0;

    if (expectedCount < 1 ||
        expectedCount > 10 ||
        expectedSize < 1 ||
        expectedSize > _maxBytes) {
      throw StateError('Invalid document metadata.');
    }

    final snapshot = await _fileChunks(versionRef).orderBy('index').get();

    if (snapshot.docs.length != expectedCount) {
      throw StateError(
        'Document is incomplete: expected '
        '$expectedCount chunks, found ${snapshot.docs.length}.',
      );
    }

    final builder = BytesBuilder(copy: false);

    for (var i = 0; i < snapshot.docs.length; i++) {
      final row = snapshot.docs[i].data();
      final payload = row['payload'];

      if (row['index'] != i ||
          payload is! Blob ||
          row['byteLength'] != payload.bytes.length ||
          payload.bytes.isEmpty ||
          payload.bytes.length > _chunkBytes) {
        throw StateError('Document chunk ${i + 1} failed integrity checks.');
      }

      builder.add(payload.bytes);
    }

    final bytes = builder.takeBytes();

    if (bytes.length != expectedSize) {
      throw StateError('Downloaded file size does not match its metadata.');
    }

    return bytes;
  }

  Future<void> _openStoredFile(String storagePath, String fileName) async {
    if (storagePath.isEmpty || !storagePath.startsWith('firestore://')) {
      _message(
        'This is an older Storage reference and has no file in the no-cost repository yet. Upload a new version.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final versionPath = storagePath.substring('firestore://'.length);
      if (!versionPath.startsWith('colonies/${widget.colonyId}/')) {
        throw StateError(
          'File reference does not belong to the selected colony.',
        );
      }
      final versionRef = FirebaseFirestore.instance.doc(versionPath);
      final bytes = await _readChunkedFile(versionRef);
      final directory = await getTemporaryDirectory();
      final safe = _safeName(fileName.isEmpty ? 'document' : fileName);
      final local = File(
        '${directory.path}/${DateTime.now().microsecondsSinceEpoch}_$safe',
      );
      await local.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(local.path);
    } catch (e) {
      _message('Unable to open this document: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadGovernanceVersion(
    DocumentReference<Map<String, dynamic>> documentRef,
    PlatformFile file, {
    String changeNote = 'New file version',
  }) async {
    final bytes = await _readPickedBytes(file);
    final mime = _mime(file.name);
    final existingVersions = await _govVersions(documentRef.id).get();
    final maxVersion = existingVersions.docs.fold<int>(0, (value, item) {
      final number = item.data()['versionNumber'];
      return number is num && number.toInt() > value ? number.toInt() : value;
    });
    final nextVersion = maxVersion + 1;
    final versionRef = _govVersions(documentRef.id).doc();
    final filePath = _firestoreFilePath(versionRef);
    final batch = FirebaseFirestore.instance.batch();
    batch.set(versionRef, {
      'versionNumber': nextVersion,
      'fileName': file.name,
      'mimeType': mime,
      'sizeBytes': bytes.length,
      'storagePath': filePath,
      'storageBackend': 'firestore_chunks',
      'chunkCount': _chunkCountFor(bytes.length),
      'uploadedBy': _uid,
      'uploadedAt': FieldValue.serverTimestamp(),
      'changeNote': changeNote,
      'status': 'available',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _appendFileChunks(batch, versionRef, bytes);
    batch.update(documentRef, {
      'version': nextVersion.toString(),
      'currentVersionId': versionRef.id,
      'currentStoragePath': filePath,
      'storageReference': filePath,
      'fileName': file.name,
      'mimeType': mime,
      'fileSizeBytes': bytes.length,
      'lastUploadedAt': FieldValue.serverTimestamp(),
      'lastUploadedBy': _uid,
      'publicationStatus': 'draft',
      'accessScope': 'admin_only',
      'allowedRoles': ['admin'],
      'residentVisible': false,
      'managerVisible': false,
      'workerVisible': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    final title =
        (await documentRef.get()).data()?['title']?.toString() ?? 'Document';
    try {
      await _audit(
        'version_uploaded',
        documentRef.id,
        title,
        'Uploaded version $nextVersion: ${file.name} using Firestore chunk storage',
      );
    } catch (auditError) {
      _message(
        'Version $nextVersion was uploaded, but its audit event could not be saved: $auditError',
      );
      return;
    }
    _message(
      'Version $nextVersion stored in Firestore. Review access and publish it when ready.',
    );
  }

  Future<void> _createGovernanceDocument() async {
    final title = TextEditingController();
    final category = TextEditingController(text: 'Policy');
    final number = TextEditingController();
    final custodian = TextEditingController(text: widget.adminName ?? 'Admin');
    final notes = TextEditingController();
    final linkedType = TextEditingController();
    final linkedId = TextEditingController();
    final folderPath = TextEditingController(text: 'Governance/General');
    String classification = 'internal';
    DateTime issueDate = DateTime.now();
    DateTime reviewDate = DateTime.now().add(const Duration(days: 365));
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: const AppText('Add document to repository'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _input(title, 'Document title'),
                    _input(
                      category,
                      'Category (policy, contract, invoice, minutes, insurance...)',
                    ),
                    _input(number, 'Document reference / number'),
                    _input(custodian, 'Custodian / responsible person'),
                    DropdownButtonFormField<String>(
                      initialValue: classification,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Classification'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'internal',
                          child: AppText('Internal'),
                        ),
                        DropdownMenuItem(
                          value: 'confidential',
                          child: AppText('Confidential'),
                        ),
                      ],
                      onChanged: (v) =>
                          setDialog(() => classification = v ?? 'internal'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: AppText('Issue: ${_date(issueDate)}')),
                        TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: issueDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setDialog(() => issueDate = d);
                          },
                          child: const AppText('Change'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            'Review / expiry: ${_date(reviewDate)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: reviewDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setDialog(() => reviewDate = d);
                          },
                          child: const AppText('Change'),
                        ),
                      ],
                    ),
                    _input(
                      folderPath,
                      'Folder path (e.g. Governance/Policies)',
                    ),
                    _input(notes, 'Description / handling notes', lines: 3),
                    _input(linkedType, 'Linked record type (optional)'),
                    _input(linkedId, 'Linked record ID (optional)'),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: AppText(
                        'Accepted files: PDF, JPG, PNG, DOCX and XLSX. Maximum 5 MB (stored in Firestore; no Storage bucket required).',
                        style: TextStyle(color: _grey, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const AppText('Continue to file selection'),
              ),
            ],
          ),
        ),
      );
      if (result != true) return;
      if (title.text.trim().length < 3 ||
          category.text.trim().isEmpty ||
          custodian.text.trim().isEmpty) {
        _message('Enter a title, category and custodian.');
        return;
      }
      final file = await _pickFile();
      if (file == null) return;
      setState(() {
        _busy = true;
        _progress = 0;
      });
      final ref = _records('rwaGovernanceDocuments').doc();
      await ref.set({
        'title': title.text.trim(),
        'category': category.text.trim(),
        'documentNumber': number.text.trim(),
        'version': '0',
        'custodian': custodian.text.trim(),
        'storageReference': '',
        'notes': notes.text.trim(),
        'classification': classification,
        'issueDate': Timestamp.fromDate(issueDate),
        'reviewDate': Timestamp.fromDate(reviewDate),
        'status': 'active',
        'publicationStatus': 'draft',
        'accessScope': 'admin_only',
        'allowedRoles': ['admin'],
        'residentVisible': false,
        'managerVisible': false,
        'workerVisible': false,
        'currentVersionId': null,
        'currentStoragePath': null,
        'fileName': null,
        'mimeType': null,
        'fileSizeBytes': 0,
        'lastUploadedAt': null,
        'lastUploadedBy': null,
        'folderPath': folderPath.text.trim(),
        'linkedRecordType': linkedType.text.trim(),
        'linkedRecordId': linkedId.text.trim(),
        'createdBy': _uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      try {
        await _uploadGovernanceVersion(ref, file);
      } catch (e) {
        _message(
          'Document record was created, but upload failed. Open the record and retry the upload: $e',
        );
      }
    } catch (e) {
      _message('Unable to create document: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      title.dispose();
      category.dispose();
      number.dispose();
      custodian.dispose();
      notes.dispose();
      linkedType.dispose();
      linkedId.dispose();
      folderPath.dispose();
    }
  }

  Future<void> _uploadReplacement(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final file = await _pickFile();
    if (file == null) return;
    if (!mounted) return;
    final note = TextEditingController(text: 'Replacement / revised issue');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const AppText('Upload new version'),
          content: _input(note, 'Version change note', lines: 3),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Upload version'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      setState(() {
        _busy = true;
        _progress = 0;
      });
      await _uploadGovernanceVersion(
        doc.reference,
        file,
        changeNote: note.text.trim(),
      );
    } catch (e) {
      _message('Version upload failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      note.dispose();
    }
  }

  Future<void> _publishDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if ((data['currentStoragePath'] ?? '').toString().isEmpty ||
        (data['currentVersionId'] ?? '').toString().isEmpty) {
      _message('Upload a file before publishing.');
      return;
    }
    String scope = (data['accessScope'] ?? 'admin_only').toString();
    const options = <String, String>{
      'admin_only': 'Admin only',
      'residents': 'Residents',
      'cleanliness_manager': 'Cleanliness Manager',
      'workers': 'Workers',
      'colony': 'All active colony roles',
    };
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const AppText('Publish and set access'),
          content: RadioGroup<String>(
            groupValue: scope,
            onChanged: (value) =>
                setDialog(() => scope = value ?? 'admin_only'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppText(
                  'Select which active colony roles can discover and open this document.',
                  style: TextStyle(fontSize: 12, color: _grey),
                ),
                const SizedBox(height: 10),
                ...options.entries.map(
                  (e) => RadioListTile<String>(
                    dense: true,
                    value: e.key,
                    title: AppText(e.value),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, scope),
              child: const AppText('Save access'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    final roles = switch (chosen) {
      'admin_only' => ['admin'],
      'residents' => ['admin', 'resident'],
      'cleanliness_manager' => ['admin', 'cleanliness_manager'],
      'workers' => ['admin', 'worker'],
      'colony' => ['admin', 'resident', 'cleanliness_manager', 'worker'],
      _ => ['admin'],
    };
    if (data['classification'] == 'confidential' && roles.length > 1) {
      _message('Confidential documents must remain Admin-only.');
      return;
    }
    try {
      await doc.reference.update({
        'publicationStatus': chosen == 'admin_only' ? 'draft' : 'published',
        'accessScope': chosen,
        'allowedRoles': roles,
        'residentVisible': roles.contains('resident'),
        'managerVisible': roles.contains('cleanliness_manager'),
        'workerVisible': roles.contains('worker'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _audit(
        chosen == 'admin_only' ? 'access_restricted' : 'document_published',
        doc.id,
        (data['title'] ?? 'Document').toString(),
        'Access scope set to $chosen',
      );
      _message(
        chosen == 'admin_only'
            ? 'Document restricted to Admin.'
            : 'Document published with $chosen access.',
      );
    } catch (e) {
      _message('Unable to update document access: $e');
    }
  }

  Future<void> _archiveDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final next = doc.data()['status'] == 'archived' ? 'active' : 'archived';
    try {
      await doc.reference.update({
        'status': next,
        'publicationStatus': next == 'archived' ? 'withdrawn' : 'draft',
        'residentVisible': false,
        'managerVisible': false,
        'workerVisible': false,
        'accessScope': 'admin_only',
        'allowedRoles': ['admin'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _audit(
        'document_$next',
        doc.id,
        (doc.data()['title'] ?? 'Document').toString(),
        'Document status changed to $next',
      );
    } catch (e) {
      _message('Unable to change document status: $e');
    }
  }

  Future<void> _showVersions(
    String documentId,
    String title,
    bool resident,
  ) async {
    final versions = resident
        ? _residentVersions(documentId)
        : _govVersions(documentId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppText(
                  'Version history · $title',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: versions.snapshots(),
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      return _empty('Unable to load versions', '${snap.error}');
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = [...snap.data!.docs]
                      ..sort(
                        (a, b) => ((b.data()['versionNumber'] ?? 0) as num)
                            .compareTo((a.data()['versionNumber'] ?? 0) as num),
                      );
                    if (docs.isEmpty) {
                      return _empty(
                        'No versions',
                        'Uploaded files will appear here.',
                      );
                    }
                    return ListView(
                      children: docs.map((v) {
                        final x = v.data();
                        return ListTile(
                          leading: const Icon(
                            Icons.description_outlined,
                            color: _navy,
                          ),
                          title: AppText(
                            'Version ${x['versionNumber'] ?? '—'} · ${x['fileName'] ?? 'file'}',
                          ),
                          subtitle: AppText(
                            '${_size(x['sizeBytes'])} · ${x['status'] ?? '—'} · ${x['changeNote'] ?? ''}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new, color: _navy),
                            onPressed: x['status'] == 'available'
                                ? () {
                                    Navigator.pop(ctx);
                                    _openStoredFile(
                                      (x['storagePath'] ?? '').toString(),
                                      (x['fileName'] ?? 'document').toString(),
                                    );
                                  }
                                : null,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createResidentUpload() async {
    final title = TextEditingController();
    final category = TextEditingController(text: 'Resident document');
    try {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const AppText('Submit a document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input(title, 'Document title'),
              _input(category, 'Document category'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Choose file'),
            ),
          ],
        ),
      );
      if (go != true) return;
      if (title.text.trim().length < 3 || category.text.trim().isEmpty) {
        _message('Enter a document title and category.');
        return;
      }
      final file = await _pickFile();
      if (file == null) return;
      final bytes = await _readPickedBytes(file);
      if (!mounted) return;
      setState(() {
        _busy = true;
        _progress = 0.2;
      });
      final docRef = _records('residentDocuments').doc();
      final versionRef = _residentVersions(docRef.id).doc();
      final filePath = _firestoreFilePath(versionRef);
      final batch = FirebaseFirestore.instance.batch();
      batch.set(docRef, {
        'ownerUid': _uid,
        'residentId': widget.residentId ?? '',
        'ownerName': widget.residentName ?? '',
        'title': title.text.trim(),
        'category': category.text.trim(),
        'fileName': file.name,
        'mimeType': _mime(file.name),
        'fileSizeBytes': bytes.length,
        'storagePath': filePath,
        'currentVersionId': versionRef.id,
        'status': 'submitted',
        'reviewStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(versionRef, {
        'versionNumber': 1,
        'fileName': file.name,
        'mimeType': _mime(file.name),
        'sizeBytes': bytes.length,
        'storagePath': filePath,
        'storageBackend': 'firestore_chunks',
        'chunkCount': _chunkCountFor(bytes.length),
        'uploadedBy': _uid,
        'status': 'available',
        'uploadedAt': FieldValue.serverTimestamp(),
        'changeNote': 'Initial resident submission',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _appendFileChunks(batch, versionRef, bytes);
      setState(() => _progress = 0.8);
      await batch.commit();
      _message(
        'Document stored in Firestore and submitted privately for Admin review.',
      );
    } catch (e) {
      _message(
        'Resident document submission failed. No partial upload was committed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = 0;
        });
      }
      title.dispose();
      category.dispose();
    }
  }

  Future<void> _retryResidentUpload(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final file = await _pickFile();
    if (file == null) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _progress = 0.2;
    });
    try {
      final bytes = await _readPickedBytes(file);
      final root = doc.reference;
      final versions = _residentVersions(doc.id);
      final existing = await versions.get();
      final maxVersion = existing.docs.fold<int>(0, (value, item) {
        final number = item.data()['versionNumber'];
        return number is num && number.toInt() > value ? number.toInt() : value;
      });
      final versionRef = versions.doc();
      final filePath = _firestoreFilePath(versionRef);
      final batch = FirebaseFirestore.instance.batch();
      batch.set(versionRef, {
        'versionNumber': maxVersion + 1,
        'fileName': file.name,
        'mimeType': _mime(file.name),
        'sizeBytes': bytes.length,
        'storagePath': filePath,
        'storageBackend': 'firestore_chunks',
        'chunkCount': _chunkCountFor(bytes.length),
        'uploadedBy': _uid,
        'status': 'available',
        'uploadedAt': FieldValue.serverTimestamp(),
        'changeNote':
            'Resident resubmission after failed upload or requested changes',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _appendFileChunks(batch, versionRef, bytes);
      batch.update(root, {
        'status': 'submitted',
        'reviewStatus': 'pending',
        'storagePath': filePath,
        'currentVersionId': versionRef.id,
        'fileName': file.name,
        'mimeType': _mime(file.name),
        'fileSizeBytes': bytes.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _progress = 0.8);
      await batch.commit();
      _message('Document resubmitted privately for Admin review.');
    } catch (e) {
      _message(
        'Resubmission failed. No partial file batch was committed; you can retry: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = 0;
        });
      }
    }
  }

  Future<void> _showResidentReviewHistory(
    String documentId,
    String title,
  ) async {
    final history = _records('residentDocuments')
        .doc(documentId)
        .collection('reviewHistory');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .55,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppText(
                  'Review history · $title',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: history
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      return _empty(
                        'Unable to load review history',
                        '${snap.error}',
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.data!.docs.isEmpty) {
                      return _empty(
                        'No reviews yet',
                        'Admin review decisions will appear here.',
                      );
                    }
                    return ListView(
                      children: snap.data!.docs.map((item) {
                        final data = item.data();
                        return ListTile(
                          leading: const Icon(
                            Icons.fact_check_outlined,
                            color: _navy,
                          ),
                          title: AppText(
                            (data['decision'] ?? 'review')
                                .toString()
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                          ),
                          subtitle: AppText(
                            '${data['notes'] ?? ''}\n${_date(data['createdAt'])}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          isThreeLine: true,
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reviewResidentDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String decision,
  ) async {
    final note = TextEditingController();
    try {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: AppText(
            '${decision == 'approved'
                ? 'Approve'
                : decision == 'rejected'
                ? 'Reject'
                : 'Request changes'} document',
          ),
          content: _input(note, 'Review notes (required)', lines: 3),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Save review'),
            ),
          ],
        ),
      );
      if (go != true) return;
      if (note.text.trim().length < 3) {
        _message('Enter a meaningful review note.');
        return;
      }
      final batch = FirebaseFirestore.instance.batch();
      final reviewRef = doc.reference.collection('reviewHistory').doc();
      batch.set(reviewRef, {
        'decision': decision,
        'notes': note.text.trim(),
        'reviewedBy': _uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(doc.reference, {
        'reviewStatus': decision,
        'reviewNotes': note.text.trim(),
        'reviewedBy': _uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _message('Document review recorded.');
    } catch (e) {
      _message('Unable to save review: $e');
    } finally {
      note.dispose();
    }
  }

  Widget _input(TextEditingController c, String label, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: AppTranslations.translate(label),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
          ),
        ),
      );
  Widget _searchBox() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _search,
      onChanged: (v) => setState(() => _searchText = v.trim().toLowerCase()),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: AppTranslations.translate(
          'Search title, category or reference',
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _search.clear();
            setState(() => _searchText = '');
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
  bool _matches(Map<String, dynamic> x) =>
      _searchText.isEmpty ||
      [
        'title',
        'category',
        'documentNumber',
        'custodian',
        'folderPath',
        'linkedRecordId',
      ].any((k) => (x[k] ?? '').toString().toLowerCase().contains(_searchText));
  Widget _documentCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    bool residentUpload = false,
    bool publishedReadOnly = false,
  }) {
    final x = doc.data();
    final path = (x['currentStoragePath'] ?? x['storagePath'] ?? '').toString();
    final name = (x['fileName'] ?? '').toString();
    final published = x['publicationStatus'] == 'published';
    final review = x['reviewStatus'] ?? 'pending';
    return Card(
      color: AppTheme.white,
      margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        leading: const Icon(Icons.description_outlined, color: _navy),
        title: AppText(
          (x['title'] ?? 'Untitled').toString(),
          style: const TextStyle(color: _navy, fontWeight: FontWeight.w800),
        ),
        subtitle: AppText(
          '${x['category'] ?? '—'} · v${x['version'] ?? '1'} · ${_size(x['fileSizeBytes'])}',
          style: const TextStyle(color: _grey, fontSize: 10),
        ),
        trailing: _status(
          residentUpload
              ? review.toString()
              : (publishedReadOnly
                    ? 'published'
                    : (published
                          ? 'published'
                          : (x['status'] ?? 'draft').toString())),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Reference: ${x['documentNumber'] ?? '—'} · Custodian: ${x['custodian'] ?? x['ownerName'] ?? '—'}',
                  style: const TextStyle(fontSize: 11),
                ),
                if ((x['folderPath'] ?? '').toString().isNotEmpty)
                  AppText(
                    'Folder: ${x['folderPath']}',
                    style: const TextStyle(fontSize: 11),
                  ),
                AppText(
                  'Classification: ${x['classification'] ?? 'private'} · Review: ${_date(x['reviewDate'])}',
                  style: const TextStyle(fontSize: 11),
                ),
                if ((x['linkedRecordId'] ?? '').toString().isNotEmpty)
                  AppText(
                    'Linked record: ${x['linkedRecordType']} / ${x['linkedRecordId']}',
                    style: const TextStyle(fontSize: 11),
                  ),
                if ((x['reviewNotes'] ?? '').toString().isNotEmpty)
                  AppText(
                    'Review notes: ${x['reviewNotes']}',
                    style: const TextStyle(fontSize: 11),
                  ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    if (path.isNotEmpty &&
                        (!residentUpload || x['status'] == 'submitted'))
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _openStoredFile(path, name),
                        icon: const Icon(Icons.open_in_new, size: 15),
                        label: const AppText('Open file'),
                      ),
                    if (!residentUpload && widget.isAdmin)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _uploadReplacement(doc),
                        icon: const Icon(Icons.upload_file, size: 15),
                        label: const AppText('New version'),
                      ),
                    if (!residentUpload && widget.isAdmin)
                      OutlinedButton.icon(
                        onPressed: () => _showVersions(
                          doc.id,
                          (x['title'] ?? 'Document').toString(),
                          false,
                        ),
                        icon: const Icon(Icons.history, size: 15),
                        label: const AppText('Versions'),
                      ),
                    if (residentUpload)
                      OutlinedButton.icon(
                        onPressed: () => _showVersions(
                          doc.id,
                          (x['title'] ?? 'Document').toString(),
                          true,
                        ),
                        icon: const Icon(Icons.history, size: 15),
                        label: const AppText('Versions'),
                      ),
                    if (residentUpload)
                      OutlinedButton.icon(
                        onPressed: () => _showResidentReviewHistory(
                          doc.id,
                          (x['title'] ?? 'Document').toString(),
                        ),
                        icon: const Icon(Icons.fact_check_outlined, size: 15),
                        label: const AppText('Review history'),
                      ),
                    if (residentUpload &&
                        !widget.isAdmin &&
                        (x['status'] == 'upload_failed' ||
                            review == 'needs_changes'))
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _retryResidentUpload(doc),
                        icon: const Icon(Icons.refresh, size: 15),
                        label: const AppText('Resubmit document'),
                      ),
                    if (!residentUpload && widget.isAdmin)
                      OutlinedButton.icon(
                        onPressed: () => _publishDocument(doc),
                        icon: const Icon(Icons.share_outlined, size: 15),
                        label: AppText(published ? 'Change access' : 'Publish'),
                      ),
                    if (!residentUpload && widget.isAdmin)
                      OutlinedButton.icon(
                        onPressed: () => _archiveDocument(doc),
                        icon: const Icon(Icons.archive_outlined, size: 15),
                        label: AppText(
                          x['status'] == 'archived' ? 'Reactivate' : 'Archive',
                        ),
                      ),
                  ],
                ),
                if (residentUpload &&
                    widget.isAdmin &&
                    x['status'] == 'submitted' &&
                    review == 'pending')
                  Wrap(
                    spacing: 7,
                    children: [
                      TextButton(
                        onPressed: () => _reviewResidentDoc(doc, 'approved'),
                        child: const AppText('Approve'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _reviewResidentDoc(doc, 'needs_changes'),
                        child: const AppText('Request changes'),
                      ),
                      TextButton(
                        onPressed: () => _reviewResidentDoc(doc, 'rejected'),
                        child: const AppText('Reject'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _governanceStream({required String accessRole}) {
    Query<Map<String, dynamic>> query = _records('rwaGovernanceDocuments');
    if (accessRole == 'resident') {
      query = query.where('residentVisible', isEqualTo: true);
    }
    if (accessRole == 'cleanliness_manager') {
      query = query.where('managerVisible', isEqualTo: true);
    }
    if (accessRole == 'worker') {
      query = query.where('workerVisible', isEqualTo: true);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _empty(
            'Unable to load library',
            'Check Firestore rules and Storage setup. ${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _navy));
        }
        final docs =
            snapshot.data!.docs.where((d) => _matches(d.data())).toList()..sort(
              (a, b) =>
                  ((b.data()['lastUploadedAt'] is Timestamp
                          ? (b.data()['lastUploadedAt'] as Timestamp)
                                .millisecondsSinceEpoch
                          : 0))
                      .compareTo(
                        a.data()['lastUploadedAt'] is Timestamp
                            ? (a.data()['lastUploadedAt'] as Timestamp)
                                  .millisecondsSinceEpoch
                            : 0,
                      ),
            );
        if (docs.isEmpty) {
          return _empty(
            'No documents found',
            accessRole == 'admin'
                ? 'Create a document record and upload the first file version.'
                : 'Documents explicitly published to your role will appear here.',
          );
        }
        return Column(
          children: docs
              .map(
                (d) =>
                    _documentCard(d, publishedReadOnly: accessRole != 'admin'),
              )
              .toList(),
        );
      },
    );
  }

  Widget _residentUploadStream({
    required bool admin,
  }) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: admin
        ? _records('residentDocuments').snapshots()
        : _records('residentDocuments')
              .where('ownerUid', isEqualTo: _uid)
              .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _empty('Unable to load resident files', '${snapshot.error}');
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator(color: _navy));
      }
      final docs = snapshot.data!.docs.where((d) => _matches(d.data())).toList()
        ..sort(
          (a, b) =>
              (b.data()['createdAt'] is Timestamp
                      ? (b.data()['createdAt'] as Timestamp)
                            .millisecondsSinceEpoch
                      : 0)
                  .compareTo(
                    a.data()['createdAt'] is Timestamp
                        ? (a.data()['createdAt'] as Timestamp)
                              .millisecondsSinceEpoch
                        : 0,
                  ),
        );
      if (docs.isEmpty) {
        return _empty(
          'No resident uploads',
          admin
              ? 'Resident-submitted documents will appear here.'
              : 'Your private submissions and review status will appear here.',
        );
      }
      return Column(
        children: docs
            .map((d) => _documentCard(d, residentUpload: true))
            .toList(),
      );
    },
  );
  Widget _overview() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      const AppText(
        'Document repository',
        style: TextStyle(
          color: _navy,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      const AppText(
        'Secure, versioned colony records with controlled publication and private resident submissions.',
        style: TextStyle(color: _grey, fontSize: 11),
      ),
      const SizedBox(height: 14),
      _metric('Governance documents', 'rwaGovernanceDocuments'),
      const SizedBox(height: 8),
      _metric('Resident submissions', 'residentDocuments'),
      const SizedBox(height: 14),
      _panel(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Document handling controls',
              style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 7),
            AppText(
              '• Each replacement creates a new version; prior file objects are retained.\n• Resident uploads are private to the uploader and Admin until reviewed.\n• Published governance records are visible only to the roles selected by Admin.\n• Files are stored in private Firestore-native 512 KiB chunks; no public download URL or Firebase Storage bucket is used.\n• Supported file types: PDF, JPG, PNG, DOCX and XLSX; 5 MB maximum.',
              style: TextStyle(color: _grey, fontSize: 11, height: 1.45),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _panel(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Firestore document storage',
              style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            AppText(
              'This module stores file content in Firestore subcollection documents, split into 512 KiB chunks (maximum 5 MB per file). A Firebase Storage bucket and Blaze Storage setup are not required. Firestore access remains protected by the project’s deployed security rules and normal Firestore quotas.',
              style: TextStyle(color: _grey, fontSize: 11, height: 1.45),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _metric(String title, String collection) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _records(collection).snapshots(),
        builder: (context, snapshot) => _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_copy_outlined, color: _navy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      title,
                      style: const TextStyle(
                        color: _grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AppText(
                    snapshot.hasError
                        ? '—'
                        : snapshot.hasData
                        ? '${snapshot.data!.docs.length}'
                        : '…',
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 4),
                AppText(
                  '${snapshot.error}',
                  style: const TextStyle(color: _grey, fontSize: 10),
                ),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const AppText('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
  Widget _libraryTab() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      _searchBox(),
      Row(
        children: [
          const Expanded(
            child: AppText(
              'Governance & colony library',
              style: TextStyle(
                color: _navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _createGovernanceDocument,
            icon: const Icon(Icons.add, size: 16),
            label: const AppText('Add document'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _governanceStream(accessRole: 'admin'),
    ],
  );
  Widget _residentPublishedTab() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      _searchBox(),
      const AppText(
        'Published colony documents',
        style: TextStyle(
          color: _navy,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      const AppText(
        'Only records explicitly published to residents are shown.',
        style: TextStyle(color: _grey, fontSize: 11),
      ),
      const SizedBox(height: 10),
      _governanceStream(accessRole: 'resident'),
    ],
  );
  Widget _sharedRoleTab() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      _searchBox(),
      const AppText(
        'Shared operational documents',
        style: TextStyle(
          color: _navy,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      const AppText(
        'Only documents explicitly published to your role are shown.',
        style: TextStyle(color: _grey, fontSize: 11),
      ),
      const SizedBox(height: 10),
      _governanceStream(accessRole: widget.roleKey),
    ],
  );
  Widget _residentUploadsTab({required bool admin}) => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      Row(
        children: [
          Expanded(
            child: AppText(
              admin ? 'Resident-submitted files' : 'My private documents',
              style: const TextStyle(
                color: _navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!admin)
            FilledButton.icon(
              onPressed: _busy ? null : _createResidentUpload,
              icon: const Icon(Icons.upload_file, size: 16),
              label: const AppText('Submit'),
            ),
        ],
      ),
      const SizedBox(height: 4),
      AppText(
        admin
            ? 'Review submitted files and record approval, rejection or required changes.'
            : 'Files are private to you and the colony Admin. The review status is shown below each submission.',
        style: const TextStyle(color: _grey, fontSize: 11),
      ),
      const SizedBox(height: 10),
      _searchBox(),
      _residentUploadStream(admin: admin),
    ],
  );
  Widget _accessTab() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      const AppText(
        'Access & document policy',
        style: TextStyle(
          color: _navy,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      _panel(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Admin only',
              style: TextStyle(fontWeight: FontWeight.w800, color: _navy),
            ),
            AppText(
              'Confidential HR, payroll, supplier and restricted governance material.',
              style: TextStyle(color: _grey, fontSize: 11),
            ),
            SizedBox(height: 10),
            AppText(
              'Residents',
              style: TextStyle(fontWeight: FontWeight.w800, color: _navy),
            ),
            AppText(
              'Published policies, notices, approved minutes and other colony documents selected by Admin.',
              style: TextStyle(color: _grey, fontSize: 11),
            ),
            SizedBox(height: 10),
            AppText(
              'Cleanliness Manager / Workers',
              style: TextStyle(fontWeight: FontWeight.w800, color: _navy),
            ),
            AppText(
              'Admin may publish selected operational documents to these roles. No general library access is granted.',
              style: TextStyle(color: _grey, fontSize: 11),
            ),
            SizedBox(height: 10),
            AppText(
              'Resident uploads',
              style: TextStyle(fontWeight: FontWeight.w800, color: _navy),
            ),
            AppText(
              'Resident-submitted files are kept in a separate private collection and Storage path; another resident cannot read them.',
              style: TextStyle(color: _grey, fontSize: 11),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const AppText(
        'File retention',
        style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
      ),
      const AppText(
        'Versions are retained and cannot be deleted from the app. Archiving removes publication access but does not erase the original file object.',
        style: TextStyle(color: _grey, fontSize: 11),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final tabs = widget.isAdmin
        ? [
            Tab(
              icon: Icon(Icons.dashboard_outlined),
              text: AppTranslations.translate('Overview'),
            ),
            Tab(
              icon: Icon(Icons.folder_outlined),
              text: AppTranslations.translate('Library'),
            ),
            Tab(
              icon: Icon(Icons.inbox_outlined),
              text: AppTranslations.translate('Resident Uploads'),
            ),
            Tab(
              icon: Icon(Icons.lock_outline),
              text: AppTranslations.translate('Access & Policies'),
            ),
          ]
        : widget.isResident
        ? [
            Tab(
              icon: Icon(Icons.library_books_outlined),
              text: AppTranslations.translate('Published'),
            ),
            Tab(
              icon: Icon(Icons.upload_file_outlined),
              text: AppTranslations.translate('My Documents'),
            ),
          ]
        : [
            Tab(
              icon: Icon(Icons.folder_shared_outlined),
              text: AppTranslations.translate('Shared Documents'),
            ),
          ];
    final views = widget.isAdmin
        ? <Widget>[
            _overview(),
            _libraryTab(),
            _residentUploadsTab(admin: true),
            _accessTab(),
          ]
        : widget.isResident
        ? <Widget>[_residentPublishedTab(), _residentUploadsTab(admin: false)]
        : <Widget>[_sharedRoleTab()];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          foregroundColor: _navy,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                widget.isAdmin ? 'Document Repository' : 'Colony Documents',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              AppText(
                widget.colonyName,
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: _navy,
            unselectedLabelColor: _grey,
            indicatorColor: _navy,
            tabs: tabs,
          ),
        ),
        body: Stack(
          children: [
            TabBarView(children: views),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black12,
                  child: Center(
                    child: _panel(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: _navy),
                          const SizedBox(height: 10),
                          AppText(
                            _progress > 0
                                ? 'Uploading ${(100 * _progress).toStringAsFixed(0)}%'
                                : 'Working...',
                            style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}
// MOHALLAFLOW_DOCUMENT_REPOSITORY_SCREEN_END
