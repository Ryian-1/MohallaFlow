// MOHALLAFLOW_ADVANCED_ANALYTICS_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

enum _AnalyticsPeriod { days30, days90, months12, financialYear, allTime }

extension _AnalyticsPeriodLabel on _AnalyticsPeriod {
  String get label => switch (this) {
    _AnalyticsPeriod.days30 => 'Last 30 days',
    _AnalyticsPeriod.days90 => 'Last 90 days',
    _AnalyticsPeriod.months12 => 'Last 12 months',
    _AnalyticsPeriod.financialYear => 'Financial year',
    _AnalyticsPeriod.allTime => 'All available records',
  };
}

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });
  final String colonyId;
  final String colonyName;
  final String adminName;
  @override
  State<AdvancedAnalyticsScreen> createState() =>
      _AdvancedAnalyticsScreenState();
}

class _AnalyticsSnapshot {
  const _AnalyticsSnapshot({
    required this.records,
    required this.errors,
    required this.capped,
    required this.loadedAt,
  });
  final Map<String, List<Map<String, dynamic>>> records;
  final Map<String, String> errors;
  final Set<String> capped;
  final DateTime loadedAt;
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  static const int _recordLimit = 300;
  static const Color _navy = AppTheme.navyBlue;
  static const Color _muted = AppTheme.textGrey;
  static const Color _border = AppTheme.borderGrey;
  static const Map<String, String> _dateFields = {
    'households': 'createdAt',
    'residents': 'createdAt',
    'complaints': 'createdAt',
    'maintenanceJobs': 'createdAt',
    'maintenanceSlaCases': 'createdAt',
    'cleanlinessTasks': 'createdAt',
    'housekeepingRequests': 'createdAt',
    'maintenanceBills': 'createdAt',
    'maintenancePayments': 'createdAt',
    'colonyExpenses': 'expenseDate',
    'workerAttendance': 'checkInAt',
    'cleanlinessWorkers': 'createdAt',
    'colonyStaff': 'createdAt',
    'visitors': 'expectedAt',
    'domesticHelpVisits': 'checkedInAt',
    'serviceProviderVisits': 'checkedInAt',
    'gateDeliveries': 'receivedAt',
    'gateShifts': 'startedAt',
    'waterMeterReadings': 'readingAt',
    'waterStorageMovements': 'createdAt',
    'waterIncidents': 'openedAt',
    'waterQualityChecks': 'testedAt',
    'waterDistributions': 'distributionDate',
    'waterDeliveries': 'deliveryDate',
    'colonyAssets': 'createdAt',
    'inventoryItems': 'createdAt',
    'inventoryTransactions': 'createdAt',
    'preventiveMaintenancePlans': 'createdAt',
    'purchaseRequisitions': 'createdAt',
    'purchaseOrders': 'orderDate',
    'supplierInvoices': 'invoiceDate',
    'supplierPayments': 'paymentDate',
    'amenityBookings': 'createdAt',
    'communityEvents': 'startsAt',
    'communityPolls': 'createdAt',
    'rsvps': 'createdAt',
    'votes': 'createdAt',
    'rwaCommitteeMembers': 'createdAt',
    'rwaGovernanceMeetings': 'meetingAt',
    'rwaResolutions': 'createdAt',
    'rwaGovernanceActions': 'dueDate',
    'rwaComplianceRegister': 'dueDate',
    'rwaGovernanceDocuments': 'reviewDate',
    'residentDocuments': 'createdAt',
    'securityIncidents': 'createdAt',
    'lostFoundItems': 'createdAt',
    'moveRequests': 'createdAt',
    'domesticHelpers': 'createdAt',
    'serviceProviders': 'createdAt',
    'residentChangeRequests': 'createdAt',
    'residentServiceRequests': 'createdAt',
    'accountingJournals': 'journalDate',
    'accountingBankStatements': 'transactionDate',
    'accountingPeriods': 'createdAt',
  };

  _AnalyticsPeriod _period = _AnalyticsPeriod.days90;
  late Future<_AnalyticsSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  DateTime? _periodStart() {
    final now = DateTime.now();
    return switch (_period) {
      _AnalyticsPeriod.days30 => now.subtract(const Duration(days: 30)),
      _AnalyticsPeriod.days90 => now.subtract(const Duration(days: 90)),
      _AnalyticsPeriod.months12 => DateTime(now.year, now.month - 12, now.day),
      _AnalyticsPeriod.financialYear => DateTime(
        now.month >= 4 ? now.year : now.year - 1,
        4,
        1,
      ),
      _AnalyticsPeriod.allTime => null,
    };
  }

