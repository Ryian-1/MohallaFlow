import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Advanced water operations layer. Existing waterSuppliers and waterDeliveries
/// remain the source of truth for supplier and tanker records.
class WaterOperationsScreen extends StatefulWidget {
  const WaterOperationsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<WaterOperationsScreen> createState() => _WaterOperationsScreenState();
}

class _WaterOperationsScreenState extends State<WaterOperationsScreen> {
  static const _navy = Color(0xFF172B4D);
  static const _soft = Color(0xFFF4F6F8);
  static const _border = Color(0xFFE1E6ED);
  static const _muted = Color(0xFF667085);

  DocumentReference<Map<String, dynamic>> get _colony =>
      FirebaseFirestore.instance.collection('colonies').doc(widget.colonyId);

  CollectionReference<Map<String, dynamic>> get _storage =>
      _colony.collection('waterStorageAssets');
  CollectionReference<Map<String, dynamic>> get _meters =>
      _colony.collection('waterMeters');
  CollectionReference<Map<String, dynamic>> get _readings =>
      _colony.collection('waterMeterReadings');
  CollectionReference<Map<String, dynamic>> get _quality =>
      _colony.collection('waterQualityChecks');
  CollectionReference<Map<String, dynamic>> get _distributions =>
      _colony.collection('waterDistributions');
  CollectionReference<Map<String, dynamic>> get _movements =>
      _colony.collection('waterStorageMovements');
  CollectionReference<Map<String, dynamic>> get _incidents =>
      _colony.collection('waterIncidents');

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(value)));
  }

  String _date(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate().toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return 'Not recorded';
  }

  String _number(dynamic value, {int decimals = 0}) {
    final n = value is num ? value : 0;
    return n.toStringAsFixed(decimals);
  }

  InputDecoration _input(String label, {String? hint}) => InputDecoration(
    labelText: AppTranslations.translate(label),
    hintText: AppTranslations.translate(hint),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Widget _metric(String label, String value, IconData icon, {String? detail}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: _navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    label,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  AppText(
                    value,
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  if (detail != null)
                    AppText(
                      detail,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _panel(
    String title,
    String subtitle,
    Widget child, {
    Widget? action,
  }) => Container(
    margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      subtitle,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ?action,
            ],
          ),
        ),
        child,
      ],
    ),
  );

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.all(22),
    child: Center(
      child: AppText(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
    ),
  );

  Future<void> _addStorage() async {
    final name = TextEditingController();
    final location = TextEditingController();
    final capacity = TextEditingController();
    final opening = TextEditingController(text: '0');
    String type = 'Underground sump';
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Add water storage asset'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: _input('Asset name'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? AppTranslations.translate('Enter an asset name')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: location,
                      decoration: _input('Location / block'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? AppTranslations.translate('Enter location')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: _input('Storage type'),
                      items:
                          [
                                'Underground sump',
                                'Overhead tank',
                                'Reservoir',
                                'Borewell',
                                'Other',
                              ]
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: AppText(v),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) setD(() => type = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: capacity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _input('Capacity (litres)'),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null || n <= 0
                            ? AppTranslations.translate(
                                'Enter a capacity greater than zero',
                              )
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: opening,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _input('Opening level (litres)'),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        final c = double.tryParse(capacity.text);
                        return n == null || n < 0 || c == null || n > c
                            ? AppTranslations.translate(
                                'Level must be between zero and capacity',
                              )
                            : null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate() || _uid.isEmpty) return;
                final cap = double.parse(capacity.text);
                final level = double.parse(opening.text);
                try {
                  await _storage.add({
                    'name': name.text.trim(),
                    'location': location.text.trim(),
                    'storageType': type,
                    'capacityLitres': cap,
                    'currentLevelLitres': level,
                    'status': 'active',
                    'createdBy': _uid,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _message('Storage asset added.');
                } catch (e) {
                  _message('Could not save storage asset: $e');
                }
              },
              child: const AppText('Save asset'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    location.dispose();
    capacity.dispose();
    opening.dispose();
  }

  Future<void> _adjustStorage(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool add,
  }) async {
    final quantity = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    final key = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText(
          add ? 'Record water receipt' : 'Record distribution / issue',
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText('Storage: ${doc.data()['name'] ?? 'Storage'}'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _input('Quantity (litres)'),
                  validator: (v) =>
                      double.tryParse(v ?? '') == null || double.parse(v!) <= 0
                      ? AppTranslations.translate(
                          'Enter a quantity greater than zero',
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: reference,
                  decoration: _input(
                    add
                        ? 'Delivery challan / reference'
                        : 'Distribution reference',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: notes,
                  maxLines: 2,
                  decoration: _input('Notes'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!key.currentState!.validate() || _uid.isEmpty) return;
              final qty = double.parse(quantity.text);
              try {
                await FirebaseFirestore.instance.runTransaction((tx) async {
                  final fresh = await tx.get(doc.reference);
                  if (!fresh.exists) {
                    throw Exception('Storage asset no longer exists.');
                  }
                  final data = fresh.data()!;
                  final current =
                      (data['currentLevelLitres'] as num?)?.toDouble() ?? 0;
                  final cap = (data['capacityLitres'] as num?)?.toDouble() ?? 0;
                  final next = add ? current + qty : current - qty;
                  if (next < 0) {
                    throw Exception('Insufficient recorded water level.');
                  }
                  if (next > cap) {
                    throw Exception('Quantity exceeds storage capacity.');
                  }
                  final movement = _movements.doc();
                  tx.update(doc.reference, {
                    'currentLevelLitres': next,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  tx.set(movement, {
                    'storageId': doc.id,
                    'storageName': data['name'] ?? '',
                    'movementType': add ? 'receipt' : 'issue',
                    'quantityLitres': qty,
                    'balanceAfterLitres': next,
                    'reference': reference.text.trim(),
                    'notes': notes.text.trim(),
                    'createdBy': _uid,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _message(
                  add ? 'Water receipt recorded.' : 'Water issue recorded.',
                );
              } catch (e) {
                _message('Storage movement failed: $e');
              }
            },
            child: const AppText('Confirm movement'),
          ),
        ],
      ),
    );
    quantity.dispose();
    reference.dispose();
    notes.dispose();
  }

  Future<void> _addMeter() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final location = TextEditingController();
    final initial = TextEditingController(text: '0');
    String type = 'Area meter';
    final key = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Register water meter'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: _input('Meter name'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? AppTranslations.translate('Enter meter name')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: code,
                    decoration: _input('Unique meter code'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? AppTranslations.translate('Enter meter code')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: location,
                    decoration: _input('Location / block'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? AppTranslations.translate('Enter location')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: _input('Meter category'),
                    items:
                        [
                              'Main inlet',
                              'Area meter',
                              'Building meter',
                              'Common-area meter',
                              'Borewell meter',
                              'Other',
                            ]
                            .map(
                              (v) =>
                                  DropdownMenuItem(value: v, child: AppText(v)),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) setD(() => type = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: initial,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _input('Opening meter reading'),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null || double.parse(v!) < 0
                        ? AppTranslations.translate(
                            'Enter a valid non-negative reading',
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!key.currentState!.validate() || _uid.isEmpty) return;
                try {
                  final normalized = code.text.trim().toUpperCase();
                  final existing = await _meters
                      .where('meterCodeNormalized', isEqualTo: normalized)
                      .limit(1)
                      .get();
                  if (existing.docs.isNotEmpty) {
                    _message('This meter code is already registered.');
                    return;
                  }
                  await _meters.add({
                    'meterName': name.text.trim(),
                    'meterCode': code.text.trim(),
                    'meterCodeNormalized': normalized,
                    'location': location.text.trim(),
                    'meterType': type,
                    'initialReading': double.parse(initial.text),
                    'latestReading': double.parse(initial.text),
                    'latestReadingAt': null,
                    'status': 'active',
                    'createdBy': _uid,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _message('Meter registered.');
                } catch (e) {
                  _message('Could not register meter: $e');
                }
              },
              child: const AppText('Register meter'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    code.dispose();
    location.dispose();
    initial.dispose();
  }

  Future<void> _recordMeterReading(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final reading = TextEditingController();
    final notes = TextEditingController();
    DateTime readAt = DateTime.now();
    final key = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: AppText(
            'Record reading — ${doc.data()['meterName'] ?? 'Meter'}',
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: reading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _input('Current cumulative meter reading'),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null || double.parse(v!) < 0
                        ? AppTranslations.translate('Enter a valid reading')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: readAt,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setD(
                            () => readAt = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              readAt.hour,
                              readAt.minute,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: AppText(
                        'Reading date: ${readAt.day}/${readAt.month}/${readAt.year}',
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: notes,
                    maxLines: 2,
                    decoration: _input('Notes / meter condition'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!key.currentState!.validate() || _uid.isEmpty) return;
                final current = double.parse(reading.text);
                try {
                  await FirebaseFirestore.instance.runTransaction((tx) async {
                    final fresh = await tx.get(doc.reference);
                    if (!fresh.exists) {
                      throw Exception('Meter no longer exists.');
                    }
                    final data = fresh.data()!;
                    if (data['status'] != 'active') {
                      throw Exception('Meter is inactive.');
                    }
                    final previous =
                        (data['latestReading'] as num?)?.toDouble() ??
                        (data['initialReading'] as num?)?.toDouble() ??
                        0;
                    final previousAt = data['latestReadingAt'];
                    if (current < previous) {
                      throw Exception(
                        'Reading cannot be lower than the previous reading.',
                      );
                    }
                    if (previousAt is Timestamp &&
                        !readAt.isAfter(previousAt.toDate())) {
                      throw Exception(
                        'Reading date must be later than the last recorded reading.',
                      );
                    }
                    final ref = _readings.doc();
                    final consumed = current - previous;
                    tx.update(doc.reference, {
                      'latestReading': current,
                      'latestReadingAt': Timestamp.fromDate(readAt),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    tx.set(ref, {
                      'meterId': doc.id,
                      'meterName': data['meterName'] ?? '',
                      'meterCode': data['meterCode'] ?? '',
                      'location': data['location'] ?? '',
                      'previousReading': previous,
                      'currentReading': current,
                      'consumptionLitres': consumed,
                      'readingAt': Timestamp.fromDate(readAt),
                      'notes': notes.text.trim(),
                      'recordedBy': _uid,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _message('Meter reading saved.');
                } catch (e) {
                  _message('Reading was not saved: $e');
                }
              },
              child: const AppText('Save reading'),
            ),
          ],
        ),
      ),
    );
    reading.dispose();
    notes.dispose();
  }

  Future<void> _addQualityCheck() async {
    final location = TextEditingController();
    final source = TextEditingController();
    final ph = TextEditingController();
    final tds = TextEditingController();
    final turbidity = TextEditingController();
    final chlorine = TextEditingController();
    final lab = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    String outcome = 'follow_up';
    DateTime testedAt = DateTime.now();
    final key = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Record water quality test'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: location,
                      decoration: _input('Sample location'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? AppTranslations.translate('Enter sample location')
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: source,
                      decoration: _input('Source / tank / supply point'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ph,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _input('pH'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: tds,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _input('TDS (mg/L)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: turbidity,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _input('Turbidity (NTU)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: chlorine,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _input('Residual chlorine'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: lab,
                      decoration: _input('Lab / tester (optional)'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: reference,
                      decoration: _input('Report / sample reference'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: outcome,
                      decoration: _input('Assessment recorded by tester'),
                      items: [
                        DropdownMenuItem(value: 'pass', child: AppText('Pass')),
                        DropdownMenuItem(
                          value: 'follow_up',
                          child: AppText('Follow-up required'),
                        ),
                        DropdownMenuItem(value: 'fail', child: AppText('Fail')),
                      ],
                      onChanged: (v) {
                        if (v != null) setD(() => outcome = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notes,
                      maxLines: 2,
                      decoration: _input('Observations / corrective action'),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: testedAt,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                          );
                          if (d != null) {
                            setD(
                              () => testedAt = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                testedAt.hour,
                                testedAt.minute,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: AppText(
                          'Test date: ${testedAt.day}/${testedAt.month}/${testedAt.year}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!key.currentState!.validate() || _uid.isEmpty) return;
                double? n(String s) =>
                    s.trim().isEmpty ? null : double.tryParse(s.trim());
                try {
                  await _quality.add({
                    'sampleLocation': location.text.trim(),
                    'source': source.text.trim(),
                    'ph': n(ph.text),
                    'tdsMgL': n(tds.text),
                    'turbidityNtu': n(turbidity.text),
                    'residualChlorine': n(chlorine.text),
                    'labOrTester': lab.text.trim(),
                    'reportReference': reference.text.trim(),
                    'outcome': outcome,
                    'observations': notes.text.trim(),
                    'testedAt': Timestamp.fromDate(testedAt),
                    'recordedBy': _uid,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _message('Quality test recorded.');
                } catch (e) {
                  _message('Could not save test: $e');
                }
              },
              child: const AppText('Save test'),
            ),
          ],
        ),
      ),
    );
    for (final c in [
      location,
      source,
      ph,
      tds,
      turbidity,
      chlorine,
      lab,
      reference,
      notes,
    ]) {
      c.dispose();
    }
  }

  Future<void> _addDistribution() async {
    final destination = TextEditingController();
    final quantity = TextEditingController();
    final purpose = TextEditingController();
    final notes = TextEditingController();
    String? storageId;
    DateTime date = DateTime.now();
    final key = GlobalKey<FormState>();
    try {
      final tanks = await _storage.where('status', isEqualTo: 'active').get();
      if (tanks.docs.isEmpty) {
        _message('Add an active storage asset before recording distribution.');
        return;
      }
      storageId = tanks.docs.first.id;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const AppText('Record water distribution'),
            content: SizedBox(
              width: 440,
              child: Form(
                key: key,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: storageId,
                        decoration: _input('Source storage'),
                        items: tanks.docs
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: AppText(
                                  '${d.data()['name']} — ${_number(d.data()['currentLevelLitres'])} L',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setD(() => storageId = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: destination,
                        decoration: _input('Destination / block / area'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? AppTranslations.translate('Enter destination')
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _input('Quantity (litres)'),
                        validator: (v) =>
                            double.tryParse(v ?? '') == null ||
                                double.parse(v!) <= 0
                            ? AppTranslations.translate(
                                'Enter a positive quantity',
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: purpose,
                        decoration: _input('Purpose / distribution type'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: notes,
                        maxLines: 2,
                        decoration: _input('Notes'),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                            );
                            if (d != null) setD(() => date = d);
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: AppText(
                            'Distribution date: ${date.day}/${date.month}/${date.year}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const AppText('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!key.currentState!.validate() ||
                      storageId == null ||
                      _uid.isEmpty) {
                    return;
                  }
                  final qty = double.parse(quantity.text);
                  final selected = tanks.docs.firstWhere(
                    (d) => d.id == storageId,
                  );
                  try {
                    await FirebaseFirestore.instance.runTransaction((tx) async {
                      final fresh = await tx.get(selected.reference);
                      if (!fresh.exists) {
                        throw Exception('Storage asset no longer exists.');
                      }
                      final data = fresh.data()!;
                      final current =
                          (data['currentLevelLitres'] as num?)?.toDouble() ?? 0;
                      if (data['status'] != 'active') {
                        throw Exception('Storage asset is inactive.');
                      }
                      if (current < qty) {
                        throw Exception('Insufficient recorded water level.');
                      }
                      final next = current - qty;
                      final dist = _distributions.doc();
                      final movement = _movements.doc();
                      tx.update(selected.reference, {
                        'currentLevelLitres': next,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      tx.set(dist, {
                        'storageId': selected.id,
                        'storageName': data['name'] ?? '',
                        'destination': destination.text.trim(),
                        'quantityLitres': qty,
                        'purpose': purpose.text.trim(),
                        'notes': notes.text.trim(),
                        'distributionDate': Timestamp.fromDate(date),
                        'createdBy': _uid,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      tx.set(movement, {
                        'storageId': selected.id,
                        'storageName': data['name'] ?? '',
                        'movementType': 'distribution',
                        'quantityLitres': qty,
                        'balanceAfterLitres': next,
                        'reference': dist.id,
                        'notes': 'Distribution to ${destination.text.trim()}',
                        'createdBy': _uid,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _message(
                      'Distribution recorded and storage level updated.',
                    );
                  } catch (e) {
                    _message('Distribution failed: $e');
                  }
                },
                child: const AppText('Record distribution'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _message('Could not load storage assets: $e');
    }
    destination.dispose();
    quantity.dispose();
    purpose.dispose();
    notes.dispose();
  }

  Future<void> _addIncident() async {
    final title = TextEditingController();
    final area = TextEditingController();
    final description = TextEditingController();
    final assigned = TextEditingController();
    String type = 'shortage';
    String severity = 'medium';
    final key = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Log water incident'),
          content: SizedBox(
            width: 430,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      decoration: _input('Incident title'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? AppTranslations.translate('Enter a title')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: _input('Incident type'),
                      items:
                          [
                                'shortage',
                                'leakage',
                                'contamination',
                                'pump_failure',
                                'overflow',
                                'supply_disruption',
                                'other',
                              ]
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: AppText(v.replaceAll('_', ' ')),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) setD(() => type = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: severity,
                      decoration: _input('Severity'),
                      items: ['low', 'medium', 'high', 'critical']
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: AppText(v.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setD(() => severity = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: area,
                      decoration: _input('Affected area / block'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? AppTranslations.translate('Enter affected area')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: assigned,
                      decoration: _input('Assigned person / vendor'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: description,
                      maxLines: 3,
                      decoration: _input('Description and immediate action'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!key.currentState!.validate() || _uid.isEmpty) return;
                try {
                  await _incidents.add({
                    'title': title.text.trim(),
                    'incidentType': type,
                    'severity': severity,
                    'affectedArea': area.text.trim(),
                    'assignedTo': assigned.text.trim(),
                    'description': description.text.trim(),
                    'status': 'open',
                    'openedAt': FieldValue.serverTimestamp(),
                    'resolvedAt': null,
                    'resolutionNotes': '',
                    'createdBy': _uid,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _message('Water incident logged.');
                } catch (e) {
                  _message('Could not log incident: $e');
                }
              },
              child: const AppText('Log incident'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    area.dispose();
    description.dispose();
    assigned.dispose();
  }

  Future<void> _updateIncident(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    final notes = TextEditingController(
      text: doc.data()['resolutionNotes'] as String? ?? '',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText('Update incident: $status'),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: _input('Response / resolution notes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await doc.reference.update({
                  'status': status,
                  'resolutionNotes': notes.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  if (status == 'resolved' || status == 'closed')
                    'resolvedAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _message('Incident updated.');
              } catch (e) {
                _message('Could not update incident: $e');
              }
            },
            child: const AppText('Save update'),
          ),
        ],
      ),
    );
    notes.dispose();
  }

  Widget _overviewTab() => ListView(
    padding: const EdgeInsets.only(bottom: 20),
    children: [
      _panel(
        'Operational snapshot',
        'Live counts from water operations records',
        Column(
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _storage.snapshots(),
              builder: (context, s) {
                final docs = s.data?.docs ?? [];
                if (s.hasError) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: _metric(
                      'Recorded stored water',
                      '—',
                      Icons.water_drop_outlined,
                      detail: 'Unable to load storage assets: ${s.error}',
                    ),
                  );
                }
                if (s.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: _metric(
                      'Recorded stored water',
                      '…',
                      Icons.water_drop_outlined,
                      detail: 'Loading storage assets',
                    ),
                  );
                }
                final litres = docs.fold<double>(
                  0,
                  (accumulator, d) =>
                      accumulator +
                      ((d.data()['currentLevelLitres'] as num?)?.toDouble() ??
                          0),
                );
                final capacity = docs.fold<double>(
                  0,
                  (accumulator, d) =>
                      accumulator +
                      ((d.data()['capacityLitres'] as num?)?.toDouble() ?? 0),
                );
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: _metric(
                    'Recorded stored water',
                    '${_number(litres)} L',
                    Icons.water_drop_outlined,
                    detail:
                        '${docs.length} storage assets · ${_number(capacity)} L capacity',
                  ),
                );
              },
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _incidents
                  .where('status', whereIn: ['open', 'in_progress'])
                  .snapshots(),
              builder: (context, s) => Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _metric(
                  'Open water incidents',
                  s.hasError
                      ? '—'
                      : s.hasData
                      ? '${s.data!.docs.length}'
                      : '…',
                  Icons.warning_amber_outlined,
                  detail: s.hasError
                      ? 'Unable to load incidents: ${s.error}'
                      : s.hasData
                      ? 'Shortage, leak, quality and supply issues'
                      : 'Loading incident records',
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _quality
                  .orderBy('testedAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, s) {
                if (s.hasError) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _metric(
                      'Latest quality assessment',
                      '—',
                      Icons.science_outlined,
                      detail: 'Unable to load quality tests: ${s.error}',
                    ),
                  );
                }
                if (s.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _metric(
                      'Latest quality assessment',
                      '…',
                      Icons.science_outlined,
                      detail: 'Loading water quality records',
                    ),
                  );
                }
                final docs = s.data?.docs ?? [];
                final label = docs.isEmpty
                    ? 'No test recorded'
                    : (docs.first.data()['outcome'] ?? 'Unknown')
                          .toString()
                          .replaceAll('_', ' ')
                          .toUpperCase();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _metric(
                    'Latest quality assessment',
                    label,
                    Icons.science_outlined,
                    detail: docs.isEmpty
                        ? 'Record a water quality test'
                        : _date(docs.first.data()['testedAt']),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      _panel(
        'Operating guidance',
        'Use this module with the existing supplier and delivery register',
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: AppText(
            'Supplier profiles and tanker deliveries remain in the existing Water Supply screen. Record accepted water received into a storage asset as a receipt movement. Record each distribution from a storage asset so the on-screen balance remains current. Meter readings are cumulative readings; the app calculates consumption from the previous approved reading. Water-quality outcomes are recorded as assessed by the tester and are not automatically represented as statutory certification.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
        ),
      ),
    ],
  );

  Widget _storageTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Row(
          children: [
            const Expanded(
              child: AppText(
                'Storage assets and manual level ledger',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addStorage,
              icon: const Icon(Icons.add, size: 16),
              label: const AppText('Add'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _storage.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, s) {
            if (s.hasError) {
              return _empty('Unable to load storage assets: ${s.error}');
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.data!.docs.isEmpty) {
              return _empty(
                'No water storage assets registered yet. Add underground sumps, overhead tanks or reservoirs.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: s.data!.docs.map((d) {
                final m = d.data();
                final cap = (m['capacityLitres'] as num?)?.toDouble() ?? 0;
                final level =
                    (m['currentLevelLitres'] as num?)?.toDouble() ?? 0;
                final pct = cap <= 0 ? 0.0 : (level / cap).clamp(0.0, 1.0);
                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: _border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                m['name'] ?? 'Storage',
                                style: const TextStyle(
                                  color: _navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            AppText(
                              '${(pct * 100).round()}%',
                              style: const TextStyle(
                                color: _navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        AppText(
                          '${m['storageType'] ?? ''} · ${m['location'] ?? ''}',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 9,
                            backgroundColor: _soft,
                            valueColor: const AlwaysStoppedAnimation(_navy),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppText(
                          '${_number(level)} L / ${_number(cap)} L',
                          style: const TextStyle(color: _navy, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _adjustStorage(d, add: true),
                              icon: const Icon(Icons.add, size: 16),
                              label: const AppText('Receipt'),
                            ),
                            OutlinedButton.icon(
                              onPressed: level > 0
                                  ? () => _adjustStorage(d, add: false)
                                  : null,
                              icon: const Icon(Icons.remove, size: 16),
                              label: const AppText('Issue'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    ],
  );

  Widget _metersTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Row(
          children: [
            const Expanded(
              child: AppText(
                'Cumulative water meters',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addMeter,
              icon: const Icon(Icons.add, size: 16),
              label: const AppText('Register'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _meters.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, s) {
            if (s.hasError) return _empty('Unable to load meters: ${s.error}');
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.data!.docs.isEmpty) {
              return _empty(
                'No meters registered. Add main inlet, area, building or common-area meters.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: s.data!.docs.map((d) {
                final m = d.data();
                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: _border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    title: AppText(
                      m['meterName'] ?? 'Meter',
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: AppText(
                      '${m['meterCode'] ?? ''} · ${m['location'] ?? ''}\nLatest: ${_number(m['latestReading'], decimals: 2)} · ${_date(m['latestReadingAt'])}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: AppTranslations.translate(
                        'Record meter reading',
                      ),
                      onPressed: m['status'] == 'active'
                          ? () => _recordMeterReading(d)
                          : null,
                      icon: const Icon(Icons.speed, color: _navy),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    ],
  );

  Widget _readingsTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _readings
        .orderBy('readingAt', descending: true)
        .limit(200)
        .snapshots(),
    builder: (context, s) {
      if (s.hasError) return _empty('Unable to load readings: ${s.error}');
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      if (s.data!.docs.isEmpty) {
        return _empty(
          'No meter readings yet. Register a meter and record its first cumulative reading.',
        );
      }
      final total = s.data!.docs.fold<double>(
        0,
        (accumulator, d) =>
            accumulator +
            ((d.data()['consumptionLitres'] as num?)?.toDouble() ?? 0),
      );
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _metric(
            'Consumption in latest 200 readings',
            '${_number(total)} L',
            Icons.analytics_outlined,
          ),
          const SizedBox(height: 10),
          ...s.data!.docs.map((d) {
            final m = d.data();
            return Card(
              color: Colors.white,
              child: ListTile(
                title: AppText(
                  m['meterName'] ?? 'Meter',
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: AppText(
                  '${m['location'] ?? ''} · ${_date(m['readingAt'])}\n${_number(m['previousReading'], decimals: 2)} → ${_number(m['currentReading'], decimals: 2)}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                isThreeLine: true,
                trailing: AppText(
                  '${_number(m['consumptionLitres'], decimals: 2)} L',
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }),
        ],
      );
    },
  );

  Widget _qualityTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Row(
          children: [
            const Expanded(
              child: AppText(
                'Quality-test register',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addQualityCheck,
              icon: const Icon(Icons.add, size: 16),
              label: const AppText('Record test'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _quality.orderBy('testedAt', descending: true).snapshots(),
          builder: (context, s) {
            if (s.hasError) {
              return _empty('Unable to load quality tests: ${s.error}');
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.data!.docs.isEmpty) {
              return _empty('No water quality tests recorded.');
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: s.data!.docs.map((d) {
                final m = d.data();
                final outcome = (m['outcome'] ?? 'follow_up').toString();
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    title: AppText(
                      m['sampleLocation'] ?? 'Sample',
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: AppText(
                      '${m['source'] ?? ''} · ${_date(m['testedAt'])}\npH ${m['ph'] ?? '—'} · TDS ${m['tdsMgL'] ?? '—'} · Turbidity ${m['turbidityNtu'] ?? '—'}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    isThreeLine: true,
                    trailing: AppText(
                      outcome.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    ],
  );

  Widget _distributionTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Row(
          children: [
            const Expanded(
              child: AppText(
                'Distribution ledger',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addDistribution,
              icon: const Icon(Icons.add, size: 16),
              label: const AppText('Record'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _distributions
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, s) {
            if (s.hasError) {
              return _empty('Unable to load distributions: ${s.error}');
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.data!.docs.isEmpty) {
              return _empty('No distribution entries yet.');
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: s.data!.docs.map((d) {
                final m = d.data();
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    title: AppText(
                      '${m['destination'] ?? 'Destination'} · ${_number(m['quantityLitres'])} L',
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: AppText(
                      '${m['storageName'] ?? ''} · ${m['purpose'] ?? ''}\n${_date(m['distributionDate'])}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    isThreeLine: true,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    ],
  );

  Widget _incidentsTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Row(
          children: [
            const Expanded(
              child: AppText(
                'Water incidents and corrective action',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addIncident,
              icon: const Icon(Icons.add, size: 16),
              label: const AppText('Log incident'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _incidents.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, s) {
            if (s.hasError) {
              return _empty('Unable to load incidents: ${s.error}');
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.data!.docs.isEmpty) {
              return _empty('No water incidents logged.');
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: s.data!.docs.map((d) {
                final m = d.data();
                final status = (m['status'] ?? 'open').toString();
                return Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                m['title'] ?? 'Incident',
                                style: const TextStyle(
                                  color: _navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            AppText(
                              status.toUpperCase(),
                              style: const TextStyle(
                                color: _navy,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        AppText(
                          '${m['incidentType'] ?? ''} · ${m['severity'] ?? ''} · ${m['affectedArea'] ?? ''}',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        if ((m['description'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: AppText(
                              m['description'],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        if ((m['resolutionNotes'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: AppText(
                              'Latest notes: ${m['resolutionNotes']}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (status == 'open')
                              OutlinedButton(
                                onPressed: () =>
                                    _updateIncident(d, 'in_progress'),
                                child: const AppText('Start work'),
                              ),
                            if (status == 'open' || status == 'in_progress')
                              OutlinedButton(
                                onPressed: () => _updateIncident(d, 'resolved'),
                                child: const AppText('Resolve'),
                              ),
                            if (status == 'resolved')
                              OutlinedButton(
                                onPressed: () => _updateIncident(d, 'closed'),
                                child: const AppText('Close'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const AppText('Water Operations'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: AppTranslations.translate('Overview')),
              Tab(text: AppTranslations.translate('Storage')),
              Tab(text: AppTranslations.translate('Meters')),
              Tab(text: AppTranslations.translate('Readings')),
              Tab(text: AppTranslations.translate('Quality')),
              Tab(text: AppTranslations.translate('Distribution')),
              Tab(text: AppTranslations.translate('Incidents')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _overviewTab(),
            _storageTab(),
            _metersTab(),
            _readingsTab(),
            _qualityTab(),
            _distributionTab(),
            _incidentsTab(),
          ],
        ),
      ),
    );
  }
}
