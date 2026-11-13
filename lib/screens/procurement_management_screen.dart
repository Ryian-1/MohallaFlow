// MOHALLAFLOW_PROCUREMENT_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// End-to-end purchasing lifecycle for colony operations.
/// Reuses the existing vendor, inventory, stock movement and expense ledgers.
class ProcurementManagementScreen extends StatefulWidget {
  const ProcurementManagementScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<ProcurementManagementScreen> createState() =>
      _ProcurementManagementScreenState();
}

class _ProcurementManagementScreenState
    extends State<ProcurementManagementScreen> {
  CollectionReference<Map<String, dynamic>> get _colony => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('purchaseRequisitions');
  CollectionReference<Map<String, dynamic>> get _requisitions => _colony;
  CollectionReference<Map<String, dynamic>> get _quotations =>
      _colony.parent!.collection('purchaseQuotations');
  CollectionReference<Map<String, dynamic>> get _orders =>
      _colony.parent!.collection('purchaseOrders');
  CollectionReference<Map<String, dynamic>> get _receipts =>
      _colony.parent!.collection('purchaseGoodsReceipts');
  CollectionReference<Map<String, dynamic>> get _invoices =>
      _colony.parent!.collection('supplierInvoices');
  CollectionReference<Map<String, dynamic>> get _payments =>
      _colony.parent!.collection('supplierPayments');
  CollectionReference<Map<String, dynamic>> get _approvals =>
      _colony.parent!.collection('procurementApprovals');
  CollectionReference<Map<String, dynamic>> get _audit =>
      _colony.parent!.collection('procurementAudit');
  CollectionReference<Map<String, dynamic>> get _vendors =>
      _colony.parent!.collection('maintenanceVendors');
  CollectionReference<Map<String, dynamic>> get _inventory =>
      _colony.parent!.collection('inventoryItems');
  CollectionReference<Map<String, dynamic>> get _stockMovements =>
      _colony.parent!.collection('inventoryTransactions');
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _colony.parent!.collection('colonyExpenses');

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  static const _categories = <String, String>{
    'repairs': 'Repairs & maintenance',
    'electrical': 'Electrical',
    'plumbing': 'Plumbing',
    'cleaning': 'Cleaning & housekeeping',
    'security': 'Security & safety',
    'water': 'Water supply',
    'landscaping': 'Gardening & landscaping',
    'equipment': 'Equipment & tools',
    'administration': 'Administration',
    'other': 'Other',
  };
  static const _priorities = <String, String>{
    'low': 'Low',
    'normal': 'Normal',
    'high': 'High',
    'urgent': 'Urgent',
  };
  static const _methods = <String, String>{
    'upi': 'UPI',
    'bank_transfer': 'Bank transfer',
    'cash': 'Cash',
    'cheque': 'Cheque',
    'card': 'Card',
    'other': 'Other',
  };
  static const _vendorCategories = <String>[
    'Lift',
    'Plumbing',
    'Electrical',
    'Generator',
    'Water Supply',
    'Civil Work',
    'Security System',
    'Other',
  ];

  DateTime _asDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  String _date(Object? value) {
    final d = _asDate(value);
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _monthKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';

  double _num(Object? value) => value is num ? value.toDouble() : 0;
  double _round2(double value) => double.parse(value.toStringAsFixed(2));
  String _money(Object? value) => '₹${_num(value).toStringAsFixed(2)}';

  String _numbered(String prefix, String id) =>
      '$prefix-${DateTime.now().year}-${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}';

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _metric(String label, String value, IconData icon, {String? detail}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.navyBlue, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    value,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  AppText(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detail != null)
                    AppText(
                      detail,
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _empty(String title, String detail, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppTheme.textGrey),
          const SizedBox(height: 10),
          AppText(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          AppText(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _header(String title, String subtitle, {Widget? action}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              AppText(
                subtitle,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );

  Widget _status(String value) {
    final label = value.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: AppText(
        label,
        style: const TextStyle(
          color: AppTheme.secondaryNavy,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _error(String label, Object error) => Padding(
    padding: const EdgeInsets.all(16),
    child: AppText('$label: $error', style: const TextStyle(color: Colors.red)),
  );

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );

  Future<void> _createVendor() async {
    final name = TextEditingController();
    final contact = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    String category = _vendorCategories.last;
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const AppText('Register supplier / vendor'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      maxLength: 150,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Supplier / vendor name *',
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? AppTranslations.translate('Enter a name')
                          : null,
                    ),
                    TextFormField(
                      controller: contact,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Contact person'),
                      ),
                    ),
                    TextFormField(
                      controller: phone,
                      maxLength: 20,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Phone number *'),
                      ),
                      validator: (v) =>
                          (v == null ||
                              v.trim().length < 7 ||
                              v.trim().length > 20)
                          ? AppTranslations.translate(
                              'Enter a 7–20 character phone number',
                            )
                          : null,
                    ),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Email'),
                      ),
                      validator: (v) =>
                          (v != null &&
                              v.trim().isNotEmpty &&
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(v.trim()))
                          ? AppTranslations.translate(
                              'Enter a valid email address',
                            )
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Service category',
                        ),
                      ),
                      items: _vendorCategories
                          .map(
                            (e) =>
                                DropdownMenuItem(value: e, child: AppText(e)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setStateDialog(() => category = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const AppText('Save supplier'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final normalizedName = name.text.trim().toLowerCase();
      final normalizedPhone = phone.text.trim();
      final existing = await _vendors.get();
      final duplicate = existing.docs.any(
        (d) =>
            (d.data()['vendorName'] as String? ?? '').trim().toLowerCase() ==
                normalizedName ||
            (d.data()['phoneNumber'] as String? ?? '').trim() ==
                normalizedPhone,
      );
      if (duplicate) {
        _message(
          'A supplier with this name or phone number already exists in Maintenance → Vendors. Open that vendor instead of creating a duplicate.',
        );
        name.dispose();
        contact.dispose();
        phone.dispose();
        email.dispose();
        return;
      }
      await _vendors.add({
        'vendorName': name.text.trim(),
        'contactPerson': contact.text.trim(),
        'phoneNumber': phone.text.trim(),
        'email': email.text.trim(),
        'serviceCategory': category,
        'status': 'active',
        'createdBy': _uid,
        'createdByName': widget.adminName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Supplier added to the existing vendor register.');
    }
    name.dispose();
    contact.dispose();
    phone.dispose();
    email.dispose();
  }

  Future<Map<String, dynamic>?> _promptRequisitionLine() async {
    final inventoryDocs =
        (await _inventory.where('active', isEqualTo: true).get()).docs;
    if (!mounted) return null;
    final name = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final unit = TextEditingController(text: 'piece');
    final rate = TextEditingController(text: '0');
    String? inventoryId;
    final key = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const AppText('Add requested item'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (inventoryDocs.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        initialValue: inventoryId,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Link to existing inventory item (optional)',
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: AppText('No inventory link'),
                          ),
                          ...inventoryDocs.map(
                            (d) => DropdownMenuItem<String?>(
                              value: d.id,
                              child: AppText(
                                '${d.data()['name'] ?? 'Item'} (${d.data()['quantityOnHand'] ?? 0} ${d.data()['unit'] ?? ''})',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setStateDialog(() {
                            inventoryId = v;
                            if (v != null) {
                              final data = inventoryDocs
                                  .firstWhere((d) => d.id == v)
                                  .data();
                              name.text = data['name'] as String? ?? name.text;
                              unit.text = data['unit'] as String? ?? unit.text;
                              rate.text = _num(data['unitCost'])
                                  .toStringAsFixed(2);
                            }
                          });
                        },
                      ),
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Item / service description *',
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? AppTranslations.translate('Enter a description')
                          : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: quantity,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Quantity *',
                              ),
                            ),
                            validator: (v) =>
                                (double.tryParse(v ?? '') ?? 0) <= 0
                                ? AppTranslations.translate('Enter quantity')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: unit,
                            readOnly: inventoryId != null,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate('Unit *'),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? AppTranslations.translate('Enter unit')
                                : null,
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Estimated unit rate (₹) *',
                        ),
                      ),
                      validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0
                          ? AppTranslations.translate('Enter a valid rate')
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, {
                    'lineId': DateTime.now().microsecondsSinceEpoch.toString(),
                    'description': name.text.trim(),
                    'quantity': double.parse(quantity.text.trim()),
                    'unit': unit.text.trim(),
                    'estimatedUnitPrice': double.parse(rate.text.trim()),
                    'inventoryItemId': inventoryId,
                  });
                }
              },
              child: const AppText('Add item'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    quantity.dispose();
    unit.dispose();
    rate.dispose();
    return result;
  }

  Future<void> _createRequisition() async {
    final title = TextEditingController();
    final purpose = TextEditingController();
    final notes = TextEditingController();
    String category = 'other';
    String priority = 'normal';
    DateTime neededBy = DateTime.now().add(const Duration(days: 7));
    final lines = <Map<String, dynamic>>[];
    final key = GlobalKey<FormState>();
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('New purchase requisition'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: title,
                      maxLength: 150,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Request title *'),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? AppTranslations.translate('Enter a title')
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Purchase category',
                        ),
                      ),
                      items: _categories.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: AppText(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => category = v);
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Priority'),
                      ),
                      items: _priorities.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: AppText(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => priority = v);
                      },
                    ),
                    TextFormField(
                      controller: purpose,
                      maxLength: 2000,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Business justification / reason *',
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().length < 5)
                          ? AppTranslations.translate(
                              'Explain why this purchase is required',
                            )
                          : null,
                    ),
                    TextFormField(
                      controller: notes,
                      maxLength: 2000,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Specifications / notes (optional)',
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final date = await _pickDate(neededBy);
                          if (date != null) {
                            setDialogState(() => neededBy = date);
                          }
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: AppText('Required by: ${_date(neededBy)}'),
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Expanded(
                          child: AppText(
                            'Requested line items',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            if (lines.length >= 30) return;
                            final line = await _promptRequisitionLine();
                            if (line != null) {
                              setDialogState(() => lines.add(line));
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const AppText('Add item'),
                        ),
                      ],
                    ),
                    if (lines.isEmpty)
                      const AppText(
                        'Add at least one item before saving.',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ...lines.asMap().entries.map(
                      (e) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: AppText(e.value['description'] as String),
                        subtitle: AppText(
                          '${e.value['quantity']} ${e.value['unit']} × ${_money(e.value['estimatedUnitPrice'])}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () =>
                              setDialogState(() => lines.removeAt(e.key)),
                        ),
                      ),
                    ),
                    if (lines.isNotEmpty)
                      AppText(
                        'Estimated total: ${_money(lines.fold<double>(0, (accumulator, line) => accumulator + _num(line['quantity']) * _num(line['estimatedUnitPrice'])))}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const AppText('Cancel'),
            ),
            OutlinedButton(
              onPressed: () {
                if ((key.currentState?.validate() ?? false) &&
                    lines.isNotEmpty) {
                  Navigator.pop(dialogContext, 'draft');
                } else {
                  _message(
                    'Complete the required fields and add at least one line item.',
                  );
                }
              },
              child: const AppText('Save draft'),
            ),
            FilledButton(
              onPressed: () {
                if ((key.currentState?.validate() ?? false) &&
                    lines.isNotEmpty) {
                  Navigator.pop(dialogContext, 'submitted');
                } else {
                  _message(
                    'Complete the required fields and add at least one line item.',
                  );
                }
              },
              child: const AppText('Submit for approval'),
            ),
          ],
        ),
      ),
    );
    if (action != null) {
      final estimated = lines.fold<double>(
        0,
        (accumulator, line) =>
            accumulator +
            _num(line['quantity']) * _num(line['estimatedUnitPrice']),
      );
      final ref = _requisitions.doc();
      final reqNo = _numbered('REQ', ref.id);
      final auditRef = _audit.doc();
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(ref, {
          'requestNumber': reqNo,
          'title': title.text.trim(),
          'category': category,
          'priority': priority,
          'purpose': purpose.text.trim(),
          'notes': notes.text.trim(),
          'neededBy': Timestamp.fromDate(neededBy),
          'status': action,
          'items': lines,
          'estimatedSubtotal': estimated,
          'estimatedTotal': estimated,
          'requestedBy': _uid,
          'requestedByName': widget.adminName,
          'reviewedBy': null,
          'reviewedByName': null,
          'reviewedAt': null,
          'reviewNote': '',
          'lastApprovalId': null,
          'selectedQuoteId': null,
          'purchaseOrderId': null,
          'createdBy': _uid,
          'createdByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(auditRef, {
          'action': action == 'draft'
              ? 'requisition_draft_created'
              : 'requisition_submitted',
          'entityType': 'purchaseRequisition',
          'entityId': ref.id,
          'summary':
              '$reqNo ${action == 'draft' ? 'saved as draft' : 'submitted for approval'}',
          'performedBy': _uid,
          'performedByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      _message(
        action == 'draft'
            ? 'Requisition saved as draft.'
            : 'Requisition submitted for Admin approval.',
      );
    }
    title.dispose();
    purpose.dispose();
    notes.dispose();
  }

  Future<void> _reviewRequisition(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (!['submitted', 'under_review'].contains(data['status'])) return;
    final note = TextEditingController();
    final decision = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('Review ${data['requestNumber'] ?? 'requisition'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              '${data['title'] ?? ''}\nEstimated: ${_money(data['estimatedTotal'])}\nPriority: ${data['priority'] ?? ''}',
            ),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppTranslations.translate(
                  'Approval / rejection remarks',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (note.text.trim().length >= 5) {
                Navigator.pop(dialogContext, 'rejected');
              } else {
                _message('Enter a rejection reason of at least 5 characters.');
              }
            },
            child: const AppText('Reject'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'approved'),
            child: const AppText('Approve request'),
          ),
        ],
      ),
    );
    if (decision != null) {
      final approvalRef = _approvals.doc();
      final auditRef = _audit.doc();
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final latest = await transaction.get(doc.reference);
        if (!latest.exists ||
            !['submitted', 'under_review'].contains(latest.data()?['status'])) {
          throw StateError(
            'This requisition has already been reviewed. Refresh and try again.',
          );
        }
        transaction.update(doc.reference, {
          'status': decision,
          'reviewedBy': _uid,
          'reviewedByName': widget.adminName,
          'reviewedAt': FieldValue.serverTimestamp(),
          'lastApprovalId': approvalRef.id,
          'reviewNote': note.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(approvalRef, {
          'action': decision,
          'entityType': 'purchaseRequisition',
          'entityId': doc.id,
          'referenceNumber': data['requestNumber'] ?? '',
          'remarks': note.text.trim(),
          'approvedAmount': _num(data['estimatedTotal']),
          'performedBy': _uid,
          'performedByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(auditRef, {
          'action': 'requisition_$decision',
          'entityType': 'purchaseRequisition',
          'entityId': doc.id,
          'summary': '${data['requestNumber'] ?? ''} $decision',
          'performedBy': _uid,
          'performedByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      _message('Requisition $decision.');
    }
    note.dispose();
  }

  Future<void> _createQuotation() async {
    final reqDocs =
        (await _requisitions.where('status', isEqualTo: 'approved').get()).docs;
    final vendorDocs =
        (await _vendors.where('status', isEqualTo: 'active').get()).docs;
    if (!mounted) return;
    if (reqDocs.isEmpty) {
      _message('Approve a requisition before recording supplier quotations.');
      return;
    }
    if (vendorDocs.isEmpty) {
      _message(
        'Register at least one supplier in Maintenance → Vendors, then record the quotation.',
      );
      return;
    }
    String? reqId = reqDocs.first.id;
    String? vendorId = vendorDocs.first.id;
    final quoteNo = TextEditingController();
    final tax = TextEditingController(text: '0');
    final freight = TextEditingController(text: '0');
    final discount = TextEditingController(text: '0');
    final deliveryDays = TextEditingController(text: '7');
    final terms = TextEditingController();
    final notes = TextEditingController();
    List<Map<String, dynamic>> quoteLines =
        (reqDocs.first.data()['items'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    List<TextEditingController> rateControllers = quoteLines
        .map(
          (e) => TextEditingController(
            text: _num(e['estimatedUnitPrice']).toStringAsFixed(2),
          ),
        )
        .toList();
    DateTime validUntil = DateTime.now().add(const Duration(days: 15));
    double quoteSubtotal() => _round2(
      quoteLines.asMap().entries.fold<double>(
        0,
        (accumulator, entry) =>
            accumulator +
            _num(entry.value['quantity']) *
                (double.tryParse(rateControllers[entry.key].text.trim()) ?? 0),
      ),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Record supplier quotation'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: reqId,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Approved requisition',
                      ),
                    ),
                    items: reqDocs
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: AppText(
                              '${d.data()['requestNumber']}: ${d.data()['title']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      for (final c in rateControllers) {
                        c.dispose();
                      }
                      final selected = reqDocs.firstWhere((d) => d.id == v);
                      quoteLines =
                          (selected.data()['items'] as List<dynamic>? ?? [])
                              .map((e) => Map<String, dynamic>.from(e as Map))
                              .toList();
                      rateControllers = quoteLines
                          .map(
                            (e) => TextEditingController(
                              text: _num(e['estimatedUnitPrice'])
                                  .toStringAsFixed(2),
                            ),
                          )
                          .toList();
                      setDialogState(() => reqId = v);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: vendorId,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Supplier'),
                    ),
                    items: vendorDocs
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: AppText(
                              d.data()['vendorName'] as String? ?? 'Vendor',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => vendorId = v),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      'To add a supplier, register it in Maintenance → Vendors, then reopen this quotation form.',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                    ),
                  ),
                  TextField(
                    controller: quoteNo,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Supplier quotation reference',
                      ),
                    ),
                  ),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      'Supplier item rates',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  ...quoteLines.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppText(
                              '${entry.value['description']}\n${entry.value['quantity']} ${entry.value['unit']}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          SizedBox(
                            width: 130,
                            child: TextField(
                              controller: rateControllers[entry.key],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: AppTranslations.translate('Rate ₹'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppText(
                      'Quoted subtotal: ${_money(quoteSubtotal())}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tax,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Tax / GST ₹'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: freight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Freight ₹'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: discount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Discount ₹'),
                    ),
                  ),
                  TextField(
                    controller: deliveryDays,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Delivery lead time (days)',
                      ),
                    ),
                  ),
                  TextField(
                    controller: terms,
                    maxLength: 2000,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Payment / warranty / commercial terms',
                      ),
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLength: 2000,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Notes / exclusions',
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final d = await _pickDate(validUntil);
                        if (d != null) setDialogState(() => validUntil = d);
                      },
                      icon: const Icon(Icons.event),
                      label: AppText('Quote valid until: ${_date(validUntil)}'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppText(
                      'Landed total: ${_money(quoteSubtotal() + (double.tryParse(tax.text) ?? 0) + (double.tryParse(freight.text) ?? 0) - (double.tryParse(discount.text) ?? 0))}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Save quotation'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && reqId != null && vendorId != null) {
      final sub = quoteSubtotal();
      final taxRaw = double.tryParse(
        tax.text.trim().isEmpty ? '0' : tax.text.trim(),
      );
      final freightRaw = double.tryParse(
        freight.text.trim().isEmpty ? '0' : freight.text.trim(),
      );
      final discountRaw = double.tryParse(
        discount.text.trim().isEmpty ? '0' : discount.text.trim(),
      );
      final taxValue = taxRaw == null ? null : _round2(taxRaw);
      final freightValue = freightRaw == null ? null : _round2(freightRaw);
      final discountValue = discountRaw == null ? null : _round2(discountRaw);
      final days = int.tryParse(deliveryDays.text.trim()) ?? 0;
      final invalidRate = rateControllers.any(
        (c) =>
            double.tryParse(c.text.trim()) == null ||
            double.parse(c.text.trim()) < 0,
      );
      if (invalidRate ||
          sub <= 0 ||
          taxValue == null ||
          freightValue == null ||
          discountValue == null ||
          [taxValue, freightValue, discountValue].any((v) => v < 0) ||
          discountValue > sub + taxValue + freightValue ||
          days < 0) {
        _message(
          'Enter valid line-item rates, tax, freight, discount and delivery days.',
        );
      } else {
        final req = reqDocs.firstWhere((d) => d.id == reqId);
        final vendor = vendorDocs.firstWhere((d) => d.id == vendorId).data();
        final ref = _quotations.doc();
        final auditRef = _audit.doc();
        final quoteLineSnapshot = quoteLines.asMap().entries.map((entry) {
          final line = Map<String, dynamic>.from(entry.value);
          final unitRate = _round2(
            double.parse(rateControllers[entry.key].text.trim()),
          );
          line['unitPrice'] = unitRate;
          line['lineTotal'] = _round2(_num(line['quantity']) * unitRate);
          return line;
        }).toList();
        final total = _round2(sub + taxValue + freightValue - discountValue);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.set(ref, {
            'quoteNumber': quoteNo.text.trim().isEmpty
                ? 'QUOTE-${ref.id.substring(0, 6).toUpperCase()}'
                : quoteNo.text.trim(),
            'requisitionId': reqId,
            'requisitionNumber': req.data()['requestNumber'] ?? '',
            'vendorId': vendorId,
            'vendorName': vendor['vendorName'] ?? '',
            'vendorPhone': vendor['phoneNumber'] ?? '',
            'quoteDate': Timestamp.fromDate(DateTime.now()),
            'validUntil': Timestamp.fromDate(validUntil),
            'deliveryDays': days,
            'items': quoteLineSnapshot,
            'subtotal': sub,
            'taxAmount': taxValue,
            'freight': freightValue,
            'discount': discountValue,
            'total': total,
            'paymentTerms': terms.text.trim(),
            'notes': notes.text.trim(),
            'status': 'received',
            'createdBy': _uid,
            'createdByName': widget.adminName,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.set(auditRef, {
            'action': 'quotation_recorded',
            'entityType': 'purchaseQuotation',
            'entityId': ref.id,
            'summary':
                'Quotation ${quoteNo.text.trim()} from ${vendor['vendorName'] ?? ''} recorded',
            'performedBy': _uid,
            'performedByName': widget.adminName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        _message('Supplier quotation recorded with item-wise pricing.');
      }
    }
    quoteNo.dispose();
    tax.dispose();
    freight.dispose();
    discount.dispose();
    deliveryDays.dispose();
    terms.dispose();
    notes.dispose();
    for (final c in rateControllers) {
      c.dispose();
    }
  }

  Future<void> _awardQuotation(
    QueryDocumentSnapshot<Map<String, dynamic>> quoteDoc,
  ) async {
    final quote = quoteDoc.data();
    if (_asDate(quote['validUntil']).isBefore(DateTime.now())) {
      _message(
        'This quotation has expired. Record a refreshed quotation before awarding it.',
      );
      return;
    }
    final reqRef = _requisitions.doc(quote['requisitionId'] as String? ?? '');
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists || reqSnap.data()?['status'] != 'approved') {
      _message('The linked requisition is no longer approved.');
      return;
    }
    final req = reqSnap.data()!;
    final quoteCount =
        (await _quotations.where('requisitionId', isEqualTo: reqRef.id).get())
            .docs
            .length;
    if (!mounted) return;
    final justification = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Award quotation and issue purchase order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              '${quote['vendorName']}\nTotal: ${_money(quote['total'])}\nQuotations received: $quoteCount',
            ),
            if (quoteCount < 2)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: AppText(
                  'Only one quotation is recorded. Add more quotations or enter an award justification before issuing the PO.',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
              ),
            TextField(
              controller: justification,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppTranslations.translate(
                  'Award decision / comparison justification *',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (justification.text.trim().length >= 5) {
                Navigator.pop(dialogContext, true);
              } else {
                _message('Enter the award justification.');
              }
            },
            child: const AppText('Issue purchase order'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final orderRef = _orders.doc();
      final approvalRef = _approvals.doc();
      final auditRef = _audit.doc();
      final poNo = _numbered('PO', orderRef.id);
      final orderItems = (quote['items'] as List<dynamic>? ?? []).map((raw) {
        final line = Map<String, dynamic>.from(raw as Map);
        line['orderedQty'] = _num(line['quantity']);
        line['receivedQty'] = 0.0;
        line['rejectedQty'] = 0.0;
        line['invoicedQty'] = 0.0;
        return line;
      }).toList();
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final latestReq = await transaction.get(reqRef);
        final latestQuote = await transaction.get(quoteDoc.reference);
        if (latestReq.data()?['status'] != 'approved' ||
            latestQuote.data()?['status'] != 'received') {
          throw StateError(
            'The requisition or quotation changed. Refresh before issuing a PO.',
          );
        }
        transaction.set(orderRef, {
          'poNumber': poNo,
          'requisitionId': reqRef.id,
          'requisitionNumber': req['requestNumber'] ?? '',
          'quotationId': quoteDoc.id,
          'quotationNumber': quote['quoteNumber'] ?? '',
          'vendorId': quote['vendorId'],
          'vendorName': quote['vendorName'],
          'vendorPhone': quote['vendorPhone'] ?? '',
          'category': req['category'] ?? 'other',
          'orderDate': Timestamp.fromDate(DateTime.now()),
          'expectedDelivery': Timestamp.fromDate(
            DateTime.now().add(
              Duration(days: (quote['deliveryDays'] as num?)?.toInt() ?? 7),
            ),
          ),
          'status': 'issued',
          'items': orderItems,
          'lastReceiptId': null,
          'lastInvoiceId': null,
          'subtotal': _num(quote['subtotal']),
          'taxAmount': _num(quote['taxAmount']),
          'freight': _num(quote['freight']),
          'discount': _num(quote['discount']),
          'total': _num(quote['total']),
          'paymentTerms': quote['paymentTerms'] ?? '',
          'awardJustification': justification.text.trim(),
          'createdBy': _uid,
          'createdByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(reqRef, {
          'status': 'ordered',
          'selectedQuoteId': quoteDoc.id,
          'purchaseOrderId': orderRef.id,
          'purchaseOrderNumber': poNo,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(quoteDoc.reference, {
          'status': 'awarded',
          'selectedAt': FieldValue.serverTimestamp(),
          'awardedPurchaseOrderId': orderRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(approvalRef, {
          'action': 'quotation_awarded',
          'entityType': 'purchaseOrder',
          'entityId': orderRef.id,
          'referenceNumber': poNo,
          'remarks': justification.text.trim(),
          'approvedAmount': _num(quote['total']),
          'performedBy': _uid,
          'performedByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(auditRef, {
          'action': 'purchase_order_issued',
          'entityType': 'purchaseOrder',
          'entityId': orderRef.id,
          'summary': '$poNo issued to ${quote['vendorName']}',
          'performedBy': _uid,
          'performedByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      _message('Purchase order $poNo issued.');
    }
    justification.dispose();
  }

  Future<void> _recordGoodsReceipt(
    QueryDocumentSnapshot<Map<String, dynamic>> orderDoc,
  ) async {
    final order = orderDoc.data();
    if (!['issued', 'partially_received'].contains(order['status'])) {
      _message('This purchase order is no longer open for goods receipt.');
      return;
    }
    final orderItems = (order['items'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final acceptedCtrls = orderItems
        .map((e) => TextEditingController(text: '0'))
        .toList();
    final rejectedCtrls = orderItems
        .map((e) => TextEditingController(text: '0'))
        .toList();
    final notesCtrls = orderItems.map((e) => TextEditingController()).toList();
    final challan = TextEditingController();
    final notes = TextEditingController();
    DateTime receivedDate = DateTime.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText('Receive goods · ${order['poNumber']}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      'Supplier: ${order['vendorName'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final d = await _pickDate(receivedDate);
                        if (d != null) setDialogState(() => receivedDate = d);
                      },
                      icon: const Icon(Icons.event),
                      label: AppText('Receipt date: ${_date(receivedDate)}'),
                    ),
                  ),
                  TextField(
                    controller: challan,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Delivery challan / gate entry reference',
                      ),
                    ),
                  ),
                  ...orderItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final line = entry.value;
                    final pending =
                        (_num(line['orderedQty']) - _num(line['receivedQty']))
                            .clamp(0, 1000000000)
                            .toDouble();
                    return Card(
                      color: AppTheme.lightGrey,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              '${line['description']} · Pending accepted: $pending ${line['unit']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: acceptedCtrls[i],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: AppTranslations.translate(
                                        'Accepted qty',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: rejectedCtrls[i],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: AppTranslations.translate(
                                        'Rejected qty',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            TextField(
                              controller: notesCtrls[i],
                              decoration: InputDecoration(
                                labelText: AppTranslations.translate(
                                  'Shortage / damage note (optional)',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Receipt remarks'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Save goods receipt'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final accepted = <double>[];
      final rejected = <double>[];
      bool valid = false;
      for (var i = 0; i < orderItems.length; i++) {
        final a = double.tryParse(acceptedCtrls[i].text.trim()) ?? -1;
        final r = double.tryParse(rejectedCtrls[i].text.trim()) ?? -1;
        final remaining =
            _num(orderItems[i]['orderedQty']) -
            _num(orderItems[i]['receivedQty']);
        if (a < 0 ||
            r < 0 ||
            a + r > remaining + 0.000001 ||
            (r > 0 && notesCtrls[i].text.trim().length < 3)) {
          valid = true;
          break;
        }
        accepted.add(a);
        rejected.add(r);
      }
      if (valid ||
          accepted.every((e) => e == 0) && rejected.every((e) => e == 0)) {
        _message(
          'Enter valid quantities within the outstanding PO quantity. A rejected quantity also needs a short damage / shortage reason.',
        );
      } else {
        try {
          await _commitGoodsReceipt(
            orderDoc,
            accepted,
            rejected,
            notesCtrls.map((e) => e.text.trim()).toList(),
            challan.text.trim(),
            notes.text.trim(),
            receivedDate,
          );
        } on StateError catch (e) {
          _message(e.message.toString());
        } on FirebaseException catch (e) {
          _message('Goods receipt failed: ${e.message ?? e.code}');
        }
      }
    }
    for (final c in [...acceptedCtrls, ...rejectedCtrls, ...notesCtrls]) {
      c.dispose();
    }
    challan.dispose();
    notes.dispose();
  }

  Future<void> _commitGoodsReceipt(
    QueryDocumentSnapshot<Map<String, dynamic>> orderDoc,
    List<double> accepted,
    List<double> rejected,
    List<String> lineNotes,
    String challan,
    String notes,
    DateTime date,
  ) async {
    final orderRef = orderDoc.reference;
    final receiptRef = _receipts.doc();
    final auditRef = _audit.doc();
    final receiptNo = _numbered('GRN', receiptRef.id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final latestOrder = await transaction.get(orderRef);
      if (!latestOrder.exists ||
          ![
            'issued',
            'partially_received',
          ].contains(latestOrder.data()?['status'])) {
        throw StateError('Purchase order is no longer open for goods receipt.');
      }
      final latestItems = (latestOrder.data()?['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final inventorySnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (var i = 0; i < latestItems.length; i++) {
        final line = latestItems[i];
        final a = accepted[i];
        final r = rejected[i];
        final remaining = _num(line['orderedQty']) - _num(line['receivedQty']);
        if (a < 0 || r < 0 || a + r > remaining + 0.000001) {
          throw StateError(
            'Received quantity for ${line['description']} exceeds the current outstanding quantity. Refresh the order.',
          );
        }
        if (a > 0 && line['inventoryItemId'] is String) {
          final id = line['inventoryItemId'] as String;
          if (!inventorySnapshots.containsKey(id)) {
            inventorySnapshots[id] = await transaction.get(_inventory.doc(id));
          }
          if (inventorySnapshots[id]?.exists != true) {
            throw StateError(
              'Linked inventory item ${line['description']} no longer exists.',
            );
          }
        }
      }
      final receiptLines = <Map<String, dynamic>>[];
      var allAccepted = true;
      for (var i = 0; i < latestItems.length; i++) {
        final line = latestItems[i];
        line['receivedQty'] = _num(line['receivedQty']) + accepted[i];
        line['rejectedQty'] = _num(line['rejectedQty']) + rejected[i];
        if (_num(line['receivedQty']) + 0.000001 < _num(line['orderedQty'])) {
          allAccepted = false;
        }
        receiptLines.add({
          'lineId': line['lineId'] ?? line['description'],
          'description': line['description'],
          'unit': line['unit'],
          'acceptedQty': accepted[i],
          'rejectedQty': rejected[i],
          'lineNote': lineNotes[i],
          'inventoryItemId': line['inventoryItemId'],
        });
      }
      // Aggregate duplicate PO lines that point to the same inventory item.
      // This guarantees one consistent stock update and one immutable movement
      // per item, avoiding conflicting before/after quantities in Firestore rules.
      final stockByItem = <String, Map<String, dynamic>>{};
      for (var i = 0; i < latestItems.length; i++) {
        final line = latestItems[i];
        if (accepted[i] <= 0 || line['inventoryItemId'] is! String) continue;
        final itemId = line['inventoryItemId'] as String;
        final itemData = inventorySnapshots[itemId]!.data()!;
        final purchaseRate = _num(
          line['unitPrice'] ?? line['estimatedUnitPrice'],
        );
        final existing = stockByItem[itemId];
        if (existing == null) {
          stockByItem[itemId] = {
            'itemRef': _inventory.doc(itemId),
            'itemData': itemData,
            'oldQty': _num(itemData['quantityOnHand']),
            'accepted': accepted[i],
            'totalCost': accepted[i] * purchaseRate,
            'movementRef': _stockMovements.doc(),
            'itemId': itemId,
          };
        } else {
          existing['accepted'] = (existing['accepted'] as double) + accepted[i];
          existing['totalCost'] =
              (existing['totalCost'] as double) + accepted[i] * purchaseRate;
        }
      }
      final stockWrites = stockByItem.values.toList();
      if (stockWrites.length > 8) {
        throw StateError(
          'This receipt links more than 8 inventory items. Split it into multiple goods receipts so stock updates remain within Firestore security-rule transaction limits.',
        );
      }
      // All transaction reads have completed before the first write.
      for (final stock in stockWrites) {
        final oldQty = stock['oldQty'] as double;
        final acceptedQty = stock['accepted'] as double;
        final newQty = oldQty + acceptedQty;
        final itemData = stock['itemData'] as Map<String, dynamic>;
        final weightedCost = newQty > 0
            ? ((oldQty * _num(itemData['unitCost'])) +
                      (stock['totalCost'] as double)) /
                  newQty
            : 0.0;
        transaction.update(
          stock['itemRef'] as DocumentReference<Map<String, dynamic>>,
          {
            'quantityOnHand': newQty,
            'unitCost': _round2(weightedCost),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
        final movementRef =
            stock['movementRef'] as DocumentReference<Map<String, dynamic>>;
        transaction.set(movementRef, {
          'inventoryItemId': stock['itemId'],
          'itemName': itemData['name'] ?? '',
          'transactionType': 'stock_in',
          'quantity': acceptedQty,
          'previousQuantity': oldQty,
          'resultingQuantity': newQty,
          'change': acceptedQty,
          'reason': 'Purchase receipt $receiptNo',
          'reference': receiptNo,
          'performedBy': _uid,
          'performedByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.update(orderRef, {
        'items': latestItems,
        'status': allAccepted ? 'received' : 'partially_received',
        'lastReceiptId': receiptRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
        if (allAccepted) 'receivedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(receiptRef, {
        'receiptNumber': receiptNo,
        'purchaseOrderId': orderRef.id,
        'purchaseOrderNumber': latestOrder.data()?['poNumber'] ?? '',
        'vendorId': latestOrder.data()?['vendorId'] ?? '',
        'vendorName': latestOrder.data()?['vendorName'] ?? '',
        'receivedDate': Timestamp.fromDate(date),
        'challanReference': challan,
        'items': receiptLines,
        'notes': notes,
        'createdBy': _uid,
        'createdByName': widget.adminName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(auditRef, {
        'action': 'goods_received',
        'entityType': 'goodsReceipt',
        'entityId': receiptRef.id,
        'summary':
            '$receiptNo recorded against ${latestOrder.data()?['poNumber'] ?? ''}',
        'performedBy': _uid,
        'performedByName': widget.adminName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    _message(
      'Goods receipt saved. Linked stock was increased with an immutable inventory movement record.',
    );
  }

  Future<void> _createInvoice() async {
    final allOrders = (await _orders.get()).docs;
    if (!mounted) return;
    // Invoiced quantities live on each PO line and are updated atomically with
    // the invoice document. This is safer than inferring quantity from a stale
    // invoice list when two invoices are being registered close together.
    List<Map<String, dynamic>> invoiceableLines(
      QueryDocumentSnapshot<Map<String, dynamic>> orderDoc,
    ) {
      final items = (orderDoc.data()['items'] as List<dynamic>? ?? [])
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList();
      return items
          .map((line) {
            line['availableToInvoice'] =
                (_num(line['receivedQty']) - _num(line['invoicedQty']))
                    .clamp(0, 1000000000)
                    .toDouble();
            return line;
          })
          .where((line) => _num(line['availableToInvoice']) > 0.000001)
          .toList();
    }

    final orderDocs = allOrders
        .where(
          (doc) =>
              doc.data()['status'] != 'cancelled' &&
              invoiceableLines(doc).isNotEmpty,
        )
        .toList();
    if (orderDocs.isEmpty) {
      _message(
        'Record an accepted goods receipt first. Invoice quantities must match goods received and not previously invoiced.',
      );
      return;
    }

    String? orderId = orderDocs.first.id;
    List<Map<String, dynamic>> lines = invoiceableLines(orderDocs.first);
    List<TextEditingController> quantityControllers = lines
        .map(
          (line) => TextEditingController(
            text: _num(line['availableToInvoice']).toString(),
          ),
        )
        .toList();
    List<TextEditingController> rateControllers = lines
        .map(
          (line) => TextEditingController(
            text: _num(line['unitPrice'] ?? line['estimatedUnitPrice'])
                .toStringAsFixed(2),
          ),
        )
        .toList();
    final invoiceNo = TextEditingController();
    final tax = TextEditingController(text: '0');
    final freight = TextEditingController(text: '0');
    final discount = TextEditingController(text: '0');
    final notes = TextEditingController();
    DateTime invoiceDate = DateTime.now();
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));
    double invoiceSubtotal() => _round2(
      lines.asMap().entries.fold<double>(
        0,
        (accumulator, entry) =>
            accumulator +
            _round2(
              (double.tryParse(quantityControllers[entry.key].text.trim()) ??
                      0) *
                  (double.tryParse(rateControllers[entry.key].text.trim()) ??
                      0),
            ),
      ),
    );
    void replaceInvoiceLines(String selectedId) {
      for (final c in [...quantityControllers, ...rateControllers]) {
        c.dispose();
      }
      final selected = orderDocs.firstWhere((d) => d.id == selectedId);
      lines = invoiceableLines(selected);
      quantityControllers = lines
          .map(
            (line) => TextEditingController(
              text: _num(line['availableToInvoice']).toString(),
            ),
          )
          .toList();
      rateControllers = lines
          .map(
            (line) => TextEditingController(
              text: _num(line['unitPrice'] ?? line['estimatedUnitPrice'])
                  .toStringAsFixed(2),
            ),
          )
          .toList();
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Record supplier invoice · 3-way match'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: orderId,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Purchase order with unbilled accepted goods',
                      ),
                    ),
                    items: orderDocs
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: AppText(
                              '${d.data()['poNumber']} · ${d.data()['vendorName']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          orderId = v;
                          replaceInvoiceLines(v);
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: invoiceNo,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Supplier invoice number *',
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final d = await _pickDate(invoiceDate);
                            if (d != null) {
                              setDialogState(() => invoiceDate = d);
                            }
                          },
                          child: AppText('Invoice date\n${_date(invoiceDate)}'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final d = await _pickDate(dueDate);
                            if (d != null) setDialogState(() => dueDate = d);
                          },
                          child: AppText('Due date\n${_date(dueDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      'Invoice line matching',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      'Only accepted quantities not already invoiced are available. Compare the supplier invoice against the PO and goods receipt before saving.',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                    ),
                  ),
                  ...lines.asMap().entries.map((entry) {
                    final i = entry.key;
                    final line = entry.value;
                    return Card(
                      color: AppTheme.lightGrey,
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              line['description'] as String? ?? 'Item',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            AppText(
                              'PO qty ${_num(line['orderedQty'])} ${line['unit']} · Accepted ${_num(line['receivedQty'])} · Previously invoiced ${_num(line['invoicedQty'])} · Available ${_num(line['availableToInvoice'])}',
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 10,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: quantityControllers[i],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (_) => setDialogState(() {}),
                                    decoration: InputDecoration(
                                      labelText: AppTranslations.translate(
                                        'Invoice qty',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: rateControllers[i],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (_) => setDialogState(() {}),
                                    decoration: InputDecoration(
                                      labelText: AppTranslations.translate(
                                        'Unit rate ₹',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppText(
                      'Line subtotal: ${_money(invoiceSubtotal())}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tax,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Tax / GST ₹'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: freight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Freight ₹'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: discount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Discount ₹'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppText(
                      'Invoice total: ${_money(invoiceSubtotal() + (double.tryParse(tax.text) ?? 0) + (double.tryParse(freight.text) ?? 0) - (double.tryParse(discount.text) ?? 0))}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLength: 2000,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Invoice notes / PO or GRN variance explanation',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Save for verification'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && orderId != null) {
      final sub = invoiceSubtotal();
      final taxRaw = double.tryParse(
        tax.text.trim().isEmpty ? '0' : tax.text.trim(),
      );
      final freightRaw = double.tryParse(
        freight.text.trim().isEmpty ? '0' : freight.text.trim(),
      );
      final discountRaw = double.tryParse(
        discount.text.trim().isEmpty ? '0' : discount.text.trim(),
      );
      final taxValue = taxRaw == null ? null : _round2(taxRaw);
      final freightValue = freightRaw == null ? null : _round2(freightRaw);
      final discountValue = discountRaw == null ? null : _round2(discountRaw);
      final invalidLines = lines.asMap().entries.any((entry) {
        final qty = double.tryParse(quantityControllers[entry.key].text.trim());
        final rate = double.tryParse(rateControllers[entry.key].text.trim());
        return qty == null ||
            rate == null ||
            qty < 0 ||
            rate < 0 ||
            qty > _num(entry.value['availableToInvoice']) + 0.000001;
      });
      final hasBillableLine = quantityControllers.any(
        (c) => (double.tryParse(c.text.trim()) ?? 0) > 0,
      );
      if (invoiceNo.text.trim().isEmpty ||
          invoiceNo.text.trim().length > 120 ||
          sub <= 0 ||
          invalidLines ||
          !hasBillableLine ||
          taxValue == null ||
          freightValue == null ||
          discountValue == null ||
          [taxValue, freightValue, discountValue].any((v) => v < 0) ||
          discountValue > sub + taxValue + freightValue ||
          dueDate.isBefore(invoiceDate)) {
        _message(
          'Enter a valid invoice number, quantities within accepted/unbilled receipt quantities, unit rates and invoice totals.',
        );
      } else {
        final orderDoc = orderDocs.firstWhere((d) => d.id == orderId);
        final order = orderDoc.data();
        final total = _round2(sub + taxValue + freightValue - discountValue);
        final varianceNeedsNote = lines.asMap().entries.any((entry) {
          final qty =
              double.tryParse(quantityControllers[entry.key].text.trim()) ?? 0;
          if (qty <= 0) return false;
          final awardedRate = _num(
            entry.value['unitPrice'] ?? entry.value['estimatedUnitPrice'],
          );
          final billedRate =
              double.tryParse(rateControllers[entry.key].text.trim()) ?? 0;
          return (billedRate - awardedRate).abs() > 0.01;
        });
        if (varianceNeedsNote && notes.text.trim().length < 5) {
          _message(
            'One or more billed unit rates differ from the awarded PO. Enter a short variance explanation in the notes.',
          );
        } else {
          final safeNumber = invoiceNo.text.trim().toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9_-]'),
            '_',
          );
          if (safeNumber.isEmpty) {
            _message(
              'Supplier invoice number must contain at least one letter or number.',
            );
          } else {
            final invoiceRef = _invoices.doc(
              '${order['vendorId']}_${safeNumber.length > 80 ? safeNumber.substring(0, 80) : safeNumber}',
            );
            final auditRef = _audit.doc();
            final requestedLines = lines
                .asMap()
                .entries
                .where(
                  (entry) =>
                      (double.tryParse(
                            quantityControllers[entry.key].text.trim(),
                          ) ??
                          0) >
                      0,
                )
                .map((entry) {
                  final line = entry.value;
                  final qty = _round2(
                    double.parse(quantityControllers[entry.key].text.trim()),
                  );
                  final rate = _round2(
                    double.parse(rateControllers[entry.key].text.trim()),
                  );
                  return <String, dynamic>{
                    'lineId':
                        line['lineId']?.toString() ??
                        line['description']?.toString() ??
                        '',
                    'description': line['description'] ?? '',
                    'unit': line['unit'] ?? '',
                    'invoicedQty': qty,
                    'receivedQty': _num(line['receivedQty']),
                    'unitPrice': rate,
                    'lineTotal': _round2(qty * rate),
                    'inventoryItemId': line['inventoryItemId'],
                  };
                })
                .toList();
            try {
              await FirebaseFirestore.instance.runTransaction((
                transaction,
              ) async {
                final latestOrder = await transaction.get(orderDoc.reference);
                final existingInvoice = await transaction.get(invoiceRef);
                if (!latestOrder.exists ||
                    latestOrder.data()?['status'] == 'cancelled') {
                  throw StateError(
                    'The purchase order is no longer available for invoicing.',
                  );
                }
                if (existingInvoice.exists) {
                  throw StateError(
                    'An invoice with this supplier reference is already registered.',
                  );
                }
                final latestItems =
                    (latestOrder.data()?['items'] as List<dynamic>? ?? [])
                        .map((raw) => Map<String, dynamic>.from(raw as Map))
                        .toList();
                final invoiceItems = <Map<String, dynamic>>[];
                for (final requested in requestedLines) {
                  final index = latestItems.indexWhere(
                    (line) =>
                        (line['lineId']?.toString() ??
                            line['description']?.toString() ??
                            '') ==
                        requested['lineId'],
                  );
                  if (index < 0) {
                    throw StateError(
                      'A purchase-order line changed. Refresh the PO and retry.',
                    );
                  }
                  final latestLine = latestItems[index];
                  final available =
                      _num(latestLine['receivedQty']) -
                      _num(latestLine['invoicedQty']);
                  final qty = _num(requested['invoicedQty']);
                  if (qty <= 0 || qty > available + 0.000001) {
                    throw StateError(
                      'Invoice quantity for ${latestLine['description']} exceeds accepted and not-yet-invoiced goods. Refresh and retry.',
                    );
                  }
                  latestLine['invoicedQty'] =
                      _num(latestLine['invoicedQty']) + qty;
                  invoiceItems.add(requested);
                }
                transaction.update(orderDoc.reference, {
                  'items': latestItems,
                  'lastInvoiceId': invoiceRef.id,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                transaction.set(invoiceRef, {
                  'supplierInvoiceNumber': invoiceNo.text.trim(),
                  'purchaseOrderId': orderDoc.id,
                  'purchaseOrderNumber': order['poNumber'] ?? '',
                  'vendorId': order['vendorId'] ?? '',
                  'vendorName': order['vendorName'] ?? '',
                  'invoiceDate': Timestamp.fromDate(invoiceDate),
                  'dueDate': Timestamp.fromDate(dueDate),
                  'items': invoiceItems,
                  'subtotal': sub,
                  'taxAmount': taxValue,
                  'freight': freightValue,
                  'discount': discountValue,
                  'total': total,
                  'paidAmount': 0.0,
                  'balanceDue': total,
                  'paymentStatus': 'unpaid',
                  'verificationStatus': 'pending',
                  'verifiedBy': null,
                  'verifiedAt': null,
                  'verificationNote': '',
                  'lastPaymentId': null,
                  'notes': notes.text.trim(),
                  'expenseCategory': _expenseCategory(
                    order['category'] as String?,
                  ),
                  'createdBy': _uid,
                  'createdByName': widget.adminName,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                transaction.set(auditRef, {
                  'action': 'supplier_invoice_recorded',
                  'entityType': 'supplierInvoice',
                  'entityId': invoiceRef.id,
                  'summary':
                      'Invoice ${invoiceNo.text.trim()} recorded for ${order['vendorName'] ?? ''}',
                  'performedBy': _uid,
                  'performedByName': widget.adminName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              });
              _message(
                'Supplier invoice saved with PO/GRN quantity matching. No expense is posted until a payment is recorded.',
              );
            } on StateError catch (e) {
              _message(e.message.toString());
            } on FirebaseException catch (e) {
              _message('Invoice registration failed: ${e.message ?? e.code}');
            }
          }
        }
      }
    }
    for (final c in [...quantityControllers, ...rateControllers]) {
      c.dispose();
    }
    invoiceNo.dispose();
    tax.dispose();
    freight.dispose();
    discount.dispose();
    notes.dispose();
  }

  String _expenseCategory(String? category) {
    switch (category) {
      case 'repairs':
      case 'electrical':
      case 'plumbing':
      case 'equipment':
        return 'repairs';
      case 'cleaning':
        return 'housekeeping';
      case 'security':
        return 'security';
      case 'water':
        return 'water';
      case 'landscaping':
        return 'landscaping';
      case 'administration':
        return 'administration';
      default:
        return 'other';
    }
  }

  Future<void> _verifyInvoice(
    QueryDocumentSnapshot<Map<String, dynamic>> invoiceDoc,
    bool approve,
  ) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(
          approve ? 'Verify supplier invoice' : 'Reject supplier invoice',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              '${invoiceDoc.data()['supplierInvoiceNumber']} · ${_money(invoiceDoc.data()['total'])}',
            ),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: AppTranslations.translate(
                  'Verification notes / rejection reason',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!approve && note.text.trim().length < 5) {
                _message('Enter a rejection reason of at least 5 characters.');
              } else {
                Navigator.pop(dialogContext, true);
              }
            },
            child: AppText(approve ? 'Verify invoice' : 'Reject invoice'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final auditRef = _audit.doc();
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final latest = await transaction.get(invoiceDoc.reference);
        if (latest.data()?['verificationStatus'] != 'pending') {
          throw StateError('Invoice has already been reviewed.');
        }
        transaction.update(invoiceDoc.reference, {
          'verificationStatus': approve ? 'verified' : 'rejected',
          'verifiedBy': _uid,
          'verifiedAt': FieldValue.serverTimestamp(),
          'verificationNote': note.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(auditRef, {
          'action': approve
              ? 'supplier_invoice_verified'
              : 'supplier_invoice_rejected',
          'entityType': 'supplierInvoice',
          'entityId': invoiceDoc.id,
          'summary':
              '${invoiceDoc.data()['supplierInvoiceNumber']} ${approve ? 'verified' : 'rejected'}',
          'performedBy': _uid,
          'performedByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      _message(
        approve
            ? 'Invoice verified. Supplier payments are now enabled.'
            : 'Invoice rejected.',
      );
    }
    note.dispose();
  }

  Future<void> _recordSupplierPayment(
    QueryDocumentSnapshot<Map<String, dynamic>> invoiceDoc,
  ) async {
    final amount = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    String method = 'bank_transfer';
    DateTime paymentDate = DateTime.now();
    final invoice = invoiceDoc.data();
    final outstanding = _num(invoice['balanceDue']);
    if (invoice['verificationStatus'] != 'verified' || outstanding <= 0) {
      _message(
        'Only verified invoices with an outstanding balance can be paid.',
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Record supplier payment'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppText(
                    'Outstanding: ${_money(outstanding)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Payment amount ₹ *'),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Payment method'),
                  ),
                  items: _methods.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: AppText(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => method = v);
                  },
                ),
                TextField(
                  controller: reference,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate(
                      'Transaction / cheque reference',
                    ),
                  ),
                ),
                TextField(
                  controller: notes,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Payment notes'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final d = await _pickDate(paymentDate);
                      if (d != null) setDialogState(() => paymentDate = d);
                    },
                    icon: const Icon(Icons.event),
                    label: AppText('Payment date: ${_date(paymentDate)}'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Record payment'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final parsedValue = double.tryParse(amount.text.trim());
      final value = parsedValue == null ? null : _round2(parsedValue);
      if (value == null || value <= 0 || value > outstanding + 0.000001) {
        _message(
          'Payment must be greater than zero and no more than the outstanding balance.',
        );
      } else {
        final paymentRef = _payments.doc();
        final expenseRef = _expenses.doc();
        final auditRef = _audit.doc();
        final expenseRefText = 'PROC-${paymentRef.id}';
        try {
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final latest = await transaction.get(invoiceDoc.reference);
            final data = latest.data();
            if (!latest.exists || data?['verificationStatus'] != 'verified') {
              throw StateError('Invoice is no longer verified.');
            }
            final balance = _num(data?['total']) - _num(data?['paidAmount']);
            if (value > balance + 0.000001) {
              throw StateError(
                'The outstanding balance changed. Refresh and retry with the current balance.',
              );
            }
            final newPaid = _round2(_num(data?['paidAmount']) + value);
            final newBalance = _round2(_num(data?['total']) - newPaid);
            final status = newBalance <= 0.01 ? 'paid' : 'partially_paid';
            final rawVendorName = data?['vendorName'] as String? ?? '';
            final expenseVendorName = rawVendorName.length > 120
                ? rawVendorName.substring(0, 120)
                : rawVendorName;
            final rawInvoiceNumber =
                data?['supplierInvoiceNumber']?.toString() ?? 'Invoice';
            final expenseTitle =
                'Supplier payment ${rawInvoiceNumber.length > 90 ? rawInvoiceNumber.substring(0, 90) : rawInvoiceNumber}';
            final expenseNotes =
                ('PO ${data?['purchaseOrderNumber'] ?? ''}; Invoice $rawInvoiceNumber; Payment ${paymentRef.id}; ${notes.text.trim()}');
            final safeExpenseNotes = expenseNotes.length > 1100
                ? expenseNotes.substring(0, 1100)
                : expenseNotes;
            transaction.update(invoiceDoc.reference, {
              'paidAmount': newPaid,
              'balanceDue': newBalance <= 0.01 ? 0.0 : newBalance,
              'paymentStatus': status,
              'lastPaymentId': paymentRef.id,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            transaction.set(paymentRef, {
              'paymentId': paymentRef.id,
              'invoiceId': invoiceDoc.id,
              'invoiceNumber': data?['supplierInvoiceNumber'] ?? '',
              'purchaseOrderId': data?['purchaseOrderId'] ?? '',
              'purchaseOrderNumber': data?['purchaseOrderNumber'] ?? '',
              'vendorId': data?['vendorId'] ?? '',
              'vendorName': data?['vendorName'] ?? '',
              'expenseId': expenseRef.id,
              'expenseReference': expenseRefText,
              'amount': value,
              'paymentMethod': method,
              'paymentDate': Timestamp.fromDate(paymentDate),
              'transactionReference': reference.text.trim(),
              'notes': notes.text.trim(),
              'createdBy': _uid,
              'createdByName': widget.adminName,
              'createdAt': FieldValue.serverTimestamp(),
            });
            transaction.set(expenseRef, {
              'title': expenseTitle,
              'category': data?['expenseCategory'] ?? 'other',
              'amount': value,
              'amountPaid': value,
              'paymentStatus': 'paid',
              'paymentMethod': method,
              'expenseDate': Timestamp.fromDate(paymentDate),
              'monthKey': _monthKey(paymentDate),
              'payeeName': expenseVendorName,
              'vendorName': expenseVendorName,
              'assetName': '',
              'reference': expenseRefText,
              'notes': safeExpenseNotes,
              'createdBy': _uid,
              'createdByName': widget.adminName,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            transaction.set(auditRef, {
              'action': 'supplier_payment_recorded',
              'entityType': 'supplierPayment',
              'entityId': paymentRef.id,
              'summary':
                  'Payment ${_money(value)} to ${data?['vendorName'] ?? ''} recorded for invoice ${data?['supplierInvoiceNumber'] ?? ''}',
              'performedBy': _uid,
              'performedByName': widget.adminName,
              'createdAt': FieldValue.serverTimestamp(),
            });
          });
          _message(
            'Payment recorded. One matching paid expense was created atomically.',
          );
        } on StateError catch (e) {
          _message(e.message);
        } on FirebaseException catch (e) {
          _message('Unable to record supplier payment: ${e.message ?? e.code}');
        }
      }
    }
    amount.dispose();
    reference.dispose();
    notes.dispose();
  }

  Widget _overviewTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requisitions.snapshots(),
      builder: (context, reqSnapshot) {
        if (reqSnapshot.hasError) {
          return _error('Unable to load requisitions', reqSnapshot.error!);
        }
        if (reqSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final reqs = reqSnapshot.data?.docs ?? [];
        final pending = reqs
            .where(
              (d) => ['submitted', 'under_review'].contains(d.data()['status']),
            )
            .length;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _orders.snapshots(),
          builder: (context, orderSnapshot) {
            if (orderSnapshot.hasError) {
              return _error(
                'Unable to load purchase orders',
                orderSnapshot.error!,
              );
            }
            if (orderSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = orderSnapshot.data?.docs ?? [];
            final openOrders = orders
                .where(
                  (d) => [
                    'issued',
                    'partially_received',
                  ].contains(d.data()['status']),
                )
                .length;
            final committed = orders
                .where(
                  (d) => [
                    'issued',
                    'partially_received',
                  ].contains(d.data()['status']),
                )
                .fold<double>(0, (accumulator, doc) {
                  final lines = (doc.data()['items'] as List<dynamic>? ?? []);
                  return accumulator +
                      lines.fold<double>(0, (lineSum, raw) {
                        final line = Map<String, dynamic>.from(raw as Map);
                        final remaining =
                            (_num(line['orderedQty']) -
                                    _num(line['receivedQty']))
                                .clamp(0, 1000000000)
                                .toDouble();
                        return lineSum +
                            _round2(remaining * _num(line['unitPrice']));
                      });
                });
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _invoices.snapshots(),
              builder: (context, invoiceSnapshot) {
                if (invoiceSnapshot.hasError) {
                  return _error(
                    'Unable to load supplier invoices',
                    invoiceSnapshot.error!,
                  );
                }
                if (invoiceSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final invoices = invoiceSnapshot.data?.docs ?? [];
                final pendingVerification = invoices
                    .where((d) => d.data()['verificationStatus'] == 'pending')
                    .length;
                final outstanding = invoices
                    .where((d) => d.data()['verificationStatus'] == 'verified')
                    .fold<double>(
                      0,
                      (s, d) => s + _num(d.data()['balanceDue']),
                    );
                return ListView(
                  padding: const EdgeInsets.only(bottom: 28),
                  children: [
                    _header(
                      'Procurement overview',
                      'Requisitions → quotations → purchase orders → receipts → invoices → supplier payments',
                      action: FilledButton.icon(
                        onPressed: _createRequisition,
                        icon: const Icon(Icons.add),
                        label: const AppText('New request'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 205,
                            child: _metric(
                              'Awaiting approval',
                              '$pending',
                              Icons.pending_actions_outlined,
                            ),
                          ),
                          SizedBox(
                            width: 205,
                            child: _metric(
                              'Open purchase orders',
                              '$openOrders',
                              Icons.shopping_cart_outlined,
                            ),
                          ),
                          SizedBox(
                            width: 205,
                            child: _metric(
                              'Open PO commitment',
                              _money(committed),
                              Icons.receipt_long_outlined,
                            ),
                          ),
                          SizedBox(
                            width: 205,
                            child: _metric(
                              'Invoices to verify',
                              '$pendingVerification',
                              Icons.fact_check_outlined,
                            ),
                          ),
                          SizedBox(
                            width: 205,
                            child: _metric(
                              'Verified supplier dues',
                              _money(outstanding),
                              Icons.account_balance_wallet_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _header(
                      'Workflow controls',
                      'Choose the stage that needs attention',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _createRequisition,
                            icon: const Icon(Icons.post_add),
                            label: const AppText('Raise requisition'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _createQuotation,
                            icon: const Icon(Icons.request_quote_outlined),
                            label: const AppText('Record quotation'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _createInvoice,
                            icon: const Icon(Icons.receipt_outlined),
                            label: const AppText('Record invoice'),
                          ),
                        ],
                      ),
                    ),
                    _header(
                      'Recent procurement activity',
                      'Latest audit entries',
                    ),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _audit.snapshots(),
                      builder: (context, auditSnapshot) {
                        if (auditSnapshot.hasError) {
                          return _error(
                            'Unable to load audit history',
                            auditSnapshot.error!,
                          );
                        }
                        final docs = (auditSnapshot.data?.docs ?? []).toList()
                          ..sort(
                            (a, b) =>
                                _asDate(b.data()['createdAt'])
                                    .compareTo(_asDate(a.data()['createdAt'])),
                          );
                        if (docs.isEmpty) {
                          return _empty(
                            'No procurement activity yet',
                            'Actions from requisition through payment will appear here.',
                            Icons.history,
                          );
                        }
                        return Column(
                          children: docs
                              .take(8)
                              .map(
                                (d) => ListTile(
                                  leading: const Icon(
                                    Icons.history,
                                    color: AppTheme.secondaryNavy,
                                  ),
                                  title: AppText(
                                    d.data()['summary'] as String? ?? '',
                                  ),
                                  subtitle: AppText(
                                    '${d.data()['action'] ?? ''} · ${_date(d.data()['createdAt'])}',
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: AppText(
                        'Financial control: purchase orders represent commitments; supplier invoices represent verified liabilities; only recorded supplier payments enter Colony Budget & Expenses. Goods receipts update linked inventory and create stock movement audit records.',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _requisitionsTab() => Column(
    children: [
      _header(
        'Purchase requisitions',
        'Create draft requests, submit for approval and retain the decision history.',
        action: FilledButton.icon(
          onPressed: _createRequisition,
          icon: const Icon(Icons.add),
          label: const AppText('New request'),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _requisitions.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _error('Unable to load requisitions', snapshot.error!);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs.toList()
              ..sort(
                (a, b) =>
                    _asDate(b.data()['createdAt'])
                        .compareTo(_asDate(a.data()['createdAt'])),
              );
            if (docs.isEmpty) {
              return _empty(
                'No purchase requests',
                'Raise a requisition for materials, repairs, equipment or services.',
                Icons.post_add,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final doc = docs[i];
                final d = doc.data();
                final lines = d['items'] as List<dynamic>? ?? [];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                d['requestNumber'] as String? ?? 'Requisition',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                            ),
                            _status(d['status'] as String? ?? 'draft'),
                          ],
                        ),
                        const SizedBox(height: 5),
                        AppText(
                          d['title'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        AppText(
                          '${_categories[d['category']] ?? d['category']} · ${_priorities[d['priority']] ?? d['priority']} · Required ${_date(d['neededBy'])}',
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 11,
                          ),
                        ),
                        AppText(
                          '${lines.length} line item(s) · Estimated ${_money(d['estimatedTotal'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if ((d['reviewNote'] as String? ?? '').isNotEmpty)
                          AppText(
                            'Review: ${d['reviewNote']}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            OutlinedButton(
                              onPressed: () => _showRequisitionDetail(doc),
                              child: const AppText('Details / history'),
                            ),
                            if (d['status'] == 'draft')
                              OutlinedButton(
                                onPressed: () => _editDraftRequisition(doc),
                                child: const AppText('Edit draft'),
                              ),
                            if ([
                              'submitted',
                              'under_review',
                            ].contains(d['status']))
                              FilledButton.tonal(
                                onPressed: () => _reviewRequisition(doc),
                                child: const AppText('Review'),
                              ),
                            if (d['status'] == 'draft')
                              FilledButton.tonal(
                                onPressed: () => _submitDraft(doc),
                                child: const AppText('Submit'),
                              ),
                            if (d['status'] == 'approved')
                              OutlinedButton(
                                onPressed: _createQuotation,
                                child: const AppText('Record quote'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  Future<void> _editDraftRequisition(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data['status'] != 'draft') return;
    final title = TextEditingController(text: data['title'] as String? ?? '');
    final purpose = TextEditingController(
      text: data['purpose'] as String? ?? '',
    );
    final notes = TextEditingController(text: data['notes'] as String? ?? '');
    String category = data['category'] as String? ?? 'other';
    String priority = data['priority'] as String? ?? 'normal';
    DateTime neededBy = _asDate(data['neededBy']);
    final lines = (data['items'] as List<dynamic>? ?? [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText('Edit draft · ${data['requestNumber'] ?? ''}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: title,
                      maxLength: 150,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Request title *'),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? AppTranslations.translate('Enter a title')
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Purchase category',
                        ),
                      ),
                      items: _categories.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: AppText(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => category = v);
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Priority'),
                      ),
                      items: _priorities.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: AppText(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => priority = v);
                      },
                    ),
                    TextFormField(
                      controller: purpose,
                      maxLength: 2000,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Business justification *',
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().length < 5)
                          ? AppTranslations.translate(
                              'Explain why this purchase is required',
                            )
                          : null,
                    ),
                    TextFormField(
                      controller: notes,
                      maxLength: 2000,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Specifications / notes',
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final d = await _pickDate(neededBy);
                          if (d != null) setDialogState(() => neededBy = d);
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: AppText('Required by: ${_date(neededBy)}'),
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Expanded(
                          child: AppText(
                            'Requested line items',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            if (lines.length >= 30) return;
                            final line = await _promptRequisitionLine();
                            if (line != null) {
                              setDialogState(() => lines.add(line));
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const AppText('Add item'),
                        ),
                      ],
                    ),
                    ...lines.asMap().entries.map(
                      (e) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: AppText(e.value['description'] as String? ?? ''),
                        subtitle: AppText(
                          '${e.value['quantity']} ${e.value['unit']} × ${_money(e.value['estimatedUnitPrice'])}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () =>
                              setDialogState(() => lines.removeAt(e.key)),
                        ),
                      ),
                    ),
                    if (lines.isEmpty)
                      const AppText(
                        'At least one item is required.',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    if (lines.isNotEmpty)
                      AppText(
                        'Estimated total: ${_money(lines.fold<double>(0, (accumulator, line) => accumulator + _num(line['quantity']) * _num(line['estimatedUnitPrice'])))}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if ((key.currentState?.validate() ?? false) &&
                    lines.isNotEmpty) {
                  Navigator.pop(dialogContext, true);
                } else {
                  _message(
                    'Complete the required fields and add at least one line item.',
                  );
                }
              },
              child: const AppText('Save draft'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final estimated = _round2(
        lines.fold<double>(
          0,
          (accumulator, line) =>
              accumulator +
              _num(line['quantity']) * _num(line['estimatedUnitPrice']),
        ),
      );
      final auditRef = _audit.doc();
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final latest = await transaction.get(doc.reference);
          if (!latest.exists || latest.data()?['status'] != 'draft') {
            throw StateError(
              'This requisition is no longer a draft. Refresh and try again.',
            );
          }
          transaction.update(doc.reference, {
            'title': title.text.trim(),
            'category': category,
            'priority': priority,
            'purpose': purpose.text.trim(),
            'notes': notes.text.trim(),
            'neededBy': Timestamp.fromDate(neededBy),
            'items': lines,
            'estimatedSubtotal': estimated,
            'estimatedTotal': estimated,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.set(auditRef, {
            'action': 'requisition_draft_updated',
            'entityType': 'purchaseRequisition',
            'entityId': doc.id,
            'summary': '${data['requestNumber'] ?? ''} draft details updated',
            'performedBy': _uid,
            'performedByName': widget.adminName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        _message('Draft requisition updated.');
      } on StateError catch (e) {
        _message(e.message.toString());
      } on FirebaseException catch (e) {
        _message('Draft update failed: ${e.message ?? e.code}');
      }
    }
    title.dispose();
    purpose.dispose();
    notes.dispose();
  }

  Future<void> _submitDraft(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const AppText('Submit requisition?'),
        content: AppText(
          'Submit ${doc.data()['requestNumber']} for Admin approval? The request details will be locked after submission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const AppText('Submit'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final auditRef = _audit.doc();
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final latest = await transaction.get(doc.reference);
          if (!latest.exists || latest.data()?['status'] != 'draft') {
            throw StateError(
              'This requisition is no longer a draft. Refresh and try again.',
            );
          }
          transaction.update(doc.reference, {
            'status': 'submitted',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          transaction.set(auditRef, {
            'action': 'requisition_submitted',
            'entityType': 'purchaseRequisition',
            'entityId': doc.id,
            'summary': '${doc.data()['requestNumber']} submitted for approval',
            'performedBy': _uid,
            'performedByName': widget.adminName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        _message('Requisition submitted.');
      } on StateError catch (e) {
        _message(e.message.toString());
      } on FirebaseException catch (e) {
        _message('Submission failed: ${e.message ?? e.code}');
      }
    }
  }

  Future<void> _showRequisitionDetail(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data();
    final items = d['items'] as List<dynamic>? ?? [];
    final approvals =
        (await _approvals.where('entityId', isEqualTo: doc.id).get()).docs;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .82,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              AppText(
                d['requestNumber'] as String? ?? 'Requisition',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navyBlue,
                ),
              ),
              AppText(
                d['title'] as String? ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              AppText(
                'Status: ${d['status']} · Required by ${_date(d['neededBy'])}',
              ),
              const Divider(),
              AppText(
                'Business justification',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              AppText(d['purpose'] as String? ?? ''),
              const SizedBox(height: 10),
              const AppText(
                'Line items',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              ...items.map((raw) {
                final line = Map<String, dynamic>.from(raw as Map);
                return ListTile(
                  dense: true,
                  title: AppText(line['description'] as String? ?? ''),
                  subtitle: AppText(
                    '${line['quantity']} ${line['unit']} · Est. rate ${_money(line['estimatedUnitPrice'])}${line['inventoryItemId'] == null ? '' : ' · Linked to inventory'}',
                  ),
                  trailing: AppText(
                    _money(
                      _num(line['quantity']) * _num(line['estimatedUnitPrice']),
                    ),
                  ),
                );
              }),
              const Divider(),
              AppText(
                'Approval / review history (${approvals.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              ...approvals.map(
                (a) => ListTile(
                  dense: true,
                  title: AppText(
                    '${a.data()['action']} · ${a.data()['performedByName'] ?? ''}',
                  ),
                  subtitle: AppText(
                    '${a.data()['remarks'] ?? ''} · ${_date(a.data()['createdAt'])}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quotationsTab() => Column(
    children: [
      _header(
        'Supplier quotations',
        'Compare landed price, lead time and terms before awarding a purchase order.',
        action: Wrap(
          spacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: _createVendor,
              icon: const Icon(Icons.business_outlined),
              label: const AppText('Add supplier'),
            ),
            FilledButton.icon(
              onPressed: _createQuotation,
              icon: const Icon(Icons.add),
              label: const AppText('Record quote'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _quotations.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _error('Unable to load quotations', snapshot.error!);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs.toList();
            if (docs.isEmpty) {
              return _empty(
                'No supplier quotations',
                'Record each supplier response against an approved requisition to compare commercial offers.',
                Icons.request_quote_outlined,
              );
            }
            // Quotes are grouped by requisition; a single global price sort would
            // incorrectly compare offers for unrelated purchases.
            final grouped =
                <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
            for (final doc in docs) {
              final key = doc.data()['requisitionId'] as String? ?? 'unknown';
              grouped
                  .putIfAbsent(
                    key,
                    () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                  )
                  .add(doc);
            }
            final requisitionGroups = grouped.values.toList()
              ..sort(
                (a, b) => (a.first.data()['requisitionNumber'] as String? ?? '')
                    .compareTo(
                      b.first.data()['requisitionNumber'] as String? ?? '',
                    ),
              );
            final comparisonWidgets = <Widget>[];
            for (final group in requisitionGroups) {
              group.sort(
                (a, b) =>
                    _num(a.data()['total']).compareTo(_num(b.data()['total'])),
              );
              final first = group.first.data();
              comparisonWidgets.add(
                _header(
                  'Requisition ${first['requisitionNumber'] ?? ''}',
                  '${group.length} quotation(s), sorted by landed total (lowest first). Compare lead time, validity and payment terms as well as price.',
                ),
              );
              comparisonWidgets.addAll(
                group.map((doc) {
                  final d = doc.data();
                  final isExpired =
                      d['status'] == 'received' &&
                      _asDate(d['validUntil']).isBefore(DateTime.now());
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    child: ListTile(
                      isThreeLine: true,
                      title: AppText(
                        '${d['vendorName']} · ${d['quoteNumber']}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: AppText(
                        'Lead time ${d['deliveryDays']} days · Valid until ${_date(d['validUntil'])}\nSubtotal ${_money(d['subtotal'])} + tax ${_money(d['taxAmount'])} + freight ${_money(d['freight'])} − discount ${_money(d['discount'])}',
                      ),
                      trailing: SizedBox(
                        width: 110,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AppText(
                              _money(d['total']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navyBlue,
                              ),
                            ),
                            _status(
                              isExpired
                                  ? 'expired'
                                  : d['status'] as String? ?? 'received',
                            ),
                          ],
                        ),
                      ),
                      onTap: () => _showQuotationDetail(doc),
                    ),
                  );
                }),
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _header(
                  'Quote comparison',
                  'Quotations are compared only against the same requisition. Lowest landed price is shown first within each group.',
                ),
                ...comparisonWidgets,
              ],
            );
          },
        ),
      ),
    ],
  );

  Future<void> _showQuotationDetail(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data();
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            runSpacing: 8,
            children: [
              AppText(
                '${d['quoteNumber']} · ${d['vendorName']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              AppText('Requisition ${d['requisitionNumber']}'),
              AppText(
                'Subtotal ${_money(d['subtotal'])} · Tax ${_money(d['taxAmount'])} · Freight ${_money(d['freight'])} · Discount ${_money(d['discount'])}',
              ),
              AppText(
                'Landed total ${_money(d['total'])} · Delivery ${d['deliveryDays']} days',
              ),
              AppText(
                'Item-wise rates',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              ...((d['items'] as List<dynamic>? ?? []).map((raw) {
                final line = Map<String, dynamic>.from(raw as Map);
                return ListTile(
                  dense: true,
                  title: AppText(line['description'] as String? ?? ''),
                  subtitle: AppText(
                    '${line['quantity']} ${line['unit']} × ${_money(line['unitPrice'])}',
                  ),
                  trailing: AppText(_money(line['lineTotal'])),
                );
              })),
              AppText('Terms: ${d['paymentTerms'] ?? 'Not recorded'}'),
              AppText('Notes: ${d['notes'] ?? ''}'),
              if (d['status'] == 'received')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _awardQuotation(doc);
                    },
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: const AppText('Award & issue purchase order'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _closeOrCancelOrder(
    QueryDocumentSnapshot<Map<String, dynamic>> orderDoc,
    String nextStatus,
  ) async {
    final current = orderDoc.data();
    final initialItems = (current['items'] as List<dynamic>? ?? [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    if (nextStatus == 'cancelled' &&
        (current['status'] != 'issued' ||
            initialItems.any(
              (line) =>
                  _num(line['receivedQty']) > 0 ||
                  _num(line['invoicedQty']) > 0,
            ))) {
      _message(
        'A purchase order can only be cancelled before any accepted goods or invoices have been recorded.',
      );
      return;
    }
    if (nextStatus == 'closed' &&
        !['partially_received', 'received'].contains(current['status'])) {
      _message(
        'Only a partially or fully received purchase order can be closed. Cancel an unreceived PO instead.',
      );
      return;
    }
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(
          nextStatus == 'cancelled'
              ? 'Cancel purchase order'
              : 'Close purchase order',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              nextStatus == 'cancelled'
                  ? 'This will cancel ${current['poNumber']} before receipt. It cannot be reopened from this screen.'
                  : 'This closes ${current['poNumber']} to further goods receipts. Any remaining quantity will be treated as not expected from the supplier; invoice entry for already accepted goods remains available.',
            ),
            TextField(
              controller: reason,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: nextStatus == 'cancelled'
                    ? AppTranslations.translate('Cancellation reason *')
                    : AppTranslations.translate(
                        'Closure / short-delivery reason *',
                      ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Keep open'),
          ),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().length >= 5) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: AppText(
              nextStatus == 'cancelled' ? 'Confirm cancellation' : 'Close PO',
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final auditRef = _audit.doc();
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final latest = await transaction.get(orderDoc.reference);
          if (!latest.exists) {
            throw StateError('Purchase order no longer exists.');
          }
          final latestData = latest.data()!;
          final latestItems = (latestData['items'] as List<dynamic>? ?? [])
              .map((raw) => Map<String, dynamic>.from(raw as Map))
              .toList();
          if (nextStatus == 'cancelled') {
            if (latestData['status'] != 'issued' ||
                latestItems.any(
                  (line) =>
                      _num(line['receivedQty']) > 0 ||
                      _num(line['invoicedQty']) > 0,
                )) {
              throw StateError(
                'The PO changed or goods have been received. Refresh before cancelling.',
              );
            }
            transaction.update(orderDoc.reference, {
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelledBy': _uid,
              'cancellationReason': reason.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            if (![
              'partially_received',
              'received',
            ].contains(latestData['status'])) {
              throw StateError(
                'The PO is no longer eligible for closure. Refresh and retry.',
              );
            }
            transaction.update(orderDoc.reference, {
              'status': 'closed',
              'closedAt': FieldValue.serverTimestamp(),
              'closedBy': _uid,
              'closureNote': reason.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          transaction.set(auditRef, {
            'action': nextStatus == 'cancelled'
                ? 'purchase_order_cancelled'
                : 'purchase_order_closed',
            'entityType': 'purchaseOrder',
            'entityId': orderDoc.id,
            'summary':
                '${latestData['poNumber']} $nextStatus: ${reason.text.trim()}',
            'performedBy': _uid,
            'performedByName': widget.adminName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        _message(
          nextStatus == 'cancelled'
              ? 'Purchase order cancelled.'
              : 'Purchase order closed. Accepted goods can still be invoiced.',
        );
      } on StateError catch (e) {
        _message(e.message.toString());
      } on FirebaseException catch (e) {
        _message('PO update failed: ${e.message ?? e.code}');
      }
    }
    reason.dispose();
  }

  Widget _ordersTab() => Column(
    children: [
      _header(
        'Purchase orders',
        'Track supplier commitments, partial deliveries, short shipments, closure and invoice linkage.',
        action: OutlinedButton.icon(
          onPressed: _createInvoice,
          icon: const Icon(Icons.receipt_outlined),
          label: const AppText('New invoice'),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _orders.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _error('Unable to load purchase orders', snapshot.error!);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs.toList()
              ..sort(
                (a, b) =>
                    _asDate(b.data()['createdAt'])
                        .compareTo(_asDate(a.data()['createdAt'])),
              );
            if (docs.isEmpty) {
              return _empty(
                'No purchase orders yet',
                'Award an approved quotation to issue a purchase order.',
                Icons.shopping_cart_outlined,
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: docs.map((doc) {
                final d = doc.data();
                final items = (d['items'] as List<dynamic>? ?? [])
                    .map((raw) => Map<String, dynamic>.from(raw as Map))
                    .toList();
                final ordered = items.fold<double>(
                  0,
                  (accumulator, line) => accumulator + _num(line['orderedQty']),
                );
                final received = items.fold<double>(
                  0,
                  (accumulator, line) =>
                      accumulator + _num(line['receivedQty']),
                );
                final invoiced = items.fold<double>(
                  0,
                  (accumulator, line) =>
                      accumulator + _num(line['invoicedQty']),
                );
                final status = d['status'] as String? ?? 'issued';
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                '${d['poNumber']} · ${d['vendorName']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                            ),
                            _status(status),
                          ],
                        ),
                        AppText(
                          'Issued ${_date(d['orderDate'])} · Expected ${_date(d['expectedDelivery'])}',
                        ),
                        AppText(
                          '${items.length} line(s) · Ordered $ordered · Accepted $received · Invoiced $invoiced · PO ${_money(d['total'])}',
                        ),
                        if ((d['awardJustification'] as String? ?? '')
                            .isNotEmpty)
                          AppText(
                            'Award rationale: ${d['awardJustification']}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        if ((d['closureNote'] as String? ?? '').isNotEmpty)
                          AppText(
                            'Closure: ${d['closureNote']}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        if ((d['cancellationReason'] as String? ?? '')
                            .isNotEmpty)
                          AppText(
                            'Cancellation: ${d['cancellationReason']}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 5,
                          children: [
                            OutlinedButton(
                              onPressed: () => _showOrderDetail(doc),
                              child: const AppText('View PO'),
                            ),
                            if ([
                              'issued',
                              'partially_received',
                            ].contains(status))
                              FilledButton.tonal(
                                onPressed: () => _recordGoodsReceipt(doc),
                                child: const AppText('Receive goods'),
                              ),
                            if (status == 'issued' &&
                                received == 0 &&
                                invoiced == 0)
                              TextButton(
                                onPressed: () =>
                                    _closeOrCancelOrder(doc, 'cancelled'),
                                child: const AppText('Cancel PO'),
                              ),
                            if ([
                              'partially_received',
                              'received',
                            ].contains(status))
                              OutlinedButton(
                                onPressed: () =>
                                    _closeOrCancelOrder(doc, 'closed'),
                                child: const AppText('Close PO'),
                              ),
                            if (status != 'cancelled')
                              OutlinedButton(
                                onPressed: _createInvoice,
                                child: const AppText('Record invoice'),
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

  Future<void> _showOrderDetail(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data();
    final items = d['items'] as List<dynamic>? ?? [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .75,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              AppText(
                d['poNumber'] as String? ?? 'Purchase order',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              AppText('Supplier: ${d['vendorName']} · Status: ${d['status']}'),
              AppText(
                'Order ${_date(d['orderDate'])} · Expected delivery ${_date(d['expectedDelivery'])}',
              ),
              const Divider(),
              const AppText(
                'Order lines',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              ...items.map((raw) {
                final line = Map<String, dynamic>.from(raw as Map);
                return ListTile(
                  title: AppText(line['description'] as String? ?? ''),
                  subtitle: AppText(
                    'Ordered ${line['orderedQty']} ${line['unit']} · Accepted ${line['receivedQty']} · Rejected ${line['rejectedQty']} · Invoiced ${line['invoicedQty'] ?? 0}',
                  ),
                  trailing: line['inventoryItemId'] == null
                      ? const AppText(
                          'No stock link',
                          style: TextStyle(fontSize: 10),
                        )
                      : const Icon(Icons.inventory_2_outlined),
                );
              }),
              const Divider(),
              AppText(
                'Commercials: Subtotal ${_money(d['subtotal'])} · Tax ${_money(d['taxAmount'])} · Freight ${_money(d['freight'])} · Discount ${_money(d['discount'])}',
                style: const TextStyle(fontSize: 12),
              ),
              AppText(
                'PO total: ${_money(d['total'])}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              AppText('Payment terms: ${d['paymentTerms'] ?? ''}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptsTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _receipts.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _error('Unable to load goods receipts', snapshot.error!);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.docs.toList()
        ..sort(
          (a, b) =>
              _asDate(b.data()['createdAt'])
                  .compareTo(_asDate(a.data()['createdAt'])),
        );
      if (docs.isEmpty) {
        return _empty(
          'No goods receipts',
          'Record full or partial deliveries from the Purchase Orders tab.',
          Icons.inventory_2_outlined,
        );
      }
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _header(
            'Goods receipt notes',
            'Accepted and rejected quantities are retained permanently; linked inventory updates are posted atomically.',
          ),
          ...docs.map((doc) {
            final d = doc.data();
            final items = d['items'] as List<dynamic>? ?? [];
            final accepted = items.fold<double>(
              0,
              (s, e) => s + _num((e as Map)['acceptedQty']),
            );
            final rejected = items.fold<double>(
              0,
              (s, e) => s + _num((e as Map)['rejectedQty']),
            );
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: ListTile(
                title: AppText(
                  '${d['receiptNumber']} · ${d['vendorName']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: AppText(
                  'PO ${d['purchaseOrderNumber']} · ${_date(d['receivedDate'])}\nAccepted $accepted · Rejected $rejected · Challan ${d['challanReference'] ?? ''}',
                ),
                trailing: const Icon(Icons.receipt_long_outlined),
              ),
            );
          }),
        ],
      );
    },
  );

  Widget _invoicesTab() => Column(
    children: [
      _header(
        'Supplier invoices & payments',
        'Verify invoices, track due dates and record full or partial payments.',
        action: FilledButton.icon(
          onPressed: _createInvoice,
          icon: const Icon(Icons.add),
          label: const AppText('Record invoice'),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _invoices.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _error(
                'Unable to load supplier invoices',
                snapshot.error!,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs.toList()
              ..sort(
                (a, b) =>
                    _asDate(b.data()['createdAt'])
                        .compareTo(_asDate(a.data()['createdAt'])),
              );
            if (docs.isEmpty) {
              return _empty(
                'No supplier invoices',
                'Record an invoice against a purchase order after receiving supplier billing.',
                Icons.receipt_long_outlined,
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: docs.map((doc) {
                final d = doc.data();
                final due = _num(d['balanceDue']);
                final overdue =
                    due > 0 && _asDate(d['dueDate']).isBefore(DateTime.now());
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                '${d['supplierInvoiceNumber']} · ${d['vendorName']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                            ),
                            _status(
                              d['verificationStatus'] as String? ?? 'pending',
                            ),
                          ],
                        ),
                        AppText(
                          'PO ${d['purchaseOrderNumber']} · Invoice ${_date(d['invoiceDate'])} · Due ${_date(d['dueDate'])}',
                        ),
                        AppText(
                          'Invoice ${_money(d['total'])} · Paid ${_money(d['paidAmount'])} · Balance ${_money(due)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (overdue)
                          const AppText(
                            'OVERDUE',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          children: [
                            OutlinedButton(
                              onPressed: () => _showInvoicePayments(doc),
                              child: const AppText('Payment history'),
                            ),
                            if (d['verificationStatus'] == 'pending')
                              FilledButton.tonal(
                                onPressed: () => _verifyInvoice(doc, true),
                                child: const AppText('Verify'),
                              ),
                            if (d['verificationStatus'] == 'pending')
                              TextButton(
                                onPressed: () => _verifyInvoice(doc, false),
                                child: const AppText('Reject'),
                              ),
                            if (d['verificationStatus'] == 'verified' &&
                                due > 0)
                              FilledButton(
                                onPressed: () => _recordSupplierPayment(doc),
                                child: const AppText('Record payment'),
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

  Future<void> _showInvoicePayments(
    QueryDocumentSnapshot<Map<String, dynamic>> invoiceDoc,
  ) async {
    final docs =
        (await _payments.where('invoiceId', isEqualTo: invoiceDoc.id).get())
            .docs;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .6,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              AppText(
                'Payment history · ${invoiceDoc.data()['supplierInvoiceNumber']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              AppText(
                'Invoice ${_money(invoiceDoc.data()['total'])} · Paid ${_money(invoiceDoc.data()['paidAmount'])} · Balance ${_money(invoiceDoc.data()['balanceDue'])}',
              ),
              const Divider(),
              if (docs.isEmpty) const AppText('No payments recorded.'),
              ...docs.map(
                (d) => ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: AppText(_money(d.data()['amount'])),
                  subtitle: AppText(
                    '${_methods[d.data()['paymentMethod']] ?? d.data()['paymentMethod']} · ${_date(d.data()['paymentDate'])} · ${d.data()['transactionReference'] ?? ''}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportInvoicesCsv() async {
    final docs = (await _invoices.get()).docs;
    final rows = <List<String>>[
      [
        'Invoice',
        'PO',
        'Supplier',
        'Invoice Date',
        'Due Date',
        'Total',
        'Paid',
        'Balance',
        'Verification',
        'Payment Status',
      ],
      ...docs.map((d) {
        final x = d.data();
        return [
          x['supplierInvoiceNumber']?.toString() ?? '',
          x['purchaseOrderNumber']?.toString() ?? '',
          x['vendorName']?.toString() ?? '',
          _date(x['invoiceDate']),
          _date(x['dueDate']),
          _num(x['total']).toStringAsFixed(2),
          _num(x['paidAmount']).toStringAsFixed(2),
          _num(x['balanceDue']).toStringAsFixed(2),
          x['verificationStatus']?.toString() ?? '',
          x['paymentStatus']?.toString() ?? '',
        ];
      }),
    ];
    final csv = rows
        .map((row) => row.map((v) => '"${v.replaceAll('"', '""')}"').join(','))
        .join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    _message('Invoice register CSV copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          title: const AppText('Procurement & Purchasing'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.dashboard_outlined),
                text: AppTranslations.translate('Overview'),
              ),
              Tab(
                icon: Icon(Icons.post_add_outlined),
                text: AppTranslations.translate('Requisitions'),
              ),
              Tab(
                icon: Icon(Icons.request_quote_outlined),
                text: AppTranslations.translate('Quotations'),
              ),
              Tab(
                icon: Icon(Icons.shopping_cart_outlined),
                text: AppTranslations.translate('Orders'),
              ),
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: AppTranslations.translate('Receipts'),
              ),
              Tab(
                icon: Icon(Icons.receipt_long_outlined),
                text: AppTranslations.translate('Invoices'),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: AppTranslations.translate('Copy supplier invoice CSV'),
              onPressed: _exportInvoicesCsv,
              icon: const Icon(Icons.file_download_outlined),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _overviewTab(),
            _requisitionsTab(),
            _quotationsTab(),
            _ordersTab(),
            _receiptsTab(),
            _invoicesTab(),
          ],
        ),
      ),
    );
  }
}
// MOHALLAFLOW_PROCUREMENT_SCREEN_END