  Future<_AnalyticsSnapshot> _load() async {
    final colony = FirebaseFirestore.instance
        .collection('colonies')
        .doc(widget.colonyId);
    final records = <String, List<Map<String, dynamic>>>{};
    final errors = <String, String>{};
    final capped = <String>{};
    final futures = _dateFields.entries.map((entry) async {
      try {
        final query = await colony
            .collection(entry.key)
            .orderBy(entry.value, descending: true)
            .limit(_recordLimit)
            .get();
        records[entry.key] = query.docs
            .map((doc) => <String, dynamic>{...doc.data(), '_docId': doc.id})
            .toList();
        if (query.docs.length >= _recordLimit) capped.add(entry.key);
      } catch (e) {
        // A source-specific failure must not hide all other dashboards.
        errors[entry.key] = e.toString();
        records[entry.key] = <Map<String, dynamic>>[];
      }
    });
    // Inventory, accounts and settings may not expose the date field used by event reports.
    final noDateCollections = <String>[
      'accountingAccounts',
      'colonyBudgets',
      'amenityFacilities',
      'waterMeters',
      'waterStorageAssets',
      'maintenanceVendors',
    ];
    final extra = noDateCollections.map((name) async {
      try {
        final query = await colony.collection(name).limit(_recordLimit).get();
        records[name] = query.docs
            .map((doc) => <String, dynamic>{...doc.data(), '_docId': doc.id})
            .toList();
        if (query.docs.length >= _recordLimit) capped.add(name);
      } catch (e) {
        errors[name] = e.toString();
        records[name] = <Map<String, dynamic>>[];
      }
    });
    await Future.wait([...futures, ...extra]);
    return _AnalyticsSnapshot(
      records: records,
      errors: errors,
      capped: capped,
      loadedAt: DateTime.now(),
    );
  }

  void _refresh() => setState(() => _future = _load());
  List<Map<String, dynamic>> _all(_AnalyticsSnapshot s, String name) =>
      s.records[name] ?? const [];
  DateTime? _asDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<Map<String, dynamic>> _periodRows(_AnalyticsSnapshot s, String name) {
    final rows = _all(s, name);
    final start = _periodStart();
    if (start == null) return rows;
    final field = _dateFields[name];
    if (field == null) return rows;
    return rows.where((row) {
      final date = _asDate(row[field]);
      return date != null &&
          !date.isBefore(start) &&
          !date.isAfter(DateTime.now());
    }).toList();
  }

  num _n(Object? v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
  String _s(Object? v) => (v ?? '').toString().trim().toLowerCase();
  bool _active(Map<String, dynamic> r) => !const {
    'inactive',
    'archived',
    'cancelled',
    'deleted',
    'suspended',
  }.contains(_s(r['status']));
  bool _open(Map<String, dynamic> r) => !const {
    'resolved',
    'closed',
    'completed',
    'cancelled',
    'rejected',
    'archived',
  }.contains(_s(r['status']));
  num _sum(List<Map<String, dynamic>> rows, String field) =>
      rows.fold<num>(0, (a, r) => a + _n(r[field]));
  String _money(num n) => '₹${n.toStringAsFixed(0)}';
  String _fmt(num n) => n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1);
  DateTime? _firstDate(Map<String, dynamic> row, List<String> fields) {
    for (final field in fields) {
      final d = _asDate(row[field]);
      if (d != null) return d;
    }
    return null;
  }

  num _paidExpense(Map<String, dynamic> row) {
    if (row.containsKey('amountPaid')) return _n(row['amountPaid']);
    final status = _s(row['paymentStatus'] ?? row['status']);
    return const {'paid', 'completed', 'verified'}.contains(status)
        ? _n(row['amount'])
        : 0;
  }

