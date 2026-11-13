// MOHALLAFLOW_RESIDENT_SELF_SERVICE_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Resident self-service workspace. Residents submit requests; only Admin
/// updates the authoritative residents/households master records.
class ResidentSelfServiceScreen extends StatefulWidget {
  const ResidentSelfServiceScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.isAdmin,
    this.residentId,
    this.residentName,
    this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final bool isAdmin;
  final String? residentId;
  final String? residentName;
  final String? adminName;

  @override
  State<ResidentSelfServiceScreen> createState() =>
      _ResidentSelfServiceScreenState();
}

class _ResidentSelfServiceScreenState extends State<ResidentSelfServiceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _saving = false;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _colony =>
      _db.collection('colonies').doc(widget.colonyId);
  DocumentReference<Map<String, dynamic>> get _resident =>
      _colony.collection('residents').doc(widget.residentId ?? '');
  CollectionReference<Map<String, dynamic>> get _residents =>
      _colony.collection('residents');
  CollectionReference<Map<String, dynamic>> get _households =>
      _colony.collection('households');
  CollectionReference<Map<String, dynamic>> get _profileRequests =>
      _colony.collection('residentChangeRequests');
  CollectionReference<Map<String, dynamic>> get _householdRequests =>
      _colony.collection('householdMemberRequests');
  CollectionReference<Map<String, dynamic>> get _serviceRequests =>
      _colony.collection('residentServiceRequests');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: widget.isAdmin ? 3 : 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
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
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
      case 'applied':
      case 'fulfilled':
      case 'completed':
        return const Color(0xFF246B8E);
      case 'pending':
      case 'needs_info':
      case 'in_review':
        return const Color(0xFF996515);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFB54747);
      default:
        return AppTheme.textGrey;
    }
  }

  Widget _status(String value) => Container(
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
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(height: 5),
          AppText(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _save(Future<void> Function() action, String success) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      _message(success);
    } on FirebaseException catch (e) {
      _message(
        'Request failed (${e.code}). Please check your access and try again.',
      );
    } catch (e) {
      _message('Unable to complete request: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final tabLabels = widget.isAdmin
        ? [
            Tab(text: AppTranslations.translate('Profile changes')),
            Tab(text: AppTranslations.translate('Household changes')),
            Tab(text: AppTranslations.translate('Letters & requests')),
          ]
        : [
            Tab(text: AppTranslations.translate('My profile')),
            Tab(text: AppTranslations.translate('My household')),
            Tab(text: AppTranslations.translate('My requests')),
            Tab(text: AppTranslations.translate('Letters & NOC')),
          ];
    final children = widget.isAdmin
        ? [
            _adminQueue(
              _profileRequests,
              'Profile change requests',
              'resident',
            ),
            _adminQueue(
              _householdRequests,
              'Household member requests',
              'household',
            ),
            _adminQueue(
              _serviceRequests,
              'Letters and resident service requests',
              'service',
            ),
          ]
        : [_myProfile(), _myHousehold(), _myRequests(), _myLetters()];
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navyBlue,
        elevation: 0,
        title: AppText(
          widget.isAdmin
              ? 'Resident Self-Service Desk'
              : 'My Household & Requests',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppTheme.navyBlue,
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: AppTheme.navyBlue,
          tabs: tabLabels,
        ),
      ),
      body: TabBarView(controller: _tabs, children: children),
    );
  }

  Widget _myProfile() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _resident.snapshots(),
    builder: (context, snap) {
      if (snap.hasError) {
        return _empty(
          'Profile unavailable',
          'We could not read your resident record. Contact the colony Admin.',
          Icons.person_off_outlined,
        );
      }
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!snap.data!.exists) {
        return _empty(
          'Resident record not found',
          'Your account is not linked to an active resident record.',
          Icons.person_off_outlined,
        );
      }
      final d = snap.data!.data()!;
      final householdId = d['householdId'] as String? ?? '';
      return ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Verified resident profile',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyBlue,
                  ),
                ),
                const SizedBox(height: 5),
                const AppText(
                  'These are the details currently held in the colony register. Changes are submitted for Admin verification; your registered record is not edited directly.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 12),
                _profileRow('Full name', d['fullName']),
                _profileRow('Phone', d['phoneNumber']),
                _profileRow('Email', d['email']),
                _profileRow(
                  'Block / House',
                  '${d['blockId'] ?? ''} / ${d['houseNumber'] ?? ''}',
                ),
                _profileRow('Relationship', d['relationshipToHead']),
                _profileRow('Resident status', d['residentStatus']),
                _profileRow('Household reference', householdId),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : () => _openProfileChange(d),
                    icon: const Icon(Icons.edit_note),
                    label: const AppText('Request profile correction'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (householdId.isNotEmpty)
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _households.doc(householdId).get(),
              builder: (context, householdSnap) {
                if (householdSnap.hasError ||
                    !householdSnap.hasData ||
                    !householdSnap.data!.exists) {
                  return const SizedBox.shrink();
                }
                final h = householdSnap.data!.data()!;
                return _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'Household details',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _profileRow('Household head', h['householdHeadName']),
                      _profileRow('Primary contact', h['primaryPhone']),
                      _profileRow('Occupancy', h['occupancyStatus']),
                    ],
                  ),
                );
              },
            ),
        ],
      );
    },
  );

  Widget _profileRow(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: AppText(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
          ),
        ),
        Expanded(
          flex: 5,
          child: AppText(
            (value?.toString().trim().isNotEmpty ?? false)
                ? value.toString()
                : 'Not provided',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.navyBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget
  _myHousehold() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _resident.snapshots(),
    builder: (context, residentSnap) {
      if (residentSnap.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _empty(
                'Unable to load resident details',
                'Your household information could not be retrieved. ${residentSnap.error}',
                Icons.cloud_off_outlined,
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
      if (residentSnap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (residentSnap.data?.exists != true) {
        return _empty(
          'Resident profile not found',
          'Ask the Colony Admin to verify your resident registration.',
          Icons.person_search_outlined,
        );
      }
      final householdId =
          residentSnap.data!.data()?['householdId'] as String? ?? '';
      if (householdId.isEmpty) {
        return _empty(
          'No household linked',
          'Ask the Admin to link your resident profile to a household.',
          Icons.home_work_outlined,
        );
      }
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'Household membership',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const AppText(
                    'View the active residents linked to your household. Additions, corrections and removals require Admin approval.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _openHouseholdRequest(
                              householdId,
                              action: 'add',
                            ),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const AppText('Request household member addition'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _residents
                  .where('householdId', isEqualTo: householdId)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: AppText(
                      'Unable to load household residents: ${snap.error}',
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs
                    .where((doc) => doc.data()['residentStatus'] == 'active')
                    .toList();
                if (docs.isEmpty) {
                  return _empty(
                    'No active members',
                    'There are no active resident records linked to this household.',
                    Icons.people_outline,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    return _panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppText(
                                  d['fullName'] as String? ?? 'Resident',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.navyBlue,
                                  ),
                                ),
                              ),
                              _status('active'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          AppText(
                            '${d['relationshipToHead'] ?? 'Relationship not set'} · ${d['phoneNumber'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textGrey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _openHouseholdRequest(
                                        householdId,
                                        action: 'update',
                                        target: doc,
                                      ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const AppText('Request correction'),
                              ),
                              TextButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _openHouseholdRequest(
                                        householdId,
                                        action: 'remove',
                                        target: doc,
                                      ),
                                icon: const Icon(
                                  Icons.person_remove_outlined,
                                  size: 16,
                                ),
                                label: const AppText('Request removal'),
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
    },
  );

  Future<void> _openProfileChange(Map<String, dynamic> current) async {
    final name = TextEditingController(
      text: current['fullName']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: current['phoneNumber']?.toString() ?? '',
    );
    final email = TextEditingController(
      text: current['email']?.toString() ?? '',
    );
    final reason = TextEditingController();
    String? error;
    try {
      final submit = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: const AppText('Request profile correction'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _input(name, 'Full name'),
                    _input(
                      phone,
                      'Mobile number',
                      keyboard: TextInputType.phone,
                    ),
                    _input(
                      email,
                      'Email address',
                      keyboard: TextInputType.emailAddress,
                    ),
                    _input(reason, 'Reason for correction', maxLines: 3),
                    if (error != null)
                      AppText(
                        error!,
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    const SizedBox(height: 4),
                    const AppText(
                      'Leave unchanged fields as currently shown. Admin verifies and applies approved changes in the resident register.',
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
                onPressed: () {
                  final p = phone.text.trim();
                  if (reason.text.trim().length < 5) {
                    setDialog(
                      () => error =
                          'Please provide a reason (at least 5 characters).',
                    );
                    return;
                  }
                  if (p.isNotEmpty && !RegExp(r'^[6-9][0-9]{9}$').hasMatch(p)) {
                    setDialog(
                      () => error =
                          'Enter a valid 10-digit Indian mobile number.',
                    );
                    return;
                  }
                  if (email.text.trim().isNotEmpty &&
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(email.text.trim())) {
                    setDialog(() => error = 'Enter a valid email address.');
                    return;
                  }
                  if (name.text.trim().isEmpty) {
                    setDialog(() => error = 'Full name cannot be empty.');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const AppText('Submit request'),
              ),
            ],
          ),
        ),
      );
      if (submit != true) return;
      final uid = _uid;
      if (uid == null) return;
      final changes = <String, dynamic>{};
      if (name.text.trim() != (current['fullName']?.toString() ?? '')) {
        changes['fullName'] = name.text.trim();
      }
      if (phone.text.trim() != (current['phoneNumber']?.toString() ?? '')) {
        changes['phoneNumber'] = phone.text.trim();
      }
      if (email.text.trim() != (current['email']?.toString() ?? '')) {
        changes['email'] = email.text.trim();
      }
      if (changes.isEmpty) {
        _message('No profile changes were entered.');
        return;
      }
      await _save(
        () => _profileRequests.add({
          'requestType': 'profile_correction',
          'requesterUid': uid,
          'residentId': widget.residentId,
          'householdId': current['householdId'],
          'requesterName': widget.residentName ?? current['fullName'],
          'currentValues': {
            'fullName': current['fullName'],
            'phoneNumber': current['phoneNumber'],
            'email': current['email'],
          },
          'requestedChanges': changes,
          'reason': reason.text.trim(),
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        'Profile correction request submitted.',
      );
    } finally {
      name.dispose();
      phone.dispose();
      email.dispose();
      reason.dispose();
    }
  }

  Future<void> _openHouseholdRequest(
    String householdId, {
    required String action,
    QueryDocumentSnapshot<Map<String, dynamic>>? target,
  }) async {
    final d = target?.data() ?? <String, dynamic>{};
    final name = TextEditingController(text: d['fullName']?.toString() ?? '');
    final phone = TextEditingController(
      text: d['phoneNumber']?.toString() ?? '',
    );
    final email = TextEditingController(text: d['email']?.toString() ?? '');
    final reason = TextEditingController();
    String relationship = d['relationshipToHead']?.toString() ?? 'Other';
    String? error;
    try {
      final submit = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: AppText('${_label(action)} household member request'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (action != 'remove') ...[
                      _input(name, 'Full name'),
                      _input(
                        phone,
                        'Mobile number',
                        keyboard: TextInputType.phone,
                      ),
                      _input(
                        email,
                        'Email address',
                        keyboard: TextInputType.emailAddress,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: relationship,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Relationship to household head',
                          ),
                        ),
                        items:
                            [
                                  'Owner',
                                  'Spouse',
                                  'Child',
                                  'Parent',
                                  'Tenant',
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
                          if (v != null) setDialog(() => relationship = v);
                        },
                      ),
                    ],
                    _input(
                      reason,
                      action == 'remove'
                          ? 'Reason for removal request'
                          : 'Reason / supporting details',
                      maxLines: 3,
                    ),
                    if (error != null)
                      AppText(
                        error!,
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    const SizedBox(height: 5),
                    const AppText(
                      'The household register changes only after Admin review and verification.',
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
                onPressed: () {
                  if (reason.text.trim().length < 5) {
                    setDialog(
                      () => error =
                          'Please enter a reason (at least 5 characters).',
                    );
                    return;
                  }
                  if (action != 'remove' && name.text.trim().isEmpty) {
                    setDialog(() => error = 'Full name is required.');
                    return;
                  }
                  if (action != 'remove' &&
                      phone.text.trim().isNotEmpty &&
                      !RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone.text.trim())) {
                    setDialog(
                      () => error = 'Enter a valid 10-digit mobile number.',
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const AppText('Submit request'),
              ),
            ],
          ),
        ),
      );
      if (submit != true) return;
      final uid = _uid;
      if (uid == null) return;
      final changes = action == 'remove'
          ? <String, dynamic>{}
          : <String, dynamic>{
              'fullName': name.text.trim(),
              'phoneNumber': phone.text.trim(),
              'email': email.text.trim(),
              'relationshipToHead': relationship,
            };
      await _save(
        () => _householdRequests.add({
          'requestType': action,
          'requesterUid': uid,
          'requesterResidentId': widget.residentId,
          'householdId': householdId,
          'targetResidentId': target?.id,
          'requesterName': widget.residentName ?? '',
          'targetName': d['fullName'] ?? name.text.trim(),
          'requestedChanges': changes,
          'reason': reason.text.trim(),
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        'Household member request submitted.',
      );
    } finally {
      name.dispose();
      phone.dispose();
      email.dispose();
      reason.dispose();
    }
  }

  Widget _myRequests() => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      const AppText(
        'Track profile and household requests',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.navyBlue,
        ),
      ),
      const SizedBox(height: 6),
      const AppText(
        'Requests are visible only to you and authorised colony Admins. Admin may ask for more information before deciding.',
        style: TextStyle(fontSize: 11, color: AppTheme.textGrey),
      ),
      const SizedBox(height: 12),
      _residentRequestList(_profileRequests, 'Profile changes'),
      const SizedBox(height: 12),
      _residentRequestList(_householdRequests, 'Household changes'),
    ],
  );

  Widget _myLetters() => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Request an official colony letter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.navyBlue,
              ),
            ),
            const SizedBox(height: 5),
            const AppText(
              'Use this for address/residency confirmation, owner/tenant confirmation, no-dues confirmation or another formal request. The Admin verifies the record and records the issued reference.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textGrey,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _openServiceRequest,
                icon: const Icon(Icons.post_add),
                label: const AppText('New letter / service request'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _residentRequestList(_serviceRequests, 'Letter requests'),
    ],
  );

  Future<void> _openServiceRequest() async {
    final purpose = TextEditingController();
    final details = TextEditingController();
    final reason = TextEditingController();
    String type = 'address_confirmation';
    String? error;
    DateTime requiredBy = DateTime.now().add(const Duration(days: 7));
    try {
      final submit = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: const AppText('New letter / service request'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Request type'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'address_confirmation',
                          child: AppText('Address confirmation'),
                        ),
                        DropdownMenuItem(
                          value: 'residency_certificate',
                          child: AppText('Residency certificate'),
                        ),
                        DropdownMenuItem(
                          value: 'ownership_confirmation',
                          child: AppText('Ownership confirmation'),
                        ),
                        DropdownMenuItem(
                          value: 'tenant_confirmation',
                          child: AppText('Tenant confirmation'),
                        ),
                        DropdownMenuItem(
                          value: 'no_dues_confirmation',
                          child: AppText('No-dues confirmation'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: AppText('Other official request'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialog(() => type = v);
                      },
                    ),
                    _input(purpose, 'Purpose / where it will be submitted'),
                    _input(
                      details,
                      'Details required on the letter',
                      maxLines: 3,
                    ),
                    _input(reason, 'Additional explanation', maxLines: 2),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: AppText(
                            'Required by',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: requiredBy,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setDialog(() => requiredBy = picked);
                            }
                          },
                          child: AppText(_date(Timestamp.fromDate(requiredBy))),
                        ),
                      ],
                    ),
                    if (error != null)
                      AppText(
                        error!,
                        style: const TextStyle(color: Colors.red, fontSize: 11),
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
                onPressed: () {
                  if (purpose.text.trim().length < 3) {
                    setDialog(
                      () => error = 'Please provide the intended purpose.',
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const AppText('Submit'),
              ),
            ],
          ),
        ),
      );
      if (submit != true) return;
      final uid = _uid;
      if (uid == null) return;
      await _save(
        () => _serviceRequests.add({
          'requestType': type,
          'requesterUid': uid,
          'residentId': widget.residentId,
          'requesterName': widget.residentName ?? '',
          'purpose': purpose.text.trim(),
          'details': details.text.trim(),
          'reason': reason.text.trim(),
          'requiredBy': Timestamp.fromDate(requiredBy),
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        'Letter request submitted.',
      );
    } finally {
      purpose.dispose();
      details.dispose();
      reason.dispose();
    }
  }

  Widget _residentRequestList(
    CollectionReference<Map<String, dynamic>> collection,
    String title,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: collection.where('requesterUid', isEqualTo: _uid).snapshots(),
    builder: (context, snap) {
      if (snap.hasError) {
        return _panel(
          AppText(
            '$title could not be loaded: ${snap.error}',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
        );
      }
      if (!snap.hasData) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final docs = [...snap.data!.docs]
        ..sort((a, b) {
          final av = a.data()['createdAt'];
          final bv = b.data()['createdAt'];
          final ad = av is Timestamp
              ? av.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          final bd = bv is Timestamp
              ? bv.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
      return _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.navyBlue,
              ),
            ),
            const SizedBox(height: 8),
            if (docs.isEmpty)
              const AppText(
                'No requests yet.',
                style: TextStyle(fontSize: 11, color: AppTheme.textGrey),
              ),
            ...docs.map((doc) {
              final d = doc.data();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            _label(d['requestType']?.toString() ?? 'request'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        _status(d['status']?.toString() ?? 'pending'),
                      ],
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      d['reason']?.toString() ?? d['purpose']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGrey,
                      ),
                    ),
                    if ((d['reviewNotes'] as String? ?? '').isNotEmpty)
                      AppText(
                        'Admin: ${d['reviewNotes']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                    AppText(
                      'Submitted ${_date(d['createdAt'])}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    },
  );

  Widget _adminQueue(
    CollectionReference<Map<String, dynamic>> collection,
    String title,
    String kind,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: collection.snapshots(),
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(child: AppText('Unable to load $title: ${snap.error}'));
      }
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = [...snap.data!.docs]
        ..sort((a, b) {
          final av = a.data()['createdAt'];
          final bv = b.data()['createdAt'];
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
          'No requests',
          'New resident submissions will appear here.',
          Icons.inbox_outlined,
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 9),
        itemBuilder: (context, i) {
          final doc = docs[i];
          final d = doc.data();
          final status = d['status']?.toString() ?? 'pending';
          final changes = d['requestedChanges'] is Map
              ? Map<String, dynamic>.from(d['requestedChanges'] as Map)
              : <String, dynamic>{};
          final current = d['currentValues'] is Map
              ? Map<String, dynamic>.from(d['currentValues'] as Map)
              : <String, dynamic>{};
          return _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        '${_label(d['requestType']?.toString() ?? 'request')} · ${d['requesterName'] ?? 'Resident'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navyBlue,
                        ),
                      ),
                    ),
                    _status(status),
                  ],
                ),
                const SizedBox(height: 5),
                AppText(
                  'Resident ID: ${d['residentId'] ?? d['requesterResidentId'] ?? '—'} · Household: ${d['householdId'] ?? '—'}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textGrey,
                  ),
                ),
                if (current.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  const AppText(
                    'Currently registered',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                  ...current.entries.map(
                    (e) => AppText(
                      '${_label(e.key)}: ${e.value}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ),
                ],
                if (changes.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  const AppText(
                    'Requested changes',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                  ...changes.entries.map(
                    (e) => AppText(
                      '${_label(e.key)}: ${e.value}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ),
                ],
                if ((d['targetName'] as String? ?? '').isNotEmpty)
                  AppText(
                    'Target member: ${d['targetName']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                if ((d['purpose'] as String? ?? '').isNotEmpty)
                  AppText(
                    'Purpose: ${d['purpose']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                if ((d['details'] as String? ?? '').isNotEmpty)
                  AppText(
                    'Details: ${d['details']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                if ((d['reason'] as String? ?? '').isNotEmpty)
                  AppText(
                    'Reason: ${d['reason']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                AppText(
                  'Submitted: ${_date(d['createdAt'])} · Required by: ${_date(d['requiredBy'])}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textGrey,
                  ),
                ),
                if ((d['reviewNotes'] as String? ?? '').isNotEmpty)
                  AppText(
                    'Review notes: ${d['reviewNotes']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                if ((d['issuedReference'] as String? ?? '').isNotEmpty)
                  AppText(
                    'Issued reference: ${d['issuedReference']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                if (status == 'pending' ||
                    status == 'needs_info' ||
                    (kind == 'service' && status == 'approved') ||
                    ((kind == 'resident' || kind == 'household') &&
                        status == 'approved')) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (status == 'pending' || status == 'needs_info')
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => _review(doc, kind, 'needs_info'),
                          child: const AppText('Need information'),
                        ),
                      if (status == 'pending' || status == 'needs_info')
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => _review(doc, kind, 'rejected'),
                          child: const AppText('Reject'),
                        ),
                      if (status == 'pending' || status == 'needs_info')
                        ElevatedButton(
                          onPressed: _saving
                              ? null
                              : () => kind == 'service'
                                    ? _review(doc, kind, 'approved')
                                    : _applyAndApprove(doc, kind),
                          child: AppText(
                            kind == 'service' ? 'Approve' : 'Approve & apply',
                          ),
                        ),
                      if (kind == 'service' && status == 'approved')
                        ElevatedButton(
                          onPressed: _saving
                              ? null
                              : () => _review(doc, kind, 'fulfilled'),
                          child: const AppText('Mark fulfilled'),
                        ),
                      if ((kind == 'resident' || kind == 'household') &&
                          status == 'approved')
                        ElevatedButton(
                          onPressed: _saving
                              ? null
                              : () => _review(doc, kind, 'applied'),
                          child: const AppText('Mark changes applied'),
                        ),
                    ],
                  ),
                ],
                if ((kind == 'resident' || kind == 'household') &&
                    status == 'approved')
                  const AppText(
                    'Apply the verified changes in the existing Residents / Households register first, then mark this request applied.',
                    style: TextStyle(fontSize: 10, color: AppTheme.textGrey),
                  ),
              ],
            ),
          );
        },
      );
    },
  );

  Future<void> _applyAndApprove(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String kind,
  ) async {
    if (kind != 'resident' && kind != 'household') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Approve and apply changes?'),
        content: const AppText(
          'This will update the official resident / household register and '
          'mark the request as applied in one Firestore transaction. '
          'The change cannot be undone from this request screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Approve & apply'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      _message('Please sign in again before reviewing this request.');
      return;
    }

    await _save(() async {
      await _db.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(doc.reference);
        if (!requestSnapshot.exists) {
          throw StateError('This request no longer exists. Refresh the queue.');
        }
        final request = requestSnapshot.data()!;
        final currentStatus = request['status']?.toString() ?? '';
        if (currentStatus != 'pending' && currentStatus != 'needs_info') {
          throw StateError(
            'This request is no longer pending. Refresh the queue before retrying.',
          );
        }

        final rawChanges = request['requestedChanges'];
        if (rawChanges is! Map) {
          throw StateError('The request has no valid change details.');
        }
        final changes = Map<String, dynamic>.from(rawChanges);
        final householdId = request['householdId']?.toString() ?? '';
        if (householdId.isEmpty) {
          throw StateError('The request is not linked to a household.');
        }

        final householdReference = _households.doc(householdId);
        final householdSnapshot = await transaction.get(householdReference);
        if (!householdSnapshot.exists) {
          throw StateError('The linked household could not be found.');
        }
        final household = householdSnapshot.data()!;
        final householdUpdate = <String, dynamic>{};

        if (kind == 'resident') {
          if (request['requestType'] != 'profile_correction') {
            throw StateError('This is not a profile correction request.');
          }
          final residentId = request['residentId']?.toString() ?? '';
          if (residentId.isEmpty) {
            throw StateError('The request is not linked to a resident record.');
          }
          const allowedFields = {'fullName', 'phoneNumber', 'email'};
          if (changes.isEmpty || !allowedFields.containsAll(changes.keys)) {
            throw StateError('The requested profile fields are invalid.');
          }

          final residentReference = _residents.doc(residentId);
          final residentSnapshot = await transaction.get(residentReference);
          if (!residentSnapshot.exists) {
            throw StateError('The resident record could not be found.');
          }
          final resident = residentSnapshot.data()!;
          if (resident['residentStatus'] != 'active' ||
              resident['householdId'] != householdId) {
            throw StateError(
              'The resident is no longer active in this household.',
            );
          }

          final residentUpdate = <String, dynamic>{};
          if (changes.containsKey('fullName')) {
            final name = changes['fullName']?.toString().trim() ?? '';
            if (name.isEmpty || name.length > 100) {
              throw StateError('The requested resident name is invalid.');
            }
            residentUpdate['fullName'] = name;
          }
          if (changes.containsKey('phoneNumber')) {
            final phone = changes['phoneNumber']?.toString().trim() ?? '';
            if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
              throw StateError('The requested mobile number is invalid.');
            }
            residentUpdate['phoneNumber'] = phone;
          }
          if (changes.containsKey('email')) {
            final email = changes['email']?.toString().trim() ?? '';
            if (email.length > 160 ||
                (email.isNotEmpty &&
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))) {
              throw StateError('The requested email address is invalid.');
            }
            residentUpdate['email'] = email;
          }
          if (residentUpdate.isEmpty) {
            throw StateError('There are no profile changes to apply.');
          }
          residentUpdate['updatedAt'] = FieldValue.serverTimestamp();
          transaction.update(residentReference, residentUpdate);

          final isHouseholdHead =
              resident['relationshipToHead'] == 'Owner' ||
              resident['fullName'] == household['householdHeadName'];
          if (isHouseholdHead) {
            if (residentUpdate.containsKey('fullName')) {
              householdUpdate['householdHeadName'] = residentUpdate['fullName'];
            }
            if (residentUpdate.containsKey('phoneNumber')) {
              householdUpdate['primaryPhone'] = residentUpdate['phoneNumber'];
            }
          }
        } else {
          final action = request['requestType']?.toString() ?? '';
          if (!{'add', 'update', 'remove'}.contains(action)) {
            throw StateError('The household request type is invalid.');
          }
          const relationships = {
            'Owner',
            'Spouse',
            'Child',
            'Parent',
            'Tenant',
            'Other',
          };
          final requesterResidentId =
              request['requesterResidentId']?.toString() ?? '';
          if (requesterResidentId.isEmpty) {
            throw StateError('The requesting resident is not linked.');
          }
          final requesterReference = _residents.doc(requesterResidentId);
          final requesterSnapshot = await transaction.get(requesterReference);
          if (!requesterSnapshot.exists ||
              requesterSnapshot.data()?['residentStatus'] != 'active' ||
              requesterSnapshot.data()?['householdId'] != householdId) {
            throw StateError(
              'The requesting resident is no longer active in this household.',
            );
          }

          if (action == 'add') {
            const allowedFields = {
              'fullName',
              'phoneNumber',
              'email',
              'relationshipToHead',
            };
            if (!allowedFields.containsAll(changes.keys) ||
                !changes.keys.toSet().containsAll(allowedFields)) {
              throw StateError(
                'The new household member details are incomplete.',
              );
            }
            final name = changes['fullName']?.toString().trim() ?? '';
            final phone = changes['phoneNumber']?.toString().trim() ?? '';
            final email = changes['email']?.toString().trim() ?? '';
            final relationship =
                changes['relationshipToHead']?.toString() ?? '';
            if (name.isEmpty || name.length > 100) {
              throw StateError('Enter a valid full name for the new member.');
            }
            if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
              throw StateError(
                'A valid 10-digit mobile number is required to register the new member.',
              );
            }
            if (email.length > 160 ||
                (email.isNotEmpty &&
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))) {
              throw StateError('The new member email address is invalid.');
            }
            if (!relationships.contains(relationship)) {
              throw StateError(
                'Select a valid relationship to the household head.',
              );
            }
            final newResidentReference = _residents.doc();
            transaction.set(newResidentReference, {
              'fullName': name,
              'phoneNumber': phone,
              'email': email,
              'householdId': householdId,
              'blockId': household['blockId'],
              'houseNumber': household['houseNumber'],
              'relationshipToHead': relationship,
              'residentStatus': 'active',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'createdBy': uid,
            });
          } else {
            final targetResidentId =
                request['targetResidentId']?.toString() ?? '';
            if (targetResidentId.isEmpty) {
              throw StateError('The target household resident is missing.');
            }
            final targetReference = _residents.doc(targetResidentId);
            final targetSnapshot = await transaction.get(targetReference);
            if (!targetSnapshot.exists) {
              throw StateError(
                'The target resident record could not be found.',
              );
            }
            final target = targetSnapshot.data()!;
            if (target['residentStatus'] != 'active' ||
                target['householdId'] != householdId) {
              throw StateError(
                'The target resident is no longer active in this household.',
              );
            }

            if (action == 'remove') {
              final isHouseholdHead =
                  target['relationshipToHead'] == 'Owner' ||
                  target['fullName'] == household['householdHeadName'];
              if (targetResidentId == requesterResidentId || isHouseholdHead) {
                throw StateError(
                  'A household head or the requesting account cannot be removed here. Use the Move-In & Move-Out workflow.',
                );
              }
              transaction.update(targetReference, {
                'residentStatus': 'inactive',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } else {
              const allowedFields = {
                'fullName',
                'phoneNumber',
                'email',
                'relationshipToHead',
              };
              if (!allowedFields.containsAll(changes.keys) ||
                  !changes.keys.toSet().containsAll(allowedFields)) {
                throw StateError(
                  'The household member correction is incomplete.',
                );
              }
              final name = changes['fullName']?.toString().trim() ?? '';
              final phone = changes['phoneNumber']?.toString().trim() ?? '';
              final email = changes['email']?.toString().trim() ?? '';
              final relationship =
                  changes['relationshipToHead']?.toString() ?? '';
              if (name.isEmpty || name.length > 100) {
                throw StateError('Enter a valid full name.');
              }
              if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
                throw StateError('Enter a valid 10-digit mobile number.');
              }
              if (email.length > 160 ||
                  (email.isNotEmpty &&
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))) {
                throw StateError('The email address is invalid.');
              }
              if (!relationships.contains(relationship)) {
                throw StateError(
                  'Select a valid relationship to the household head.',
                );
              }
              transaction.update(targetReference, {
                'fullName': name,
                'phoneNumber': phone,
                'email': email,
                'relationshipToHead': relationship,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              final isHouseholdHead =
                  target['relationshipToHead'] == 'Owner' ||
                  target['fullName'] == household['householdHeadName'] ||
                  relationship == 'Owner';
              if (isHouseholdHead) {
                householdUpdate['householdHeadName'] = name;
                householdUpdate['primaryPhone'] = phone;
              }
            }
          }
        }

        if (householdUpdate.isNotEmpty) {
          householdUpdate['updatedAt'] = FieldValue.serverTimestamp();
          transaction.update(householdReference, householdUpdate);
        }

        transaction.update(doc.reference, {
          'status': 'applied',
          'reviewerUid': uid,
          'reviewerName': widget.adminName ?? 'Admin',
          'reviewNotes':
              'Approved and applied to the official resident records.',
          'reviewedAt': FieldValue.serverTimestamp(),
          'appliedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    }, 'Request approved and applied to the official resident records.');
  }

  Future<void> _review(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String kind,
    String status,
  ) async {
    final notes = TextEditingController();
    final issuedReference = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: AppText(
            status == 'fulfilled'
                ? 'Fulfil letter request'
                : status == 'applied'
                ? 'Mark approved changes as applied'
                : '${_label(status)} request',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: notes,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: status == 'applied'
                        ? AppTranslations.translate(
                            'Application confirmation / reference',
                          )
                        : AppTranslations.translate('Review notes / reason'),
                    hintText: AppTranslations.translate(
                      'Required for rejection, information request or application confirmation',
                    ),
                  ),
                ),
                if (status == 'fulfilled')
                  TextField(
                    controller: issuedReference,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Issued letter / reference number *',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if ((status == 'rejected' ||
                        status == 'needs_info' ||
                        status == 'applied') &&
                    notes.text.trim().length < 5) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: AppText(
                        'Please enter at least five characters.',
                      ),
                    ),
                  );
                  return;
                }
                if (status == 'fulfilled' &&
                    issuedReference.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: AppText('Enter the issued reference.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const AppText('Save review'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final uid = _uid;
      if (uid == null) return;
      final update = <String, dynamic>{
        'status': status,
        'reviewerUid': uid,
        'reviewerName': widget.adminName ?? 'Admin',
        'reviewNotes': notes.text.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (status == 'fulfilled') {
        update['issuedReference'] = issuedReference.text.trim();
        update['fulfilledAt'] = FieldValue.serverTimestamp();
      }
      await _save(
        () => doc.reference.update(update),
        'Request marked ${_label(status).toLowerCase()}.',
      );
    } finally {
      notes.dispose();
      issuedReference.dispose();
    }
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: AppTranslations.translate(label),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}
// MOHALLAFLOW_RESIDENT_SELF_SERVICE_SCREEN_END
