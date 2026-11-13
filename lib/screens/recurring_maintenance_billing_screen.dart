// MOHALLAFLOW_RECURRING_MAINTENANCE_BILLING_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'maintenance_dues_screen.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Recurring maintenance billing, idempotent monthly issuance, late fees,
/// arrears ageing and resident household statements.
/// Existing maintenanceBills and maintenancePayments remain the source of truth.
class RecurringMaintenanceBillingScreen extends StatefulWidget {
  const RecurringMaintenanceBillingScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.isAdmin,
    this.adminName,
    this.residentId,
    this.residentName,
  });

  final String colonyId;
  final String colonyName;
  final bool isAdmin;
  final String? adminName;
  final String? residentId;
  final String? residentName;

  @override
  State<RecurringMaintenanceBillingScreen> createState() =>
      _RecurringMaintenanceBillingScreenState();
}

class _RecurringMaintenanceBillingScreenState
    extends State<RecurringMaintenanceBillingScreen> {
  final TextEditingController _periodController = TextEditingController();
  String? _selectedPlanId;
  String _arrearsFilter = 'all';
  bool _working = false;
  String _progressText = '';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get _colony =>
      FirebaseFirestore.instance.collection('colonies').doc(widget.colonyId);

  CollectionReference<Map<String, dynamic>> get _plans =>
      _colony.collection('maintenanceBillingPlans');

  CollectionReference<Map<String, dynamic>> get _runs =>
      _colony.collection('maintenanceBillingRuns');

  CollectionReference<Map<String, dynamic>> get _runItems =>
      _colony.collection('maintenanceBillingRunItems');

  CollectionReference<Map<String, dynamic>> get _audit =>
      _colony.collection('maintenanceBillingAudit');

  CollectionReference<Map<String, dynamic>> get _bills =>
      _colony.collection('maintenanceBills');

  CollectionReference<Map<String, dynamic>> get _households =>
      _colony.collection('households');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _colony.collection('maintenancePayments');

  DocumentReference<Map<String, dynamic>> get _resident =>
      _colony.collection('residents').doc(widget.residentId ?? '');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodController.text =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  num _number(dynamic value) => value is num ? value : 0;

  String _money(num value) => '₹${value.toStringAsFixed(2)}';

  DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is DateTime) {
      return value.toLocal();
    }
    return null;
  }

  String _date(dynamic value) {
    final date = _dateValue(value);
    if (date == null) {
      return '—';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) {
      return key;
    }
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[0]);
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month == null || month < 1 || month > 12 || year == null) {
      return key;
    }
    return '${months[month - 1]} $year';
  }

  String _runId(String planId, String periodKey) =>
      '${planId}_${periodKey.replaceAll('-', '')}';

  String _billId(String runId, String householdId) =>
      'rec_${runId}_$householdId';

  String _runItemId(String runId, String householdId) =>
      'runitem_${runId}_$householdId';

  String _lateFeeBillId(String runId, String householdId) =>
      'late_${runId}_$householdId';

  Map<String, dynamic> _planSnapshotFromRun(
    Map<String, dynamic> run,
    Map<String, dynamic> fallback,
  ) {
    return {
      'name': run['planName'] ?? fallback['name'],
      'description': run['planDescription'] ?? fallback['description'] ?? '',
      'amount': run['planAmount'] ?? fallback['amount'],
      'dueDay': run['dueDay'] ?? fallback['dueDay'],
      'graceDays': run['graceDays'] ?? fallback['graceDays'] ?? 0,
      'lateFeeMode': run['lateFeeMode'] ?? fallback['lateFeeMode'] ?? 'none',
      'lateFeeValue': run['lateFeeValue'] ?? fallback['lateFeeValue'] ?? 0,
      'upiId': run['upiId'] ?? fallback['upiId'] ?? '',
      'paymentInstructions':
          run['paymentInstructions'] ?? fallback['paymentInstructions'] ?? '',
    };
  }

  DateTime _dueDate(String periodKey, int dueDay) {
    final parts = periodKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return DateTime(year, month, dueDay, 23, 59, 59);
  }

  Future<void> _writeAudit({
    required String action,
    required String details,
    String planId = '',
    String runId = '',
    String householdId = '',
    String sourceBillId = '',
    String createdBillId = '',
    num amount = 0,
  }) async {
    await _audit.add({
      'action': action,
      'details': details,
      'planId': planId,
      'runId': runId,
      'householdId': householdId,
      'sourceBillId': sourceBillId,
      'createdBillId': createdBillId,
      'amount': amount,
      'createdBy': _uid,
      'createdByName': widget.adminName ?? 'Admin',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.borderGrey),
    ),
    child: child,
  );

  Widget _metric(String label, num amount, {String? footnote}) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(
            color: AppTheme.textGrey,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        AppText(
          _money(amount),
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 3),
          AppText(
            footnote,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 9),
          ),
        ],
      ],
    ),
  );

  Widget _status(String value) {
    final label = value.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText(
        label,
        style: const TextStyle(
          color: AppTheme.navyBlue,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ADMIN: BILLING PLAN MANAGEMENT
  // -------------------------------------------------------------------------

  Future<void> _showPlanDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final old = existing?.data() ?? <String, dynamic>{};
    final name = TextEditingController(text: old['name'] as String? ?? '');
    final description = TextEditingController(
      text: old['description'] as String? ?? '',
    );
    final amount = TextEditingController(
      text: old['amount'] == null ? '' : '${old['amount']}',
    );
    final dueDay = TextEditingController(text: '${old['dueDay'] ?? 7}');
    final graceDays = TextEditingController(text: '${old['graceDays'] ?? 5}');
    final lateFeeValue = TextEditingController(
      text: '${old['lateFeeValue'] ?? 0}',
    );
    final upiId = TextEditingController(text: old['upiId'] as String? ?? '');
    final instructions = TextEditingController(
      text: old['paymentInstructions'] as String? ?? '',
    );
    String feeMode = old['lateFeeMode'] as String? ?? 'none';

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setLocal) => AlertDialog(
            title: AppText(
              existing == null
                  ? 'Create recurring billing plan'
                  : 'Edit billing plan',
            ),
            content: SizedBox(
              width: 470,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Plan name *'),
                        hintText: AppTranslations.translate(
                          'Monthly maintenance',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Charge description',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Monthly amount per household (₹) *',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dueDay,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Due day (1–28) *',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: graceDays,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Grace days (0–30) *',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: feeMode,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Late-fee policy'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'none',
                          child: AppText('No late fee'),
                        ),
                        DropdownMenuItem(
                          value: 'flat',
                          child: AppText('Flat fee (₹)'),
                        ),
                        DropdownMenuItem(
                          value: 'percentage',
                          child: AppText('Percentage of unpaid balance'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setLocal(() => feeMode = value);
                        }
                      },
                    ),
                    if (feeMode != 'none') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: lateFeeValue,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: feeMode == 'flat'
                              ? AppTranslations.translate(
                                  'Late fee amount (₹) *',
                                )
                              : AppTranslations.translate(
                                  'Late fee percentage (0–100) *',
                                ),
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                    TextField(
                      controller: upiId,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'UPI ID for this plan',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: instructions,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Resident payment instructions',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const AppText(
                      'Plans are issued only when an Admin runs a billing cycle. No automatic background charging or payment collection occurs.',
                      style: TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 10,
                        height: 1.35,
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                ),
                onPressed: () {
                  final parsedAmount = num.tryParse(amount.text.trim());
                  final parsedDay = int.tryParse(dueDay.text.trim());
                  final parsedGrace = int.tryParse(graceDays.text.trim());
                  final parsedFee = num.tryParse(lateFeeValue.text.trim()) ?? 0;
                  final feeValid =
                      feeMode == 'none' ||
                      (parsedFee > 0 &&
                          (feeMode != 'percentage' || parsedFee <= 100));
                  if (name.text.trim().isEmpty ||
                      parsedAmount == null ||
                      parsedAmount <= 0 ||
                      parsedDay == null ||
                      parsedDay < 1 ||
                      parsedDay > 28 ||
                      parsedGrace == null ||
                      parsedGrace < 0 ||
                      parsedGrace > 30 ||
                      !feeValid) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: AppText('Check the required plan values.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: AppText(existing == null ? 'Save plan' : 'Save changes'),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true || !mounted) {
        return;
      }
      final amountValue = num.parse(amount.text.trim());
      final dayValue = int.parse(dueDay.text.trim());
      final graceValue = int.parse(graceDays.text.trim());
      final feeValue = feeMode == 'none'
          ? 0
          : num.parse(lateFeeValue.text.trim());
      final uid = _uid;
      if (uid.isEmpty) {
        throw StateError('Please sign in again.');
      }

      final payload = <String, dynamic>{
        'name': name.text.trim(),
        'description': description.text.trim(),
        'amount': amountValue,
        'frequency': 'monthly',
        'dueDay': dayValue,
        'graceDays': graceValue,
        'lateFeeMode': feeMode,
        'lateFeeValue': feeValue,
        'upiId': upiId.text.trim(),
        'paymentInstructions': instructions.text.trim(),
      };

      if (existing == null) {
        final ref = _plans.doc();
        await ref.set({
          ...payload,
          'status': 'active',
          'createdBy': uid,
          'createdByName': widget.adminName ?? 'Admin',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        try {
          await _writeAudit(
            action: 'billing_plan_created',
            planId: ref.id,
            details:
                'Created plan ${name.text.trim()} at ${_money(amountValue)} per household/month.',
          );
        } catch (auditError) {
          _message('Plan saved, but the audit entry failed: $auditError');
        }
      } else {
        await existing.reference.update({
          ...payload,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        try {
          await _writeAudit(
            action: 'billing_plan_updated',
            planId: existing.id,
            details: 'Updated billing plan ${name.text.trim()}.',
          );
        } catch (auditError) {
          _message('Plan updated, but the audit entry failed: $auditError');
        }
      }
      _message('Billing plan saved.');
    } catch (error) {
      _message('Unable to save plan: $error');
    } finally {
      name.dispose();
      description.dispose();
      amount.dispose();
      dueDay.dispose();
      graceDays.dispose();
      lateFeeValue.dispose();
      upiId.dispose();
      instructions.dispose();
    }
  }

  Future<void> _togglePlan(
    QueryDocumentSnapshot<Map<String, dynamic>> plan,
  ) async {
    final data = plan.data();
    final next = data['status'] == 'active' ? 'paused' : 'active';
    try {
      await plan.reference.update({
        'status': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      try {
        await _writeAudit(
          action: 'billing_plan_status_changed',
          planId: plan.id,
          details: '${data['name']} changed to $next.',
        );
      } catch (auditError) {
        _message(
          'Plan status changed, but the audit entry failed: $auditError',
        );
      }
      _message('Plan ${next == 'active' ? 'activated' : 'paused'}.');
    } catch (error) {
      _message('Unable to update plan: $error');
    }
  }

  Widget _plansTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(
          children: [
            const Expanded(
              child: AppText(
                'Recurring billing plans',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.navyBlue),
              onPressed: () => _showPlanDialog(),
              icon: const Icon(Icons.add, size: 17),
              label: const AppText('New plan'),
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: AppText(
          'Create monthly charge templates. Plans can be paused without deleting their history; issued bills remain unchanged when a plan is edited.',
          style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _plans.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: AppText('Unable to load plans: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.navyBlue),
              );
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return _emptyState(
                'No billing plans yet',
                'Create a monthly plan before generating household bills.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final active = data['status'] == 'active';
                final mode = data['lateFeeMode'] as String? ?? 'none';
                final feeText = mode == 'none'
                    ? 'No late fee'
                    : mode == 'flat'
                    ? 'Late fee ${_money(_number(data['lateFeeValue']))}'
                    : 'Late fee ${_number(data['lateFeeValue'])}% of unpaid balance';
                return _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              data['name'] as String? ?? 'Billing plan',
                              style: const TextStyle(
                                color: AppTheme.navyBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          _status(active ? 'active' : 'paused'),
                        ],
                      ),
                      const SizedBox(height: 7),
                      AppText(
                        '${_money(_number(data['amount']))} per household / month',
                        style: const TextStyle(
                          color: AppTheme.navyBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AppText(
                        'Due day ${data['dueDay']} · ${data['graceDays']} grace days · $feeText',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 11,
                        ),
                      ),
                      if ((data['description'] as String? ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: AppText(
                            data['description'] as String,
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      const Divider(height: 22),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showPlanDialog(existing: doc),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const AppText('Edit'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _togglePlan(doc),
                            icon: Icon(
                              active ? Icons.pause : Icons.play_arrow,
                              size: 16,
                            ),
                            label: AppText(
                              active ? 'Pause plan' : 'Activate plan',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  // -------------------------------------------------------------------------
  // ADMIN: IDEMPOTENT BILLING CYCLE PREVIEW AND GENERATION
  // -------------------------------------------------------------------------

  Future<void> _previewAndGenerate(
    String planId,
    Map<String, dynamic> plan,
  ) async {
    if (_working) {
      return;
    }
    final periodKey = _periodController.text.trim();
    final validPeriod = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(periodKey);
    if (!validPeriod) {
      _message('Enter the billing period as YYYY-MM, for example 2026-11.');
      return;
    }

    setState(() {
      _working = true;
      _progressText = 'Checking occupied households and existing bill runs…';
    });

    try {
      final runId = _runId(planId, periodKey);
      final runRef = _runs.doc(runId);
      final runSnapshot = await runRef.get();
      if (runSnapshot.exists && runSnapshot.data()?['status'] == 'completed') {
        _message(
          'This plan already has a completed billing run for $periodKey.',
        );
        return;
      }
      final effectivePlan = runSnapshot.exists
          ? _planSnapshotFromRun(runSnapshot.data()!, plan)
          : plan;

      final householdSnapshot = await _households
          .where('occupancyStatus', isEqualTo: 'occupied')
          .limit(2001)
          .get();
      if (householdSnapshot.docs.length > 2000) {
        _message(
          'This run exceeds the 2,000-household safety limit. No bills were issued.',
        );
        return;
      }
      final households = householdSnapshot.docs;
      final itemSnapshot = await _runItems
          .where('runId', isEqualTo: runId)
          .get();
      final alreadyMapped = itemSnapshot.docs
          .map((doc) => doc.data()['householdId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final activeHouseholdIds = households
          .map((household) => household.id)
          .toSet();
      final alreadyMappedCurrent = alreadyMapped.intersection(
        activeHouseholdIds,
      );
      final remaining = households.length - alreadyMappedCurrent.length;
      final dueDate = _dueDate(
        periodKey,
        (effectivePlan['dueDay'] as num).toInt(),
      );

      if (!mounted) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const AppText('Preview monthly billing run'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText('Plan: ${effectivePlan['name']}'),
              const SizedBox(height: 6),
              AppText('Billing period: ${_monthLabel(periodKey)}'),
              AppText('Occupied households: ${households.length}'),
              AppText('Already processed: ${alreadyMappedCurrent.length}'),
              AppText('Remaining households: $remaining'),
              AppText(
                'Charge per household: ${_money(_number(effectivePlan['amount']))}',
              ),
              AppText(
                'Projected new billing: ${_money(remaining * _number(effectivePlan['amount']))}',
              ),
              AppText('Due date: ${_date(Timestamp.fromDate(dueDate))}'),
              const SizedBox(height: 10),
              const AppText(
                'The run creates one standard maintenance bill per eligible household. Re-running a partial cycle resumes missing items and does not duplicate bills.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.navyBlue),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: AppText(
                remaining == 0 ? 'Repair run record' : 'Generate bills',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await _generateBillingRun(
        planId: planId,
        plan: effectivePlan,
        periodKey: periodKey,
        households: households,
        existingItemHouseholdIds: alreadyMapped,
      );
    } catch (error) {
      _message('Unable to prepare billing run: $error');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _progressText = '';
        });
      }
    }
  }

  Future<void> _generateBillingRun({
    required String planId,
    required Map<String, dynamic> plan,
    required String periodKey,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> households,
    required Set<String> existingItemHouseholdIds,
  }) async {
    final runId = _runId(planId, periodKey);
    final runRef = _runs.doc(runId);
    final uid = _uid;
    if (uid.isEmpty) {
      throw StateError('Please sign in again.');
    }
    final periodLabel = _monthLabel(periodKey);
    final dueDate = _dueDate(periodKey, (plan['dueDay'] as num).toInt());

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final current = await transaction.get(runRef);
      if (current.exists && current.data()?['status'] == 'completed') {
        throw StateError('This billing run is already completed.');
      }
      if (!current.exists) {
        transaction.set(runRef, {
          'runType': 'monthly',
          'planId': planId,
          'planName': plan['name'],
          'planDescription': plan['description'] ?? '',
          'planAmount': _number(plan['amount']),
          'dueDay': (plan['dueDay'] as num).toInt(),
          'graceDays': (plan['graceDays'] as num?)?.toInt() ?? 0,
          'lateFeeMode': plan['lateFeeMode'] ?? 'none',
          'lateFeeValue': _number(plan['lateFeeValue']),
          'upiId': plan['upiId'] ?? '',
          'paymentInstructions': plan['paymentInstructions'] ?? '',
          'periodKey': periodKey,
          'periodLabel': periodLabel,
          'householdCount': households.length,
          'issuedCount': 0,
          'skippedCount': 0,
          'totalAmount': 0,
          'status': 'generating',
          'errorMessage': '',
          'createdBy': uid,
          'createdByName': widget.adminName ?? 'Admin',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(runRef, {
          'status': 'generating',
          'errorMessage': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    var issuedCount = 0;
    var skippedCount = 0;
    var totalAmount = 0.0;
    final allHouseholds = households;

    try {
      const chunkSize = 6;
      for (var start = 0; start < allHouseholds.length; start += chunkSize) {
        final end = (start + chunkSize < allHouseholds.length)
            ? start + chunkSize
            : allHouseholds.length;
        final chunk = allHouseholds.sublist(start, end);
        final batch = FirebaseFirestore.instance.batch();
        var writesInBatch = 0;
        var chunkIssued = 0;
        var chunkSkipped = 0;
        var chunkTotal = 0.0;

        for (final household in chunk) {
          final householdId = household.id;
          final householdData = household.data();
          final billRef = _bills.doc(_billId(runId, householdId));
          final itemRef = _runItems.doc(_runItemId(runId, householdId));
          final itemExists = existingItemHouseholdIds.contains(householdId);
          if (itemExists) {
            final existingBillSnapshot = await billRef.get();
            if (!existingBillSnapshot.exists) {
              throw StateError(
                'A billing run item exists but its bill is missing for household $householdId.',
              );
            }
            chunkIssued += 1;
            chunkTotal += _number(existingBillSnapshot.data()?['totalAmount'])
                .toDouble();
            continue;
          }

          final billSnapshot = await billRef.get();
          final billExists = billSnapshot.exists;
          if (billExists) {
            chunkSkipped += 1;
          } else {
            batch.set(billRef, {
              'householdId': householdId,
              'blockId': householdData['blockId'] as String? ?? '',
              'houseNumber': householdData['houseNumber'] as String? ?? '',
              'householdHeadName':
                  householdData['householdHeadName'] as String? ?? '',
              'billingPeriod': periodLabel,
              'title': plan['name'] as String? ?? 'Monthly maintenance',
              'description': plan['description'] as String? ?? '',
              'totalAmount': _number(plan['amount']),
              'amountPaid': 0,
              'status': 'unpaid',
              'dueDate': Timestamp.fromDate(dueDate),
              'upiId': plan['upiId'] as String? ?? '',
              'paymentInstructions':
                  plan['paymentInstructions'] as String? ?? '',
              'createdBy': uid,
              'createdByName': widget.adminName ?? 'Admin',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            writesInBatch += 1;
          }

          batch.set(itemRef, {
            'runId': runId,
            'planId': planId,
            'householdId': householdId,
            'billId': billRef.id,
            'periodKey': periodKey,
            'dueDate': Timestamp.fromDate(dueDate),
            'lateFeeAssessed': false,
            'lateFeeBillId': '',
            'lateFeeAmount': 0,
            'lateFeeAssessedAt': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          writesInBatch += 1;
          chunkIssued += 1;
          if (billExists) {
            final existingBillData = billSnapshot.data();
            if (existingBillData == null) {
              throw StateError(
                'An existing maintenance bill could not be read for household $householdId.',
              );
            }
            chunkTotal += _number(existingBillData['totalAmount']).toDouble();
          } else {
            chunkTotal += _number(plan['amount']).toDouble();
          }
        }

        if (writesInBatch > 0) {
          await batch.commit();
        }
        issuedCount += chunkIssued;
        skippedCount += chunkSkipped;
        totalAmount += chunkTotal;
        if (mounted) {
          setState(() {
            _progressText =
                'Processed $end of ${allHouseholds.length} households…';
          });
        }
      }

      await runRef.update({
        'status': 'completed',
        'householdCount': allHouseholds.length,
        'issuedCount': issuedCount,
        'skippedCount': skippedCount,
        'totalAmount': totalAmount,
        'finishedAt': FieldValue.serverTimestamp(),
        'errorMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      try {
        await _writeAudit(
          action: 'billing_run_completed',
          planId: planId,
          runId: runId,
          details:
              'Issued/resumed $issuedCount household bills for $periodLabel; $skippedCount pre-existing bill documents were linked without replacement.',
          amount: totalAmount,
        );
      } catch (auditError) {
        _message(
          'Billing completed, but the audit entry could not be saved: $auditError',
        );
      }
      _message('Billing cycle completed: $issuedCount households processed.');
    } catch (error) {
      await runRef.update({
        'status': 'partial',
        'issuedCount': issuedCount,
        'skippedCount': skippedCount,
        'totalAmount': totalAmount,
        'errorMessage': error.toString().substring(
          0,
          error.toString().length > 450 ? 450 : error.toString().length,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      rethrow;
    }
  }

  Widget _runsTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _plans.orderBy('createdAt', descending: true).snapshots(),
    builder: (context, planSnapshot) {
      if (planSnapshot.hasError) {
        return Center(
          child: AppText('Unable to load plans: ${planSnapshot.error}'),
        );
      }
      if (!planSnapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyBlue),
        );
      }
      final planDocs = planSnapshot.data!.docs;
      final activePlans = planDocs
          .where((doc) => doc.data()['status'] == 'active')
          .toList();
      final selectedActive = activePlans.where(
        (doc) => doc.id == _selectedPlanId,
      );
      final selectedPlan = selectedActive.isNotEmpty
          ? selectedActive.first
          : (activePlans.isEmpty ? null : activePlans.first);
      if (selectedPlan != null && _selectedPlanId != selectedPlan.id) {
        _selectedPlanId = selectedPlan.id;
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Generate monthly bills',
                  style: TextStyle(
                    color: AppTheme.navyBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                if (activePlans.isEmpty)
                  const AppText(
                    'Create and activate a billing plan first.',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedPlan?.id,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Active billing plan',
                      ),
                    ),
                    items: activePlans
                        .map(
                          (doc) => DropdownMenuItem(
                            value: doc.id,
                            child: AppText(
                              '${doc.data()['name']} · ${_money(_number(doc.data()['amount']))}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _working
                        ? null
                        : (value) => setState(() => _selectedPlanId = value),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _periodController,
                  enabled: !_working,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate(
                      'Billing period (YYYY-MM)',
                    ),
                    hintText: AppTranslations.translate('2026-11'),
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyBlue,
                    ),
                    onPressed: _working || selectedPlan == null
                        ? null
                        : () => _previewAndGenerate(
                            selectedPlan.id,
                            selectedPlan.data(),
                          ),
                    icon: const Icon(Icons.playlist_add_check_outlined),
                    label: const AppText('Preview & generate billing cycle'),
                  ),
                ),
                if (_working) ...[
                  const SizedBox(height: 9),
                  const LinearProgressIndicator(
                    color: AppTheme.navyBlue,
                    minHeight: 3,
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    _progressText,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 10,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const AppText(
                  'A cycle is unique for each plan and month. Completed runs cannot be issued twice. Interrupted runs can be resumed; the billing engine uses deterministic bill IDs and small write chunks to stay within Firestore security-rule access-call limits.',
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppText(
                'Billing run history',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _runs.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: AppText(
                      'Unable to load run history: ${snapshot.error}',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.navyBlue),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _emptyState(
                    'No billing runs yet',
                    'Completed and interrupted billing cycles will appear here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppText(
                                  '${data['planName'] ?? 'Billing plan'} · ${data['periodLabel'] ?? data['periodKey'] ?? ''}',
                                  style: const TextStyle(
                                    color: AppTheme.navyBlue,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              _status(data['status'] as String? ?? 'unknown'),
                            ],
                          ),
                          const SizedBox(height: 7),
                          AppText(
                            '${data['issuedCount'] ?? 0} processed / ${data['householdCount'] ?? 0} households · ${_money(_number(data['totalAmount']))}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                          if ((data['errorMessage'] as String? ?? '')
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: AppText(
                                data['errorMessage'] as String,
                                style: const TextStyle(
                                  color: Color(0xFFB54747),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (data['status'] != 'completed')
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => _resumeRun(doc),
                                icon: const Icon(Icons.replay, size: 16),
                                label: const AppText('Resume cycle'),
                              ),
                            ),
                          if (data['status'] == 'completed' &&
                              data['lateFeeMode'] != 'none' &&
                              _number(data['lateFeeValue']) > 0)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => _assessLateFees(doc),
                                icon: const Icon(
                                  Icons.price_check_outlined,
                                  size: 16,
                                ),
                                label: const AppText(
                                  'Assess eligible late fees',
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    },
  );

  Future<void> _resumeRun(
    QueryDocumentSnapshot<Map<String, dynamic>> runDoc,
  ) async {
    final data = runDoc.data();
    final runPlan = <String, dynamic>{
      'name': data['planName'],
      'description': data['planDescription'] ?? '',
      'amount': data['planAmount'],
      'dueDay': data['dueDay'],
      'graceDays': data['graceDays'],
      'lateFeeMode': data['lateFeeMode'] ?? 'none',
      'lateFeeValue': data['lateFeeValue'] ?? 0,
      'upiId': data['upiId'] ?? '',
      'paymentInstructions': data['paymentInstructions'] ?? '',
    };
    final households = await _households
        .where('occupancyStatus', isEqualTo: 'occupied')
        .limit(2001)
        .get();
    if (households.docs.length > 2000) {
      _message('The household count exceeds the 2,000-household safety limit.');
      return;
    }
    final existingItems = await _runItems
        .where('runId', isEqualTo: runDoc.id)
        .get();
    if (!mounted) {
      return;
    }
    setState(() {
      _working = true;
      _progressText = 'Resuming ${data['periodLabel']}…';
    });
    try {
      await _generateBillingRun(
        planId: data['planId'] as String,
        plan: runPlan,
        periodKey: data['periodKey'] as String,
        households: households.docs,
        existingItemHouseholdIds: existingItems.docs
            .map((doc) => doc.data()['householdId'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet(),
      );
    } catch (error) {
      _message('Unable to resume billing run: $error');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _progressText = '';
        });
      }
    }
  }

  // -------------------------------------------------------------------------
  // ADMIN: ONE-TIME LATE-FEE ASSESSMENT
  // -------------------------------------------------------------------------

  Future<void> _assessLateFees(
    QueryDocumentSnapshot<Map<String, dynamic>> runDoc,
  ) async {
    if (_working) {
      return;
    }
    final run = runDoc.data();
    final mode = run['lateFeeMode'] as String? ?? 'none';
    final feeValue = _number(run['lateFeeValue']);
    if (mode == 'none' || feeValue <= 0) {
      _message('This billing plan has no late-fee policy.');
      return;
    }
    setState(() {
      _working = true;
      _progressText = 'Checking grace periods and outstanding balances…';
    });
    var created = 0;
    var skipped = 0;
    try {
      final items = await _runItems.where('runId', isEqualTo: runDoc.id).get();
      for (var index = 0; index < items.docs.length; index++) {
        final itemDoc = items.docs[index];
        final didCreate = await _assessOneLateFee(
          itemDoc.reference,
          runDoc.id,
          run,
        );
        if (didCreate) {
          created++;
        } else {
          skipped++;
        }
        if (mounted && index % 20 == 0) {
          setState(() {
            _progressText =
                'Checked ${index + 1} of ${items.docs.length} billing records…';
          });
        }
      }
      try {
        await _writeAudit(
          action: 'late_fee_assessment_run',
          planId: run['planId'] as String? ?? '',
          runId: runDoc.id,
          details:
              'Late fee assessment completed for ${run['periodLabel']}; created $created late-fee bills and skipped $skipped records.',
        );
      } catch (auditError) {
        _message(
          'Fees were processed, but the audit summary failed: $auditError',
        );
      }
      _message(
        'Late-fee assessment complete: $created fees created, $skipped skipped.',
      );
    } catch (error) {
      _message('Late-fee assessment stopped: $error');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _progressText = '';
        });
      }
    }
  }

  Future<bool> _assessOneLateFee(
    DocumentReference<Map<String, dynamic>> itemRef,
    String runId,
    Map<String, dynamic> run,
  ) async {
    final householdId = itemRef.id.substring('runitem_${runId}_'.length);
    final sourceBillId = _billId(runId, householdId);
    final sourceBillRef = _bills.doc(sourceBillId);
    final feeBillRef = _bills.doc(_lateFeeBillId(runId, householdId));
    final householdRef = _households.doc(householdId);
    final auditRef = _audit.doc();

    final created = await FirebaseFirestore.instance.runTransaction<bool>((
      transaction,
    ) async {
      final itemSnapshot = await transaction.get(itemRef);
      final billSnapshot = await transaction.get(sourceBillRef);
      final feeSnapshot = await transaction.get(feeBillRef);
      final householdSnapshot = await transaction.get(householdRef);
      if (!itemSnapshot.exists ||
          !billSnapshot.exists ||
          !householdSnapshot.exists) {
        return false;
      }
      final item = itemSnapshot.data()!;
      if (item['lateFeeAssessed'] == true) {
        return false;
      }
      if (feeSnapshot.exists) {
        transaction.update(itemRef, {
          'lateFeeAssessed': true,
          'lateFeeBillId': feeBillRef.id,
          'lateFeeAmount': _number(feeSnapshot.data()?['totalAmount']),
          'lateFeeAssessedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return false;
      }
      if (householdSnapshot.data()?['occupancyStatus'] != 'occupied') {
        return false;
      }
      final bill = billSnapshot.data()!;
      final dueDate = _dateValue(bill['dueDate']);
      if (dueDate == null) {
        return false;
      }
      final graceDays = (run['graceDays'] as num?)?.toInt() ?? 0;
      final eligibleAt = dueDate.add(Duration(days: graceDays));
      if (DateTime.now().isBefore(eligibleAt)) {
        return false;
      }
      final outstanding =
          _number(bill['totalAmount']) - _number(bill['amountPaid']);
      if (outstanding <= 0) {
        return false;
      }

      final mode = run['lateFeeMode'] as String? ?? 'none';
      final feeValue = _number(run['lateFeeValue']);
      final rawFee = mode == 'flat'
          ? feeValue
          : mode == 'percentage'
          ? outstanding * feeValue / 100
          : 0;
      final fee = (rawFee * 100).roundToDouble() / 100;
      if (fee <= 0) {
        return false;
      }

      final now = DateTime.now();
      final feePeriod = '${run['periodLabel']} · Late fee';
      transaction.set(feeBillRef, {
        'householdId': householdId,
        'blockId': bill['blockId'] as String? ?? '',
        'houseNumber': bill['houseNumber'] as String? ?? '',
        'householdHeadName': bill['householdHeadName'] as String? ?? '',
        'billingPeriod': feePeriod,
        'title': 'Late payment charge',
        'description':
            'One-time late fee for ${bill['title'] ?? 'maintenance bill'} (${bill['billingPeriod'] ?? run['periodLabel']}). Original bill reference: $sourceBillId. Applied after ${run['graceDays']} grace days.',
        'totalAmount': fee,
        'amountPaid': 0,
        'status': 'unpaid',
        'dueDate': Timestamp.fromDate(now.add(const Duration(days: 7))),
        'upiId': bill['upiId'] as String? ?? '',
        'paymentInstructions': bill['paymentInstructions'] as String? ?? '',
        'createdBy': _uid,
        'createdByName': widget.adminName ?? 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(itemRef, {
        'lateFeeAssessed': true,
        'lateFeeBillId': feeBillRef.id,
        'lateFeeAmount': fee,
        'lateFeeAssessedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(auditRef, {
        'action': 'late_fee_assessed',
        'details':
            'One-time late fee assessed for overdue bill ${bill['billingPeriod'] ?? run['periodLabel']}.',
        'planId': run['planId'] as String? ?? '',
        'runId': runId,
        'householdId': householdId,
        'sourceBillId': sourceBillId,
        'createdBillId': feeBillRef.id,
        'amount': fee,
        'createdBy': _uid,
        'createdByName': widget.adminName ?? 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
    return created;
  }

  // -------------------------------------------------------------------------
  // ADMIN: ARREARS AGEING AND EXPORT
  // -------------------------------------------------------------------------

  int _daysOverdue(Map<String, dynamic> bill) {
    final dueDate = _dateValue(bill['dueDate']);
    if (dueDate == null) {
      return 0;
    }
    final balance = _number(bill['totalAmount']) - _number(bill['amountPaid']);
    final now = DateTime.now();
    if (balance <= 0 || !dueDate.isBefore(now)) {
      return 0;
    }
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final calendarDays = today.difference(dueDay).inDays;
    return calendarDays < 1 ? 1 : calendarDays;
  }

  String _ageBand(int days) {
    if (days <= 0) {
      return 'current';
    }
    if (days <= 30) {
      return '1–30 days';
    }
    if (days <= 60) {
      return '31–60 days';
    }
    if (days <= 90) {
      return '61–90 days';
    }
    return '90+ days';
  }

  Widget _arrearsTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _bills.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: AppText('Unable to load arrears: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyBlue),
        );
      }
      final bills = snapshot.data!.docs;
      final outstanding = bills.where((doc) {
        final data = doc.data();
        return _number(data['totalAmount']) > _number(data['amountPaid']);
      }).toList();
      final overdue = outstanding
          .where((doc) => _daysOverdue(doc.data()) > 0)
          .toList();
      final totalDue = outstanding.fold<num>(
        0,
        (runningTotal, doc) =>
            runningTotal +
            (_number(doc.data()['totalAmount']) -
                _number(doc.data()['amountPaid'])),
      );
      final bands = <String, num>{
        '1–30 days': 0,
        '31–60 days': 0,
        '61–90 days': 0,
        '90+ days': 0,
      };
      for (final bill in overdue) {
        final data = bill.data();
        final balance =
            _number(data['totalAmount']) - _number(data['amountPaid']);
        final band = _ageBand(_daysOverdue(data));
        bands[band] = (bands[band] ?? 0) + balance;
      }
      final visible =
          outstanding.where((doc) {
            if (_arrearsFilter == 'all') {
              return true;
            }
            if (_arrearsFilter == 'current') {
              return _daysOverdue(doc.data()) == 0;
            }
            return _ageBand(_daysOverdue(doc.data())) == _arrearsFilter;
          }).toList()..sort(
            (a, b) => _daysOverdue(b.data()).compareTo(_daysOverdue(a.data())),
          );

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 7),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _metric('Total outstanding', totalDue)),
                    const SizedBox(width: 8),
                    Expanded(child: _metric('Overdue bills', overdue.length)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _metric('1–30 days', bands['1–30 days'] ?? 0),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _metric('31–60 days', bands['31–60 days'] ?? 0),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _metric('61–90 days', bands['61–90 days'] ?? 0),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _metric('90+ days', bands['90+ days'] ?? 0),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _arrearsChip('All', 'all'),
                    _arrearsChip('Current', 'current'),
                    _arrearsChip('1–30', '1–30 days'),
                    _arrearsChip('31–60', '31–60 days'),
                    _arrearsChip('61–90', '61–90 days'),
                    _arrearsChip('90+', '90+ days'),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _exportArrears(visible),
                    icon: const Icon(Icons.copy_all_outlined, size: 16),
                    label: const AppText('Copy CSV'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? _emptyState(
                    'No matching balances',
                    'There are no outstanding bills in this ageing category.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = visible[index];
                      final data = doc.data();
                      final balance =
                          _number(data['totalAmount']) -
                          _number(data['amountPaid']);
                      final days = _daysOverdue(data);
                      return _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AppText(
                                    '${data['blockId'] ?? ''} · ${data['houseNumber'] ?? ''} · ${data['householdHeadName'] ?? 'Household'}',
                                    style: const TextStyle(
                                      color: AppTheme.navyBlue,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                _status(days == 0 ? 'current' : _ageBand(days)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            AppText(
                              '${data['title'] ?? 'Maintenance bill'} · ${data['billingPeriod'] ?? ''}',
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: AppText(
                                    'Balance: ${_money(balance)}',
                                    style: const TextStyle(
                                      color: AppTheme.navyBlue,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                AppText(
                                  days == 0
                                      ? 'Not overdue'
                                      : '$days days overdue',
                                  style: const TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            AppText(
                              'Due date: ${_date(data['dueDate'])}',
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );

  Widget _arrearsChip(String label, String value) => ChoiceChip(
    label: AppText(label),
    selected: _arrearsFilter == value,
    selectedColor: AppTheme.navyBlue,
    backgroundColor: AppTheme.white,
    labelStyle: TextStyle(
      color: _arrearsFilter == value ? Colors.white : AppTheme.navyBlue,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    ),
    onSelected: (_) => setState(() => _arrearsFilter = value),
  );

  Future<void> _exportArrears(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final rows = <String>[
      'Block,House,Household,Title,Billing Period,Total,Paid,Balance,Due Date,Days Overdue',
    ];
    for (final doc in docs) {
      final data = doc.data();
      final balance =
          _number(data['totalAmount']) - _number(data['amountPaid']);
      String csv(dynamic value) =>
          '"${(value ?? '').toString().replaceAll('"', '""')}"';
      rows.add(
        [
          csv(data['blockId']),
          csv(data['houseNumber']),
          csv(data['householdHeadName']),
          csv(data['title']),
          csv(data['billingPeriod']),
          _number(data['totalAmount']).toStringAsFixed(2),
          _number(data['amountPaid']).toStringAsFixed(2),
          balance.toStringAsFixed(2),
          csv(_date(data['dueDate'])),
          _daysOverdue(data).toString(),
        ].join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    _message('CSV copied to clipboard. Paste it into a spreadsheet.');
  }

  // -------------------------------------------------------------------------
  // ADMIN: APPEND-ONLY BILLING AUDIT
  // -------------------------------------------------------------------------

  Widget _auditTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _audit
        .orderBy('createdAt', descending: true)
        .limit(250)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: AppText('Unable to load billing audit: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyBlue),
        );
      }
      final docs = snapshot.data!.docs;
      if (docs.isEmpty) {
        return _emptyState(
          'No billing activity yet',
          'Plan changes, billing runs and late-fee assessments will appear here.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(15),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final data = docs[index].data();
          return _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        (data['action'] as String? ?? 'activity')
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.navyBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    AppText(
                      _date(data['createdAt']),
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AppText(
                  data['details'] as String? ?? '',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 5),
                AppText(
                  'By ${data['createdByName'] ?? 'Admin'}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  // -------------------------------------------------------------------------
  // RESIDENT: LIVE HOUSEHOLD ACCOUNT STATEMENT
  // -------------------------------------------------------------------------

  Widget _residentStatement() {
    if (widget.residentId == null || widget.residentId!.isEmpty) {
      return _emptyState(
        'Resident account not linked',
        'Contact your Colony Admin to link your resident record.',
      );
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _resident.get(),
      builder: (context, residentSnapshot) {
        if (residentSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }
        if (residentSnapshot.hasError ||
            !residentSnapshot.hasData ||
            !residentSnapshot.data!.exists) {
          return _emptyState(
            'Unable to load resident profile',
            'Contact your Colony Admin.',
          );
        }
        final resident = residentSnapshot.data!.data()!;
        if (resident['residentStatus'] != 'active') {
          return _emptyState(
            'Resident profile inactive',
            'Contact your Colony Admin.',
          );
        }
        final householdId = resident['householdId'] as String? ?? '';
        if (householdId.isEmpty) {
          return _emptyState(
            'No household linked',
            'Your resident profile needs a household assignment.',
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _bills
              .where('householdId', isEqualTo: householdId)
              .snapshots(),
          builder: (context, billSnapshot) {
            if (billSnapshot.hasError) {
              return Center(
                child: AppText(
                  'Unable to load account statement: ${billSnapshot.error}',
                ),
              );
            }
            if (!billSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.navyBlue),
              );
            }
            final docs = billSnapshot.data!.docs.toList()
              ..sort((a, b) {
                final aDate = _dateValue(a.data()['dueDate']) ?? DateTime(2000);
                final bDate = _dateValue(b.data()['dueDate']) ?? DateTime(2000);
                return bDate.compareTo(aDate);
              });
            num billed = 0;
            num paid = 0;
            num due = 0;
            num overdue = 0;
            final bands = <String, num>{
              '1–30 days': 0,
              '31–60 days': 0,
              '61–90 days': 0,
              '90+ days': 0,
            };
            for (final doc in docs) {
              final data = doc.data();
              final total = _number(data['totalAmount']);
              final received = _number(data['amountPaid']);
              final balance = (total - received) > 0 ? total - received : 0;
              billed += total;
              paid += received;
              due += balance;
              final days = _daysOverdue(data);
              if (days > 0 && balance > 0) {
                overdue += balance;
                final band = _ageBand(days);
                bands[band] = (bands[band] ?? 0) + balance;
              }
            }

            return ListView(
              padding: const EdgeInsets.all(15),
              children: [
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'HOUSEHOLD ACCOUNT STATEMENT',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      AppText(
                        '${resident['blockId'] ?? ''} · ${resident['houseNumber'] ?? ''}',
                        style: const TextStyle(
                          color: AppTheme.navyBlue,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      AppText(
                        resident['residentName'] as String? ??
                            widget.residentName ??
                            'Resident',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 11,
                        ),
                      ),
                      const Divider(height: 23),
                      Row(
                        children: [
                          Expanded(child: _metric('Total billed', billed)),
                          const SizedBox(width: 7),
                          Expanded(child: _metric('Total paid', paid)),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(child: _metric('Outstanding', due)),
                          const SizedBox(width: 7),
                          Expanded(child: _metric('Overdue', overdue)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'Overdue ageing',
                        style: TextStyle(
                          color: AppTheme.navyBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      for (final label in bands.keys)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: AppText(
                                  label,
                                  style: const TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              AppText(
                                _money(bands[label] ?? 0),
                                style: const TextStyle(
                                  color: AppTheme.navyBlue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: AppText(
                        'Bill history',
                        style: TextStyle(
                          color: AppTheme.navyBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _copyResidentStatement(docs, resident, due, paid),
                      icon: const Icon(Icons.copy_all_outlined, size: 16),
                      label: const AppText('Copy statement'),
                    ),
                  ],
                ),
                if (docs.isEmpty)
                  _emptyState(
                    'No bills found',
                    'Your Admin has not issued a maintenance bill for this household.',
                  ),
                for (final doc in docs) _residentBillCard(doc),
                const SizedBox(height: 12),
                const AppText(
                  'Recent payment submissions',
                  style: TextStyle(
                    color: AppTheme.navyBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                _residentPaymentHistory(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyBlue,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MaintenanceDuesScreen(
                            colonyId: widget.colonyId,
                            colonyName: widget.colonyName,
                            isAdmin: false,
                            residentId: widget.residentId,
                            residentName: widget.residentName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const AppText('Open bills & payment submission'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _residentPaymentHistory() {
    if (_uid.isEmpty) {
      return const AppText('Please sign in again.');
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _payments
          .where('submittedBy', isEqualTo: _uid)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppText(
            'Unable to load payment submissions: ${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aDate = _dateValue(a.data()['createdAt']) ?? DateTime(2000);
            final bDate = _dateValue(b.data()['createdAt']) ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });
        if (docs.isEmpty) {
          return const AppText(
            'No payment submissions recorded yet.',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
          );
        }
        return Column(
          children: docs.take(8).map((doc) {
            final data = doc.data();
            final status = data['status'] as String? ?? 'pending';
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _panel(
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            _money(_number(data['amount'])),
                            style: const TextStyle(
                              color: AppTheme.navyBlue,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AppText(
                            '${data['paymentMethod'] ?? ''} · ${_date(data['createdAt'])}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 10,
                            ),
                          ),
                          if ((data['rejectionReason'] as String? ?? '')
                              .isNotEmpty)
                            AppText(
                              'Admin note: ${data['rejectionReason']}',
                              style: const TextStyle(
                                color: Color(0xFFB54747),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _status(status),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _residentBillCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final total = _number(data['totalAmount']);
    final paid = _number(data['amountPaid']);
    final balance = (total - paid) > 0 ? total - paid : 0;
    final days = _daysOverdue(data);
    final status = balance <= 0
        ? 'paid'
        : days > 0
        ? 'overdue'
        : paid > 0
        ? 'partially_paid'
        : 'unpaid';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(
                    data['title'] as String? ?? 'Maintenance bill',
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _status(status),
              ],
            ),
            const SizedBox(height: 5),
            AppText(
              '${data['billingPeriod'] ?? ''} · Due ${_date(data['dueDate'])}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(child: _amountText('Billed', total)),
                Expanded(child: _amountText('Paid', paid)),
                Expanded(child: _amountText('Balance', balance)),
              ],
            ),
            if ((data['description'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: AppText(
                  data['description'] as String,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 10,
                  ),
                ),
              ),
            if (days > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AppText(
                  '$days days overdue · ${_ageBand(days)}',
                  style: const TextStyle(
                    color: Color(0xFFB54747),
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _amountText(String label, num value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        label,
        style: const TextStyle(color: AppTheme.textGrey, fontSize: 9),
      ),
      const SizedBox(height: 3),
      AppText(
        _money(value),
        style: const TextStyle(
          color: AppTheme.navyBlue,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    ],
  );

  Future<void> _copyResidentStatement(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, dynamic> resident,
    num due,
    num paid,
  ) async {
    final lines = <String>[
      'MohallaFlow Household Account Statement',
      'Colony,${widget.colonyName}',
      'House,${resident['blockId'] ?? ''}-${resident['houseNumber'] ?? ''}',
      'Resident,${widget.residentName ?? ''}',
      'Total paid,${paid.toStringAsFixed(2)}',
      'Outstanding,${due.toStringAsFixed(2)}',
      '',
      'Title,Billing Period,Due Date,Total,Paid,Balance,Status',
    ];
    for (final doc in docs) {
      final data = doc.data();
      final total = _number(data['totalAmount']);
      final received = _number(data['amountPaid']);
      final balance = (total - received) > 0 ? total - received : 0;
      lines.add(
        [
              data['title'] ?? 'Maintenance bill',
              data['billingPeriod'] ?? '',
              _date(data['dueDate']),
              total.toStringAsFixed(2),
              received.toStringAsFixed(2),
              balance.toStringAsFixed(2),
              balance <= 0
                  ? 'Paid'
                  : _daysOverdue(data) > 0
                  ? 'Overdue'
                  : 'Due',
            ]
            .map((value) => '"${value.toString().replaceAll('"', '""')}"')
            .join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    _message('Account statement copied as CSV text.');
  }

  Widget _emptyState(String title, String note) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: AppTheme.secondaryNavy,
            size: 38,
          ),
          const SizedBox(height: 10),
          AppText(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          AppText(
            note,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return DefaultTabController(
      length: widget.isAdmin ? 4 : 1,
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          foregroundColor: AppTheme.navyBlue,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                widget.isAdmin
                    ? 'Recurring Billing & Arrears'
                    : 'My Account Statement',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              AppText(
                widget.colonyName,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
              ),
            ],
          ),
          bottom: widget.isAdmin
              ? TabBar(
                  isScrollable: true,
                  labelColor: AppTheme.navyBlue,
                  unselectedLabelColor: AppTheme.textGrey,
                  indicatorColor: AppTheme.navyBlue,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.tune_outlined),
                      text: AppTranslations.translate('Plans'),
                    ),
                    Tab(
                      icon: Icon(Icons.calendar_month_outlined),
                      text: AppTranslations.translate('Billing runs'),
                    ),
                    Tab(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      text: AppTranslations.translate('Arrears'),
                    ),
                    Tab(
                      icon: Icon(Icons.history_outlined),
                      text: AppTranslations.translate('Audit'),
                    ),
                  ],
                )
              : null,
        ),
        body: widget.isAdmin
            ? TabBarView(
                children: [_plansTab(), _runsTab(), _arrearsTab(), _auditTab()],
              )
            : _residentStatement(),
      ),
    );
  }
}