  int _countWhere(
    List<Map<String, dynamic>> rows,
    bool Function(Map<String, dynamic>) test,
  ) => rows.where(test).length;
  String _periodTitle() => _period.label;

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  Map<String, num> _executiveMetrics(_AnalyticsSnapshot s) {
    final residents = _all(s, 'residents');
    final households = _all(s, 'households');
    final complaints = _periodRows(s, 'complaints');
    final sla = _all(s, 'maintenanceSlaCases');
    final bills = _periodRows(s, 'maintenanceBills');
    final expenses = _periodRows(s, 'colonyExpenses');
    final incidents = _all(s, 'waterIncidents');
    final actions = _all(s, 'rwaGovernanceActions');
    final now = DateTime.now();
    final activeResidents = _countWhere(
      residents,
      (r) =>
          !_s(r['status']).contains('inactive') &&
          !_s(r['status']).contains('moved_out'),
    );
    final occupiedHomes = _countWhere(
      households,
      (r) => _s(r['occupancyStatus']) == 'occupied',
    );
    final openComplaints = _countWhere(complaints, _open);
    final openSlaBreaches = _countWhere(sla, (r) {
      if (!_open(r) || _s(r['status']).startsWith('waiting_')) return false;
      final responseDue = _asDate(r['responseDueAt']);
      final resolutionDue = _asDate(r['resolutionDueAt']);
      final responseBreach =
          r['firstResponseAt'] == null &&
          responseDue != null &&
          responseDue.isBefore(now);
      final resolutionBreach =
          !const {
            'resolved',
            'closed',
            'completed',
          }.contains(_s(r['status'])) &&
          resolutionDue != null &&
          resolutionDue.isBefore(now);
      return responseBreach || resolutionBreach;
    });
    final billed = _sum(bills, 'totalAmount');
    final collected = _sum(bills, 'amountPaid');
    final paidExpenses = expenses.fold<num>(0, (a, r) => a + _paidExpense(r));
    final overdueActions = _countWhere(
      actions,
      (r) => _open(r) && (_asDate(r['dueDate'])?.isBefore(now) ?? false),
    );
    final openIncidents = _countWhere(incidents, _open);
    return {
      'residents': activeResidents,
      'occupied': occupiedHomes,
      'complaints': openComplaints,
      'slaBreaches': openSlaBreaches,
      'billed': billed,
      'collected': collected,
      'outstanding': (billed - collected).clamp(0, double.infinity),
      'expenses': paidExpenses,
      'overdueActions': overdueActions,
      'incidents': openIncidents,
    };
  }

