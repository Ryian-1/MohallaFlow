import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

enum _ReportsPeriod { sevenDays, thirtyDays, ninetyDays, allTime }

extension _ReportsPeriodLabel on _ReportsPeriod {
  String get label {
    switch (this) {
      case _ReportsPeriod.sevenDays:
        return 'Last 7 days';
      case _ReportsPeriod.thirtyDays:
        return 'Last 30 days';
      case _ReportsPeriod.ninetyDays:
        return 'Last 90 days';
      case _ReportsPeriod.allTime:
        return 'All time';
    }
  }
}

typedef _ReportDocument = QueryDocumentSnapshot<Map<String, dynamic>>;

class _ReportsData {
  const _ReportsData(this.collections);

  final Map<String, List<_ReportDocument>> collections;

  List<_ReportDocument> docs(String name) => collections[name] ?? const [];
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
  });

  final String colonyId;
  final String colonyName;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportsPeriod _period = _ReportsPeriod.thirtyDays;

  late Future<_ReportsData> _reportsFuture;

  static const Map<String, String> _dateFields = {
    'households': 'createdAt',
    'residents': 'createdAt',
    'complaints': 'createdAt',
    'cleanlinessTasks': 'createdAt',
    'maintenanceJobs': 'createdAt',
    'maintenanceBills': 'createdAt',
    'maintenancePayments': 'createdAt',
    'visitors': 'expectedAt',
    'waterDeliveries': 'deliveryDate',
    'housekeepingRequests': 'createdAt',
  };

  @override
  void initState() {
    super.initState();
    _reportsFuture = _loadReports();
  }

  DateTime _periodStart() {
    final now = DateTime.now();

    switch (_period) {
      case _ReportsPeriod.sevenDays:
        return now.subtract(const Duration(days: 7));
      case _ReportsPeriod.thirtyDays:
        return now.subtract(const Duration(days: 30));
      case _ReportsPeriod.ninetyDays:
        return now.subtract(const Duration(days: 90));
      case _ReportsPeriod.allTime:
        return DateTime(2000);
    }
  }

  Future<_ReportsData> _loadReports() async {
    final colony = FirebaseFirestore.instance
        .collection('colonies')
        .doc(widget.colonyId);

    final names = _dateFields.keys.toList();

    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    // Capture a consistent upper boundary for this report.
    final reportEnd = Timestamp.fromDate(DateTime.now());

    final periodStart = _period == _ReportsPeriod.allTime
        ? null
        : Timestamp.fromDate(_periodStart());

    for (final entry in _dateFields.entries) {
      Query<Map<String, dynamic>> query = colony.collection(entry.key);

      // Finite reporting periods exclude records dated in the future.
      if (periodStart != null) {
        query = query
            .where(entry.value, isGreaterThanOrEqualTo: periodStart)
            .where(entry.value, isLessThanOrEqualTo: reportEnd);
      }

      // All time retains the existing historical and scheduled-record behaviour.
      futures.add(query.get());
    }

    final results = await Future.wait(futures);

    final records = <String, List<_ReportDocument>>{};

    for (var i = 0; i < names.length; i++) {
      records[names[i]] = results[i].docs;
    }

    return _ReportsData(records);
  }

  void _refresh() {
    setState(() {
      _reportsFuture = _loadReports();
    });
  }

  void _changePeriod(_ReportsPeriod? value) {
    if (value == null || value == _period) return;

    setState(() {
      _period = value;
      _reportsFuture = _loadReports();
    });
  }

  int _countStatus(List<_ReportDocument> documents, List<String> statuses) {
    return documents.where((document) {
      final status = document.data()['status']?.toString() ?? '';
      return statuses.contains(status);
    }).length;
  }

  num _sumField(
    List<_ReportDocument> documents,
    String field, {
    String? status,
  }) {
    num total = 0;

    for (final document in documents) {
      final data = document.data();

      if (status != null && data['status'] != status) {
        continue;
      }

      final value = data[field];

      if (value is num) {
        total += value;
      }
    }

    return total;
  }

  num _outstandingAmount(List<_ReportDocument> bills) {
    num total = 0;

    for (final document in bills) {
      final data = document.data();
      final amount = data['totalAmount'];
      final paid = data['amountPaid'];

      if (amount is! num || paid is! num) continue;

      total += (amount - paid).clamp(0, amount);
    }

    return total;
  }

  String _money(num value) => '₹${value.toStringAsFixed(0)}';

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _csvCell(Object? value) {
    final escaped = (value?.toString() ?? '').replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _exportCsv(_ReportsData data) async {
    final households = data.docs('households');
    final residents = data.docs('residents');
    final complaints = data.docs('complaints');
    final cleaning = data.docs('cleanlinessTasks');
    final housekeeping = data.docs('housekeepingRequests');
    final jobs = data.docs('maintenanceJobs');
    final bills = data.docs('maintenanceBills');
    final payments = data.docs('maintenancePayments');
    final visitors = data.docs('visitors');
    final deliveries = data.docs('waterDeliveries');

    final outstanding = _outstandingAmount(bills);

    final verifiedCollections = _sumField(
      payments,
      'amount',
      status: 'verified',
    );

    final rows = <List<Object?>>[
      ['MohallaFlow Colony Report'],
      ['Colony', widget.colonyName],
      ['Colony ID', widget.colonyId],
      ['Reporting period', _period.label],
      ['Generated', DateTime.now().toIso8601String()],
      [],
      ['Category', 'Metric', 'Value'],

      ['Households', 'Added', households.length],
      [
        'Households',
        'Occupied',
        households
            .where((d) => d.data()['occupancyStatus'] == 'occupied')
            .length,
      ],
      [
        'Households',
        'Vacant',
        households.where((d) => d.data()['occupancyStatus'] == 'vacant').length,
      ],

      ['Residents', 'Registered', residents.length],
      [
        'Residents',
        'Active',
        residents.where((d) => d.data()['residentStatus'] == 'active').length,
      ],

      ['Complaints', 'Received', complaints.length],
      [
        'Complaints',
        'Open or in progress',
        _countStatus(complaints, ['submitted', 'acknowledged', 'in_progress']),
      ],
      [
        'Complaints',
        'Resolved or closed',
        _countStatus(complaints, ['resolved', 'closed']),
      ],

      ['Cleanliness', 'Tasks created', cleaning.length],
      [
        'Cleanliness',
        'Completed',
        _countStatus(cleaning, ['completed']),
      ],

      ['Housekeeping', 'Requests received', housekeeping.length],
      [
        'Housekeeping',
        'Completed',
        _countStatus(housekeeping, ['completed']),
      ],

      ['Maintenance', 'Jobs created', jobs.length],
      [
        'Maintenance',
        'Completed',
        _countStatus(jobs, ['completed']),
      ],
      [
        'Maintenance',
        'Recorded completed-job cost',
        _money(_sumField(jobs, 'actualCost', status: 'completed')),
      ],

      ['Maintenance dues', 'Bills issued', bills.length],
      [
        'Maintenance dues',
        'Billed amount',
        _money(_sumField(bills, 'totalAmount')),
      ],
      [
        'Maintenance dues',
        'Outstanding amount on listed bills',
        _money(outstanding),
      ],

      [
        'Collections',
        'Verified payment records',
        _countStatus(payments, ['verified']),
      ],
      ['Collections', 'Verified amount', _money(verifiedCollections)],

      ['Visitors', 'Expected visits', visitors.length],
      [
        'Visitors',
        'Currently checked in',
        _countStatus(visitors, ['checked_in']),
      ],

      ['Water supply', 'Deliveries recorded', deliveries.length],
      [
        'Water supply',
        'Delivered litres',
        _sumField(deliveries, 'quantityLitres', status: 'delivered'),
      ],
    ];

    final csv = rows
        .map((row) {
          return row.map(_csvCell).join(',');
        })
        .join('\r\n');

    await Clipboard.setData(ClipboardData(text: csv));

    _showMessage('CSV summary copied. Paste it into Excel or Google Sheets.');
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          AppText(
            subtitle,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.secondaryNavy, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: AppText(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          AppText(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _performanceCard({
    required IconData icon,
    required String title,
    required int completed,
    required int total,
    required String completedLabel,
  }) {
    final rate = total == 0
        ? 0.0
        : (completed / total).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.secondaryNavy, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: AppText(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          AppText(
            total == 0 ? '—' : '${(rate * 100).round()}%',
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              backgroundColor: AppTheme.lightGrey,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryNavy),
            ),
          ),
          const SizedBox(height: 9),
          AppText(
            total == 0
                ? 'No records in this period'
                : '$completed of $total $completedLabel',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850 ? 3 : 2;

        return LayoutBuilder(
          builder: (context, constraints) {
            final int responsiveColumnCount = columns;
            final double horizontalGap = (12).toDouble();
            final double itemWidth =
                (constraints.maxWidth -
                    horizontalGap * (responsiveColumnCount - 1)) /
                responsiveColumnCount;
            return Wrap(
              spacing: horizontalGap,
              runSpacing: 12,
              children: (cards)
                  .map<Widget>(
                    (child) => SizedBox(width: itemWidth, child: child),
                  )
                  .toList(growable: false),
            );
          },
        );
      },
    );
  }

  Widget _buildReport(_ReportsData data) {
    final households = data.docs('households');
    final residents = data.docs('residents');
    final complaints = data.docs('complaints');
    final cleaning = data.docs('cleanlinessTasks');
    final housekeeping = data.docs('housekeepingRequests');
    final jobs = data.docs('maintenanceJobs');
    final bills = data.docs('maintenanceBills');
    final payments = data.docs('maintenancePayments');
    final visitors = data.docs('visitors');
    final deliveries = data.docs('waterDeliveries');

    final occupied = households
        .where((d) => d.data()['occupancyStatus'] == 'occupied')
        .length;

    final activeResidents = residents
        .where((d) => d.data()['residentStatus'] == 'active')
        .length;

    final openComplaints = _countStatus(complaints, [
      'submitted',
      'acknowledged',
      'in_progress',
    ]);

    final completedCleaning = _countStatus(cleaning, ['completed']);

    final resolvedComplaints = _countStatus(complaints, ['resolved', 'closed']);

    final completedHousekeeping = _countStatus(housekeeping, ['completed']);
    final completedMaintenanceJobs = _countStatus(jobs, ['completed']);

    final outstandingBills = _outstandingAmount(bills);

    final verifiedCollections = _sumField(
      payments,
      'amount',
      status: 'verified',
    );

    final deliveredLitres = _sumField(
      deliveries,
      'quantityLitres',
      status: 'delivered',
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.borderGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                widget.colonyName,
                style: const TextStyle(
                  color: AppTheme.navyBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const AppText(
                'Reporting period',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_ReportsPeriod>(
                        value: _period,
                        isExpanded: true,
                        items: _ReportsPeriod.values.map((period) {
                          return DropdownMenuItem(
                            value: period,
                            child: AppText(period.label),
                          );
                        }).toList(),
                        onChanged: _changePeriod,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _exportCsv(data),
                    icon: const Icon(Icons.file_download_outlined, size: 17),
                    label: const AppText('Copy CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navyBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const AppText(
                'Records are filtered by creation date, except visitor '
                'records (expected date) and water deliveries '
                '(delivery date).',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        _sectionHeading(
          'Colony overview',
          'Household and resident registrations in the selected period.',
        ),
        _metricsGrid([
          _metricCard(
            icon: Icons.home_work_outlined,
            title: 'Households added',
            value: '${households.length}',
            subtitle: '$occupied occupied in these records',
          ),
          _metricCard(
            icon: Icons.people_outline_rounded,
            title: 'Residents added',
            value: '${residents.length}',
            subtitle: '$activeResidents active in these records',
          ),
        ]),

        _sectionHeading(
          'Complaints and services',
          'Workload and completion figures for the selected period.',
        ),
        _metricsGrid([
          _metricCard(
            icon: Icons.assignment_outlined,
            title: 'Complaints',
            value: '${complaints.length}',
            subtitle: '$openComplaints open or in progress',
          ),
          _metricCard(
            icon: Icons.cleaning_services_outlined,
            title: 'Cleanliness tasks',
            value: '${cleaning.length}',
            subtitle: '$completedCleaning completed',
          ),
          _metricCard(
            icon: Icons.home_repair_service_outlined,
            title: 'Housekeeping',
            value: '${housekeeping.length}',
            subtitle: '$completedHousekeeping completed',
          ),
          _metricCard(
            icon: Icons.handyman_outlined,
            title: 'Maintenance jobs',
            value: '${jobs.length}',
            subtitle: '${_countStatus(jobs, ['completed'])} completed',
          ),
          _metricCard(
            icon: Icons.payments_outlined,
            title: 'Completed job costs',
            value: _money(_sumField(jobs, 'actualCost', status: 'completed')),
            subtitle: 'Recorded actual costs',
          ),
        ]),

        _sectionHeading(
          'Operational performance',
          'Completion status of records created during the selected period.',
        ),
        _metricsGrid([
          _performanceCard(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Complaint resolution',
            completed: resolvedComplaints,
            total: complaints.length,
            completedLabel: 'resolved or closed',
          ),
          _performanceCard(
            icon: Icons.cleaning_services_outlined,
            title: 'Cleanliness completion',
            completed: completedCleaning,
            total: cleaning.length,
            completedLabel: 'tasks completed',
          ),
          _performanceCard(
            icon: Icons.home_repair_service_outlined,
            title: 'Housekeeping completion',
            completed: completedHousekeeping,
            total: housekeeping.length,
            completedLabel: 'requests completed',
          ),
          _performanceCard(
            icon: Icons.handyman_outlined,
            title: 'Maintenance completion',
            completed: completedMaintenanceJobs,
            total: jobs.length,
            completedLabel: 'jobs completed',
          ),
        ]),

        _sectionHeading(
          'Maintenance dues and collections',
          'Bill values and verified payments for the selected period.',
        ),
        _metricsGrid([
          _metricCard(
            icon: Icons.receipt_long_outlined,
            title: 'Bills issued',
            value: '${bills.length}',
            subtitle: 'Maintenance bills created',
          ),
          _metricCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Billed amount',
            value: _money(_sumField(bills, 'totalAmount')),
            subtitle: 'Total value of listed bills',
          ),
          _metricCard(
            icon: Icons.pending_actions_outlined,
            title: 'Outstanding dues',
            value: _money(outstandingBills),
            subtitle: 'Remaining on listed bills',
          ),
          _metricCard(
            icon: Icons.payments_outlined,
            title: 'Verified collections',
            value: _money(verifiedCollections),
            subtitle:
                '${_countStatus(payments, ['verified'])} verified payments',
          ),
        ]),

        _sectionHeading(
          'Colony activity',
          'Visitor and water supply records for the selected period.',
        ),
        _metricsGrid([
          _metricCard(
            icon: Icons.directions_walk_outlined,
            title: 'Expected visitors',
            value: '${visitors.length}',
            subtitle:
                '${_countStatus(visitors, ['checked_in'])} currently inside',
          ),
          _metricCard(
            icon: Icons.water_drop_outlined,
            title: 'Water deliveries',
            value: '${deliveries.length}',
            subtitle: '${_countStatus(deliveries, ['delivered'])} delivered',
          ),
          _metricCard(
            icon: Icons.opacity_outlined,
            title: 'Water delivered',
            value: '${deliveredLitres.toStringAsFixed(0)} L',
            subtitle: 'Recorded delivered quantity',
          ),
        ]),

        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppTheme.borderGrey),
          ),
          child: const AppText(
            'Reporting note: These are operational summaries from '
            'the existing colony records. Outstanding dues are calculated '
            'from the current paid balance on bills issued in the selected '
            'period. Verified collections are based on payment records '
            'marked verified; they are not bank reconciliation figures.',
            style: TextStyle(
              color: AppTheme.textGrey,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

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
          'Colony Reports',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: AppTranslations.translate('Refresh reports'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<_ReportsData>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: AppTheme.textGrey,
                      size: 45,
                    ),
                    const SizedBox(height: 12),
                    const AppText(
                      'Unable to load colony reports.',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppText(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const AppText('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.navyBlue),
            );
          }

          return _buildReport(snapshot.data!);
        },
      ),
    );
  }
}
