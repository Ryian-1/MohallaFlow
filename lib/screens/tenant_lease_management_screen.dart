import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class TenantLeaseManagementScreen extends StatefulWidget {
  const TenantLeaseManagementScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<TenantLeaseManagementScreen> createState() =>
      _TenantLeaseManagementScreenState();
}

class _TenantLeaseManagementScreenState
    extends State<TenantLeaseManagementScreen> {
  CollectionReference<Map<String, dynamic>> get _leases => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('tenantLeases');

  CollectionReference<Map<String, dynamic>> get _renewalRequests =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('tenantLeaseRenewalRequests');

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _renewalStream;

  CollectionReference<Map<String, dynamic>> get _residents => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('residents');

  CollectionReference<Map<String, dynamic>> get _households => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('households');

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _leaseStream;

  @override
  void initState() {
    super.initState();
    _leaseStream = _leases.orderBy('leaseStart', descending: true).snapshots();
    _renewalStream = _renewalRequests
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  String _dateLabel(Object? value) {
    if (value is! Timestamp) return 'Not set';
    final date = value.toDate().toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _money(Object? value) {
    final amount = value is num ? value : 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _status(Map<String, dynamic> data) {
    final stored = data['status'] as String? ?? 'active';
    if (stored == 'terminated') return 'Terminated';
    final start = data['leaseStart'];
    final end = data['leaseEnd'];
    final today = DateUtils.dateOnly(DateTime.now());
    if (end is Timestamp && DateUtils.dateOnly(end.toDate()).isBefore(today)) {
      return 'Expired';
    }
    if (start is Timestamp &&
        DateUtils.dateOnly(start.toDate()).isAfter(today)) {
      return 'Upcoming';
    }
    if (end is Timestamp &&
        DateUtils.dateOnly(end.toDate()).difference(today).inDays <= 30) {
      return 'Expires soon';
    }
    return 'Active';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return AppTheme.navyBlue;
      case 'Upcoming':
      case 'Expires soon':
        return const Color(0xFF8A641D);
      case 'Expired':
      case 'Terminated':
        return AppTheme.textGrey;
      default:
        return AppTheme.textGrey;
    }
  }

  Future<void> _openCreateLease() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _message('Please sign in again.');
      return;
    }

    _message('Loading active Tenant residents…');
    QuerySnapshot<Map<String, dynamic>> residentSnapshot;
    QuerySnapshot<Map<String, dynamic>> householdSnapshot;
    try {
      final results = await Future.wait([
        _residents.where('residentStatus', isEqualTo: 'active').get(),
        _households.get(),
      ]);
      residentSnapshot = results[0];
      householdSnapshot = results[1];
    } on FirebaseException catch (error) {
      _message('Unable to load resident records (${error.code}).');
      return;
    }
    if (!mounted) return;

    final households = <String, Map<String, dynamic>>{
      for (final doc in householdSnapshot.docs) doc.id: doc.data(),
    };
    final tenants = residentSnapshot.docs.where((doc) {
      final data = doc.data();
      final relation = (data['relationshipToHead'] as String? ?? '')
          .trim()
          .toLowerCase();
      final householdId = data['householdId'] as String? ?? '';
      return relation == 'tenant' && households.containsKey(householdId);
    }).toList();

    if (tenants.isEmpty) {
      _message('Register an active resident with relationship “Tenant” first.');
      return;
    }

    final startInitial = DateTime.now();
    final endInitial = DateTime(
      startInitial.year + 1,
      startInitial.month,
      startInitial.day,
    );
    final rentController = TextEditingController();
    final depositController = TextEditingController(text: '0');
    final agreementController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedResidentId = tenants.first.id;
    DateTime leaseStart = DateTime(
      startInitial.year,
      startInitial.month,
      startInitial.day,
    );
    DateTime leaseEnd = endInitial;
    bool saving = false;
    String? formError;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> chooseDate({required bool isStart}) async {
              final initial = isStart ? leaseStart : leaseEnd;
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                helpText: isStart ? 'Lease start date' : 'Lease end date',
              );
              if (picked == null || !dialogContext.mounted) return;
              setDialogState(() {
                if (isStart) {
                  leaseStart = picked;
                } else {
                  leaseEnd = picked;
                }
                formError = null;
              });
            }

            Future<void> save() async {
              if (saving || !formKey.currentState!.validate()) return;
              final residentId = selectedResidentId;
              if (residentId == null) return;
              if (!leaseEnd.isAfter(leaseStart)) {
                setDialogState(() {
                  formError = 'Lease end date must be after start date.';
                });
                return;
              }

              final residentDoc = tenants.firstWhere(
                (doc) => doc.id == residentId,
              );
              final residentData = residentDoc.data();
              final householdId = residentData['householdId'] as String;
              final householdData = households[householdId]!;
              setDialogState(() {
                saving = true;
                formError = null;
              });

              try {
                final existing = await _leases
                    .where('householdId', isEqualTo: householdId)
                    .where('status', isEqualTo: 'active')
                    .get();
                final overlaps = existing.docs.any((doc) {
                  final data = doc.data();
                  final oldStart = data['leaseStart'];
                  final oldEnd = data['leaseEnd'];
                  if (oldStart is! Timestamp || oldEnd is! Timestamp) {
                    return false;
                  }
                  return leaseStart.isBefore(oldEnd.toDate()) &&
                      leaseEnd.isAfter(oldStart.toDate());
                });
                if (overlaps) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    saving = false;
                    formError = 'This household already has an overlapping active lease.';
                  });
                  return;
                }

                await _leases.add({
                  'householdId': householdId,
                  'blockId': householdData['blockId'] as String? ?? '',
                  'houseNumber': householdData['houseNumber'] as String? ?? '',
                  'householdHeadName':
                      householdData['householdHeadName'] as String? ?? '',
                  'tenantResidentId': residentId,
                  'tenantName': residentData['fullName'] as String? ?? '',
                  'tenantPhone': residentData['phoneNumber'] as String? ?? '',
                  'leaseStart': Timestamp.fromDate(leaseStart),
                  'leaseEnd': Timestamp.fromDate(leaseEnd),
                  'monthlyRent': double.parse(rentController.text.trim()),
                  'securityDeposit': double.parse(
                    depositController.text.trim(),
                  ),
                  'agreementReference': agreementController.text.trim(),
                  'status': 'active',
                  'createdBy': uid,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              } on FirebaseException catch (error) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  saving = false;
                  formError = 'Could not save lease (${error.code}).';
                });
              } catch (error) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  saving = false;
                  formError = 'Could not save lease: $error';
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.white,
              title: const AppText(
                'Register tenant lease',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedResidentId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Registered Tenant resident',
                            ),
                          ),
                          items: tenants.map((doc) {
                            final data = doc.data();
                            final household =
                                households[data['householdId'] as String] ?? {};
                            final unit =
                                '${household['blockId'] ?? ''}-${household['houseNumber'] ?? ''}';
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: AppText(
                                '${data['fullName'] ?? 'Tenant'} · $unit',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: saving
                              ? null
                              : (value) => setDialogState(
                                  () => selectedResidentId = value,
                                ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: rentController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Monthly rent (₹)',
                            ),
                          ),
                          validator: (value) {
                            final amount = double.tryParse(value?.trim() ?? '');
                            if (amount == null ||
                                !amount.isFinite ||
                                amount < 0) {
                              return AppTranslations.translate(
                                'Enter a valid non-negative amount',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: depositController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Security deposit (₹)',
                            ),
                          ),
                          validator: (value) {
                            final amount = double.tryParse(value?.trim() ?? '');
                            if (amount == null ||
                                !amount.isFinite ||
                                amount < 0) {
                              return AppTranslations.translate(
                                'Enter a valid non-negative amount',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _dateRow(
                          label: 'Lease start',
                          value: _dateLabel(Timestamp.fromDate(leaseStart)),
                          onTap: saving
                              ? null
                              : () => chooseDate(isStart: true),
                        ),
                        _dateRow(
                          label: 'Lease end',
                          value: _dateLabel(Timestamp.fromDate(leaseEnd)),
                          onTap: saving
                              ? null
                              : () => chooseDate(isStart: false),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: agreementController,
                          maxLength: 120,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Agreement reference (optional)',
                            ),
                          ),
                        ),
                        if (formError != null) ...[
                          const SizedBox(height: 8),
                          AppText(
                            formError!,
                            style: const TextStyle(
                              color: Color(0xFFB54747),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const AppText('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navyBlue,
                    foregroundColor: AppTheme.white,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppText('Save lease'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      rentController.dispose();
      depositController.dispose();
      agreementController.dispose();
    }
  }

  Widget _dateRow({
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: AppText(label, style: const TextStyle(fontSize: 12)),
      subtitle: AppText(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(Icons.calendar_month_outlined),
      onTap: onTap,
    );
  }

  Future<void> _terminateLease(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.white,
          title: const AppText('Terminate lease'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: noteController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: AppTranslations.translate('Termination reason'),
                hintText: AppTranslations.translate(
                  'Enter the reason for record purposes',
                ),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 5
                  ? AppTranslations.translate('Enter at least five characters')
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.navyBlue,
                foregroundColor: AppTheme.white,
              ),
              child: const AppText('Terminate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _message('Please sign in again.');
        return;
      }
      await document.reference.update({
        'status': 'terminated',
        'terminationNote': noteController.text.trim(),
        'terminatedAt': FieldValue.serverTimestamp(),
        'terminatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Lease marked as terminated.');
    } on FirebaseException catch (error) {
      _message('Unable to terminate lease (${error.code}).');
    } finally {
      noteController.dispose();
    }
  }

  Future<void> _reviewRenewalRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
    String decision,
  ) async {
    if (!['approved', 'rejected'].contains(decision)) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _message('Please sign in again.');
      return;
    }
    final data = request.data();
    final leaseId = data['leaseId'] as String? ?? request.id;
    final requestedEnd = data['requestedEndDate'];
    if (decision == 'approved' && requestedEnd is! Timestamp) {
      _message('The renewal request has no valid requested end date.');
      return;
    }
    try {
      final now = FieldValue.serverTimestamp();
      final batch = FirebaseFirestore.instance.batch();
      if (decision == 'approved') {
        batch.update(_leases.doc(leaseId), {
          'leaseEnd': requestedEnd,
          'updatedAt': now,
          'lastRenewalRequestId': request.id,
          'renewedAt': now,
          'renewedBy': uid,
        });
      }
      batch.update(request.reference, {
        'status': decision,
        'reviewNote': decision == 'approved'
            ? 'Renewal approved and lease end date extended.'
            : 'Renewal request declined by Colony Admin.',
        'reviewedBy': uid,
        'reviewedAt': now,
        'updatedAt': now,
      });
      await batch.commit();
      _message(
        decision == 'approved'
            ? 'Lease renewed successfully.'
            : 'Renewal request declined.',
      );
    } on FirebaseException catch (error) {
      _message('Unable to review renewal request (${error.code}).');
    }
  }

  Widget _renewalRequestCard(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) {
    final data = request.data();
    final unit = '${data['blockId'] ?? ''}-${data['houseNumber'] ?? ''}';
    return Card(
      color: AppTheme.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              '${data['tenantName'] ?? 'Tenant'} · Unit $unit',
              style: const TextStyle(
                color: AppTheme.navyBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            AppText(
              'Current end: ${_dateLabel(data['currentLeaseEnd'])} · '
              'Requested end: ${_dateLabel(data['requestedEndDate'])}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
            if ((data['note'] as String? ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              AppText(
                data['note'].toString(),
                style: const TextStyle(color: AppTheme.textDark, fontSize: 12),
              ),
            ],
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _reviewRenewalRequest(request, 'rejected'),
                    child: const AppText('Decline'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyBlue,
                      foregroundColor: AppTheme.white,
                    ),
                    onPressed: () => _reviewRenewalRequest(request, 'approved'),
                    child: const AppText('Approve & extend'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renewalQueue() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _renewalStream,
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final requests = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Resident renewal requests',
              style: TextStyle(
                color: AppTheme.navyBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            ...requests.map(_renewalRequestCard),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _leaseCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? <String, dynamic>{};
    final status = _status(data);
    final unit = '${data['blockId'] ?? ''}-${data['houseNumber'] ?? ''}';
    final canTerminate = data['status'] == 'active' && status != 'Expired';

    return Card(
      color: AppTheme.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.key_outlined, color: AppTheme.navyBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        data['tenantName'] as String? ?? 'Tenant',
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      AppText(
                        'Unit $unit · ${data['tenantPhone'] ?? 'No phone'}',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AppText(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _detail(
                  'Lease period',
                  '${_dateLabel(data['leaseStart'])} – ${_dateLabel(data['leaseEnd'])}',
                ),
                _detail('Monthly rent', _money(data['monthlyRent'])),
                _detail('Security deposit', _money(data['securityDeposit'])),
              ],
            ),
            if ((data['agreementReference'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              AppText(
                'Agreement: ${data['agreementReference']}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
            ],
            if ((data['terminationNote'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              AppText(
                'Termination: ${data['terminationNote']}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
            ],
            if (canTerminate) ...[
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _terminateLease(document),
                  icon: const Icon(Icons.block_outlined, size: 17),
                  label: const AppText('Terminate lease'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.navyBlue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => SizedBox(
    width: 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
        ),
        const SizedBox(height: 3),
        AppText(
          value,
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navyBlue,
        elevation: 0,
        title: const AppText(
          'Tenant & Lease Management',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _leaseStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppText('Unable to load leases: ${snapshot.error}'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.navyBlue),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          final active = docs
              .where((doc) => _status(doc.data()) == 'Active')
              .length;
          final expiring = docs
              .where((doc) => _status(doc.data()) == 'Expires soon')
              .length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _renewalQueue(),
              Row(
                children: [
                  Expanded(child: _summary('Total leases', '${docs.length}')),
                  const SizedBox(width: 8),
                  Expanded(child: _summary('Active', '$active')),
                  const SizedBox(width: 8),
                  Expanded(child: _summary('Expiring soon', '$expiring')),
                ],
              ),
              const SizedBox(height: 16),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(
                        Icons.key_outlined,
                        size: 42,
                        color: AppTheme.textGrey,
                      ),
                      SizedBox(height: 10),
                      AppText(
                        'No tenant leases yet',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 5),
                      AppText(
                        'Register residents with relationship “Tenant” before creating a lease.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...docs.map(_leaseCard),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateLease,
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: AppTheme.white,
        icon: const Icon(Icons.add),
        label: const AppText('Register lease'),
      ),
    );
  }

  Widget _summary(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.borderGrey),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          value,
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        AppText(
          label,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
        ),
      ],
    ),
  );
}