  Widget _metric(
    String label,
    String value,
    String note, {
    IconData icon = Icons.insights_outlined,
  }) => Container(
    width: 164,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _navy),
        const SizedBox(height: 10),
        AppText(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: _navy,
          ),
        ),
        const SizedBox(height: 3),
        AppText(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 3),
        AppText(note, style: const TextStyle(fontSize: 10, color: _muted)),
      ],
    ),
  );
  Widget _panel(String title, String note, List<Widget> children) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          title,
          style: const TextStyle(
            color: _navy,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 3),
        AppText(note, style: const TextStyle(color: _muted, fontSize: 10)),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
  Widget _bars(
    String title,
    String note,
    Map<String, num> values, {
    bool currency = false,
  }) {
    if (values.isEmpty) {
      return _panel(title, note, [
        const AppText(
          'No records in this reporting period.',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
      ]);
    }
    final maxValue = values.values.fold<num>(0, (a, b) => b > a ? b : a);
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _panel(
      title,
      note,
      entries.take(8).map((e) {
        final ratio = maxValue <= 0
            ? 0.0
            : (e.value / maxValue).clamp(0.0, 1.0).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      e.key.replaceAll('_', ' '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AppText(
                    currency ? _money(e.value) : _fmt(e.value),
                    style: const TextStyle(
                      fontSize: 11,
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: AppTheme.lightGrey,
                  color: _navy,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Map<String, num> _groupCount(List<Map<String, dynamic>> rows, String field) {
    final map = <String, num>{};
    for (final row in rows) {
      final key = (row[field] ?? 'Unspecified').toString();
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Map<String, num> _groupExpense(List<Map<String, dynamic>> rows) {
    final map = <String, num>{};
    for (final row in rows) {
      final key = (row['category'] ?? 'other').toString();
      map[key] = (map[key] ?? 0) + _paidExpense(row);
    }
    return map;
  }

  Map<String, num> _monthlyCounts(
    List<Map<String, dynamic>> rows,
    String field,
  ) {
    final now = DateTime.now();
    final result = <String, num>{};
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      result['${_month(d.month)} ${d.year.toString().substring(2)}'] = 0;
    }
    for (final row in rows) {
      final d = _asDate(row[field]);
      if (d == null) continue;
      final key = '${_month(d.month)} ${d.year.toString().substring(2)}';
      if (result.containsKey(key)) result[key] = result[key]! + 1;
    }
    return result;
  }

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  Widget _executive(_AnalyticsSnapshot s) {
    final m = _executiveMetrics(s);
    final expense = _periodRows(s, 'colonyExpenses');
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _metric(
              'Active residents',
              _fmt(m['residents']!),
              'Current colony register',
              icon: Icons.people_outline,
            ),
            _metric(
              'Occupied households',
              _fmt(m['occupied']!),
              'Current occupancy',
              icon: Icons.home_outlined,
            ),
            _metric(
              'Open complaints',
              _fmt(m['complaints']!),
              _periodTitle(),
              icon: Icons.report_problem_outlined,
            ),
            _metric(
              'SLA breaches',
              _fmt(m['slaBreaches']!),
              'Open cases past a target',
              icon: Icons.timer_off_outlined,
            ),
            _metric(
              'Maintenance billed',
              _money(m['billed']!),
              _periodTitle(),
              icon: Icons.receipt_long_outlined,
            ),
            _metric(
              'Collected',
              _money(m['collected']!),
              'Recorded bill payments',
              icon: Icons.account_balance_wallet_outlined,
            ),
            _metric(
              'Outstanding',
              _money(m['outstanding']!),
              'Bills less amount paid',
              icon: Icons.pending_actions_outlined,
            ),
            _metric(
              'Paid expenses',
              _money(m['expenses']!),
              _periodTitle(),
              icon: Icons.payments_outlined,
            ),
            _metric(
              'Open water/security incidents',
              _fmt(m['incidents']!),
              'Current open incidents',
              icon: Icons.shield_outlined,
            ),
            _metric(
              'Overdue governance actions',
              _fmt(m['overdueActions']!),
              'Open actions past due date',
              icon: Icons.assignment_late_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _bars(
          'Complaint trend · last six months',
          'Count of complaints by creation month.',
          _monthlyCounts(_all(s, 'complaints'), 'createdAt'),
        ),
        _bars(
          'Expenses by category',
          'Paid amounts from the existing colony expense ledger. Procurement mirror rows are included only as recorded there.',
          _groupExpense(expense),
          currency: true,
        ),
        _panel('Executive interpretation', 'How to read this dashboard', [
          const AppText(
            'Collections are taken from the bill register amountPaid field; verified payment submissions are not added again. Expenses use colonyExpenses paid amounts, including staff and procurement payout mirrors. Supplier payments are not summed separately.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
          ),
          const SizedBox(height: 7),
          const AppText(
            'Open operational counts are current-state snapshots. Financial, complaint and activity totals follow the selected reporting period.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
          ),
        ]),
      ],
    );
  }

  Widget _maintenance(_AnalyticsSnapshot s) {
    final complaints = _periodRows(s, 'complaints');
    final jobs = _periodRows(s, 'maintenanceJobs');
    final cases = _all(s, 'maintenanceSlaCases');
    final housekeeping = _periodRows(s, 'housekeepingRequests');
    final now = DateTime.now();
    final breaches = cases.where((r) {
      if (!_open(r) || _s(r['status']).startsWith('waiting_')) return false;
      final response = _asDate(r['responseDueAt']);
      final resolution = _asDate(r['resolutionDueAt']);
      return (r['firstResponseAt'] == null &&
              response != null &&
              response.isBefore(now)) ||
          (resolution != null && resolution.isBefore(now) && _open(r));
    }).length;
    final completedJobs = _countWhere(
      jobs,
      (r) =>
          const {'completed', 'resolved', 'closed'}.contains(_s(r['status'])),
    );
    final openJobs = _countWhere(jobs, _open);
    final vendorWork = <String, num>{};
    for (final r in jobs) {
      final name = (r['vendorName'] ?? 'Unassigned').toString();
      vendorWork[name] = (vendorWork[name] ?? 0) + 1;
    }
    final averageResolutionHours = <num>[];
    for (final r in complaints) {
      final start = _firstDate(r, ['createdAt']);
      final end = _firstDate(r, ['resolvedAt', 'completedAt', 'closedAt']);
      if (start != null && end != null && !end.isBefore(start)) {
        averageResolutionHours.add(end.difference(start).inMinutes / 60);
      }
    }
    final avg = averageResolutionHours.isEmpty
        ? 0
        : averageResolutionHours.reduce((a, b) => a + b) /
              averageResolutionHours.length;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _metric(
              'Complaints created',
              '${complaints.length}',
              _periodTitle(),
              icon: Icons.report_outlined,
            ),
            _metric(
              'Open repair jobs',
              '$openJobs',
              _periodTitle(),
              icon: Icons.handyman_outlined,
            ),
            _metric(
              'Completed repair jobs',
              '$completedJobs',
              _periodTitle(),
              icon: Icons.task_alt_outlined,
            ),
            _metric(
              'Open SLA breaches',
              '$breaches',
              'Current active SLA cases',
              icon: Icons.timer_outlined,
            ),
            _metric(
              'Avg. resolution',
              '${avg.toStringAsFixed(1)} h',
              'Resolved complaints with both timestamps',
              icon: Icons.hourglass_bottom_outlined,
            ),
            _metric(
              'Housekeeping requests',
              '${housekeeping.length}',
              _periodTitle(),
              icon: Icons.cleaning_services_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _bars(
          'Complaints by category',
          'Based on the category recorded on each complaint.',
          _groupCount(complaints, 'category'),
        ),
        _bars(
          'Repair jobs by status',
          'Current workflow status for jobs in the selected period.',
          _groupCount(jobs, 'status'),
        ),
        _bars(
          'Vendor workload',
          'Repair jobs grouped by recorded vendor name; this is volume, not a quality score.',
          vendorWork,
        ),
        _panel(
          'SLA measurement notes',
          'Avoid misinterpreting missing timestamps',
          [
            const AppText(
              'Average resolution uses only complaints with both createdAt and a resolvedAt/completedAt/closedAt timestamp. Cases currently waiting on a vendor or resident are excluded from the live breach count. SLA targets use the saved case deadlines.',
              style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
            ),
          ],
        ),
      ],
    );
  }

  Widget _finance(_AnalyticsSnapshot s) {
    final bills = _periodRows(s, 'maintenanceBills');
    final expenses = _periodRows(s, 'colonyExpenses');
    final supplierInvoices = _periodRows(s, 'supplierInvoices');
    final supplierPayments = _periodRows(s, 'supplierPayments');
    final budgets = _all(s, 'colonyBudgets');
    final billed = _sum(bills, 'totalAmount');
    final collected = _sum(bills, 'amountPaid');
    final paidOut = expenses.fold<num>(0, (a, r) => a + _paidExpense(r));
    final unpaidSupplier = supplierInvoices.fold<num>(
      0,
      (a, r) => a + _n(r['balanceDue']),
    );
    final purchaseCommitment = _sum(_periodRows(s, 'purchaseOrders'), 'total');
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _metric(
              'Billed',
              _money(billed),
              _periodTitle(),
              icon: Icons.receipt_outlined,
            ),
            _metric(
              'Collected',
              _money(collected),
              'Bill amountPaid',
              icon: Icons.savings_outlined,
            ),
            _metric(
              'Receivable balance',
              _money((billed - collected).clamp(0, double.infinity)),
              'Bills less payments',
              icon: Icons.account_balance_wallet_outlined,
            ),
            _metric(
              'Paid expenditure',
              _money(paidOut),
              'Colony expense ledger',
              icon: Icons.trending_down_outlined,
            ),
            _metric(
              'Supplier payables',
              _money(unpaidSupplier),
              'Verified invoice balances',
              icon: Icons.store_outlined,
            ),
            _metric(
              'Purchase order value',
              _money(purchaseCommitment),
              'Orders created in period; not cash paid',
              icon: Icons.shopping_cart_outlined,
            ),
            _metric(
              'Supplier payments',
              '${supplierPayments.length}',
              'Payment records; not added again to expenses',
              icon: Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _bars(
          'Paid expenditure by category',
          'Uses colonyExpenses.amountPaid; no supplierPayments or payroll payments are added separately.',
          _groupExpense(expenses),
          currency: true,
        ),
        _bars(
          'Maintenance billing status',
          'Bill totals by stored status.',
          _groupCount(bills, 'status'),
        ),
        _bars(
          'Expense trend · last six months',
          'Number of expense records by expense date.',
          _monthlyCounts(_all(s, 'colonyExpenses'), 'expenseDate'),
        ),
        _panel(
          'Accounting scope and anti-duplication rules',
          'Management view, not a statutory statement',
          [
            const AppText(
              'This dashboard does not add supplierPayments to paid expenditure because Procurement writes matching payments to colonyExpenses. Payroll payouts are likewise represented by their Staff expense entries. Billed, collected and paid figures are operational summaries; the RWA Accounting ledger remains the source for double-entry balances and bank reconciliation.',
              style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
            ),
            const SizedBox(height: 5),
            AppText(
              'Budget records currently loaded: ${budgets.length}. Budget-vs-actual comparisons require matching monthKey/category records and are shown as source data, not recalculated as cash.',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _workforceAssets(_AnalyticsSnapshot s) {
    final staff = _all(s, 'colonyStaff');
    final workers = _all(s, 'cleanlinessWorkers');
    final attendance = _periodRows(s, 'workerAttendance');
    final tasks = _periodRows(s, 'cleanlinessTasks');
    final assets = _all(s, 'colonyAssets');
    final inventory = _all(s, 'inventoryItems');
    final plans = _all(s, 'preventiveMaintenancePlans');
    final now = DateTime.now();
    final lowStock = _countWhere(
      inventory,
      (r) => _n(r['quantityOnHand']) <= _n(r['reorderLevel']) && _active(r),
    );
    final duePlans = _countWhere(
      plans,
      (r) => _active(r) && (_asDate(r['nextDueDate'])?.isBefore(now) ?? false),
    );
    final attendanceWorkers = attendance
        .map((r) => (r['workerId'] ?? '').toString())
        .where((v) => v.isNotEmpty)
        .toSet()
        .length;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _metric(
              'Active staff profiles',
              '${_countWhere(staff, _active)}',
              'Payroll staff register',
              icon: Icons.badge_outlined,
            ),
            _metric(
              'Active cleanliness workers',
              '${_countWhere(workers, _active)}',
              'Worker register',
              icon: Icons.engineering_outlined,
            ),
            _metric(
              'Attendance records',
              '${attendance.length}',
              _periodTitle(),
              icon: Icons.fact_check_outlined,
            ),
            _metric(
              'Workers recorded',
              '$attendanceWorkers',
              'Distinct worker IDs in period',
              icon: Icons.people_alt_outlined,
            ),
            _metric(
              'Cleaning tasks',
              '${tasks.length}',
              _periodTitle(),
              icon: Icons.cleaning_services_outlined,
            ),
            _metric(
              'Assets registered',
              '${assets.length}',
              'Fixed-asset register',
              icon: Icons.precision_manufacturing_outlined,
            ),
            _metric(
              'Low / reorder stock',
              '$lowStock',
              'At or below reorder level',
              icon: Icons.inventory_outlined,
            ),
            _metric(
              'Maintenance plans overdue',
              '$duePlans',
              'Active plans past next due date',
              icon: Icons.event_busy_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _bars(
          'Attendance by recorded status',
          'Uses recorded attendance only. Missing check-ins are not inferred as absence.',
          _groupCount(attendance, 'status'),
        ),
        _bars(
          'Cleaning tasks by status',
          'Current stored status for tasks created in the selected period.',
          _groupCount(tasks, 'status'),
        ),
        _bars(
          'Assets by lifecycle status',
          'Current asset register.',
          _groupCount(assets, 'status'),
        ),
        _panel('Workforce and stock notes', 'Operational interpretation', [
          const AppText(
            'Attendance counts represent saved workerAttendance documents, not unique shifts or payroll-approved payable days. Payroll calculations remain in Staff & Payroll. Low-stock counts compare quantityOnHand with reorderLevel; confirm physical stock before purchasing.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
          ),
        ]),
      ],
    );
  }

  Widget _waterSecurity(_AnalyticsSnapshot s) {
    final readings = _periodRows(s, 'waterMeterReadings');
    final incidents = _all(s, 'waterIncidents');
    final quality = _periodRows(s, 'waterQualityChecks');
    final visitors = _periodRows(s, 'visitors');
    final helperVisits = _periodRows(s, 'domesticHelpVisits');
    final providerVisits = _periodRows(s, 'serviceProviderVisits');
    final deliveries = _periodRows(s, 'gateDeliveries');
    final waterDeliveries = _periodRows(s, 'waterDeliveries');
    final totalUsage = _sum(readings, 'consumptionLitres');
    final activeVisitorEntries = _countWhere(
      visitors,
      (r) => r['checkedInAt'] != null && r['checkedOutAt'] == null,
    );
    final unsafeQuality = _countWhere(
      quality,
      (r) => const {
        'fail',
        'unsafe',
        'failed',
        'not_compliant',
      }.contains(_s(r['outcome'])),
    );
    final now = DateTime.now();
    final unresolved = _countWhere(incidents, _open);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _metric(
              'Meter consumption',
              '${_fmt(totalUsage)} L',
              _periodTitle(),
              icon: Icons.water_drop_outlined,
            ),
            _metric(
              'Water quality checks',
              '${quality.length}',
              _periodTitle(),
              icon: Icons.science_outlined,
            ),
            _metric(
              'Adverse quality outcomes',
              '$unsafeQuality',
              'As recorded by tester',
              icon: Icons.warning_amber_outlined,
            ),
            _metric(
              'Open water incidents',
              '$unresolved',
              'Current incident register',
              icon: Icons.plumbing_outlined,
            ),
            _metric(
              'Visitor entries',
              '${visitors.length}',
              _periodTitle(),
              icon: Icons.directions_walk_outlined,
            ),
            _metric(
              'Visitors currently inside',
              '$activeVisitorEntries',
              'Based on check-in/out fields',
              icon: Icons.meeting_room_outlined,
            ),
            _metric(
              'Domestic-help visits',
              '${helperVisits.length}',
              _periodTitle(),
              icon: Icons.home_repair_service_outlined,
            ),
            _metric(
              'Service-provider visits',
              '${providerVisits.length}',
              _periodTitle(),
              icon: Icons.handyman_outlined,
            ),
            _metric(
              'Gate deliveries',
              '${deliveries.length}',
              _periodTitle(),
              icon: Icons.inventory_2_outlined,
            ),
            _metric(
              'Tanker deliveries',
              '${waterDeliveries.length}',
              _periodTitle(),
              icon: Icons.local_shipping_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _bars(
          'Water incidents by type',
          'Current unresolved and historical incident records.',
          _groupCount(incidents, 'incidentType'),
        ),
        _bars(
          'Water quality outcomes',
          'Recorded outcome labels; this is not independent regulatory certification.',
          _groupCount(quality, 'outcome'),
        ),
        _panel('Gate and water data notes', 'Coverage limitations', [
          AppText(
            "Outstanding gate deliveries: ${_countWhere(_all(s, 'gateDeliveries'), (r) => _s(r['status']) == 'received')}. As-of date: ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}.",
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          const AppText(
            'Visitor currently-inside count requires checkedInAt and checkedOutAt timestamps. Physical vehicle stickers are not tracked by this dashboard. Meter usage is summed from saved consumptionLitres readings; it is not a sensor feed.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
          ),
        ]),
      ],
    );
  }

  Widget _communityGovernance(_AnalyticsSnapshot s) {
    final events = _periodRows(s, 'communityEvents');
    final rsvps = _periodRows(s, 'rsvps');
    final votes = _periodRows(s, 'votes');
    final bookings = _periodRows(s, 'amenityBookings');
    final committee = _all(s, 'rwaCommitteeMembers');
    final meetings = _periodRows(s, 'rwaGovernanceMeetings');
    final resolutions = _periodRows(s, 'rwaResolutions');
    final actions = _all(s, 'rwaGovernanceActions');
    final compliance = _all(s, 'rwaComplianceRegister');
    final documents = _all(s, 'rwaGovernanceDocuments');
    final now = DateTime.now();
    final dueCompliance = _countWhere(
      compliance,
      (r) => _active(r) && (_asDate(r['dueDate'])?.isBefore(now) ?? false),
    );
    final docsDue = _countWhere(
      documents,
      (r) => _active(r) && (_asDate(r['reviewDate'])?.isBefore(now) ?? false),
    );
    final quorumMet = _countWhere(meetings, (r) => r['quorumMet'] == true);
    final upcomingEvents = _countWhere(
      _all(s, 'communityEvents'),
      (r) =>
          _s(r['status']) == 'published' &&
          (_asDate(r['startsAt'])?.isAfter(now) ?? false),
    );
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _metric(
              'Community events',
              '${events.length}',
              _periodTitle(),
              icon: Icons.event_outlined,
            ),
            _metric(
              'Upcoming published events',
              '$upcomingEvents',
              'Future event schedule',
              icon: Icons.calendar_month_outlined,
            ),
            _metric(
              'Resident RSVPs',
              '${rsvps.length}',
              _periodTitle(),
              icon: Icons.how_to_reg_outlined,
            ),
            _metric(
              'Poll votes',
              '${votes.length}',
              _periodTitle(),
              icon: Icons.poll_outlined,
            ),
            _metric(
              'Facility bookings',
              '${bookings.length}',
              _periodTitle(),
              icon: Icons.event_available_outlined,
            ),
            _metric(
              'Active committee members',
              '${_countWhere(committee, _active)}',
              'Current committee register',
              icon: Icons.groups_outlined,
            ),
            _metric(
              'Meetings with quorum',
              '$quorumMet / ${meetings.length}',
              _periodTitle(),
              icon: Icons.meeting_room_outlined,
            ),
            _metric(
              'Resolutions recorded',
              '${resolutions.length}',
              _periodTitle(),
              icon: Icons.gavel_outlined,
            ),
            _metric(
              'Overdue compliance items',
              '$dueCompliance',
              'Current compliance register',
              icon: Icons.fact_check_outlined,
            ),
            _metric(
              'Documents due for review',
              '$docsDue',
              'Governance document register',
              icon: Icons.folder_open_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _bars(
          'Bookings by status',
          'Amenity booking workflow records.',
          _groupCount(bookings, 'status'),
        ),
        _bars(
          'Governance resolutions by status',
          'Formal resolution register.',
          _groupCount(resolutions, 'status'),
        ),
        _bars(
          'Governance actions by status',
          'Current action register.',
          _groupCount(actions, 'status'),
        ),
        _panel('Repository and governance coverage', 'Optional source modules', [
          AppText(
            "Governance document metadata records loaded: ${documents.length}. Resident document submissions loaded: ${_all(s, 'residentDocuments').length}.",
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          const AppText(
            'Document review metrics use the existing governance metadata and repository records when available. Event, poll, RSVP and voting counts are activity totals, not unique household participation rates.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
          ),
        ]),
      ],
    );
  }

  Future<void> _export(_AnalyticsSnapshot s) async {
    final m = _executiveMetrics(s);
    final rows = <List<Object?>>[
      ['MohallaFlow Advanced Operational Analytics'],
      ['Colony', widget.colonyName],
      ['Colony ID', widget.colonyId],
      ['Period', _periodTitle()],
      ['Generated at', s.loadedAt.toIso8601String()],
      [],
      ['Metric', 'Value'],
      ...m.entries.map((e) => [e.key, e.value]),
      ['complaints_created', _periodRows(s, 'complaints').length],
      ['maintenance_jobs', _periodRows(s, 'maintenanceJobs').length],
      ['attendance_records', _periodRows(s, 'workerAttendance').length],
      ['water_meter_readings', _periodRows(s, 'waterMeterReadings').length],
      ['supplier_invoices', _periodRows(s, 'supplierInvoices').length],
      ['supplier_payments_records', _periodRows(s, 'supplierPayments').length],
      ['community_events', _periodRows(s, 'communityEvents').length],
      ['amenity_bookings', _periodRows(s, 'amenityBookings').length],
      [],
      ['Data source', 'Records loaded', 'Status'],
      ...s.records.entries.map(
        (e) => [
          e.key,
          e.value.length,
          s.errors.containsKey(e.key)
              ? 'error: ${s.errors[e.key]}'
              : s.capped.contains(e.key)
              ? 'capped at $_recordLimit'
              : 'loaded',
        ],
      ),
    ];
    String cell(Object? v) {
      final escaped = (v ?? '').toString().replaceAll('"', '""');
      return '"$escaped"';
    }

    final csv = rows.map((r) => r.map(cell).join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    _message(
      'Analytics CSV snapshot copied. It includes data-source coverage and errors.',
    );
  }

  Widget _dataCoverage(_AnalyticsSnapshot s) {
    final entries = s.records.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const AppText(
        'Data source coverage',
        style: TextStyle(
          color: _navy,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: AppText(
        '${entries.length - s.errors.length} sources loaded · ${s.errors.length} source errors · ${s.capped.length} sources at the $_recordLimit record cap',
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
      children: entries
          .map(
            (e) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: AppText(
                e.key,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: AppText(
                s.errors[e.key] ??
                    (s.capped.contains(e.key)
                        ? 'Record cap reached; latest ordered records only.'
                        : 'Loaded successfully.'),
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
              trailing: AppText(
                '${e.value.length}',
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          foregroundColor: _navy,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Advanced Operational Analytics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              AppText(
                widget.colonyName,
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _refresh,
              tooltip: AppTranslations.translate('Refresh analytics'),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: () => _future.then(_export),
              tooltip: AppTranslations.translate('Copy CSV snapshot'),
              icon: const Icon(Icons.file_download_outlined),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: _navy,
            unselectedLabelColor: _muted,
            indicatorColor: _navy,
            tabs: [
              Tab(
                icon: Icon(Icons.dashboard_outlined),
                text: AppTranslations.translate('Executive'),
              ),
              Tab(
                icon: Icon(Icons.handyman_outlined),
                text: AppTranslations.translate('Maintenance'),
              ),
              Tab(
                icon: Icon(Icons.account_balance_outlined),
                text: AppTranslations.translate('Finance'),
              ),
              Tab(
                icon: Icon(Icons.groups_outlined),
                text: AppTranslations.translate('Workforce & Assets'),
              ),
              Tab(
                icon: Icon(Icons.water_drop_outlined),
                text: AppTranslations.translate('Water & Security'),
              ),
              Tab(
                icon: Icon(Icons.account_tree_outlined),
                text: AppTranslations.translate('Community & Governance'),
              ),
            ],
          ),
        ),
        body: FutureBuilder<_AnalyticsSnapshot>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _navy),
              );
            }
            if (!snap.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.analytics_outlined,
                        size: 38,
                        color: _muted,
                      ),
                      const SizedBox(height: 10),
                      const AppText(
                        'Analytics could not be loaded',
                        style: TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AppText(
                        snap.error?.toString() ?? 'No data returned',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const AppText('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final s = snap.data!;
            return Column(
              children: [
                Container(
                  color: AppTheme.white,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.date_range_outlined,
                        size: 18,
                        color: _navy,
                      ),
                      const SizedBox(width: 7),
                      const AppText(
                        'Reporting period',
                        style: TextStyle(
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<_AnalyticsPeriod>(
                          initialValue: _period,
                          isDense: true,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: _AnalyticsPeriod.values
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: AppText(
                                    p.label,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _period = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _executive(s),
                      _maintenance(s),
                      _finance(s),
                      _workforceAssets(s),
                      _waterSecurity(s),
                      _communityGovernance(s),
                    ],
                  ),
                ),
                Container(
                  color: AppTheme.white,
                  padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Last refreshed: ${s.loadedAt.toLocal()}',
                        style: const TextStyle(fontSize: 9, color: _muted),
                      ),
                      _dataCoverage(s),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
// MOHALLAFLOW_ADVANCED_ANALYTICS_SCREEN_END
