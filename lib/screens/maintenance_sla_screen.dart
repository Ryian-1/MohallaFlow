// MOHALLAFLOW_MAINTENANCE_SLA_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Administrative SLA control centre for existing maintenance complaints/jobs.
/// SLA clocks use elapsed calendar time (24x7) and support explicit pause states.
class MaintenanceSlaScreen extends StatefulWidget {
  const MaintenanceSlaScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<MaintenanceSlaScreen> createState() => _MaintenanceSlaScreenState();
}

class _MaintenanceSlaScreenState extends State<MaintenanceSlaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final CollectionReference<Map<String, dynamic>> _cases;
  late final CollectionReference<Map<String, dynamic>> _policies;
  late final CollectionReference<Map<String, dynamic>> _events;
  late final CollectionReference<Map<String, dynamic>> _complaints;
  late final CollectionReference<Map<String, dynamic>> _jobs;
  late final CollectionReference<Map<String, dynamic>> _vendors;
  bool _busy = false;
  String _statusFilter = 'all';
  String _priorityFilter = 'all';
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static const Map<String, Map<String, int>> _defaults = {
    'urgent': {
      'responseMinutes': 15,
      'resolutionMinutes': 240,
      'escalationMinutes': 30,
    },
    'high': {
      'responseMinutes': 60,
      'resolutionMinutes': 720,
      'escalationMinutes': 180,
    },
    'normal': {
      'responseMinutes': 240,
      'resolutionMinutes': 2880,
      'escalationMinutes': 720,
    },
    'low': {
      'responseMinutes': 480,
      'resolutionMinutes': 7200,
      'escalationMinutes': 1440,
    },
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    final colony = FirebaseFirestore.instance
        .collection('colonies')
        .doc(widget.colonyId);
    _cases = colony.collection('maintenanceSlaCases');
    _policies = colony.collection('maintenanceSlaPolicies');
    _events = colony.collection('maintenanceSlaEvents');
    _complaints = colony.collection('complaints');
    _jobs = colony.collection('maintenanceJobs');
    _vendors = colony.collection('maintenanceVendors');
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedPolicies());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _seedPolicies() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      var writes = 0;
      for (final entry in _defaults.entries) {
        final ref = _policies.doc(entry.key);
        final snapshot = await ref.get();
        if (!snapshot.exists) {
          batch.set(ref, {
            'priority': entry.key,
            ...entry.value,
            'enabled': true,
            'clockMode': 'calendar_24x7',
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': _uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          writes++;
        }
      }
      if (writes > 0) await batch.commit();
    } catch (error) {
      debugPrint('SLA default policy seed failed: $error');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(text), behavior: SnackBarBehavior.floating),
    );
  }

  String _label(String value) => value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _dateLabel(Object? value) {
    final date = _date(value);
    if (date == null) return '—';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  int _int(Object? value, [int fallback = 0]) =>
      value is num ? value.toInt() : fallback;

  String _adjustedDueLabel(Map<String, dynamic> data, int targetMinutes) {
    final opened = _date(data['openedAt']);
    if (opened == null) return '—';
    var paused = _int(data['totalPausedMinutes']);
    final pausedAt = _date(data['pausedAt']);
    if (pausedAt != null) {
      paused += DateTime.now().difference(pausedAt).inMinutes;
    }
    return _dateLabel(
      Timestamp.fromDate(opened.add(Duration(minutes: targetMinutes + paused))),
    );
  }

  int _elapsedMinutes(
    Map<String, dynamic> data, {
    DateTime? at,
    int? pauseMinutesOverride,
  }) {
    final opened = _date(data['openedAt']);
    if (opened == null) return 0;
    final end = at ?? DateTime.now();
    var elapsed = end.difference(opened).inMinutes;
    elapsed -= pauseMinutesOverride ?? _int(data['totalPausedMinutes']);
    final pausedAt = _date(data['pausedAt']);
    if (pausedAt != null && end.isAfter(pausedAt)) {
      elapsed -= end.difference(pausedAt).inMinutes;
    }
    return elapsed < 0 ? 0 : elapsed;
  }

  bool _escalationReviewDue(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? 'open';
    if (['resolved', 'closed'].contains(status) || _paused(data)) return false;
    if (_int(data['escalationLevel']) > 0) return false;
    return _elapsedMinutes(data) >= _int(data['escalationMinutes']);
  }

  bool _responseBreached(Map<String, dynamic> data) {
    final responseAt = _date(data['firstResponseAt']);
    if (responseAt != null) {
      return _elapsedMinutes(
            data,
            at: responseAt,
            pauseMinutesOverride: _int(
              data['firstResponsePausedMinutesSnapshot'],
            ),
          ) >
          _int(data['responseMinutes']);
    }
    if (['closed', 'resolved'].contains(data['status'])) return false;
    return _elapsedMinutes(data) > _int(data['responseMinutes']);
  }

  bool _resolutionBreached(Map<String, dynamic> data) {
    final resolvedAt = _date(data['resolvedAt']);
    final elapsed = resolvedAt == null
        ? _elapsedMinutes(data)
        : _elapsedMinutes(data, at: resolvedAt);
    return elapsed > _int(data['resolutionMinutes']);
  }

  bool _paused(Map<String, dynamic> data) =>
      data['status'] == 'waiting_vendor' ||
      data['status'] == 'waiting_resident';

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFB54747);
      case 'high':
        return const Color(0xFFB7791F);
      case 'normal':
        return const Color(0xFF356B8C);
      default:
        return AppTheme.textGrey;
    }
  }

  Widget _pill(String text, {Color? color}) {
    final c = color ?? AppTheme.secondaryNavy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: AppText(
        text.toUpperCase(),
        style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
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

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _message(success);
    } on FirebaseException catch (error) {
      _message('Operation failed (${error.code}). Check access and try again.');
      debugPrint(
        'Maintenance SLA Firebase error: ${error.code} ${error.message}',
      );
    } catch (error) {
      _message('Operation could not be completed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Maintenance SLA & Escalations',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            AppText(
              widget.colonyName,
              style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppTheme.navyBlue,
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: AppTheme.navyBlue,
          tabs: [
            Tab(text: AppTranslations.translate('Overview')),
            Tab(text: AppTranslations.translate('SLA cases')),
            Tab(text: AppTranslations.translate('Untracked')),
            Tab(text: AppTranslations.translate('Policies')),
            Tab(text: AppTranslations.translate('Vendor scorecard')),
            Tab(text: AppTranslations.translate('Event history')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _overviewTab(),
          _casesTab(),
          _untrackedTab(),
          _policiesTab(),
          _vendorTab(),
          _eventsTab(),
        ],
      ),
    );
  }

  Widget _overviewTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _cases.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _error('SLA cases could not be loaded.', snapshot.error);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.docs;
      final active = docs
          .where((d) => !['resolved', 'closed'].contains(d.data()['status']))
          .toList();
      final responseBreaches = active
          .where((d) => _responseBreached(d.data()))
          .length;
      final resolutionBreaches = active
          .where((d) => _resolutionBreached(d.data()))
          .length;
      final paused = active.where((d) => _paused(d.data())).length;
      final escalated = active
          .where((d) => _int(d.data()['escalationLevel']) > 0)
          .length;
      final escalationReviewDue = active
          .where((d) => _escalationReviewDue(d.data()))
          .length;
      final dueSoon = active.where((d) {
        final elapsed = _elapsedMinutes(d.data());
        final remaining = _int(d.data()['resolutionMinutes']) - elapsed;
        return remaining >= 0 && remaining <= 120;
      }).length;
      return ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Service-level control centre',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyBlue,
                  ),
                ),
                const SizedBox(height: 5),
                const AppText(
                  'Track acknowledgement and resolution commitments for existing maintenance complaints and repair jobs. Clocks use calendar time (24×7); waiting-on-vendor and waiting-on-resident states pause the SLA clock.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 9),
                _pill('Calendar clock · 24×7', color: AppTheme.secondaryNavy),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final int responsiveColumnCount = 2;
              final double horizontalGap = (9).toDouble();
              final double itemWidth =
                  (constraints.maxWidth -
                      horizontalGap * (responsiveColumnCount - 1)) /
                  responsiveColumnCount;
              return Wrap(
                spacing: horizontalGap,
                runSpacing: 9,
                children:
                    ([
                          _metric(
                            'Active cases',
                            active.length.toString(),
                            Icons.assignment_outlined,
                          ),
                          _metric(
                            'Response breaches',
                            responseBreaches.toString(),
                            Icons.hourglass_top,
                            warning: responseBreaches > 0,
                          ),
                          _metric(
                            'Resolution breaches',
                            resolutionBreaches.toString(),
                            Icons.warning_amber_rounded,
                            warning: resolutionBreaches > 0,
                          ),
                          _metric(
                            'Due within 2 hours',
                            dueSoon.toString(),
                            Icons.schedule,
                          ),
                          _metric(
                            'Paused clocks',
                            paused.toString(),
                            Icons.pause_circle_outline,
                          ),
                          _metric(
                            'Escalated cases',
                            escalated.toString(),
                            Icons.trending_up,
                          ),
                          _metric(
                            'Escalation review due',
                            escalationReviewDue.toString(),
                            Icons.notifications_active_outlined,
                            warning: escalationReviewDue > 0,
                          ),
                        ])
                        .map<Widget>(
                          (child) => SizedBox(width: itemWidth, child: child),
                        )
                        .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 12),
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Operating rules',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyBlue,
                  ),
                ),
                const SizedBox(height: 8),
                const AppText(
                  '• SLA cases are snapshots linked to an existing complaint or maintenance job.\n• First response is recorded when a case is acknowledged or progressed.\n• Paused time is subtracted only while waiting for a resident or vendor.\n• Escalations are Admin-initiated and permanently recorded.\n• Changing a policy does not alter targets on cases already created.\n• Breach calculations refresh when this screen is opened; no background scheduler or push service is used.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.55,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _tabs.animateTo(1),
              icon: const Icon(Icons.list_alt),
              label: const AppText('Review SLA cases'),
            ),
          ),
        ],
      );
    },
  );

  Widget _metric(
    String label,
    String value,
    IconData icon, {
    bool warning = false,
  }) => _panel(
    Row(
      children: [
        Icon(
          icon,
          color: warning ? const Color(0xFFB54747) : AppTheme.secondaryNavy,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                value,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: warning ? const Color(0xFFB54747) : AppTheme.navyBlue,
                ),
              ),
              AppText(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textGrey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _casesTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _cases.orderBy('openedAt', descending: true).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _error('SLA cases could not be loaded.', snapshot.error);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      var docs = snapshot.data!.docs.toList();
      if (_statusFilter != 'all') {
        docs = docs.where((d) => d.data()['status'] == _statusFilter).toList();
      }
      if (_priorityFilter != 'all') {
        docs = docs
            .where((d) => d.data()['priority'] == _priorityFilter)
            .toList();
      }
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Status'),
                      isDense: true,
                    ),
                    items:
                        [
                              'all',
                              'open',
                              'acknowledged',
                              'in_progress',
                              'waiting_vendor',
                              'waiting_resident',
                              'resolved',
                              'closed',
                              'reopened',
                            ]
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: AppText(
                                  v == 'all' ? 'All statuses' : _label(v),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (v) =>
                        setState(() => _statusFilter = v ?? 'all'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priorityFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Priority'),
                      isDense: true,
                    ),
                    items: ['all', 'urgent', 'high', 'normal', 'low']
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: AppText(
                              v == 'all' ? 'All priorities' : _label(v),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _priorityFilter = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: docs.isEmpty
                ? _empty('No SLA cases match these filters.', Icons.task_alt)
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) => _caseCard(docs[index]),
                  ),
          ),
        ],
      );
    },
  );

  Widget _caseCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final status = d['status']?.toString() ?? 'open';
    final priority = d['priority']?.toString() ?? 'normal';
    final responseBreach = _responseBreached(d);
    final resolutionBreach = _resolutionBreached(d);
    final isClosed = status == 'closed';
    final isTerminal = ['resolved', 'closed'].contains(status);
    final paused = _paused(d);
    final resolvedAt = _date(d['resolvedAt']);
    final elapsed = _elapsedMinutes(d, at: resolvedAt ?? DateTime.now());
    final escalationDue = _escalationReviewDue(d);
    final resolutionRemaining = _int(d['resolutionMinutes']) - elapsed;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  d['sourceTitle']?.toString() ?? 'Maintenance case',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppTheme.navyBlue,
                  ),
                ),
              ),
              _pill(priority, color: _priorityColor(priority)),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              _pill(_label(status)),
              if (paused) _pill('Clock paused', color: const Color(0xFF996515)),
              if (responseBreach)
                _pill('Response breached', color: const Color(0xFFB54747)),
              if (resolutionBreach)
                _pill('Resolution breached', color: const Color(0xFFB54747)),
              if (escalationDue)
                _pill('Escalation review due', color: const Color(0xFFB7791F)),
            ],
          ),
          const SizedBox(height: 7),
          AppText(
            '${_label(d['sourceType']?.toString() ?? 'source')} · ${d['sourceCategory'] ?? 'Uncategorised'} · ${d['location'] ?? 'Location not recorded'}',
            style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
          ),
          AppText(
            'Opened: ${_dateLabel(d['openedAt'])} · Response target: ${_minutes(_int(d['responseMinutes']))} · Resolution target: ${_minutes(_int(d['resolutionMinutes']))}',
            style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
          ),
          AppText(
            'Vendor: ${d['assignedVendorName'] ?? 'Not assigned'} · Escalation level: ${_int(d['escalationLevel'])} · Resolution time remaining: ${resolutionRemaining < 0 ? '${-resolutionRemaining} min overdue' : '$resolutionRemaining min'}',
            style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (!isTerminal)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _assignVendor(doc),
                  icon: const Icon(Icons.business_outlined, size: 16),
                  label: const AppText('Assign vendor'),
                ),
              if (!isTerminal)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _escalate(doc),
                  icon: const Icon(Icons.trending_up, size: 16),
                  label: const AppText('Escalate'),
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _showCaseDetails(doc),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const AppText('Details'),
              ),
              if (!isClosed)
                PopupMenuButton<String>(
                  tooltip: AppTranslations.translate('Change case state'),
                  onSelected: (v) => _changeStatus(doc, v),
                  itemBuilder: (_) => _availableTransitions(status)
                      .map(
                        (v) =>
                            PopupMenuItem(value: v, child: AppText(_label(v))),
                      )
                      .toList(),
                  child: const Chip(
                    label: AppText('Update state'),
                    avatar: Icon(Icons.sync_alt, size: 16),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _availableTransitions(String status) {
    switch (status) {
      case 'open':
        return [
          'acknowledged',
          'in_progress',
          'waiting_vendor',
          'waiting_resident',
        ];
      case 'acknowledged':
        return [
          'in_progress',
          'waiting_vendor',
          'waiting_resident',
          'resolved',
        ];
      case 'in_progress':
        return ['waiting_vendor', 'waiting_resident', 'resolved'];
      case 'waiting_vendor':
      case 'waiting_resident':
        return ['in_progress', 'resolved'];
      case 'resolved':
        return ['closed', 'reopened'];
      case 'reopened':
        return [
          'acknowledged',
          'in_progress',
          'waiting_vendor',
          'waiting_resident',
          'resolved',
        ];
      default:
        return [];
    }
  }

  Widget _untrackedTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _cases.snapshots(),
    builder: (context, caseSnapshot) {
      if (caseSnapshot.hasError) {
        return _error('SLA cases could not be loaded.', caseSnapshot.error);
      }
      if (!caseSnapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final tracked = caseSnapshot.data!.docs.map((d) {
        final data = d.data();
        return data['sourceKey']?.toString() ??
            '${data['sourceType']}:${data['sourceId']}';
      }).toSet();
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _panel(
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Bring existing work under SLA control',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyBlue,
                  ),
                ),
                SizedBox(height: 5),
                AppText(
                  'Select an existing resident maintenance complaint or repair job to create its SLA snapshot. The original source record remains the system of record.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const AppText(
            'Maintenance complaints',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(height: 7),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _complaints
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _error('Complaints could not be loaded.', snap.error);
              }
              if (!snap.hasData) return const LinearProgressIndicator();
              final docs = snap.data!.docs
                  .where(
                    (d) =>
                        d.data()['complaintType'] == 'maintenance' &&
                        !['closed', 'resolved'].contains(d.data()['status']) &&
                        !tracked.contains('complaint:${d.id}'),
                  )
                  .toList();
              if (docs.isEmpty) {
                return _empty(
                  'No untracked open maintenance complaints.',
                  Icons.assignment_turned_in_outlined,
                );
              }
              return Column(
                children: docs
                    .map((doc) => _sourceCard(doc.id, doc.data(), 'complaint'))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          const AppText(
            'Repair jobs',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(height: 7),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _jobs.orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _error('Repair jobs could not be loaded.', snap.error);
              }
              if (!snap.hasData) return const LinearProgressIndicator();
              final docs = snap.data!.docs.where((d) {
                final data = d.data();
                final key = _sourceKey('job', d.id, data);
                return !['completed', 'cancelled'].contains(data['status']) &&
                    !tracked.contains(key);
              }).toList();
              if (docs.isEmpty) {
                return _empty(
                  'No untracked open repair jobs.',
                  Icons.handyman_outlined,
                );
              }
              return Column(
                children: docs
                    .map((doc) => _sourceCard(doc.id, doc.data(), 'job'))
                    .toList(),
              );
            },
          ),
        ],
      );
    },
  );

  Widget _sourceCard(
    String id,
    Map<String, dynamic> data,
    String type,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _panel(
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  data['title']?.toString() ?? 'Maintenance item',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navyBlue,
                  ),
                ),
                AppText(
                  '${data['category'] ?? data['complaintType'] ?? 'Other'} · ${data['priority'] ?? 'normal'} · ${data['location'] ?? 'Location not recorded'}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textGrey,
                  ),
                ),
                AppText(
                  'Source ID: $id',
                  style: const TextStyle(fontSize: 9, color: AppTheme.textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _busy ? null : () => _createCase(type, id, data),
            child: const AppText('Track SLA'),
          ),
        ],
      ),
    ),
  );

  String _sourceKey(
    String sourceType,
    String sourceId,
    Map<String, dynamic> source,
  ) {
    final linkedComplaintId = sourceType == 'job'
        ? source['sourceComplaintId']?.toString()
        : null;
    if (linkedComplaintId != null && linkedComplaintId.isNotEmpty) {
      return 'complaint:$linkedComplaintId';
    }
    return '$sourceType:$sourceId';
  }

  String _complaintStatusFor(String caseStatus) {
    switch (caseStatus) {
      case 'acknowledged':
        return 'acknowledged';
      case 'resolved':
        return 'resolved';
      case 'closed':
        return 'closed';
      case 'in_progress':
      case 'waiting_vendor':
      case 'waiting_resident':
      case 'reopened':
        return 'in_progress';
      default:
        return 'submitted';
    }
  }

  String _jobStatusFor(
    String caseStatus,
    String currentStatus,
    bool hasVendor,
  ) {
    switch (caseStatus) {
      case 'in_progress':
      case 'waiting_vendor':
      case 'waiting_resident':
        if (currentStatus == 'in_progress' || currentStatus == 'assigned') {
          return currentStatus;
        }
        return hasVendor ? 'assigned' : 'open';
      case 'resolved':
      case 'closed':
        return 'completed';
      case 'reopened':
        return hasVendor ? 'assigned' : 'open';
      case 'acknowledged':
        if (currentStatus == 'in_progress' || currentStatus == 'assigned') {
          return currentStatus;
        }
        return hasVendor ? 'assigned' : 'open';
      default:
        return currentStatus;
    }
  }

  Future<void> _createCase(
    String sourceType,
    String sourceId,
    Map<String, dynamic> source,
  ) async {
    await _run(() async {
      final priority =
          ['urgent', 'high', 'normal', 'low'].contains(source['priority'])
          ? source['priority'].toString()
          : 'normal';
      final policySnap = await _policies.doc(priority).get();
      final policy = policySnap.data() ?? _defaults[priority]!;
      if (policy['enabled'] == false) {
        throw StateError('The $priority SLA policy is disabled.');
      }
      final sourceKey = _sourceKey(sourceType, sourceId, source);
      final caseId = 'sla_${sourceKey.replaceAll(':', '_')}';
      final linkedComplaintCandidate = sourceType == 'complaint'
          ? sourceId
          : source['sourceComplaintId']?.toString();
      final linkedComplaintId =
          linkedComplaintCandidate == null || linkedComplaintCandidate.isEmpty
          ? null
          : linkedComplaintCandidate;
      final linkedJobId = sourceType == 'job' ? sourceId : null;
      final caseRef = _cases.doc(caseId);
      final eventRef = _events.doc();
      final now = DateTime.now();
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final existing = await tx.get(caseRef);
        if (existing.exists) {
          throw StateError('This source already has an SLA case.');
        }
        tx.set(caseRef, {
          'sourceType': sourceType,
          'sourceId': sourceId,
          'sourceKey': sourceKey,
          'linkedComplaintId': linkedComplaintId,
          'linkedJobId': linkedJobId,
          'sourceTitle': source['title']?.toString() ?? 'Maintenance item',
          'sourceCategory':
              source['category']?.toString() ??
              source['complaintType']?.toString() ??
              'Other',
          'location': source['location']?.toString() ?? '',
          'priority': priority,
          'sourcePrioritySnapshot': priority,
          'sourceStatusSnapshot': source['status']?.toString() ?? '',
          'status': 'open',
          'responseMinutes': _int(
            policy['responseMinutes'],
            _defaults[priority]!['responseMinutes']!,
          ),
          'resolutionMinutes': _int(
            policy['resolutionMinutes'],
            _defaults[priority]!['resolutionMinutes']!,
          ),
          'escalationMinutes': _int(
            policy['escalationMinutes'],
            _defaults[priority]!['escalationMinutes']!,
          ),
          'policyUpdatedAtSnapshot': policy['updatedAt'],
          'openedAt': Timestamp.fromDate(now),
          'responseDueAt': Timestamp.fromDate(
            now.add(
              Duration(
                minutes: _int(
                  policy['responseMinutes'],
                  _defaults[priority]!['responseMinutes']!,
                ),
              ),
            ),
          ),
          'resolutionDueAt': Timestamp.fromDate(
            now.add(
              Duration(
                minutes: _int(
                  policy['resolutionMinutes'],
                  _defaults[priority]!['resolutionMinutes']!,
                ),
              ),
            ),
          ),
          'firstResponseAt': null,
          'firstResponsePausedMinutesSnapshot': 0,
          'resolvedAt': null,
          'closedAt': null,
          'pausedAt': null,
          'totalPausedMinutes': 0,
          'assignedVendorId': sourceType == 'job' ? source['vendorId'] : null,
          'assignedVendorName': sourceType == 'job'
              ? source['vendorName']
              : null,
          'assignedVendorPhone': sourceType == 'job'
              ? source['vendorPhone']
              : null,
          'assignedTo': null,
          'escalationLevel': 0,
          'reopenedCount': 0,
          'createdBy': _uid,
          'createdByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(
          eventRef,
          _eventData(
            caseId,
            'case_created',
            'SLA tracking started from $sourceType $sourceId.',
          ),
        );
      });
    }, 'SLA case created.');
  }

  Map<String, dynamic> _eventData(
    String caseId,
    String type,
    String note, {
    Map<String, dynamic>? extra,
  }) => {
    'caseId': caseId,
    'eventType': type,
    'note': note,
    'extra': extra ?? <String, dynamic>{},
    'createdBy': _uid,
    'createdByName': widget.adminName,
    'createdAt': FieldValue.serverTimestamp(),
  };

  Future<void> _changeStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String nextStatus,
  ) async {
    final d = doc.data();
    final noteController = TextEditingController();
    String? error;
    final requiredNote = [
      'resolved',
      'closed',
      'reopened',
    ].contains(nextStatus);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText('${_label(nextStatus)} case'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                'Current status: ${_label(d['status']?.toString() ?? 'open')}',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: requiredNote
                      ? AppTranslations.translate('Reason / resolution notes *')
                      : AppTranslations.translate('Notes (optional)'),
                  hintText: nextStatus == 'reopened'
                      ? AppTranslations.translate(
                          'Why is this case being reopened?',
                        )
                      : AppTranslations.translate('Add operational context'),
                ),
              ),
              if (error != null)
                AppText(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (requiredNote && noteController.text.trim().isEmpty) {
                  setDialogState(() => error = 'A reason is required.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const AppText('Confirm'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final now = DateTime.now();
      final note = noteController.text.trim();
      final ref = _cases.doc(doc.id);
      final eventRef = _events.doc();
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final latest = await tx.get(ref);
        if (!latest.exists) throw StateError('SLA case no longer exists.');
        final data = latest.data()!;
        final oldStatus = data['status']?.toString() ?? 'open';
        if (!_availableTransitions(oldStatus).contains(nextStatus)) {
          throw StateError(
            'This status transition is no longer valid. Refresh and retry.',
          );
        }

        DocumentSnapshot<Map<String, dynamic>>? sourceJob;
        DocumentSnapshot<Map<String, dynamic>>? sourceComplaint;
        final sourceType = data['sourceType']?.toString() ?? '';
        if (sourceType == 'job') {
          sourceJob = await tx.get(_jobs.doc(data['sourceId'].toString()));
          if (!sourceJob.exists) {
            throw StateError('Linked maintenance job no longer exists.');
          }
          if (sourceJob.data()?['status'] == 'cancelled') {
            throw StateError(
              'The linked repair job was cancelled. Review the source job before changing its SLA case.',
            );
          }
          final complaintId = data['linkedComplaintId']?.toString() ?? '';
          if (complaintId.isNotEmpty) {
            sourceComplaint = await tx.get(_complaints.doc(complaintId));
            if (!sourceComplaint.exists) {
              throw StateError(
                'Linked maintenance complaint no longer exists.',
              );
            }
          }
        } else if (sourceType == 'complaint') {
          sourceComplaint = await tx.get(
            _complaints.doc(data['sourceId'].toString()),
          );
          if (!sourceComplaint.exists) {
            throw StateError('Linked maintenance complaint no longer exists.');
          }
        }

        final update = <String, dynamic>{
          'status': nextStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final pauseAt = _date(data['pausedAt']);
        if (['waiting_vendor', 'waiting_resident'].contains(nextStatus) &&
            !['waiting_vendor', 'waiting_resident'].contains(oldStatus)) {
          update['pausedAt'] = Timestamp.fromDate(now);
        }
        if (!['waiting_vendor', 'waiting_resident'].contains(nextStatus) &&
            pauseAt != null) {
          final pausedMinutes = now.difference(pauseAt).inMinutes;
          update['totalPausedMinutes'] =
              _int(data['totalPausedMinutes']) +
              (pausedMinutes < 0 ? 0 : pausedMinutes);
          update['pausedAt'] = null;
        }
        if (data['firstResponseAt'] == null &&
            [
              'acknowledged',
              'in_progress',
              'waiting_vendor',
              'waiting_resident',
              'resolved',
            ].contains(nextStatus)) {
          update['firstResponseAt'] = FieldValue.serverTimestamp();
          update['firstResponsePausedMinutesSnapshot'] = _int(
            data['totalPausedMinutes'],
          );
        }
        if (nextStatus == 'resolved') {
          update['resolvedAt'] = FieldValue.serverTimestamp();
        }
        if (nextStatus == 'closed') {
          update['closedAt'] = FieldValue.serverTimestamp();
        }
        if (nextStatus == 'reopened') {
          update['resolvedAt'] = null;
          update['closedAt'] = null;
          update['reopenedCount'] = _int(data['reopenedCount']) + 1;
          update['lastReopenedAt'] = FieldValue.serverTimestamp();
          update['lastReopenReason'] = note;
        }
        update['lastStatusNote'] = note;

        // Keep the existing maintenance source record aligned with SLA state.
        if (sourceJob != null) {
          final jobData = sourceJob.data()!;
          final jobStatus = _jobStatusFor(
            nextStatus,
            jobData['status']?.toString() ?? 'open',
            (jobData['vendorId'] ?? '').toString().isNotEmpty,
          );
          tx.update(sourceJob.reference, {
            'status': jobStatus,
            'completedAt': jobStatus == 'completed'
                ? FieldValue.serverTimestamp()
                : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        if (sourceComplaint != null) {
          tx.update(sourceComplaint.reference, {
            'status': _complaintStatusFor(nextStatus),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        tx.update(ref, update);
        tx.set(
          eventRef,
          _eventData(
            doc.id,
            'status_changed',
            '${_label(oldStatus)} → ${_label(nextStatus)}${note.isEmpty ? '' : ': $note'}${sourceJob != null || sourceComplaint != null ? ' Source record synchronised.' : ''}',
          ),
        );
      });
    }, 'SLA case updated.');
  }

  Future<void> _assignVendor(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final vendorsSnapshot = await _vendors
        .where('status', isEqualTo: 'active')
        .get();
    if (!mounted) return;
    final vendors = vendorsSnapshot.docs;
    if (vendors.isEmpty) {
      _message('No active maintenance vendors are registered.');
      return;
    }
    String? selected = doc.data()['assignedVendorId']?.toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Assign maintenance vendor'),
          content: DropdownButtonFormField<String?>(
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: AppTranslations.translate('Vendor'),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: AppText('Unassigned'),
              ),
              ...vendors.map(
                (v) => DropdownMenuItem<String?>(
                  value: v.id,
                  child: AppText(
                    v.data()['vendorName']?.toString() ?? 'Vendor',
                  ),
                ),
              ),
            ],
            onChanged: (v) => setDialogState(() => selected = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Save assignment'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      Map<String, dynamic>? vendor;
      if (selected != null) {
        final docSnap = vendors.firstWhere((v) => v.id == selected);
        vendor = docSnap.data();
      }
      final ref = _cases.doc(doc.id);
      final eventRef = _events.doc();
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final latest = await tx.get(ref);
        if (!latest.exists) throw StateError('SLA case no longer exists.');
        final latestData = latest.data()!;
        DocumentSnapshot<Map<String, dynamic>>? linkedJob;
        if (latestData['sourceType'] == 'job') {
          linkedJob = await tx.get(
            _jobs.doc(latestData['sourceId'].toString()),
          );
          if (!linkedJob.exists) {
            throw StateError('Linked maintenance job no longer exists.');
          }
          if ([
            'completed',
            'cancelled',
          ].contains(linkedJob.data()?['status'])) {
            throw StateError(
              'A completed or cancelled repair job cannot be reassigned.',
            );
          }
        }
        tx.update(ref, {
          'assignedVendorId': selected,
          'assignedVendorName': vendor?['vendorName'],
          'assignedVendorPhone': vendor?['phoneNumber'],
          'assignedAt': FieldValue.serverTimestamp(),
          'assignedBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (linkedJob != null) {
          final jobData = linkedJob.data()!;
          final currentStatus = jobData['status']?.toString() ?? 'open';
          tx.update(linkedJob.reference, {
            'vendorId': selected,
            'vendorName': vendor?['vendorName'],
            'vendorPhone': vendor?['phoneNumber'],
            'status': selected != null && currentStatus == 'open'
                ? 'assigned'
                : (selected == null && currentStatus == 'assigned'
                      ? 'open'
                      : currentStatus),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        tx.set(
          eventRef,
          _eventData(
            doc.id,
            'vendor_assigned',
            selected == null
                ? 'Vendor assignment cleared.'
                : 'Assigned to ${vendor?['vendorName'] ?? 'vendor'}.${linkedJob != null ? ' Linked repair job synchronised.' : ''}',
            extra: {'vendorId': selected},
          ),
        );
      });
    }, 'Vendor assignment updated.');
  }

  Future<void> _escalate(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final controller = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Escalate SLA case'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText(
                'Escalation does not reset the response or resolution clock. Record why additional management attention is required.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: AppTranslations.translate('Escalation reason *'),
                ),
              ),
              if (error != null)
                AppText(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  setDialogState(() => error = 'Enter an escalation reason.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const AppText('Escalate'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final ref = _cases.doc(doc.id);
      final eventRef = _events.doc();
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final latest = await tx.get(ref);
        if (!latest.exists) throw StateError('SLA case no longer exists.');
        final level = _int(latest.data()?['escalationLevel']) + 1;
        tx.update(ref, {
          'escalationLevel': level,
          'lastEscalatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(
          eventRef,
          _eventData(
            doc.id,
            'escalated',
            'Level $level: ${controller.text.trim()}',
            extra: {'level': level},
          ),
        );
      });
    }, 'SLA case escalated.');
  }

  Future<void> _showCaseDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(d['sourceTitle']?.toString() ?? 'SLA case'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detail('Source', '${d['sourceType']} · ${d['sourceId']}'),
                _detail('Status', _label(d['status']?.toString() ?? 'open')),
                _detail('Priority', d['priority']?.toString() ?? 'normal'),
                _detail('Opened', _dateLabel(d['openedAt'])),
                _detail('First response', _dateLabel(d['firstResponseAt'])),
                _detail(
                  'Adjusted response due',
                  _adjustedDueLabel(d, _int(d['responseMinutes'])),
                ),
                _detail(
                  'Adjusted resolution due',
                  _adjustedDueLabel(d, _int(d['resolutionMinutes'])),
                ),
                _detail('Resolved', _dateLabel(d['resolvedAt'])),
                _detail(
                  'Total paused minutes',
                  _int(d['totalPausedMinutes']).toString(),
                ),
                _detail(
                  'Assigned vendor',
                  d['assignedVendorName']?.toString() ?? 'Unassigned',
                ),
                _detail(
                  'Escalation level',
                  _int(d['escalationLevel']).toString(),
                ),
                _detail('Reopen count', _int(d['reopenedCount']).toString()),
                _detail(
                  'Last status note',
                  d['lastStatusNote']?.toString() ?? '—',
                ),
              ],
            ),
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

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: AppText(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
          ),
        ),
        Expanded(
          child: AppText(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _policiesTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _policies.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _error('SLA policies could not be loaded.', snapshot.error);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.docs.toList()
        ..sort(
          (a, b) => ['urgent', 'high', 'normal', 'low']
              .indexOf(a.id)
              .compareTo(['urgent', 'high', 'normal', 'low'].indexOf(b.id)),
        );
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _panel(
            const AppText(
              'Priority-based response and resolution targets. These are configurable operational defaults, not statutory or contractual standards. The clock runs 24×7; documented waiting states pause elapsed time.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppTheme.textGrey,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...docs.map(
            (doc) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            _label(doc.id),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.navyBlue,
                            ),
                          ),
                        ),
                        _pill(
                          doc.data()['enabled'] == true
                              ? 'Enabled'
                              : 'Disabled',
                          color: doc.data()['enabled'] == true
                              ? const Color(0xFF356B8C)
                              : AppTheme.textGrey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    AppText(
                      'First response: ${_minutes(_int(doc.data()['responseMinutes']))} · Resolution: ${_minutes(_int(doc.data()['resolutionMinutes']))} · Escalation review: ${_minutes(_int(doc.data()['escalationMinutes']))}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGrey,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _editPolicy(doc),
                        icon: const Icon(Icons.tune, size: 16),
                        label: const AppText('Configure'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Future<void> _editPolicy(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final d = doc.data();
    final response = TextEditingController(
      text: _int(d['responseMinutes']).toString(),
    );
    final resolution = TextEditingController(
      text: _int(d['resolutionMinutes']).toString(),
    );
    final escalation = TextEditingController(
      text: _int(d['escalationMinutes']).toString(),
    );
    bool enabled = d['enabled'] != false;
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AppText('Configure ${_label(doc.id)} SLA'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _numberField(response, 'First response target (minutes)'),
                _numberField(resolution, 'Resolution target (minutes)'),
                _numberField(
                  escalation,
                  'Escalation review threshold (minutes)',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const AppText('Policy enabled'),
                  value: enabled,
                  onChanged: (v) => setDialogState(() => enabled = v),
                ),
                if (error != null)
                  AppText(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final values = [
                  response.text,
                  resolution.text,
                  escalation.text,
                ].map(int.tryParse).toList();
                if (values.any((v) => v == null || v <= 0)) {
                  setDialogState(
                    () => error =
                        'All SLA targets must be positive whole minutes.',
                  );
                  return;
                }
                if (values[0]! > values[1]!) {
                  setDialogState(
                    () => error =
                        'Response target cannot exceed the resolution target.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const AppText('Save policy'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await doc.reference.update({
        'responseMinutes': int.parse(response.text),
        'resolutionMinutes': int.parse(resolution.text),
        'escalationMinutes': int.parse(escalation.text),
        'enabled': enabled,
        'clockMode': 'calendar_24x7',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      });
    }, 'SLA policy saved. Existing cases keep their original target snapshot.');
  }

  Widget _numberField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: AppTranslations.translate(label),
          ),
        ),
      );

  Widget _vendorTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _cases.snapshots(),
    builder: (context, casesSnapshot) {
      if (casesSnapshot.hasError) {
        return _error('SLA cases could not be loaded.', casesSnapshot.error);
      }
      if (!casesSnapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final cases = casesSnapshot.data!.docs
          .map((d) => d.data())
          .where((d) => (d['assignedVendorId'] ?? '').toString().isNotEmpty)
          .toList();
      final ids = cases.map((d) => d['assignedVendorId'].toString()).toSet();
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _panel(
            const AppText(
              'Vendor performance is calculated from SLA cases assigned in this module. It is an operational indicator, not a contractual rating or automatic vendor penalty.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppTheme.textGrey,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (ids.isEmpty)
            _empty(
              'No SLA cases have vendor assignments yet.',
              Icons.business_outlined,
            ),
          ...ids.map((id) {
            final records = cases
                .where((d) => d['assignedVendorId'] == id)
                .toList();
            final resolved = records
                .where((d) => ['resolved', 'closed'].contains(d['status']))
                .length;
            final breached = records
                .where((d) => _resolutionBreached(d))
                .length;
            final responseBreach = records
                .where((d) => _responseBreached(d))
                .length;
            final name =
                records.first['assignedVendorName']?.toString() ?? 'Vendor';
            final percentage = records.isEmpty
                ? 0
                : (resolved * 100 / records.length).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _pill('${records.length} assigned'),
                        _pill('$resolved resolved'),
                        _pill('$percentage% completion'),
                        _pill(
                          '$responseBreach response breaches',
                          color: responseBreach > 0
                              ? const Color(0xFFB54747)
                              : AppTheme.textGrey,
                        ),
                        _pill(
                          '$breached resolution breaches',
                          color: breached > 0
                              ? const Color(0xFFB54747)
                              : AppTheme.textGrey,
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

  Widget _eventsTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _events
        .orderBy('createdAt', descending: true)
        .limit(250)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _error('SLA event history could not be loaded.', snapshot.error);
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.docs;
      if (docs.isEmpty) {
        return _empty('No SLA events recorded yet.', Icons.history);
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final d = docs[i].data();
          return _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        _label(d['eventType']?.toString() ?? 'event'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navyBlue,
                        ),
                      ),
                    ),
                    AppText(
                      _dateLabel(d['createdAt']),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AppText(
                  d['note']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textDark,
                  ),
                ),
                AppText(
                  'Case: ${d['caseId'] ?? '—'} · By: ${d['createdByName'] ?? d['createdBy'] ?? '—'}',
                  style: const TextStyle(fontSize: 9, color: AppTheme.textGrey),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  String _minutes(int value) {
    if (value < 60) return '$value min';
    if (value < 1440) {
      return '${(value / 60).toStringAsFixed(value % 60 == 0 ? 0 : 1)} hr';
    }
    return '${(value / 1440).toStringAsFixed(value % 1440 == 0 ? 0 : 1)} days';
  }

  Widget _empty(String text, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppTheme.textGrey),
          const SizedBox(height: 8),
          AppText(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
        ],
      ),
    ),
  );

  Widget _error(String message, Object? error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: AppText(
        '$message\n$error',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
      ),
    ),
  );
}
// MOHALLAFLOW_MAINTENANCE_SLA_SCREEN_END
