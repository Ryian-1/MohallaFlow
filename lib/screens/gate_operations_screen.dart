// MOHALLAFLOW_GATE_OPERATIONS_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Gate desk workflows. Guard access is granted only through an Admin-created
/// gateOperators/{uid} record and is additionally enforced by Firestore rules.
class GateOperationsScreen extends StatefulWidget {
  const GateOperationsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.isAdmin,
    this.adminName,
    this.workerId,
    this.workerName,
  });

  final String colonyId;
  final String colonyName;
  final bool isAdmin;
  final String? adminName;
  final String? workerId;
  final String? workerName;

  @override
  State<GateOperationsScreen> createState() => _GateOperationsScreenState();
}

class _GateOperationsScreenState extends State<GateOperationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _busy = false;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _colony =>
      _db.collection('colonies').doc(widget.colonyId);
  CollectionReference<Map<String, dynamic>> get _visitors =>
      _colony.collection('visitors');
  CollectionReference<Map<String, dynamic>> get _helpers =>
      _colony.collection('domesticHelpers');
  CollectionReference<Map<String, dynamic>> get _helperVisits =>
      _colony.collection('domesticHelpVisits');
  CollectionReference<Map<String, dynamic>> get _serviceVisits =>
      _colony.collection('serviceProviderVisits');
  CollectionReference<Map<String, dynamic>> get _deliveries =>
      _colony.collection('gateDeliveries');
  CollectionReference<Map<String, dynamic>> get _shifts =>
      _colony.collection('gateShifts');
  CollectionReference<Map<String, dynamic>> get _handovers =>
      _colony.collection('gateHandovers');
  CollectionReference<Map<String, dynamic>> get _operators =>
      _colony.collection('gateOperators');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: widget.isAdmin ? 9 : 8, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
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

  String _date(Object? value) {
    if (value is! Timestamp) return '—';
    final d = value.toDate().toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String value) {
    if ([
      'active',
      'checked_in',
      'inside',
      'received',
      'open',
    ].contains(value)) {
      return const Color(0xFF246B8E);
    }
    if (['expected', 'pending', 'on_hold'].contains(value)) {
      return const Color(0xFF996515);
    }
    if (['suspended', 'cancelled', 'refused', 'closed'].contains(value)) {
      return const Color(0xFFB54747);
    }
    return AppTheme.textGrey;
  }

  Widget _pill(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _statusColor(value).withValues(alpha: .10),
      borderRadius: BorderRadius.circular(30),
    ),
    child: AppText(
      _label(value).toUpperCase(),
      style: TextStyle(
        color: _statusColor(value),
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
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
    } on FirebaseException catch (e) {
      _message('Operation failed (${e.code}). Check access and try again.');
    } catch (e) {
      _message('Operation could not be completed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final tabs = <Tab>[
      Tab(text: AppTranslations.translate('Overview')),
      Tab(text: AppTranslations.translate('Gate log')),
      Tab(text: AppTranslations.translate('Domestic help')),
      Tab(text: AppTranslations.translate('Approved providers')),
      Tab(text: AppTranslations.translate('Service visits')),
      Tab(text: AppTranslations.translate('Deliveries')),
      Tab(text: AppTranslations.translate('Shifts')),
      Tab(text: AppTranslations.translate('Handovers')),
      if (widget.isAdmin)
        Tab(text: AppTranslations.translate('Gate operators')),
    ];
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navyBlue,
        elevation: 0,
        title: AppText(
          widget.isAdmin ? 'Gate Operations' : 'Gate Desk',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppTheme.navyBlue,
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: AppTheme.navyBlue,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _overview(),
          _gateLog(),
          _domesticHelp(),
          _providersView(),
          _serviceVisitsView(),
          _deliveriesView(),
          _shiftsView(),
          _handoversView(),
          if (widget.isAdmin) _operatorsView(),
        ],
      ),
    );
  }

  Widget _count(
    String title,
    String collection, {
    String? field,
    String? equals,
  }) {
    Query<Map<String, dynamic>> query = _colony.collection(collection);
    if (field != null && equals != null) {
      query = query.where(field, isEqualTo: equals);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        final String value = snap.hasError
            ? '—'
            : snap.hasData
            ? '${snap.data!.docs.length}'
            : '…';
        return _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navyBlue,
                ),
              ),
              const SizedBox(height: 4),
              AppText(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textGrey,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (snap.hasError) ...[
                const SizedBox(height: 5),
                AppText(
                  'Could not retrieve this count: ${snap.error}',
                  style: const TextStyle(fontSize: 9, color: AppTheme.textGrey),
                  maxLines: 3,
                ),
                TextButton(
                  onPressed: () {
                    if (mounted) setState(() {});
                  },
                  child: const AppText('Retry'),
                ),
              ] else if (!snap.hasData) ...[
                const SizedBox(height: 5),
                const AppText(
                  'Loading live count…',
                  style: TextStyle(fontSize: 9, color: AppTheme.textGrey),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _overview() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Security desk overview',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppTheme.navyBlue,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              '${widget.colonyName} · ${widget.isAdmin ? 'Administrator view' : 'Guard operator view'}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const AppText(
              'Use this workspace to record arrivals, departures, deliveries and shift handovers. Resident vehicle stickers remain the colony’s existing identification method; this module does not create a vehicle-registration programme.',
              style: TextStyle(
                height: 1.5,
                fontSize: 12,
                color: AppTheme.textGrey,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final int responsiveColumnCount = 2;
          final double horizontalGap = (10).toDouble();
          final double itemWidth =
              (constraints.maxWidth -
                  horizontalGap * (responsiveColumnCount - 1)) /
              responsiveColumnCount;
          return Wrap(
            spacing: horizontalGap,
            runSpacing: 10,
            children:
                ([
                      _count(
                        'Visitors currently inside',
                        'visitors',
                        field: 'status',
                        equals: 'checked_in',
                      ),
                      _count(
                        'Domestic help inside',
                        'domesticHelpVisits',
                        field: 'status',
                        equals: 'inside',
                      ),
                      _count(
                        'Service providers inside',
                        'serviceProviderVisits',
                        field: 'status',
                        equals: 'inside',
                      ),
                      _count(
                        'Deliveries awaiting handover',
                        'gateDeliveries',
                        field: 'status',
                        equals: 'received',
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
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Gate desk operating checklist',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.navyBlue,
              ),
            ),
            SizedBox(height: 8),
            AppText(
              '1. Verify expected visitor details with the host.\n2. Record check-in and check-out at the gate.\n3. Check domestic-help authorisation and validity.\n4. Record packages received and hand them to the correct household.\n5. Record service-provider purpose and host approval.\n6. Complete shift handover with unresolved matters.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppTheme.textGrey,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _gateLog() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _newWalkInVisitor,
            icon: const Icon(Icons.person_add_alt_1),
            label: const AppText('Register walk-in visitor'),
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: (widget.isAdmin
              ? _visitors.snapshots()
              : _visitors
                    .where('status', whereIn: ['expected', 'checked_in'])
                    .snapshots()),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: AppText(
                  'Unable to load visitor register: ${snap.error}',
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = [...snap.data!.docs]
              ..sort((a, b) {
                final av = a.data()['expectedAt'];
                final bv = b.data()['expectedAt'];
                final ad = av is Timestamp
                    ? av.toDate()
                    : DateTime.fromMillisecondsSinceEpoch(0);
                final bd = bv is Timestamp
                    ? bv.toDate()
                    : DateTime.fromMillisecondsSinceEpoch(0);
                return bd.compareTo(ad);
              });
            if (docs.isEmpty) {
              return _empty(
                'No visitor records',
                'Residents’ pre-registrations and Admin walk-ins will appear here.',
                Icons.directions_walk_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, i) {
                final doc = docs[i];
                final d = doc.data();
                final status = d['status'] as String? ?? 'unknown';
                return _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              d['visitorName'] as String? ?? 'Visitor',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navyBlue,
                              ),
                            ),
                          ),
                          _pill(status),
                        ],
                      ),
                      const SizedBox(height: 5),
                      AppText(
                        '${d['hostName'] ?? 'Host not set'} · ${d['hostUnit'] ?? 'Unit not set'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      AppText(
                        '${d['visitorPhone'] ?? ''} · ${d['purpose'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      AppText(
                        'Expected: ${_date(d['expectedAt'])} · In: ${_date(d['checkedInAt'])} · Out: ${_date(d['checkedOutAt'])}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      if (status == 'expected' || status == 'checked_in') ...[
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            if (status == 'expected')
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => doc.reference.update({
                                            'status': 'checked_in',
                                            'checkedInAt':
                                                FieldValue.serverTimestamp(),
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                            'updatedBy': _uid,
                                          }),
                                          'Visitor checked in.',
                                        ),
                                  icon: const Icon(Icons.login),
                                  label: const AppText('Check in'),
                                ),
                              ),
                            if (status == 'expected') const SizedBox(width: 8),
                            if (status == 'checked_in')
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => doc.reference.update({
                                            'status': 'checked_out',
                                            'checkedOutAt':
                                                FieldValue.serverTimestamp(),
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                            'updatedBy': _uid,
                                          }),
                                          'Visitor checked out.',
                                        ),
                                  icon: const Icon(Icons.logout),
                                  label: const AppText('Check out'),
                                ),
                              ),
                          ],
                        ),
                      ],
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

  Future<void> _newWalkInVisitor() async {
    final name = TextEditingController(),
        phone = TextEditingController(),
        purpose = TextEditingController(),
        host = TextEditingController(),
        unit = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Walk-in visitor'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(name, 'Visitor full name *'),
                _field(phone, 'Visitor phone *', type: TextInputType.phone),
                _field(purpose, 'Purpose of visit *'),
                _field(host, 'Resident / host name *'),
                _field(unit, 'Block / flat number'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Check in'),
          ),
        ],
      ),
    );
    if (ok != true) {
      for (final c in [name, phone, purpose, host, unit]) {
        c.dispose();
      }
      return;
    }
    if (name.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        purpose.text.trim().isEmpty ||
        host.text.trim().isEmpty) {
      _message('Complete visitor name, phone, purpose and host.');
      return;
    }
    final uid = _uid;
    if (uid == null) return;
    await _run(
      () => _visitors.add({
        'visitorName': name.text.trim(),
        'visitorPhone': phone.text.trim(),
        'purpose': purpose.text.trim(),
        'hostName': host.text.trim(),
        'hostUnit': unit.text.trim(),
        'hostResidentId': null,
        'hostUid': null,
        'visitType': 'walk_in',
        'status': 'checked_in',
        'expectedAt': FieldValue.serverTimestamp(),
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedOutAt': null,
        'cancelledAt': null,
        'createdBy': uid,
        'createdByRole': widget.isAdmin ? 'admin' : 'gate_operator',
        'createdByName': widget.isAdmin
            ? (widget.adminName ?? 'Admin')
            : (widget.workerName ?? 'Gate operator'),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      }),
      'Walk-in visitor checked in.',
    );
    for (final c in [name, phone, purpose, host, unit]) {
      c.dispose();
    }
  }

  Widget _domesticHelp() => Column(
    children: [
      if (widget.isAdmin)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addHelper,
              icon: const Icon(Icons.person_add_alt_1),
              label: const AppText('Register domestic helper'),
            ),
          ),
        ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: (widget.isAdmin
              ? _helpers.orderBy('name').snapshots()
              : _helpers.where('status', isEqualTo: 'active').snapshots()),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: AppText('Unable to load helper register: ${snap.error}'),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = [...snap.data!.docs]
              ..sort(
                (a, b) => ((a.data()['name'] as String? ?? '').toLowerCase())
                    .compareTo(
                      (b.data()['name'] as String? ?? '').toLowerCase(),
                    ),
              );
            if (docs.isEmpty) {
              return _empty(
                'No domestic-help profiles',
                'Admin can register regular domestic staff with household authorisation.',
                Icons.home_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, i) {
                final doc = docs[i];
                final d = doc.data();
                final expiry = d['validUntil'];
                final expired =
                    expiry is Timestamp &&
                    expiry.toDate().isBefore(DateTime.now());
                final active = d['status'] == 'active' && !expired;
                final displayStatus = expired
                    ? 'expired'
                    : (d['status'] as String? ?? 'inactive');
                return _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              d['name'] as String? ?? 'Helper',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navyBlue,
                              ),
                            ),
                          ),
                          _pill(displayStatus),
                        ],
                      ),
                      AppText(
                        '${d['category'] ?? 'Domestic help'} · ${d['phone'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      AppText(
                        'Household: ${d['houseNumber'] ?? '—'} · Resident: ${d['residentName'] ?? '—'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      AppText(
                        'Authorised until: ${_date(d['validUntil'])}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      if (active) const SizedBox(height: 8),
                      if (active && d['currentVisitId'] == null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : () => _helperCheckIn(doc),
                            icon: const Icon(Icons.login),
                            label: const AppText('Check in'),
                          ),
                        ),
                      if (active && d['currentVisitId'] != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _helperCheckOut(doc),
                            icon: const Icon(Icons.logout),
                            label: const AppText('Check out'),
                          ),
                        ),
                      if (widget.isAdmin)
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            if (active)
                              IconButton(
                                tooltip: AppTranslations.translate(
                                  'Suspend helper',
                                ),
                                onPressed: () =>
                                    _setHelperStatus(doc, 'suspended'),
                                icon: const Icon(
                                  Icons.block_outlined,
                                  color: Colors.redAccent,
                                ),
                              ),
                            IconButton(
                              tooltip: AppTranslations.translate(
                                'Renew authorisation',
                              ),
                              onPressed: () => _renewHelper(doc),
                              icon: const Icon(Icons.event_repeat_outlined),
                            ),
                          ],
                        ),
                      if (widget.isAdmin && !active && d['status'] != 'active')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _setHelperStatus(doc, 'active'),
                            child: const AppText('Reactivate'),
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

  Future<void> _addHelper() async {
    final name = TextEditingController(),
        phone = TextEditingController(),
        category = TextEditingController(text: 'Domestic help'),
        house = TextEditingController(),
        resident = TextEditingController(),
        days = TextEditingController(text: 'Monday-Saturday'),
        notes = TextEditingController();
    DateTime validUntil = DateTime.now().add(const Duration(days: 365));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Register domestic helper'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Full name *'),
                  _field(phone, 'Phone number *', type: TextInputType.phone),
                  _field(category, 'Category / work type'),
                  _field(house, 'House / flat number *'),
                  _field(resident, 'Resident / host name *'),
                  _field(days, 'Allowed days / schedule'),
                  _field(notes, 'Admin notes'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: ctx,
                          initialDate: validUntil,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 1825),
                          ),
                        );
                        if (p != null) setD(() => validUntil = p);
                      },
                      icon: const Icon(Icons.event),
                      label: AppText(
                        'Valid until: ${_date(Timestamp.fromDate(validUntil))}',
                      ),
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
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Save profile'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      for (final c in [name, phone, category, house, resident, days, notes]) {
        c.dispose();
      }
      return;
    }
    if (name.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        house.text.trim().isEmpty ||
        resident.text.trim().isEmpty) {
      _message('Complete all required helper and host details.');
      return;
    }
    await _run(() async {
      final ref = _helpers.doc();
      await ref.set({
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'category': category.text.trim(),
        'houseNumber': house.text.trim(),
        'residentName': resident.text.trim(),
        'hostUid': '',
        'allowedSchedule': days.text.trim(),
        'validUntil': Timestamp.fromDate(
          DateTime(validUntil.year, validUntil.month, validUntil.day, 23, 59),
        ),
        'notes': notes.text.trim(),
        'status': 'active',
        'currentVisitId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      });
    }, 'Domestic helper registered.');
    for (final c in [name, phone, category, house, resident, days, notes]) {
      c.dispose();
    }
  }

  Future<void> _setHelperStatus(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) => _run(() async {
    await _db.runTransaction((tx) async {
      final fresh = await tx.get(doc.reference);
      final data = fresh.data() ?? {};
      if (status == 'suspended' && data['currentVisitId'] != null) {
        throw StateError('Check the helper out before suspending access.');
      }
      tx.update(doc.reference, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      });
    });
  }, 'Helper status updated.');

  Future<void> _renewHelper(DocumentSnapshot<Map<String, dynamic>> doc) async {
    DateTime until = DateTime.now().add(const Duration(days: 365));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Renew domestic-help authorisation'),
          content: TextButton.icon(
            onPressed: () async {
              final p = await showDatePicker(
                context: ctx,
                initialDate: until,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 1825)),
              );
              if (p != null) setD(() => until = p);
            },
            icon: const Icon(Icons.event),
            label: AppText(
              'New valid-until date: ${_date(Timestamp.fromDate(until))}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Renew'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => doc.reference.update({
        'validUntil': Timestamp.fromDate(
          DateTime(until.year, until.month, until.day, 23, 59),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      }),
      'Domestic-help authorisation renewed.',
    );
  }

  Future<void> _helperCheckIn(
    DocumentSnapshot<Map<String, dynamic>> helper,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    await _run(() async {
      final visit = _helperVisits.doc();
      await _db.runTransaction((tx) async {
        final fresh = await tx.get(helper.reference);
        final data = fresh.data() ?? {};
        if (!fresh.exists || data['status'] != 'active') {
          throw StateError('Helper is not active.');
        }
        if (data['currentVisitId'] != null) {
          throw StateError('This helper is already checked in.');
        }
        final until = data['validUntil'];
        if (until is Timestamp && until.toDate().isBefore(DateTime.now())) {
          throw StateError('Authorisation has expired.');
        }
        tx.set(visit, {
          'helperId': helper.id,
          'helperName': data['name'],
          'phone': data['phone'],
          'houseNumber': data['houseNumber'],
          'hostUid': data['hostUid'],
          'status': 'inside',
          'checkedInAt': FieldValue.serverTimestamp(),
          'checkedOutAt': null,
          'guardUid': uid,
          'guardName': widget.isAdmin ? widget.adminName : widget.workerName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(helper.reference, {
          'currentVisitId': visit.id,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
      });
    }, 'Domestic helper checked in.');
  }

  Future<void> _helperCheckOut(
    DocumentSnapshot<Map<String, dynamic>> helper,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    await _run(() async {
      await _db.runTransaction((tx) async {
        final fresh = await tx.get(helper.reference);
        final data = fresh.data() ?? {};
        final id = data['currentVisitId'];
        if (id is! String || id.isEmpty) {
          throw StateError('No active check-in exists.');
        }
        final visitRef = _helperVisits.doc(id);
        final visit = await tx.get(visitRef);
        if (!visit.exists || visit.data()?['status'] != 'inside') {
          throw StateError('Active visit record not found.');
        }
        tx.update(visitRef, {
          'status': 'checked_out',
          'checkedOutAt': FieldValue.serverTimestamp(),
          'checkedOutBy': uid,
        });
        tx.update(helper.reference, {
          'currentVisitId': null,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
      });
    }, 'Domestic helper checked out.');
  }

  Widget _providersView() => Column(
    children: [
      if (widget.isAdmin)
        Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addApprovedProvider,
              icon: const Icon(Icons.add_business_outlined),
              label: const AppText('Add approved service provider'),
            ),
          ),
        ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: (widget.isAdmin
              ? _colony
                    .collection('serviceProviders')
                    .orderBy('name')
                    .snapshots()
              : _colony
                    .collection('serviceProviders')
                    .where('status', isEqualTo: 'active')
                    .snapshots()),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: AppText(
                  'Unable to load approved providers: ${snap.error}',
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return _empty(
                'No approved providers',
                'Admin can register recurring or pre-verified service providers. Walk-in providers can still be entered in Service Visits.',
                Icons.business_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              itemCount: snap.data!.docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, i) {
                final doc = snap.data!.docs[i];
                final d = doc.data();
                final rawStatus = d['status'] as String? ?? 'active';
                final exp = d['validUntil'];
                final expired =
                    exp is Timestamp && exp.toDate().isBefore(DateTime.now());
                final status = expired ? 'expired' : rawStatus;
                return _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              d['name'] as String? ?? 'Provider',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navyBlue,
                              ),
                            ),
                          ),
                          _pill(status),
                        ],
                      ),
                      AppText(
                        '${d['company'] ?? 'Independent'} · ${d['serviceCategory'] ?? 'Service'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      AppText(
                        'Contact: ${d['phone'] ?? '—'} · Valid until: ${_date(d['validUntil'])}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      if (status == 'active')
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _providerCheckIn(doc),
                              icon: const Icon(Icons.login),
                              label: const AppText('Check in'),
                            ),
                            if (widget.isAdmin)
                              TextButton(
                                onPressed: () =>
                                    _providerStatus(doc, 'suspended'),
                                child: const AppText('Suspend'),
                              ),
                          ],
                        ),
                      if (widget.isAdmin)
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _renewProvider(doc),
                              icon: const Icon(Icons.event_repeat_outlined),
                              label: const AppText('Renew'),
                            ),
                            if (rawStatus != 'active')
                              TextButton(
                                onPressed: () => _providerStatus(doc, 'active'),
                                child: const AppText('Reactivate'),
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

  Future<void> _addApprovedProvider() async {
    final name = TextEditingController(),
        phone = TextEditingController(),
        company = TextEditingController(),
        category = TextEditingController(),
        notes = TextEditingController();
    DateTime until = DateTime.now().add(const Duration(days: 365));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Approved service provider'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Contact person / provider name *'),
                  _field(phone, 'Phone number *', type: TextInputType.phone),
                  _field(company, 'Company / agency'),
                  _field(category, 'Service category *'),
                  _field(notes, 'Admin verification notes'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: ctx,
                          initialDate: until,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 1825),
                          ),
                        );
                        if (p != null) setD(() => until = p);
                      },
                      icon: const Icon(Icons.event),
                      label: AppText(
                        'Authorised until: ${_date(Timestamp.fromDate(until))}',
                      ),
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
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Save provider'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      for (final c in [name, phone, company, category, notes]) {
        c.dispose();
      }
      return;
    }
    if (name.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        category.text.trim().isEmpty) {
      _message('Enter provider name, phone and service category.');
      return;
    }
    await _run(
      () => _colony.collection('serviceProviders').add({
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'company': company.text.trim(),
        'serviceCategory': category.text.trim(),
        'notes': notes.text.trim(),
        'validUntil': Timestamp.fromDate(
          DateTime(until.year, until.month, until.day, 23, 59),
        ),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      }),
      'Approved provider saved.',
    );
    for (final c in [name, phone, company, category, notes]) {
      c.dispose();
    }
  }

  Future<void> _providerStatus(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) => _run(
    () => doc.reference.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _uid,
    }),
    'Provider authorisation updated.',
  );

  Future<void> _renewProvider(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    DateTime until = DateTime.now().add(const Duration(days: 365));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Renew service-provider authorisation'),
          content: TextButton.icon(
            onPressed: () async {
              final p = await showDatePicker(
                context: ctx,
                initialDate: until,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 1825)),
              );
              if (p != null) setD(() => until = p);
            },
            icon: const Icon(Icons.event),
            label: AppText(
              'New valid-until date: ${_date(Timestamp.fromDate(until))}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Renew'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => doc.reference.update({
        'validUntil': Timestamp.fromDate(
          DateTime(until.year, until.month, until.day, 23, 59),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      }),
      'Service-provider authorisation renewed.',
    );
  }

  Future<void> _providerCheckIn(
    DocumentSnapshot<Map<String, dynamic>> provider,
  ) async {
    final d = provider.data() ?? {};
    final validUntil = d['validUntil'];
    if (validUntil is Timestamp &&
        validUntil.toDate().isBefore(DateTime.now())) {
      _message(
        'This provider authorisation has expired. Ask Admin to renew it.',
      );
      return;
    }
    final host = TextEditingController(),
        unit = TextEditingController(),
        work = TextEditingController(
          text: d['serviceCategory'] as String? ?? '',
        ),
        vehicle = TextEditingController(),
        permit = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Approved provider check-in'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(host, 'Resident / host name *'),
                _field(unit, 'House / flat number *'),
                _field(work, 'Work purpose *'),
                _field(vehicle, 'Vehicle number (optional)'),
                _field(permit, 'Work permit reference (optional)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Check in'),
          ),
        ],
      ),
    );
    if (ok != true) {
      for (final c in [host, unit, work, vehicle, permit]) {
        c.dispose();
      }
      return;
    }
    if (host.text.trim().isEmpty ||
        unit.text.trim().isEmpty ||
        work.text.trim().isEmpty) {
      _message('Host, unit and purpose are required.');
      return;
    }
    await _run(
      () => _serviceVisits.add({
        'providerId': provider.id,
        'personName': d['name'],
        'phone': d['phone'],
        'company': d['company'] ?? '',
        'workType': work.text.trim(),
        'hostName': host.text.trim(),
        'houseNumber': unit.text.trim(),
        'vehicleNumber': vehicle.text.trim().toUpperCase(),
        'permitReference': permit.text.trim(),
        'status': 'inside',
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedOutAt': null,
        'guardUid': _uid,
        'guardName': widget.isAdmin ? widget.adminName : widget.workerName,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      'Approved service provider checked in.',
    );
    for (final c in [host, unit, work, vehicle, permit]) {
      c.dispose();
    }
  }

  Widget _serviceVisitsView() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _newServiceVisit,
            icon: const Icon(Icons.engineering_outlined),
            label: const AppText('Register service provider entry'),
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: (widget.isAdmin
              ? _serviceVisits
                    .orderBy('checkedInAt', descending: true)
                    .limit(100)
                    .snapshots()
              : _serviceVisits
                    .where('status', isEqualTo: 'inside')
                    .limit(100)
                    .snapshots()),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: AppText('Unable to load service visits: ${snap.error}'),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return _empty(
                'No service-provider entries',
                'Record electricians, plumbers, technicians, delivery contractors and other service visits.',
                Icons.engineering_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              itemCount: snap.data!.docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, i) {
                final doc = snap.data!.docs[i];
                final d = doc.data();
                final status = d['status'] as String? ?? 'inside';
                return _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              d['personName'] as String? ?? 'Service provider',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navyBlue,
                              ),
                            ),
                          ),
                          _pill(status),
                        ],
                      ),
                      AppText(
                        '${d['company'] ?? 'Independent'} · ${d['workType'] ?? 'Service'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      AppText(
                        'Host: ${d['hostName'] ?? '—'} · ${d['houseNumber'] ?? '—'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      AppText(
                        'Vehicle: ${d['vehicleNumber'] ?? '—'} · In: ${_date(d['checkedInAt'])} · Out: ${_date(d['checkedOutAt'])}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      if (status == 'inside')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _run(
                              () => doc.reference.update({
                                'status': 'checked_out',
                                'checkedOutAt': FieldValue.serverTimestamp(),
                                'checkedOutBy': _uid,
                              }),
                              'Service provider checked out.',
                            ),
                            icon: const Icon(Icons.logout),
                            label: const AppText('Check out'),
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

  Future<void> _newServiceVisit() async {
    final person = TextEditingController(),
        phone = TextEditingController(),
        company = TextEditingController(),
        work = TextEditingController(),
        host = TextEditingController(),
        unit = TextEditingController(),
        vehicle = TextEditingController(),
        permit = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Service provider entry'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(person, 'Person name *'),
                _field(phone, 'Phone number *', type: TextInputType.phone),
                _field(company, 'Company / agency'),
                _field(work, 'Work purpose *'),
                _field(host, 'Resident / host name *'),
                _field(unit, 'House / flat number *'),
                _field(vehicle, 'Vehicle registration (optional)'),
                _field(permit, 'Work permit / reference (optional)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Record entry'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (person.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        work.text.trim().isEmpty ||
        host.text.trim().isEmpty ||
        unit.text.trim().isEmpty) {
      _message('Complete all required service-provider details.');
      return;
    }
    await _run(
      () => _serviceVisits.add({
        'personName': person.text.trim(),
        'phone': phone.text.trim(),
        'company': company.text.trim(),
        'workType': work.text.trim(),
        'hostName': host.text.trim(),
        'houseNumber': unit.text.trim(),
        'vehicleNumber': vehicle.text.trim().toUpperCase(),
        'permitReference': permit.text.trim(),
        'status': 'inside',
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedOutAt': null,
        'guardUid': _uid,
        'guardName': widget.isAdmin ? widget.adminName : widget.workerName,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      'Service provider entry recorded.',
    );
    for (final c in [
      person,
      phone,
      company,
      work,
      host,
      unit,
      vehicle,
      permit,
    ]) {
      c.dispose();
    }
  }

  Widget _deliveriesView() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _receiveDelivery,
            icon: const Icon(Icons.inventory_2_outlined),
            label: const AppText('Record incoming delivery'),
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: (widget.isAdmin
              ? _deliveries
                    .orderBy('receivedAt', descending: true)
                    .limit(150)
                    .snapshots()
              : _deliveries
                    .where('status', isEqualTo: 'received')
                    .limit(150)
                    .snapshots()),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: AppText(
                  'Unable to load delivery register: ${snap.error}',
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return _empty(
                'No delivery records',
                'Record courier packages, food deliveries and other items received at the gate.',
                Icons.inventory_2_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              itemCount: snap.data!.docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, i) {
                final doc = snap.data!.docs[i];
                final d = doc.data();
                final status = d['status'] as String? ?? 'received';
                return _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              d['recipientName'] as String? ?? 'Recipient',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navyBlue,
                              ),
                            ),
                          ),
                          _pill(status),
                        ],
                      ),
                      AppText(
                        '${d['courier'] ?? 'Courier'} · ${d['packageCount'] ?? 1} parcel(s)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      AppText(
                        'Unit: ${d['houseNumber'] ?? '—'} · Tracking: ${d['trackingReference'] ?? '—'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      AppText(
                        'Received: ${_date(d['receivedAt'])} · Collected: ${_date(d['collectedAt'])}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      if (status == 'received')
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _deliveryStatus(doc, 'refused'),
                              child: const AppText('Refuse'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _deliveryStatus(doc, 'handed_over'),
                              icon: const Icon(Icons.check),
                              label: const AppText('Hand over'),
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

  Future<void> _receiveDelivery() async {
    final recipient = TextEditingController(),
        unit = TextEditingController(),
        courier = TextEditingController(),
        tracking = TextEditingController(),
        count = TextEditingController(text: '1'),
        notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Incoming delivery'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(recipient, 'Recipient name *'),
                _field(unit, 'House / flat number *'),
                _field(courier, 'Courier / delivery company *'),
                _field(tracking, 'Tracking reference (optional)'),
                _field(count, 'Number of packages', type: TextInputType.number),
                _field(notes, 'Package notes'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Record delivery'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final n = int.tryParse(count.text.trim()) ?? 0;
    if (recipient.text.trim().isEmpty ||
        unit.text.trim().isEmpty ||
        courier.text.trim().isEmpty ||
        n < 1 ||
        n > 50) {
      _message(
        'Enter a recipient, unit, courier and package count from 1 to 50.',
      );
      return;
    }
    await _run(
      () => _deliveries.add({
        'recipientName': recipient.text.trim(),
        'houseNumber': unit.text.trim(),
        'courier': courier.text.trim(),
        'trackingReference': tracking.text.trim(),
        'packageCount': n,
        'notes': notes.text.trim(),
        'status': 'received',
        'receivedAt': FieldValue.serverTimestamp(),
        'receivedBy': _uid,
        'receivedByName': widget.isAdmin ? widget.adminName : widget.workerName,
        'collectedAt': null,
        'collectedByName': null,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      'Delivery recorded.',
    );
    for (final c in [recipient, unit, courier, tracking, count, notes]) {
      c.dispose();
    }
  }

  Future<void> _deliveryStatus(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    String? collectedBy;
    if (status == 'handed_over') {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const AppText('Confirm handover'),
          content: TextField(
            controller: c,
            decoration: InputDecoration(
              labelText: AppTranslations.translate(
                'Name of person collecting package *',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Confirm'),
            ),
          ],
        ),
      );
      if (ok != true) {
        c.dispose();
        return;
      }
      collectedBy = c.text.trim();
      c.dispose();
      if (collectedBy.isEmpty) {
        _message('Enter the name of the person collecting the package.');
        return;
      }
    }
    await _run(
      () => doc.reference.update({
        'status': status,
        'collectedAt': status == 'handed_over'
            ? FieldValue.serverTimestamp()
            : null,
        'collectedByName': collectedBy,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      }),
      status == 'handed_over'
          ? 'Delivery handover recorded.'
          : 'Delivery marked refused.',
    );
  }

  Widget _shiftsView() => Column(
    children: [
      if (!widget.isAdmin)
        Padding(
          padding: const EdgeInsets.all(14),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _shifts.where('guardUid', isEqualTo: _uid).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'Unable to verify your current gate shift. No shift action is available until this check succeeds.',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AppText(
                        snap.error.toString(),
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 10,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (mounted) setState(() {});
                        },
                        child: const AppText('Retry'),
                      ),
                    ],
                  ),
                );
              }
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final openDocs = snap.data!.docs
                  .where((d) => d.data()['status'] == 'open')
                  .toList();
              final active = openDocs.isNotEmpty;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy
                      ? null
                      : active
                      ? () => _closeShift(openDocs.first)
                      : _openShift,
                  icon: Icon(
                    active
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                  ),
                  label: AppText(
                    active ? 'Close current shift' : 'Start gate shift',
                  ),
                ),
              );
            },
          ),
        ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: (widget.isAdmin
              ? _shifts
                    .orderBy('startedAt', descending: true)
                    .limit(100)
                    .snapshots()
              : _shifts
                    .where('guardUid', isEqualTo: _uid)
                    .limit(100)
                    .snapshots()),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: AppText('Unable to load shift register: ${snap.error}'),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return _empty(
                'No gate shifts',
                'Guard operators record the beginning and end of each shift with a handover note.',
                Icons.badge_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              itemCount: snap.data!.docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, i) {
                final d = snap.data!.docs[i].data();
                return _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              d['guardName'] as String? ?? 'Guard',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navyBlue,
                              ),
                            ),
                          ),
                          _pill(d['status'] as String? ?? 'open'),
                        ],
                      ),
                      AppText(
                        'Started: ${_date(d['startedAt'])} · Ended: ${_date(d['endedAt'])}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      if ((d['handoverNote'] as String? ?? '').isNotEmpty)
                        AppText(
                          'Handover: ${d['handoverNote']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textGrey,
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

  Future<void> _openShift() async {
    final uid = _uid;
    if (uid == null) return;
    final now = DateTime.now();
    final id =
        '${uid}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    await _run(() async {
      final ref = _shifts.doc(id);
      await _db.runTransaction((tx) async {
        final old = await tx.get(ref);
        if (old.exists) {
          throw StateError(
            'A shift has already been recorded for this operator today.',
          );
        }
        tx.set(ref, {
          'guardUid': uid,
          'guardId': widget.workerId,
          'guardName': widget.isAdmin ? widget.adminName : widget.workerName,
          'status': 'open',
          'startedAt': FieldValue.serverTimestamp(),
          'endedAt': null,
          'handoverNote': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    }, 'Gate shift started.');
  }

  Future<void> _closeShift(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Close shift & hand over'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: c,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: AppTranslations.translate(
                'Handover notes / unresolved matters *',
              ),
              hintText: AppTranslations.translate(
                'Pending visitors, deliveries, incidents, keys or equipment...',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Close shift'),
          ),
        ],
      ),
    );
    if (ok != true) {
      c.dispose();
      return;
    }
    final note = c.text.trim();
    c.dispose();
    if (note.isEmpty) {
      _message('Handover notes are mandatory.');
      return;
    }
    final uid = _uid;
    if (uid == null) return;
    await _run(() async {
      final handover = _handovers.doc(doc.id);
      await _db.runTransaction((tx) async {
        final fresh = await tx.get(doc.reference);
        if (!fresh.exists ||
            fresh.data()?['status'] != 'open' ||
            fresh.data()?['guardUid'] != uid) {
          throw StateError('This is not your active shift.');
        }
        tx.update(doc.reference, {
          'status': 'closed',
          'endedAt': FieldValue.serverTimestamp(),
          'handoverNote': note,
          'closedBy': uid,
        });
        tx.set(handover, {
          'shiftId': doc.id,
          'outgoingGuardUid': uid,
          'outgoingGuardName': widget.isAdmin
              ? widget.adminName
              : widget.workerName,
          'handoverNote': note,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    }, 'Shift closed and handover recorded.');
  }

  Widget _handoversView() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: (widget.isAdmin
        ? _handovers
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots()
        : _handovers
              .where('outgoingGuardUid', isEqualTo: _uid)
              .limit(100)
              .snapshots()),
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(
          child: AppText('Unable to load handovers: ${snap.error}'),
        );
      }
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snap.data!.docs;
      if (docs.isEmpty) {
        return _empty(
          'No handover records',
          'Closed shifts create permanent handover records for review.',
          Icons.swap_horiz_outlined,
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 9),
        itemBuilder: (context, i) {
          final d = docs[i].data();
          return _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  d['outgoingGuardName'] as String? ?? 'Outgoing guard',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyBlue,
                  ),
                ),
                AppText(
                  'Shift: ${d['shiftId'] ?? '—'} · ${_date(d['createdAt'])}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 7),
                AppText(
                  d['handoverNote'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  Widget _operatorsView() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _assignOperator,
            icon: const Icon(Icons.person_add_alt_1),
            label: const AppText('Assign gate operator'),
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _operators.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: AppText('Unable to load gate operators: ${snap.error}'),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return _empty(
                'No gate operators assigned',
                'Assign an existing active Worker account by its Firebase UID and worker ID.',
                Icons.badge_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              itemCount: snap.data!.docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, i) {
                final doc = snap.data!.docs[i];
                final d = doc.data();
                return _panel(
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              d['workerName'] as String? ?? 'Gate operator',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navyBlue,
                              ),
                            ),
                            AppText(
                              'UID: ${doc.id} · Worker ID: ${d['workerId'] ?? '—'}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _pill(d['isActive'] == true ? 'active' : 'suspended'),
                      Switch(
                        value: d['isActive'] == true,
                        onChanged: (v) => _run(
                          () => doc.reference.update({
                            'isActive': v,
                            'updatedAt': FieldValue.serverTimestamp(),
                            'updatedBy': _uid,
                          }),
                          v ? 'Gate access enabled.' : 'Gate access suspended.',
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

  Future<void> _assignOperator() async {
    final uid = TextEditingController(),
        workerId = TextEditingController(),
        name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Assign gate operator'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(uid, 'Existing Worker Firebase UID *'),
                _field(workerId, 'Worker ID from colony staff register *'),
                _field(name, 'Worker full name *'),
                const SizedBox(height: 8),
                const AppText(
                  'The account must already be an active Worker member of this colony. The UID and worker ID must match its existing membership.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textGrey),
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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Assign'),
          ),
        ],
      ),
    );
    if (ok != true) {
      uid.dispose();
      workerId.dispose();
      name.dispose();
      return;
    }
    if (uid.text.trim().isEmpty ||
        workerId.text.trim().isEmpty ||
        name.text.trim().isEmpty) {
      _message('Complete all gate operator fields.');
      return;
    }
    final operatorUid = uid.text.trim();
    await _run(() async {
      final member = await _colony.collection('members').doc(operatorUid).get();
      final m = member.data() ?? {};
      if (!member.exists ||
          m['role'] != 'worker' ||
          m['status'] != 'active' ||
          m['workerId'] != workerId.text.trim()) {
        throw StateError(
          'The UID must belong to an active Worker membership and the worker ID must match.',
        );
      }
      await _operators.doc(operatorUid).set({
        'uid': operatorUid,
        'workerId': workerId.text.trim(),
        'workerName': name.text.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      });
    }, 'Gate operator assigned.');
    uid.dispose();
    workerId.dispose();
    name.dispose();
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: type,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: AppTranslations.translate(label),
            border: const OutlineInputBorder(),
          ),
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
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 5),
          AppText(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}
// MOHALLAFLOW_GATE_OPERATIONS_SCREEN_END
