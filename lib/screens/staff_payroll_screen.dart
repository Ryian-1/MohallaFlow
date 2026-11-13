// MOHALLAFLOW_STAFF_PAYROLL_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Admin-only staff master, monthly payroll, approval, payout and reports.
/// Payroll entries snapshot the compensation used for that pay period.
class StaffPayrollScreen extends StatefulWidget {
  const StaffPayrollScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<StaffPayrollScreen> createState() => _StaffPayrollScreenState();
}

class _StaffPayrollScreenState extends State<StaffPayrollScreen> {
  CollectionReference<Map<String, dynamic>> get _staff =>
      _colony('colonyStaff');
  CollectionReference<Map<String, dynamic>> get _runs =>
      _colony('colonyPayrollRuns');
  CollectionReference<Map<String, dynamic>> get _attendance =>
      _colony('workerAttendance');
  CollectionReference<Map<String, dynamic>> get _leaveRequests =>
      _colony('staffLeaveRequests');
  CollectionReference<Map<String, dynamic>> get _workers =>
      _colony('cleanlinessWorkers');
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _colony('colonyExpenses');
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _colony(String name) =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection(name);

  static const Map<String, String> _departments = {
    'security': 'Security',
    'housekeeping': 'Housekeeping',
    'maintenance': 'Maintenance',
    'gardening': 'Gardening',
    'administration': 'Administration',
    'other': 'Other',
  };
  static const Map<String, String> _employmentTypes = {
    'full_time': 'Full-time',
    'part_time': 'Part-time',
    'contract': 'Contract',
    'daily_wage': 'Daily wage',
  };
  static const Map<String, String> _payBases = {
    'monthly': 'Monthly salary',
    'daily': 'Daily rate',
    'hourly': 'Hourly rate',
  };
  static const Map<String, String> _paymentMethods = {
    'upi': 'UPI',
    'bank_transfer': 'Bank transfer',
    'cash': 'Cash',
    'cheque': 'Cheque',
    'other': 'Other',
  };

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  double _num(Object? value) => value is num ? value.toDouble() : 0;
  String _money(Object? value) => '₹${_num(value).toStringAsFixed(2)}';
  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _monthLabel(String key) {
    final bits = key.split('-');
    if (bits.length != 2) return key;
    final month = int.tryParse(bits[1]);
    const names = [
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
    if (month == null || month < 1 || month > 12) return key;
    return '${names[month - 1]} ${bits[0]}';
  }

  String _dateLabel(Object? value) {
    if (value is Timestamp) value = value.toDate();
    if (value is DateTime) {
      return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    }
    if (value is String && value.isNotEmpty) return value;
    return '—';
  }

  double _allowances(Map<String, dynamic> data) =>
      _num(data['hra']) +
      _num(data['transportAllowance']) +
      _num(data['otherAllowance']);

  Map<String, double> _calculate(Map<String, dynamic> d, double divisor) {
    final basis = d['payBasis'] as String? ?? 'monthly';
    final rate = _num(d['baseRate']);
    final allowance = _allowances(d);
    final bonus = _num(d['bonus']);
    final reimbursement = _num(d['reimbursements']);
    final overtime = _num(d['overtimeHours']) * _num(d['overtimeRate']);
    final unpaid = _num(d['unpaidLeaveDays']);
    final paidDays = _num(d['paidDays']) + _num(d['paidLeaveDays']);
    final hours = _num(d['hoursWorked']);
    double base;
    if (basis == 'daily') {
      base = rate * paidDays;
    } else if (basis == 'hourly') {
      base = rate * hours;
    } else {
      final standard = divisor <= 0 ? 30 : divisor;
      base = (rate - ((rate / standard) * unpaid)).clamp(0, rate).toDouble();
    }
    final gross = base + allowance + bonus + reimbursement + overtime;
    final deductions =
        _num(d['defaultDeduction']) +
        _num(d['advanceRecovery']) +
        _num(d['otherDeductions']);
    final net = (gross - deductions).clamp(0, double.infinity).toDouble();
    return {
      'basePay': base,
      'overtimePay': overtime,
      'grossPay': gross,
      'totalDeductions': deductions,
      'netPay': net,
    };
  }

  Widget _panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(15),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppTheme.borderGrey),
    ),
    child: child,
  );

  Widget _metric(String label, String value, IconData icon, {String? note}) =>
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.secondaryNavy, size: 21),
            const SizedBox(height: 10),
            AppText(
              value,
              style: const TextStyle(
                color: AppTheme.navyBlue,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            AppText(
              label,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 3),
              AppText(
                note,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
              ),
            ],
          ],
        ),
      );

  Widget _status(String value) {
    final label = value.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText(
        label.isEmpty
            ? 'unknown'
            : '${label[0].toUpperCase()}${label.substring(1)}',
        style: const TextStyle(
          color: AppTheme.secondaryNavy,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          foregroundColor: AppTheme.navyBlue,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Staff & Payroll',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              AppText(
                widget.colonyName,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: AppTranslations.translate('Add staff member'),
              onPressed: _showStaffForm,
              icon: const Icon(Icons.person_add_alt_1_rounded),
            ),
            const SizedBox(width: 5),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppTheme.navyBlue,
            unselectedLabelColor: AppTheme.textGrey,
            indicatorColor: AppTheme.navyBlue,
            tabs: [
              Tab(
                icon: Icon(Icons.dashboard_outlined),
                text: AppTranslations.translate('Overview'),
              ),
              Tab(
                icon: Icon(Icons.groups_outlined),
                text: AppTranslations.translate('Staff'),
              ),
              Tab(
                icon: Icon(Icons.payments_outlined),
                text: AppTranslations.translate('Payroll'),
              ),
              Tab(
                icon: Icon(Icons.assessment_outlined),
                text: AppTranslations.translate('Reports'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [_overviewTab(), _staffTab(), _payrollTab(), _reportsTab()],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.navyBlue,
          foregroundColor: AppTheme.white,
          onPressed: _createPayrollRun,
          icon: const Icon(Icons.playlist_add_check_rounded),
          label: const AppText('Prepare payroll'),
        ),
      ),
    );
  }

  Widget _overviewTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const AppText(
        'Payroll overview',
        style: TextStyle(
          color: AppTheme.textDark,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      const AppText(
        'Staff strength, monthly payroll exposure and payout progress.',
        style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
      ),
      const SizedBox(height: 14),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _staff.where('status', isEqualTo: 'active').snapshots(),
        builder: (context, staffSnap) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _runs
                  .orderBy('periodKey', descending: true)
                  .limit(6)
                  .snapshots(),
              builder: (context, runSnap) {
                if (staffSnap.hasError || runSnap.hasError) {
                  final errors = <String>[
                    if (staffSnap.hasError) 'Staff: ${staffSnap.error}',
                    if (runSnap.hasError) 'Payroll cycles: ${runSnap.error}',
                  ];
                  return Column(
                    children: [
                      _emptyState(
                        'Payroll overview unavailable',
                        errors.join('\n'),
                        Icons.cloud_off_outlined,
                      ),
                      TextButton(
                        onPressed: () => setState(() {}),
                        child: const AppText('Retry'),
                      ),
                    ],
                  );
                }
                if (!staffSnap.hasData || !runSnap.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: AppTheme.navyBlue,
                      ),
                    ),
                  );
                }
                final staffCount = staffSnap.data!.docs.length;
                final runs = runSnap.data!.docs;
                final latest = runs.isEmpty ? null : runs.first.data();
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _metric(
                            'Active staff',
                            '$staffCount',
                            Icons.groups_outlined,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _metric(
                            'Payroll cycles',
                            '${runs.length}',
                            Icons.calendar_month_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: _metric(
                            'Latest net payroll',
                            latest == null ? '—' : _money(latest['netTotal']),
                            Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _metric(
                            'Outstanding',
                            latest == null
                                ? '—'
                                : _money(latest['balanceTotal']),
                            Icons.pending_actions_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'Latest payroll cycles',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (runSnap.connectionState ==
                              ConnectionState.waiting)
                            const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.navyBlue,
                              ),
                            )
                          else if (runs.isEmpty)
                            const AppText(
                              'No payroll cycle created yet.',
                              style: TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 12,
                              ),
                            )
                          else
                            ...runs.map(
                              (doc) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: AppText(
                                  _monthLabel(doc.id),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                subtitle: AppText(
                                  '${doc.data()['staffCount'] ?? 0} staff · ${_money(doc.data()['netTotal'])} net',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textGrey,
                                  ),
                                ),
                                trailing: _status(
                                  doc.data()['status'] as String? ?? 'draft',
                                ),
                                onTap: () => _openRun(doc.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _panel(
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'Payroll controls',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 7),
                          AppText(
                            'Prepare → review attendance and adjustments → approve → record salary payouts. Every payout creates one matching Staff expense entry.',
                            style: TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
      ),
    ],
  );

  Widget _staffTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _staff.orderBy('fullName').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: AppText('Unable to load staff. ${snapshot.error}'),
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
          'No staff profiles yet',
          'Add housekeeping, security, maintenance and other colony staff to begin payroll.',
          Icons.groups_outlined,
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Staff register',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              AppText(
                '${docs.length} profiles',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...docs.map((doc) {
            final d = doc.data();
            final basis = d['payBasis'] as String? ?? 'monthly';
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _panel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.lightGrey,
                      foregroundColor: AppTheme.navyBlue,
                      child: AppText(
                        (d['fullName'] as String? ?? 'S').trim().isEmpty
                            ? 'S'
                            : (d['fullName'] as String).trim()[0].toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            d['fullName'] as String? ?? 'Unnamed staff',
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AppText(
                            '${d['staffCode'] ?? 'No code'} · ${_departments[d['department']] ?? d['department'] ?? 'Other'}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                          AppText(
                            '${d['designation'] ?? 'Staff'} · ${_employmentTypes[d['employmentType']] ?? '—'}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 5),
                          AppText(
                            '${_payBases[basis] ?? basis}: ${_money(d['baseRate'])} · Allowances ${_money(_allowances(d))}',
                            style: const TextStyle(
                              color: AppTheme.secondaryNavy,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if ((d['linkedWorkerName'] as String? ?? '')
                              .isNotEmpty)
                            AppText(
                              'Attendance linked: ${d['linkedWorkerName']}',
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 10,
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _showSalaryHistory(doc),
                              icon: const Icon(Icons.history_rounded, size: 15),
                              label: const AppText('Compensation history'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _status(d['status'] as String? ?? 'active'),
                        IconButton(
                          tooltip: AppTranslations.translate(
                            'Edit staff profile',
                          ),
                          onPressed: () => _showStaffForm(doc: doc),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppTheme.navyBlue,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    },
  );

  Widget _payrollTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _runs.orderBy('periodKey', descending: true).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: AppText('Unable to load payroll runs. ${snapshot.error}'),
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
          'No payroll runs',
          'Prepare a monthly payroll after adding staff profiles.',
          Icons.payments_outlined,
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const AppText(
            'Payroll register',
            style: TextStyle(
              color: AppTheme.textDark,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...docs.map(
            (doc) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => _openRun(doc.id),
                child: _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              _monthLabel(doc.id),
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          _status(doc.data()['status'] as String? ?? 'draft'),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            child: _smallStat(
                              'Staff',
                              '${doc.data()['staffCount'] ?? 0}',
                            ),
                          ),
                          Expanded(
                            child: _smallStat(
                              'Net payable',
                              _money(doc.data()['netTotal']),
                            ),
                          ),
                          Expanded(
                            child: _smallStat(
                              'Paid',
                              _money(doc.data()['paidTotal']),
                            ),
                          ),
                          Expanded(
                            child: _smallStat(
                              'Balance',
                              _money(doc.data()['balanceTotal']),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      AppText(
                        'Pay date: ${_dateLabel(doc.data()['payDate'])} · Open payroll details',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _reportsTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _runs.orderBy('periodKey', descending: true).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: AppText('Unable to load payroll reports. ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyBlue),
        );
      }
      final docs = snapshot.data!.docs
          .where((d) => d.data()['status'] != 'draft')
          .toList();
      if (docs.isEmpty) {
        return _emptyState(
          'Reports will appear here',
          'Approve a payroll run to create a locked financial snapshot and reporting totals.',
          Icons.assessment_outlined,
        );
      }
      final gross = docs.fold<double>(
        0,
        (s, d) => s + _num(d.data()['grossTotal']),
      );
      final net = docs.fold<double>(
        0,
        (s, d) => s + _num(d.data()['netTotal']),
      );
      final paid = docs.fold<double>(
        0,
        (s, d) => s + _num(d.data()['paidTotal']),
      );
      final balance = docs.fold<double>(
        0,
        (s, d) => s + _num(d.data()['balanceTotal']),
      );
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          const AppText(
            'Payroll reports',
            style: TextStyle(
              color: AppTheme.textDark,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const AppText(
            'Totals across approved payroll cycles currently retained in the register.',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Gross payroll',
                  _money(gross),
                  Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'Net payroll',
                  _money(net),
                  Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Paid',
                  _money(paid),
                  Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'Outstanding',
                  _money(balance),
                  Icons.pending_actions_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...docs.map(
            (doc) => Card(
              color: AppTheme.white,
              elevation: 0,
              child: ListTile(
                title: AppText(
                  _monthLabel(doc.id),
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: AppText(
                  'Gross ${_money(doc.data()['grossTotal'])} · Deductions ${_money(doc.data()['deductionTotal'])}\nNet ${_money(doc.data()['netTotal'])} · Paid ${_money(doc.data()['paidTotal'])}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textGrey,
                  ),
                ),
                isThreeLine: true,
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.navyBlue,
                ),
                onTap: () => _openRun(doc.id),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _smallStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        value,
        style: const TextStyle(
          color: AppTheme.navyBlue,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 2),
      AppText(
        label,
        style: const TextStyle(color: AppTheme.textGrey, fontSize: 9),
      ),
    ],
  );

  Widget _emptyState(String title, String detail, IconData icon) => Center(
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

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool numeric = false,
    int maxLines = 1,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: AppTranslations.translate(label),
      hintText: AppTranslations.translate(hint),
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );

  Future<Map<String, dynamic>?> _pickWorker(BuildContext dialogContext) async =>
      showDialog<Map<String, dynamic>>(
        context: dialogContext,
        builder: (pickerContext) => AlertDialog(
          title: const AppText('Link an attendance worker'),
          content: SizedBox(
            width: 460,
            height: 420,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _workers.where('status', isEqualTo: 'active').snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return AppText('Unable to load workers: ${snap.error}');
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.data!.docs.isEmpty) {
                  return const Center(
                    child: AppText('No active cleanliness workers found.'),
                  );
                }
                return ListView(
                  children: snap.data!.docs
                      .map(
                        (doc) => ListTile(
                          leading: const Icon(Icons.badge_outlined),
                          title: AppText(
                            doc.data()['fullName'] as String? ?? 'Worker',
                          ),
                          subtitle: AppText('Worker ID: ${doc.id}'),
                          onTap: () => Navigator.pop(pickerContext, {
                            'id': doc.id,
                            'name': doc.data()['fullName'] ?? 'Worker',
                          }),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(pickerContext),
              child: const AppText('Cancel'),
            ),
          ],
        ),
      );

  void _showSalaryHistory(DocumentSnapshot<Map<String, dynamic>> staffDoc) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(
          'Compensation history · ${staffDoc.data()?['fullName'] ?? 'Staff'}',
        ),
        content: SizedBox(
          width: 520,
          height: 420,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: staffDoc.reference
                .collection('salaryHistory')
                .orderBy('recordedAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return AppText('Unable to load history: ${snap.error}');
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.data!.docs.isEmpty) {
                return const Center(
                  child: AppText('No compensation history recorded.'),
                );
              }
              return ListView.separated(
                itemCount: snap.data!.docs.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final d = snap.data!.docs[index].data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: AppText(
                      '${_money(d['newBaseRate'])} · ${_payBases[d['newPayBasis']] ?? d['newPayBasis'] ?? 'Pay rate'}',
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: AppText(
                      'Effective ${d['effectiveDate'] ?? '—'}\nPrevious: ${_money(d['previousBaseRate'])} · ${d['reason'] ?? 'Compensation update'}',
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 11,
                      ),
                    ),
                    isThreeLine: true,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStaffForm({
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final old = doc?.data() ?? <String, dynamic>{};
    final name = TextEditingController(text: old['fullName'] as String? ?? '');
    final code = TextEditingController(
      text:
          old['staffCode'] as String? ??
          'STF-${DateTime.now().microsecondsSinceEpoch}',
    );
    final phone = TextEditingController(text: old['phone'] as String? ?? '');
    final designation = TextEditingController(
      text: old['designation'] as String? ?? '',
    );
    final rate = TextEditingController(
      text: _num(old['baseRate']).toStringAsFixed(2),
    );
    final hra = TextEditingController(
      text: _num(old['hra']).toStringAsFixed(2),
    );
    final travel = TextEditingController(
      text: _num(old['transportAllowance']).toStringAsFixed(2),
    );
    final otherAllowance = TextEditingController(
      text: _num(old['otherAllowance']).toStringAsFixed(2),
    );
    final defaultDeduction = TextEditingController(
      text: _num(old['defaultDeduction']).toStringAsFixed(2),
    );
    final joinDate = TextEditingController(
      text: old['joinDate'] as String? ?? _dateKey(DateTime.now()),
    );
    var department = old['department'] as String? ?? 'housekeeping';
    var employment = old['employmentType'] as String? ?? 'full_time';
    var basis = old['payBasis'] as String? ?? 'monthly';
    var status = old['status'] as String? ?? 'active';
    String? linkedWorkerId = old['linkedWorkerId'] as String?;
    String? linkedWorkerName = old['linkedWorkerName'] as String?;
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText(
            doc == null ? 'Add staff profile' : 'Edit staff profile',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(name, 'Full name'),
                  const SizedBox(height: 9),
                  _field(code, 'Staff / employee code'),
                  const SizedBox(height: 9),
                  _field(phone, 'Phone number', hint: 'Optional'),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    initialValue: department,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Department'),
                      border: OutlineInputBorder(),
                    ),
                    items: _departments.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: AppText(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => department = v ?? department),
                  ),
                  const SizedBox(height: 9),
                  _field(designation, 'Designation / role'),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    initialValue: employment,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Employment type'),
                      border: OutlineInputBorder(),
                    ),
                    items: _employmentTypes.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: AppText(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => employment = v ?? employment),
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    initialValue: basis,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Pay basis'),
                      border: OutlineInputBorder(),
                    ),
                    items: _payBases.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: AppText(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => basis = v ?? basis),
                  ),
                  const SizedBox(height: 9),
                  _field(
                    rate,
                    basis == 'monthly'
                        ? 'Monthly base salary (₹)'
                        : basis == 'daily'
                        ? 'Rate per day (₹)'
                        : 'Rate per hour (₹)',
                    numeric: true,
                  ),
                  const SizedBox(height: 9),
                  _field(
                    hra,
                    'House allowance / HRA per payroll period (₹)',
                    numeric: true,
                  ),
                  const SizedBox(height: 9),
                  _field(
                    travel,
                    'Transport allowance per payroll period (₹)',
                    numeric: true,
                  ),
                  const SizedBox(height: 9),
                  _field(
                    otherAllowance,
                    'Other fixed allowance per payroll period (₹)',
                    numeric: true,
                  ),
                  const SizedBox(height: 9),
                  _field(
                    defaultDeduction,
                    'Default deduction per payroll period (₹)',
                    numeric: true,
                  ),
                  const SizedBox(height: 9),
                  _field(joinDate, 'Joining date (YYYY-MM-DD)'),
                  const SizedBox(height: 11),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'Attendance integration',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 5),
                        AppText(
                          linkedWorkerId == null
                              ? 'No worker account linked. Attendance will not be imported.'
                              : '$linkedWorkerName · $linkedWorkerId',
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 11,
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final selected = await _pickWorker(
                                  dialogContext,
                                );
                                if (selected != null) {
                                  setDialogState(() {
                                    linkedWorkerId = selected['id'] as String;
                                    linkedWorkerName =
                                        selected['name'] as String;
                                  });
                                }
                              },
                              icon: const Icon(Icons.link),
                              label: const AppText('Link worker'),
                            ),
                            if (linkedWorkerId != null)
                              TextButton(
                                onPressed: () => setDialogState(() {
                                  linkedWorkerId = null;
                                  linkedWorkerName = null;
                                }),
                                child: const AppText('Remove link'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Profile status'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'active',
                        child: AppText('Active'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: AppText('Inactive'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => status = v ?? status),
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'Do not enter bank account numbers, Aadhaar or PAN here. This module records salary calculations and payment references only.',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final amountFields = [
                        rate,
                        hra,
                        travel,
                        otherAllowance,
                        defaultDeduction,
                      ];
                      final amounts = amountFields
                          .map((c) => double.tryParse(c.text.trim()))
                          .toList();
                      if (name.text.trim().length < 2 ||
                          name.text.trim().length > 120 ||
                          code.text.trim().isEmpty ||
                          code.text.trim().length > 40 ||
                          phone.text.trim().length > 25 ||
                          designation.text.trim().length > 80 ||
                          amounts.any((v) => v == null || v < 0) ||
                          (amounts.first ?? 0) <= 0 ||
                          !RegExp(r'^\d{4}-\d{2}-\d{2}$')
                              .hasMatch(joinDate.text.trim())) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: AppText(
                              'Enter a name, staff code, valid date and non-negative pay amounts. Base rate must be greater than zero.',
                            ),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final duplicateCodes = await _staff
                            .where('staffCode', isEqualTo: code.text.trim())
                            .get();
                        if (duplicateCodes.docs.any(
                          (item) => item.id != doc?.id,
                        )) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: AppText(
                                'That staff code is already in use. Choose a unique code.',
                              ),
                            ),
                          );
                          return;
                        }
                        final target = doc?.reference ?? _staff.doc();
                        final now = FieldValue.serverTimestamp();
                        final record = <String, dynamic>{
                          'staffCode': code.text.trim(),
                          'fullName': name.text.trim(),
                          'phone': phone.text.trim(),
                          'department': department,
                          'designation': designation.text.trim(),
                          'employmentType': employment,
                          'payBasis': basis,
                          'baseRate': amounts[0],
                          'hra': amounts[1],
                          'transportAllowance': amounts[2],
                          'otherAllowance': amounts[3],
                          'defaultDeduction': amounts[4],
                          'joinDate': joinDate.text.trim(),
                          'linkedWorkerId': linkedWorkerId ?? '',
                          'linkedWorkerName': linkedWorkerName ?? '',
                          'status': status,
                          'updatedAt': now,
                          'updatedBy': _uid,
                        };
                        final batch = FirebaseFirestore.instance.batch();
                        if (doc == null) {
                          record['createdAt'] = now;
                          record['createdBy'] = _uid;
                          batch.set(target, record);
                          batch.set(target.collection('salaryHistory').doc(), {
                            'effectiveDate': joinDate.text.trim(),
                            'previousPayBasis': '',
                            'newPayBasis': basis,
                            'previousBaseRate': 0.0,
                            'newBaseRate': amounts[0],
                            'previousHra': 0.0,
                            'newHra': amounts[1],
                            'previousTransportAllowance': 0.0,
                            'newTransportAllowance': amounts[2],
                            'previousOtherAllowance': 0.0,
                            'newOtherAllowance': amounts[3],
                            'previousDefaultDeduction': 0.0,
                            'newDefaultDeduction': amounts[4],
                            'reason': 'Initial compensation profile',
                            'recordedBy': _uid,
                            'recordedAt': now,
                          });
                        } else {
                          final changed =
                              _num(old['baseRate']) != amounts[0] ||
                              (old['payBasis'] != basis) ||
                              _num(old['hra']) != amounts[1] ||
                              _num(old['transportAllowance']) != amounts[2] ||
                              _num(old['otherAllowance']) != amounts[3] ||
                              _num(old['defaultDeduction']) != amounts[4];
                          batch.update(target, record);
                          if (changed) {
                            batch.set(
                              target.collection('salaryHistory').doc(),
                              {
                                'effectiveDate': _dateKey(DateTime.now()),
                                'previousPayBasis':
                                    old['payBasis'] ?? 'monthly',
                                'newPayBasis': basis,
                                'previousBaseRate': _num(old['baseRate']),
                                'newBaseRate': amounts[0],
                                'previousHra': _num(old['hra']),
                                'newHra': amounts[1],
                                'previousTransportAllowance': _num(
                                  old['transportAllowance'],
                                ),
                                'newTransportAllowance': amounts[2],
                                'previousOtherAllowance': _num(
                                  old['otherAllowance'],
                                ),
                                'newOtherAllowance': amounts[3],
                                'previousDefaultDeduction': _num(
                                  old['defaultDeduction'],
                                ),
                                'newDefaultDeduction': amounts[4],
                                'reason':
                                    'Compensation updated from Staff & Payroll',
                                'recordedBy': _uid,
                                'recordedAt': now,
                              },
                            );
                          }
                        }
                        await batch.commit();
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                        _message(
                          doc == null ? 'Staff profile created.' : 'Staff profile updated. Previous payroll snapshots remain unchanged.',
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: AppText(
                              'Could not save staff profile: $error',
                            ),
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppText('Save profile'),
            ),
          ],
        ),
      ),
    );
    for (final c in [
      name,
      code,
      phone,
      designation,
      rate,
      hra,
      travel,
      otherAllowance,
      defaultDeduction,
      joinDate,
    ]) {
      c.dispose();
    }
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _createPayrollRun() async {
    final now = DateTime.now();
    final month = TextEditingController(text: _monthKey(now));
    final payDate = TextEditingController(
      text: _dateKey(DateTime(now.year, now.month + 1, 0)),
    );
    final divisor = TextEditingController(text: '30');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Prepare monthly payroll'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(month, 'Payroll month (YYYY-MM)'),
              const SizedBox(height: 9),
              _field(payDate, 'Planned pay date (YYYY-MM-DD)'),
              const SizedBox(height: 9),
              _field(
                divisor,
                'Monthly salary proration divisor (days)',
                numeric: true,
              ),
              const SizedBox(height: 8),
              const AppText(
                'The divisor is used only to calculate unpaid-leave proration for monthly-paid staff. It defaults to 30 calendar days and can be set to your colony policy. It is not a statutory payroll setting.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
              const SizedBox(height: 7),
              const AppText(
                'Attendance is imported as a review reference. Missing check-ins are not automatically treated as unpaid absence.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
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
            child: const AppText('Prepare draft'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      month.dispose();
      payDate.dispose();
      divisor.dispose();
      return;
    }
    final monthKey = month.text.trim();
    final d = double.tryParse(divisor.text.trim());
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(monthKey) ||
        d == null ||
        d <= 0 ||
        d > 31 ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(payDate.text.trim())) {
      _message('Enter a valid month, pay date and divisor (1–31).');
      month.dispose();
      payDate.dispose();
      divisor.dispose();
      return;
    }
    final parts = monthKey.split('-').map(int.parse).toList();
    final periodStart = DateTime(parts[0], parts[1], 1);
    final periodEnd = DateTime(parts[0], parts[1] + 1, 0);
    final runRef = _runs.doc(monthKey);
    try {
      final existing = await runRef.get();
      if (existing.exists) {
        _message(
          'A payroll run already exists for ${_monthLabel(monthKey)}. Open it from Payroll.',
        );
        return;
      }
      final staffSnap = await _staff.where('status', isEqualTo: 'active').get();
      if (staffSnap.docs.isEmpty) {
        _message(
          'Add at least one active staff profile before preparing payroll.',
        );
        return;
      }
      if (staffSnap.docs.length > 400) {
        _message(
          'This payroll run supports up to 400 active staff profiles. Split the workforce or extend the batch workflow before proceeding.',
        );
        return;
      }
      final attendanceSnap = await _attendance
          .where(
            'attendanceDateKey',
            isGreaterThanOrEqualTo: _dateKey(periodStart),
          )
          .where('attendanceDateKey', isLessThanOrEqualTo: _dateKey(periodEnd))
          .get();
      final attendanceByWorker = <String, Set<String>>{};
      for (final record in attendanceSnap.docs) {
        final x = record.data();
        final workerId = x['workerId'] as String? ?? '';
        final dateKey = x['attendanceDateKey'] as String? ?? '';
        if (workerId.isNotEmpty &&
            dateKey.isNotEmpty &&
            x['checkInAt'] != null) {
          attendanceByWorker
              .putIfAbsent(workerId, () => <String>{})
              .add(dateKey);
        }
      }
      final leaveSnap = await _leaveRequests
          .where('status', isEqualTo: 'approved')
          .get();
      final leaveDaysByWorker = <String, Map<String, Set<String>>>{};
      final monthStartKey = _dateKey(periodStart);
      final monthEndKey = _dateKey(periodEnd);
      for (final leaveDoc in leaveSnap.docs) {
        final leave = leaveDoc.data();
        final workerId = leave['workerId'] as String? ?? '';
        final treatment = leave['payTreatment'] as String? ?? '';
        final from = DateTime.tryParse(leave['startDateKey'] as String? ?? '');
        final through = DateTime.tryParse(leave['endDateKey'] as String? ?? '');
        if (workerId.isEmpty ||
            from == null ||
            through == null ||
            !['paid', 'unpaid'].contains(treatment)) {
          continue;
        }
        final rangeStart = from.isBefore(periodStart) ? periodStart : from;
        final rangeEnd = through.isAfter(periodEnd) ? periodEnd : through;
        if (rangeEnd.isBefore(rangeStart)) {
          continue;
        }
        final buckets = leaveDaysByWorker.putIfAbsent(
          workerId,
          () => <String, Set<String>>{'paid': <String>{}, 'unpaid': <String>{}},
        );
        for (
          var day = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
          !day.isAfter(rangeEnd);
          day = day.add(const Duration(days: 1))
        ) {
          final key = _dateKey(day);
          if (key.compareTo(monthStartKey) < 0 ||
              key.compareTo(monthEndKey) > 0) {
            continue;
          }
          // A recorded check-in takes precedence over a leave request for the same day.
          if (attendanceByWorker[workerId]?.contains(key) == true) {
            continue;
          }
          buckets[treatment]!.add(key);
        }
      }

      final runData = <String, dynamic>{
        'periodKey': monthKey,
        'periodStart': _dateKey(periodStart),
        'periodEnd': _dateKey(periodEnd),
        'payDate': payDate.text.trim(),
        'monthlyProrationDivisor': d,
        'status': 'draft',
        'staffCount': staffSnap.docs.length,
        'grossTotal': 0.0,
        'deductionTotal': 0.0,
        'netTotal': 0.0,
        'paidTotal': 0.0,
        'balanceTotal': 0.0,
        'createdBy': _uid,
        'createdByName': widget.adminName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final entryWrites =
          <
            MapEntry<
              DocumentReference<Map<String, dynamic>>,
              Map<String, dynamic>
            >
          >[];
      for (final staffDoc in staffSnap.docs) {
        final s = staffDoc.data();
        final basis = s['payBasis'] as String? ?? 'monthly';
        final linkedId = s['linkedWorkerId'] as String? ?? '';
        final attendanceDays = attendanceByWorker[linkedId]?.length ?? 0;
        final approvedLeaveDays =
            leaveDaysByWorker[linkedId] ??
            <String, Set<String>>{'paid': <String>{}, 'unpaid': <String>{}};
        final importedPaidLeaveDays = approvedLeaveDays['paid']!.length;
        final importedUnpaidLeaveDays = approvedLeaveDays['unpaid']!.length;
        final initial = <String, dynamic>{
          'staffId': staffDoc.id,
          'staffCode': s['staffCode'] ?? '',
          'staffName': s['fullName'] ?? 'Staff',
          'phoneSnapshot': s['phone'] ?? '',
          'department': s['department'] ?? 'other',
          'designation': s['designation'] ?? '',
          'employmentType': s['employmentType'] ?? 'full_time',
          'payBasis': basis,
          'baseRate': _num(s['baseRate']),
          'hra': _num(s['hra']),
          'transportAllowance': _num(s['transportAllowance']),
          'otherAllowance': _num(s['otherAllowance']),
          'defaultDeduction': _num(s['defaultDeduction']),
          'linkedWorkerId': linkedId,
          'linkedWorkerName': s['linkedWorkerName'] ?? '',
          'attendanceDays': attendanceDays,
          'paidDays': basis == 'daily'
              ? attendanceDays.toDouble()
              : (basis == 'monthly' ? d : 0.0),
          'paidLeaveDays': importedPaidLeaveDays.toDouble(),
          'unpaidLeaveDays': importedUnpaidLeaveDays.toDouble(),
          'approvedPaidLeaveDays': importedPaidLeaveDays,
          'approvedUnpaidLeaveDays': importedUnpaidLeaveDays,
          'hoursWorked': 0.0,

          'overtimeHours': 0.0,
          'overtimeRate': 0.0,
          'bonus': 0.0,
          'reimbursements': 0.0,
          'advanceRecovery': 0.0,
          'otherDeductions': 0.0,
          'amountPaid': 0.0,
          'status': 'draft',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final calc = _calculate(initial, d);
        initial.addAll(calc);
        initial['balance'] = calc['netPay'];
        entryWrites.add(
          MapEntry(runRef.collection('entries').doc(staffDoc.id), initial),
        );
      }
      // The deterministic YYYY-MM run ID is protected by a transaction so two
      // Admins cannot overwrite each other's draft for the same payroll month.
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final existingRun = await transaction.get(runRef);
        if (existingRun.exists) {
          throw StateError(
            'A payroll run for $monthKey was created by another Admin. Open the existing run instead.',
          );
        }
        transaction.set(runRef, runData);
        for (final write in entryWrites) {
          transaction.set(write.key, write.value);
        }
      });
      _message(
        'Draft payroll prepared for ${_monthLabel(monthKey)}. Review each staff entry before approval.',
      );
    } on FirebaseException catch (error) {
      debugPrint('Payroll preparation failed: ${error.code} ${error.message}');
      _message('Could not prepare payroll: ${error.message ?? error.code}');
    } catch (error) {
      _message('Could not prepare payroll: $error');
    } finally {
      month.dispose();
      payDate.dispose();
      divisor.dispose();
    }
  }

  Future<void> _approveRun(String runId, Map<String, dynamic> run) async {
    if (run['status'] != 'draft') {
      _message('Only a draft payroll can be approved.');
      return;
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('approveColonyPayrollRun');

      await callable.call(<String, dynamic>{
        'colonyId': widget.colonyId,
        'runId': runId,
      });

      _message(
        'Payroll for ${_monthLabel(runId)} approved and locked. '
        'You can now record individual salary payouts.',
      );
    } on FirebaseFunctionsException catch (error) {
      _message('Could not approve payroll: ${error.message ?? error.code}');
    } catch (error) {
      _message('Could not approve payroll: $error');
    }
  }

  Future<void> _editEntry(
    String runId,
    Map<String, dynamic> run,
    DocumentSnapshot<Map<String, dynamic>> entry,
  ) async {
    if (run['status'] != 'draft') {
      _message('Approved payroll entries are locked.');
      return;
    }
    final data = entry.data() ?? <String, dynamic>{};
    final paidDays = TextEditingController(
      text: _num(data['paidDays']).toStringAsFixed(2),
    );
    final paidLeave = TextEditingController(
      text: _num(data['paidLeaveDays']).toStringAsFixed(2),
    );
    final unpaidLeave = TextEditingController(
      text: _num(data['unpaidLeaveDays']).toStringAsFixed(2),
    );
    final hours = TextEditingController(
      text: _num(data['hoursWorked']).toStringAsFixed(2),
    );
    final overtimeHours = TextEditingController(
      text: _num(data['overtimeHours']).toStringAsFixed(2),
    );
    final overtimeRate = TextEditingController(
      text: _num(data['overtimeRate']).toStringAsFixed(2),
    );
    final bonus = TextEditingController(
      text: _num(data['bonus']).toStringAsFixed(2),
    );
    final reimbursements = TextEditingController(
      text: _num(data['reimbursements']).toStringAsFixed(2),
    );
    final advance = TextEditingController(
      text: _num(data['advanceRecovery']).toStringAsFixed(2),
    );
    final other = TextEditingController(
      text: _num(data['otherDeductions']).toStringAsFixed(2),
    );
    final ctrls = [
      paidDays,
      paidLeave,
      unpaidLeave,
      hours,
      overtimeHours,
      overtimeRate,
      bonus,
      reimbursements,
      advance,
      other,
    ];
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('Payroll adjustment · ${data['staffName'] ?? 'Staff'}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Attendance reference: ${data['attendanceDays'] ?? 0} recorded check-in days',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const AppText(
                        'Attendance is a reference only. Confirm approved leave and payable days before saving.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                if (data['payBasis'] == 'daily') ...[
                  _field(
                    paidDays,
                    'Payable days (excluding paid leave)',
                    numeric: true,
                  ),
                  const SizedBox(height: 8),
                  _field(paidLeave, 'Approved paid leave days', numeric: true),
                ] else if (data['payBasis'] == 'hourly')
                  _field(hours, 'Approved hours worked', numeric: true)
                else
                  _field(
                    unpaidLeave,
                    'Unpaid leave days (monthly salary proration)',
                    numeric: true,
                  ),
                const SizedBox(height: 8),
                _field(overtimeHours, 'Approved overtime hours', numeric: true),
                const SizedBox(height: 8),
                _field(
                  overtimeRate,
                  'Overtime rate per hour (₹)',
                  numeric: true,
                ),
                const SizedBox(height: 8),
                _field(
                  bonus,
                  'Bonus / incentive for this period (₹)',
                  numeric: true,
                ),
                const SizedBox(height: 8),
                _field(
                  reimbursements,
                  'Approved reimbursements (₹)',
                  numeric: true,
                ),
                const SizedBox(height: 8),
                _field(advance, 'Advance / loan recovery (₹)', numeric: true),
                const SizedBox(height: 8),
                _field(other, 'Other deductions (₹)', numeric: true),
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
            child: const AppText('Save adjustments'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      for (final c in ctrls) {
        c.dispose();
      }
      return;
    }
    final parsed = ctrls.map((c) => double.tryParse(c.text.trim())).toList();
    if (parsed.any((v) => v == null || v < 0)) {
      _message('All adjustment values must be valid non-negative numbers.');
      for (final c in ctrls) {
        c.dispose();
      }
      return;
    }
    final updated = <String, dynamic>{
      'paidDays': parsed[0],
      'paidLeaveDays': parsed[1],
      'unpaidLeaveDays': parsed[2],
      'hoursWorked': parsed[3],
      'overtimeHours': parsed[4],
      'overtimeRate': parsed[5],
      'bonus': parsed[6],
      'reimbursements': parsed[7],
      'advanceRecovery': parsed[8],
      'otherDeductions': parsed[9],
    };
    final runRef = _runs.doc(runId);
    var savedNetPay = 0.0;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Re-read both records after the adjustment dialog has closed.
        // This prevents a stale draft screen from editing approved payroll.
        final freshRunSnapshot = await transaction.get(runRef);
        final freshEntrySnapshot = await transaction.get(entry.reference);

        if (!freshRunSnapshot.exists || !freshEntrySnapshot.exists) {
          throw StateError('Payroll run or staff entry no longer exists.');
        }

        final freshRun = freshRunSnapshot.data()!;
        final freshEntry = freshEntrySnapshot.data()!;

        if (freshRun['status'] != 'draft' || freshEntry['status'] != 'draft') {
          throw StateError(
            'Payroll was approved while this adjustment was open. '
            'The approved entry remains locked; refresh the payroll screen.',
          );
        }

        // Recalculate using the latest entry and latest run divisor.
        final calc = _calculate({
          ...freshEntry,
          ...updated,
        }, _num(freshRun['monthlyProrationDivisor']));
        savedNetPay = calc['netPay']!;

        transaction.update(entry.reference, {
          ...updated,
          ...calc,
          'balance': calc['netPay'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _message(
        'Payroll adjustments saved. Net payable: ${_money(savedNetPay)}.',
      );
    } catch (error) {
      _message('Could not save adjustments: $error');
    }
    for (final c in ctrls) {
      c.dispose();
    }
  }

  Future<void> _recordPayment(
    String runId,
    Map<String, dynamic> run,
    DocumentSnapshot<Map<String, dynamic>> entry,
  ) async {
    final data = entry.data() ?? <String, dynamic>{};
    if (!['approved', 'partially_paid'].contains(run['status'])) {
      _message('Approve the payroll run before recording payouts.');
      return;
    }
    final balance = _num(data['balance']);
    if (balance <= 0) {
      _message('This salary entry has no outstanding balance.');
      return;
    }
    final amount = TextEditingController(text: balance.toStringAsFixed(2));
    final reference = TextEditingController();
    final notes = TextEditingController();
    var method = 'upi';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText(
            'Record salary payout · ${data['staffName'] ?? 'Staff'}',
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppText(
                    'Outstanding: ${_money(balance)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                _field(amount, 'Amount paid now (₹)', numeric: true),
                const SizedBox(height: 9),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Payment method'),
                    border: OutlineInputBorder(),
                  ),
                  items: _paymentMethods.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: AppText(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => method = v ?? method),
                ),
                const SizedBox(height: 9),
                _field(
                  reference,
                  'Transaction / cheque reference',
                  hint: 'Optional',
                ),
                const SizedBox(height: 9),
                _field(notes, 'Payment notes', hint: 'Optional', maxLines: 2),
                const SizedBox(height: 7),
                const AppText(
                  'This records a payment; it does not initiate a UPI or bank transfer.',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 10),
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
    if (accepted != true) {
      amount.dispose();
      reference.dispose();
      notes.dispose();
      return;
    }
    final paymentAmount = double.tryParse(amount.text.trim());
    if (paymentAmount == null ||
        paymentAmount <= 0 ||
        paymentAmount > balance ||
        paymentAmount > 1000000000 ||
        reference.text.trim().length > 100 ||
        notes.text.trim().length > 500) {
      _message(
        'Enter a positive payment not exceeding the outstanding balance. Reference (max 100) and notes (max 500) are allowed.',
      );
      amount.dispose();
      reference.dispose();
      notes.dispose();
      return;
    }
    final paymentRef = entry.reference.collection('payments').doc();
    final expenseRef = _expenses.doc(
      'payroll_${runId}_${entry.id}_${paymentRef.id}',
    );
    final runRef = _runs.doc(runId);
    final expenseNotesRaw =
        'Payroll $runId · staff ${data['staffCode'] ?? entry.id} · ${notes.text.trim()}';
    final expenseNotes = expenseNotesRaw.length > 1200
        ? expenseNotesRaw.substring(0, 1200)
        : expenseNotesRaw;
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshEntry = await transaction.get(entry.reference);
        final freshRun = await transaction.get(runRef);
        if (!freshEntry.exists || !freshRun.exists) {
          throw StateError('Payroll record no longer exists.');
        }
        final e = freshEntry.data() ?? <String, dynamic>{};
        final r = freshRun.data() ?? <String, dynamic>{};
        if (!['approved', 'partially_paid'].contains(r['status'])) {
          throw StateError('Payroll is not open for payout.');
        }
        final outstanding = _num(e['balance']);
        if (paymentAmount > outstanding || outstanding <= 0) {
          throw StateError(
            'Payment exceeds the latest outstanding balance. Refresh and try again.',
          );
        }
        final paidNow = _num(e['amountPaid']) + paymentAmount;
        final remaining = (outstanding - paymentAmount)
            .clamp(0, double.infinity)
            .toDouble();
        final entryStatus = remaining <= 0.005 ? 'paid' : 'partially_paid';
        final runPaid = _num(r['paidTotal']) + paymentAmount;
        final runBalance = (_num(r['netTotal']) - runPaid)
            .clamp(0, double.infinity)
            .toDouble();
        transaction.update(entry.reference, {
          'amountPaid': paidNow,
          'balance': remaining,
          'status': entryStatus,
          'lastPaidAt': FieldValue.serverTimestamp(),
          'lastPaymentId': paymentRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(runRef, {
          'paidTotal': runPaid,
          'balanceTotal': runBalance,
          'status': runBalance <= 0.005 ? 'paid' : 'partially_paid',
          'lastPaymentId': paymentRef.id,
          'lastPaymentStaffEntryId': entry.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(paymentRef, {
          'runId': runId,
          'staffEntryId': entry.id,
          'expenseId': expenseRef.id,
          'amount': paymentAmount,
          'paymentMethod': method,
          'reference': reference.text.trim(),
          'notes': notes.text.trim(),
          'recordedBy': _uid,
          'recordedByName': widget.adminName,
          'recordedAt': FieldValue.serverTimestamp(),
        });
        final today = DateTime.now();
        final title =
            'Salary payout - ${(e['staffName'] as String? ?? 'Staff')} - $runId';
        transaction.set(expenseRef, {
          'payrollRunId': runId,
          'payrollStaffEntryId': entry.id,
          'payrollPaymentId': paymentRef.id,
          'title': title.length > 120 ? title.substring(0, 120) : title,
          'category': 'staff',
          'amount': paymentAmount,
          'amountPaid': paymentAmount,
          'paymentStatus': 'paid',
          'paymentMethod': method,
          'expenseDate': Timestamp.fromDate(today),
          'monthKey': _monthKey(today),
          'payeeName': e['staffName'] ?? 'Staff',
          'vendorName': '',
          'assetName': '',
          'reference': reference.text.trim(),
          'notes': expenseNotes,
          'createdBy': _uid,
          'createdByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      _message(
        'Salary payout recorded. One matching Staff expense was added to Colony Budget & Expenses.',
      );
    } catch (error) {
      _message('Could not record salary payout: $error');
    }
    amount.dispose();
    reference.dispose();
    notes.dispose();
  }

  void _openRun(String runId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 760,
          height: MediaQuery.of(dialogContext).size.height * 0.86,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _runs.doc(runId).snapshots(),
            builder: (context, runSnap) {
              if (runSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 38),
                        const SizedBox(height: 8),
                        const AppText('Unable to load this payroll run.'),
                        const SizedBox(height: 6),
                        AppText(
                          '${runSnap.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const AppText(
                          'Close this window and reopen the payroll run to retry.',
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!runSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.navyBlue),
                );
              }
              if (!runSnap.data!.exists) {
                return const Center(child: AppText('Payroll run not found.'));
              }
              final run = runSnap.data!.data()!;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                'Payroll · ${_monthLabel(runId)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                              AppText(
                                'Pay date ${_dateLabel(run['payDate'])} · ${run['staffCount'] ?? 0} staff',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _status(run['status'] as String? ?? 'draft'),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _smallStat('Gross', _money(run['grossTotal'])),
                        ),
                        Expanded(
                          child: _smallStat(
                            'Deductions',
                            _money(run['deductionTotal']),
                          ),
                        ),
                        Expanded(
                          child: _smallStat('Net', _money(run['netTotal'])),
                        ),
                        Expanded(
                          child: _smallStat('Paid', _money(run['paidTotal'])),
                        ),
                        Expanded(
                          child: _smallStat(
                            'Balance',
                            _money(run['balanceTotal']),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 18),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _runs
                          .doc(runId)
                          .collection('entries')
                          .orderBy('staffName')
                          .snapshots(),
                      builder: (context, entriesSnap) {
                        if (entriesSnap.hasError) {
                          return Center(
                            child: AppText(
                              'Unable to load payroll entries: ${entriesSnap.error}',
                            ),
                          );
                        }
                        if (!entriesSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.navyBlue,
                            ),
                          );
                        }
                        final entries = entriesSnap.data!.docs;
                        if (entries.isEmpty) {
                          return const Center(
                            child: AppText('No payroll entries.'),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 7),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final e = entry.data();
                            return _panel(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AppText(
                                          e['staffName'] as String? ?? 'Staff',
                                          style: const TextStyle(
                                            color: AppTheme.textDark,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      _status(
                                        e['status'] as String? ?? 'draft',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  AppText(
                                    '${e['staffCode'] ?? entry.id} · ${_departments[e['department']] ?? e['department'] ?? 'Other'} · ${_payBases[e['payBasis']] ?? e['payBasis']}',
                                    style: const TextStyle(
                                      color: AppTheme.textGrey,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 5,
                                    children: [
                                      AppText(
                                        'Attendance: ${e['attendanceDays'] ?? 0} days · Paid leave: ${e['approvedPaidLeaveDays'] ?? 0} · Unpaid leave: ${e['approvedUnpaidLeaveDays'] ?? 0}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textGrey,
                                        ),
                                      ),
                                      AppText(
                                        'Gross: ${_money(e['grossPay'])}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textGrey,
                                        ),
                                      ),
                                      AppText(
                                        'Deductions: ${_money(e['totalDeductions'])}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textGrey,
                                        ),
                                      ),
                                      AppText(
                                        'Net: ${_money(e['netPay'])}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.navyBlue,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      AppText(
                                        'Paid: ${_money(e['amountPaid'])}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textGrey,
                                        ),
                                      ),
                                      AppText(
                                        'Balance: ${_money(e['balance'])}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 6,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _copyPayslip(runId, e),
                                        icon: const Icon(
                                          Icons.copy_outlined,
                                          size: 15,
                                        ),
                                        label: const AppText('Copy payslip'),
                                      ),
                                      if (run['status'] == 'draft')
                                        TextButton.icon(
                                          onPressed: () =>
                                              _editEntry(runId, run, entry),
                                          icon: const Icon(
                                            Icons.tune,
                                            size: 16,
                                          ),
                                          label: const AppText(
                                            'Adjust payroll',
                                          ),
                                        ),
                                      if ([
                                            'approved',
                                            'partially_paid',
                                          ].contains(run['status']) &&
                                          _num(e['balance']) > 0)
                                        FilledButton.tonalIcon(
                                          onPressed: () =>
                                              _recordPayment(runId, run, entry),
                                          icon: const Icon(
                                            Icons.payments_outlined,
                                            size: 16,
                                          ),
                                          label: const AppText('Record payout'),
                                        ),
                                    ],
                                  ),
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: const AppText(
                                      'Pay breakdown & payment history',
                                      style: TextStyle(
                                        color: AppTheme.secondaryNavy,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Wrap(
                                          spacing: 12,
                                          runSpacing: 5,
                                          children: [
                                            AppText(
                                              'Base: ${_money(e['basePay'])}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                            AppText(
                                              'HRA: ${_money(e['hra'])}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                            AppText(
                                              'Transport: ${_money(e['transportAllowance'])}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                            AppText(
                                              'Other allowance: ${_money(e['otherAllowance'])}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                            AppText(
                                              'Overtime: ${_money(e['overtimePay'])}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                            AppText(
                                              'Bonus: ${_money(e['bonus'])}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                            AppText(
                                              'Reimbursements: ${_money(e['reimbursements'])}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                            AppText(
                                              'Default deduction: ${_money(e['defaultDeduction'])}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                            AppText(
                                              'Advance recovery: ${_money(e['advanceRecovery'])}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                            AppText(
                                              'Other deductions: ${_money(e['otherDeductions'])}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>
                                      >(
                                        stream: entry.reference
                                            .collection('payments')
                                            .orderBy(
                                              'recordedAt',
                                              descending: true,
                                            )
                                            .snapshots(),
                                        builder: (context, paymentSnap) {
                                          if (paymentSnap.hasError) {
                                            return AppText(
                                              'Unable to load payment history: ${paymentSnap.error}',
                                            );
                                          }
                                          if (!paymentSnap.hasData) {
                                            return const Padding(
                                              padding: EdgeInsets.all(8),
                                              child: LinearProgressIndicator(),
                                            );
                                          }
                                          if (paymentSnap.data!.docs.isEmpty) {
                                            return const Align(
                                              alignment: Alignment.centerLeft,
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                child: AppText(
                                                  'No salary payouts recorded yet.',
                                                  style: TextStyle(
                                                    color: AppTheme.textGrey,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          return Column(
                                            children: paymentSnap.data!.docs.map((
                                              payment,
                                            ) {
                                              final p = payment.data();
                                              return ListTile(
                                                dense: true,
                                                contentPadding: EdgeInsets.zero,
                                                leading: const Icon(
                                                  Icons.receipt_long_outlined,
                                                  size: 17,
                                                  color: AppTheme.navyBlue,
                                                ),
                                                title: AppText(
                                                  '${_money(p['amount'])} · ${_paymentMethods[p['paymentMethod']] ?? p['paymentMethod'] ?? 'Payment'}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.textDark,
                                                  ),
                                                ),
                                                subtitle: AppText(
                                                  '${_dateLabel(p['recordedAt'])} · ${p['reference'] ?? 'No reference'}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppTheme.textGrey,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
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
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _copyRunCsv(runId),
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const AppText('Copy CSV'),
                        ),
                        const Spacer(),
                        if (run['status'] == 'draft')
                          FilledButton.icon(
                            onPressed: () => _approveRun(runId, run),
                            icon: const Icon(Icons.verified_outlined),
                            label: const AppText('Approve & lock payroll'),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _copyPayslip(String runId, Map<String, dynamic> e) async {
    final lines = <String>[
      'MOHALLAFLOW — SALARY STATEMENT',
      'Payroll period: $runId',
      'Staff: ${e['staffName'] ?? 'Staff'}',
      'Employee code: ${e['staffCode'] ?? ''}',
      'Department: ${_departments[e['department']] ?? e['department'] ?? ''}',
      'Pay basis: ${_payBases[e['payBasis']] ?? e['payBasis'] ?? ''}',
      'Attendance reference: ${e['attendanceDays'] ?? 0} day(s)',
      '',
      'Base pay: ${_money(e['basePay'])}',
      'HRA: ${_money(e['hra'])}',
      'Transport allowance: ${_money(e['transportAllowance'])}',
      'Other allowance: ${_money(e['otherAllowance'])}',
      'Overtime: ${_money(e['overtimePay'])}',
      'Bonus: ${_money(e['bonus'])}',
      'Reimbursements: ${_money(e['reimbursements'])}',
      'Gross pay: ${_money(e['grossPay'])}',
      'Default deductions: ${_money(e['defaultDeduction'])}',
      'Advance recovery: ${_money(e['advanceRecovery'])}',
      'Other deductions: ${_money(e['otherDeductions'])}',
      'Total deductions: ${_money(e['totalDeductions'])}',
      'NET PAYABLE: ${_money(e['netPay'])}',
      'Amount paid: ${_money(e['amountPaid'])}',
      'Balance: ${_money(e['balance'])}',
      'Status: ${e['status'] ?? ''}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    _message('Salary statement copied to clipboard.');
  }

  Future<void> _copyRunCsv(String runId) async {
    try {
      final snap = await _runs
          .doc(runId)
          .collection('entries')
          .orderBy('staffName')
          .get();
      String cell(Object? value) =>
          '"${(value ?? '').toString().replaceAll('"', '""')}"';
      final lines = <String>[
        'Staff Code,Staff Name,Department,Pay Basis,Attendance Days,Gross,Deductions,Net Pay,Paid,Balance,Status',
      ];
      for (final doc in snap.docs) {
        final d = doc.data();
        lines.add(
          [
            d['staffCode'],
            d['staffName'],
            d['department'],
            d['payBasis'],
            d['attendanceDays'],
            d['grossPay'],
            d['totalDeductions'],
            d['netPay'],
            d['amountPaid'],
            d['balance'],
            d['status'],
          ].map(cell).join(','),
        );
      }
      await Clipboard.setData(ClipboardData(text: lines.join('\n')));
      _message('Payroll CSV copied. Paste it into Excel or Google Sheets.');
    } catch (error) {
      _message('Could not export payroll CSV: $error');
    }
  }
}
// MOHALLAFLOW_STAFF_PAYROLL_SCREEN_END
