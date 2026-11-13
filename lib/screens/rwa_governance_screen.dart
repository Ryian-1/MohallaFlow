// MOHALLAFLOW_RWA_GOVERNANCE_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Admin-only RWA governance, meeting, resolution and compliance workspace.
/// Document entries are metadata/reference records; files are not uploaded here.
class RwaGovernanceScreen extends StatefulWidget {
  const RwaGovernanceScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });
  final String colonyId;
  final String colonyName;
  final String adminName;
  @override
  State<RwaGovernanceScreen> createState() => _RwaGovernanceScreenState();
}

class _RwaGovernanceScreenState extends State<RwaGovernanceScreen> {
  CollectionReference<Map<String, dynamic>> _records(String name) =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection(name);
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  static const _navy = AppTheme.navyBlue;
  static const _grey = AppTheme.textGrey;
  static const _border = AppTheme.borderGrey;

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  String _text(Object? value) => value == null ? '—' : value.toString();
  DateTime? _dateValue(Object? value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : null;
  String _date(Object? value) {
    final d = _dateValue(value);
    if (d == null) return 'Not set';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Future<void> _audit(
    String event,
    String recordType,
    String recordId,
    String summary,
  ) async {
    await _records('rwaGovernanceAudit').add({
      'event': event,
      'recordType': recordType,
      'recordId': recordId,
      'summary': summary,
      'createdBy': _uid,
      'createdByName': widget.adminName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: child,
  );
  Widget _status(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.lightGrey,
      borderRadius: BorderRadius.circular(20),
    ),
    child: AppText(
      value.replaceAll('_', ' ').toUpperCase(),
      style: const TextStyle(
        color: _navy,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
  Widget _empty(String title, String note) => _panel(
    Column(
      children: [
        const Icon(Icons.folder_open_outlined, color: _grey, size: 30),
        const SizedBox(height: 8),
        AppText(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _navy),
        ),
        const SizedBox(height: 4),
        AppText(
          note,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _grey, fontSize: 11),
        ),
      ],
    ),
  );
  Widget _streamList(
    String collection,
    Widget Function(QueryDocumentSnapshot<Map<String, dynamic>>) itemBuilder, {
    String? emptyTitle,
    String? emptyNote,
  }) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _records(collection).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _empty(
          'Unable to load records',
          'Check your connection and Firestore access. ${snapshot.error}',
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(color: _navy),
          ),
        );
      }
      final docs = [...snapshot.data!.docs];
      docs.sort(
        (a, b) =>
            (b.data()['createdAt'] is Timestamp
                    ? (b.data()['createdAt'] as Timestamp)
                          .millisecondsSinceEpoch
                    : 0)
                .compareTo(
                  a.data()['createdAt'] is Timestamp
                      ? (a.data()['createdAt'] as Timestamp)
                            .millisecondsSinceEpoch
                      : 0,
                ),
      );
      if (docs.isEmpty) {
        return _empty(
          emptyTitle ?? 'No records yet',
          emptyNote ?? 'Use the add action to create the first record.',
        );
      }
      return Column(children: docs.map(itemBuilder).toList());
    },
  );
  Widget _sectionHeader(
    String title,
    String note,
    VoidCallback onAdd,
    String addLabel,
  ) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              title,
              style: const TextStyle(
                color: _navy,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            AppText(note, style: const TextStyle(color: _grey, fontSize: 11)),
          ],
        ),
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: AppTheme.white,
        ),
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 17),
        label: AppText(addLabel),
      ),
    ],
  );
  Widget _field(
    TextEditingController c,
    String label, {
    int lines = 1,
    TextInputType? type,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: TextField(
      controller: c,
      maxLines: lines,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: AppTranslations.translate(label),
        hintText: AppTranslations.translate(hint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    ),
  );
  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    builder: (context, child) => Theme(
      data: Theme.of(context)
          .copyWith(colorScheme: const ColorScheme.light(primary: _navy)),
      child: child!,
    ),
  );

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
                'RWA Governance & Compliance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              AppText(
                widget.colonyName,
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: _navy,
            unselectedLabelColor: _grey,
            indicatorColor: _navy,
            tabs: [
              Tab(
                icon: Icon(Icons.dashboard_outlined),
                text: AppTranslations.translate('Overview'),
              ),
              Tab(
                icon: Icon(Icons.groups_outlined),
                text: AppTranslations.translate('Committee'),
              ),
              Tab(
                icon: Icon(Icons.meeting_room_outlined),
                text: AppTranslations.translate('Meetings'),
              ),
              Tab(
                icon: Icon(Icons.gavel_outlined),
                text: AppTranslations.translate('Resolutions'),
              ),
              Tab(
                icon: Icon(Icons.fact_check_outlined),
                text: AppTranslations.translate('Compliance'),
              ),
              Tab(
                icon: Icon(Icons.folder_outlined),
                text: AppTranslations.translate('Documents'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _overview(),
            _committee(),
            _meetings(),
            _resolutions(),
            _compliance(),
            _documents(),
          ],
        ),
      ),
    );
  }

  Widget _metricStream(
    String collection,
    String title,
    String field,
    String expected,
    IconData icon,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _records(collection).snapshots(),
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs ?? [];
      final count = docs.where((d) => d.data()[field] == expected).length;
      return _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _navy, size: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: AppText(
                    title,
                    style: const TextStyle(
                      color: _grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AppText(
                  snapshot.hasError
                      ? '—'
                      : snapshot.hasData
                      ? '$count'
                      : '…',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (snapshot.hasError) ...[
              const SizedBox(height: 4),
              AppText(
                '${snapshot.error}',
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
              TextButton(
                onPressed: () => setState(() {}),
                child: const AppText('Retry'),
              ),
            ],
          ],
        ),
      );
    },
  );
  Widget _overview() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      const AppText(
        'Governance dashboard',
        style: TextStyle(
          color: _navy,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 4),
      const AppText(
        'Committee strength, formal meetings, decisions and compliance obligations.',
        style: TextStyle(color: _grey, fontSize: 11),
      ),
      const SizedBox(height: 13),
      _metricStream(
        'rwaCommitteeMembers',
        'Active committee members',
        'status',
        'active',
        Icons.groups_outlined,
      ),
      const SizedBox(height: 8),
      _metricStream(
        'rwaGovernanceMeetings',
        'Upcoming / scheduled meetings',
        'status',
        'scheduled',
        Icons.calendar_month_outlined,
      ),
      const SizedBox(height: 8),
      _metricStream(
        'rwaGovernanceActions',
        'Open governance action items',
        'status',
        'open',
        Icons.assignment_late_outlined,
      ),
      const SizedBox(height: 8),
      _metricStream(
        'rwaComplianceRegister',
        'Open compliance obligations',
        'status',
        'open',
        Icons.event_busy_outlined,
      ),
      const SizedBox(height: 14),
      _panel(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Operating controls',
              style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 7),
            AppText(
              '• Meeting minutes require a recorded attendance register and quorum assessment.\n• Resolutions can be approved only when the linked meeting has approved minutes and quorum.\n• Action items retain owner, due date and completion notes.\n• Compliance items retain due dates, recurrence and closure evidence.\n• Document entries are metadata references; files are not uploaded by this module.',
              style: TextStyle(color: _grey, fontSize: 11, height: 1.45),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const AppText(
        'Recent audit activity',
        style: TextStyle(
          color: _navy,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      _streamList(
        'rwaGovernanceAudit',
        (d) => Card(
          color: AppTheme.white,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.history, color: _navy),
            title: AppText(
              _text(d.data()['summary']),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            subtitle: AppText(
              '${_text(d.data()['recordType'])} · ${_date(d.data()['createdAt'])}',
              style: const TextStyle(fontSize: 10, color: _grey),
            ),
          ),
        ),
        emptyTitle: 'No audit entries',
        emptyNote: 'Governance actions will appear here.',
      ),
    ],
  );

  Future<void> _memberForm() async {
    final name = TextEditingController(),
        position = TextEditingController(),
        phone = TextEditingController(),
        email = TextEditingController(),
        term = TextEditingController();
    DateTime start = DateTime.now(),
        end = DateTime(
          DateTime.now().year + 1,
          DateTime.now().month,
          DateTime.now().day,
        );
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const AppText('Add committee member'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(name, 'Full name'),
                    _field(
                      position,
                      'Position / responsibility',
                      hint: 'President, Secretary, Treasurer...',
                    ),
                    _field(phone, 'Phone number', type: TextInputType.phone),
                    _field(email, 'Email', type: TextInputType.emailAddress),
                    _field(term, 'Term / election reference'),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const AppText('Term starts'),
                      subtitle: AppText(_date(start)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final d = await _pickDate(start);
                          if (d != null) setLocal(() => start = d);
                        },
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const AppText('Term ends'),
                      subtitle: AppText(_date(end)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final d = await _pickDate(end);
                          if (d != null) setLocal(() => end = d);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (name.text.trim().isEmpty ||
                      position.text.trim().isEmpty ||
                      end.isBefore(start)) {
                    _message('Enter a name, position and valid term dates.');
                    return;
                  }
                  try {
                    final ref = await _records('rwaCommitteeMembers').add({
                      'fullName': name.text.trim(),
                      'position': position.text.trim(),
                      'phone': phone.text.trim(),
                      'email': email.text.trim(),
                      'termReference': term.text.trim(),
                      'termStart': Timestamp.fromDate(start),
                      'termEnd': Timestamp.fromDate(end),
                      'status': 'active',
                      'createdBy': _uid,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    await _audit(
                      'committee_member_added',
                      'committee_member',
                      ref.id,
                      'Added ${name.text.trim()} as ${position.text.trim()}',
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (e) {
                    _message('Unable to save committee member: $e');
                  }
                },
                child: const AppText('Save member'),
              ),
            ],
          ),
        ),
      );
    } finally {
      name.dispose();
      position.dispose();
      phone.dispose();
      email.dispose();
      term.dispose();
    }
  }

  Future<void> _changeMemberStatus(String id, Map<String, dynamic> data) async {
    final next = data['status'] == 'active' ? 'inactive' : 'active';
    final memberRef = _records('rwaCommitteeMembers').doc(id);
    final auditRef = _records('rwaGovernanceAudit').doc();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final memberSnapshot = await transaction.get(memberRef);
        final currentData = memberSnapshot.data();
        if (!memberSnapshot.exists || currentData == null) {
          throw StateError('The committee appointment no longer exists.');
        }
        if (currentData['status'] != data['status']) {
          throw StateError(
            'This committee appointment changed. Refresh and try again.',
          );
        }

        final currentLinkedUid = (currentData['linkedUserUid'] ?? '')
            .toString()
            .trim();
        DocumentReference<Map<String, dynamic>>? grantRef;
        DocumentSnapshot<Map<String, dynamic>>? grantSnapshot;
        if (currentLinkedUid.isNotEmpty) {
          grantRef = _records('rwaCommitteePermissions').doc(currentLinkedUid);
          grantSnapshot = await transaction.get(grantRef);
        }

        transaction.update(memberRef, {
          'status': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Deactivation revokes the currently linked grant in the same atomic change.
        // Reactivation never silently restores previously revoked permissions.
        var revokedDelegatedAccess = false;
        if (next == 'inactive' &&
            grantRef != null &&
            grantSnapshot?.exists == true &&
            grantSnapshot?.data()?['committeeMemberId'] == id &&
            grantSnapshot?.data()?['status'] == 'active') {
          transaction.update(grantRef, {
            'status': 'revoked',
            'updatedBy': _uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          revokedDelegatedAccess = true;
        }

        transaction.set(auditRef, {
          'event': 'committee_member_status_changed',
          'recordType': 'committee_member',
          'recordId': id,
          'summary':
              'Changed ${_text(currentData['fullName'])} to $next${revokedDelegatedAccess ? ' and revoked delegated access' : ''}',
          'createdBy': _uid,
          'createdByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      _message(
        next == 'inactive'
            ? 'Committee member deactivated. Any linked delegated access was revoked.'
            : 'Committee member reactivated. Delegated access must be granted again.',
      );
    } catch (e) {
      _message('Unable to update member: $e');
    }
  }

  Widget _committee() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      _sectionHeader(
        'Committee register',
        'Record elected / appointed positions, responsibilities and term dates.',
        _memberForm,
        'Add member',
      ),
      const SizedBox(height: 12),
      _streamList(
        'rwaCommitteeMembers',
        (d) {
          final x = d.data();
          return Card(
            color: AppTheme.white,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.lightGrey,
                child: const Icon(Icons.person_outline, color: _navy),
              ),
              title: AppText(
                _text(x['fullName']),
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: AppText(
                '${_text(x['position'])}\nTerm: ${_date(x['termStart'])} – ${_date(x['termEnd'])}\n${_text(x['phone'])} · ${_text(x['email'])}',
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (_) => _changeMemberStatus(d.id, x),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: AppText(
                      x['status'] == 'active' ? 'Mark inactive' : 'Reactivate',
                    ),
                  ),
                ],
                child: _status(_text(x['status'])),
              ),
            ),
          );
        },
        emptyTitle: 'Committee register is empty',
        emptyNote: 'Add committee members and their term information.',
      ),
    ],
  );

  Future<void> _meetingForm() async {
    final title = TextEditingController(),
        type = TextEditingController(text: 'Committee meeting'),
        venue = TextEditingController(),
        agenda = TextEditingController(),
        quorum = TextEditingController(text: '3');
    DateTime when = DateTime.now().add(const Duration(days: 7));
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const AppText('Schedule RWA meeting'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(title, 'Meeting title'),
                    _field(
                      type,
                      'Meeting type',
                      hint: 'AGM, SGM, committee, special meeting',
                    ),
                    _field(venue, 'Venue / meeting mode'),
                    _field(agenda, 'Agenda and papers summary', lines: 3),
                    _field(
                      quorum,
                      'Required quorum (number)',
                      type: TextInputType.number,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const AppText('Meeting date'),
                      subtitle: AppText(_date(when)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final d = await _pickDate(when);
                          if (d != null) setLocal(() => when = d);
                        },
                      ),
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
              FilledButton(
                onPressed: () async {
                  final q = int.tryParse(quorum.text.trim());
                  if (title.text.trim().isEmpty ||
                      venue.text.trim().isEmpty ||
                      q == null ||
                      q < 1) {
                    _message('Enter a title, venue and valid quorum.');
                    return;
                  }
                  try {
                    final ref = await _records('rwaGovernanceMeetings').add({
                      'title': title.text.trim(),
                      'meetingType': type.text.trim(),
                      'venue': venue.text.trim(),
                      'agendaSummary': agenda.text.trim(),
                      'meetingAt': Timestamp.fromDate(when),
                      'quorumRequired': q,
                      'attendeeIds': <String>[],
                      'attendeeNames': <String>[],
                      'attendanceCount': 0,
                      'quorumMet': false,
                      'status': 'scheduled',
                      'minutesStatus': 'not_started',
                      'createdBy': _uid,
                      'createdByName': widget.adminName,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    await _audit(
                      'meeting_scheduled',
                      'meeting',
                      ref.id,
                      'Scheduled ${title.text.trim()} for ${_dateKey(when)}',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    _message('Unable to schedule meeting: $e');
                  }
                },
                child: const AppText('Schedule'),
              ),
            ],
          ),
        ),
      );
    } finally {
      title.dispose();
      type.dispose();
      venue.dispose();
      agenda.dispose();
      quorum.dispose();
    }
  }

  Future<void> _recordAttendance(
    String meetingId,
    Map<String, dynamic> meeting,
  ) async {
    if (meeting['status'] == 'cancelled' ||
        meeting['minutesStatus'] == 'submitted' ||
        meeting['minutesStatus'] == 'approved') {
      _message(
        'Attendance is locked after minutes are submitted '
        'or when a meeting is cancelled.',
      );
      return;
    }

    try {
      final snapshot = await _records('rwaCommitteeMembers')
          .where('status', isEqualTo: 'active')
          .get();

      if (snapshot.docs.isEmpty) {
        _message('Add active committee members before recording attendance.');
        return;
      }

      final selected = <String>{
        ...((meeting['attendeeIds'] as List?)?.whereType<String>() ??
            const <String>[]),
      };

      final names = <String, String>{
        for (final member in snapshot.docs)
          member.id: _text(member.data()['fullName']),
      };

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setLocal) {
              return AlertDialog(
                title: const AppText('Record meeting attendance'),
                content: SizedBox(
                  width: 400,
                  height: 380,
                  child: Column(
                    children: [
                      AppText(
                        'Required quorum: ${_text(meeting['quorumRequired'])}',
                        style: const TextStyle(color: _grey),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: snapshot.docs.map<Widget>((member) {
                            return CheckboxListTile(
                              value: selected.contains(member.id),
                              title: AppText(names[member.id] ?? member.id),
                              onChanged: (checked) {
                                setLocal(() {
                                  if (checked == true) {
                                    selected.add(member.id);
                                  } else {
                                    selected.remove(member.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const AppText('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        final quorum =
                            (meeting['quorumRequired'] as num?)?.toInt() ?? 1;

                        final attendeeIds = selected.toList()..sort();

                        final attendeeNames = attendeeIds
                            .map((id) => names[id] ?? id)
                            .toList();

                        final quorumMet = attendeeIds.length >= quorum;

                        await _records('rwaGovernanceMeetings')
                            .doc(meetingId)
                            .update({
                              'attendeeIds': attendeeIds,
                              'attendeeNames': attendeeNames,
                              'attendanceCount': attendeeIds.length,
                              'quorumMet': quorumMet,
                              'status': 'held',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                        await _audit(
                          'meeting_attendance_recorded',
                          'meeting',
                          meetingId,
                          'Recorded ${attendeeIds.length} attendees; '
                              'quorum ${quorumMet ? 'met' : 'not met'}',
                        );

                        if (!mounted) return;

                        Navigator.of(context).pop();

                        _message(
                          quorumMet
                              ? 'Attendance saved. Quorum met.'
                              : 'Attendance saved. Quorum not met.',
                        );
                      } catch (e) {
                        _message('Unable to record attendance: $e');
                      }
                    },
                    child: const AppText('Save attendance'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      _message('Unable to load committee attendance: $e');
    }
  }

  Future<void> _minutesForm(
    String meetingId,
    Map<String, dynamic> meeting,
  ) async {
    if (meeting['status'] != 'held') {
      _message(
        'Record the meeting as held and enter attendance before preparing minutes.',
      );
      return;
    }
    final summary = TextEditingController(),
        discussion = TextEditingController(),
        decisions = TextEditingController(),
        nextMeeting = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const AppText('Prepare meeting minutes'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(summary, 'Meeting summary'),
                  _field(
                    discussion,
                    'Discussion record by agenda item',
                    lines: 4,
                  ),
                  _field(
                    decisions,
                    'Decisions and dissent / abstentions',
                    lines: 4,
                  ),
                  _field(nextMeeting, 'Next meeting / follow-up notes'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (summary.text.trim().isEmpty ||
                    discussion.text.trim().isEmpty) {
                  _message('Enter the summary and discussion record.');
                  return;
                }
                try {
                  final existing = await _records('rwaMeetingMinutes')
                      .where('meetingId', isEqualTo: meetingId)
                      .get();
                  final version = existing.docs.length + 1;
                  final ref = await _records('rwaMeetingMinutes').add({
                    'meetingId': meetingId,
                    'meetingTitle': meeting['title'],
                    'version': version,
                    'summary': summary.text.trim(),
                    'discussion': discussion.text.trim(),
                    'decisions': decisions.text.trim(),
                    'nextMeetingNotes': nextMeeting.text.trim(),
                    'status': 'submitted',
                    'submittedBy': _uid,
                    'submittedByName': widget.adminName,
                    'submittedAt': FieldValue.serverTimestamp(),
                    'approvedBy': null,
                    'approvedAt': null,
                  });
                  await _records('rwaGovernanceMeetings')
                      .doc(meetingId)
                      .update({
                        'minutesStatus': 'submitted',
                        'latestMinutesId': ref.id,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                  await _audit(
                    'minutes_submitted',
                    'meeting_minutes',
                    ref.id,
                    'Submitted minutes v$version for ${_text(meeting['title'])}',
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  _message('Unable to submit minutes: $e');
                }
              },
              child: const AppText('Submit minutes'),
            ),
          ],
        ),
      );
    } finally {
      summary.dispose();
      discussion.dispose();
      decisions.dispose();
      nextMeeting.dispose();
    }
  }

  Future<void> _approveMinutes(
    String meetingId,
    String minutesId,
    Map<String, dynamic> minutes,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_records('rwaMeetingMinutes').doc(minutesId), {
        'status': 'approved',
        'approvedBy': _uid,
        'approvedByName': widget.adminName,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_records('rwaGovernanceMeetings').doc(meetingId), {
        'minutesStatus': 'approved',
        'status': 'minutes_approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_records('rwaGovernanceAudit').doc(), {
        'event': 'minutes_approved',
        'recordType': 'meeting_minutes',
        'recordId': minutesId,
        'summary':
            'Approved minutes v${_text(minutes['version'])} for ${_text(minutes['meetingTitle'])}',
        'createdBy': _uid,
        'createdByName': widget.adminName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _message('Minutes approved.');
    } catch (e) {
      _message('Unable to approve minutes: $e');
    }
  }

  Widget _meetings() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      _sectionHeader(
        'Meetings & minutes',
        'Schedule AGM / SGM / committee meetings, record attendance and approve minutes.',
        _meetingForm,
        'Schedule',
      ),
      const SizedBox(height: 12),
      _streamList(
        'rwaGovernanceMeetings',
        (d) {
          final x = d.data();
          final ids = (x['attendeeIds'] as List?)?.length ?? 0;
          return Card(
            color: AppTheme.white,
            child: ExpansionTile(
              leading: const Icon(Icons.meeting_room_outlined, color: _navy),
              title: AppText(
                _text(x['title']),
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: AppText(
                '${_date(x['meetingAt'])} · ${_text(x['meetingType'])}\n${_text(x['venue'])}',
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
              trailing: _status(_text(x['status'])),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('Agenda: ${_text(x['agendaSummary'])}'),
                      AppText(
                        'Attendance: $ids / quorum ${_text(x['quorumRequired'])} · ${x['quorumMet'] == true ? 'quorum met' : 'quorum not met'}',
                      ),
                      AppText('Minutes: ${_text(x['minutesStatus'])}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _recordAttendance(d.id, x),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const AppText('Record attendance'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _minutesForm(d.id, x),
                            icon: const Icon(Icons.description_outlined),
                            label: const AppText('Prepare minutes'),
                          ),
                          if (x['status'] == 'scheduled')
                            TextButton(
                              onPressed: () async {
                                await _records('rwaGovernanceMeetings')
                                    .doc(d.id)
                                    .update({
                                      'status': 'cancelled',
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                await _audit(
                                  'meeting_cancelled',
                                  'meeting',
                                  d.id,
                                  'Cancelled ${_text(x['title'])}',
                                );
                              },
                              child: const AppText('Cancel meeting'),
                            ),
                        ],
                      ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _records('rwaMeetingMinutes')
                            .where('meetingId', isEqualTo: d.id)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  'Unable to load meeting minutes: ${snap.error}',
                                ),
                                TextButton(
                                  onPressed: () => setState(() {}),
                                  child: const AppText('Retry'),
                                ),
                              ],
                            );
                          }
                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: LinearProgressIndicator(minHeight: 2),
                            );
                          }
                          final ms = snap.data!.docs;
                          if (ms.isEmpty) return const SizedBox.shrink();
                          ms.sort(
                            (a, b) =>
                                ((b.data()['version'] as num?)?.toInt() ?? 0)
                                    .compareTo(
                                      (a.data()['version'] as num?)?.toInt() ??
                                          0,
                                    ),
                          );
                          final m = ms.first;
                          final md = m.data();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: AppText(
                              'Latest minutes · v${_text(md['version'])}',
                            ),
                            subtitle: AppText(
                              '${_text(md['summary'])} · ${_text(md['status'])}',
                            ),
                            trailing: md['status'] == 'submitted'
                                ? TextButton(
                                    onPressed: () =>
                                        _approveMinutes(d.id, m.id, md),
                                    child: const AppText('Approve'),
                                  )
                                : _status(_text(md['status'])),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        emptyTitle: 'No meetings scheduled',
        emptyNote: 'Create a meeting to begin the formal governance record.',
      ),
    ],
  );

  Future<void> _resolutionForm() async {
    final available = await _records('rwaGovernanceMeetings')
        .where('status', isEqualTo: 'minutes_approved')
        .get();
    if (!mounted) return;
    final eligible = available.docs
        .where((d) => d.data()['quorumMet'] == true)
        .toList();
    if (eligible.isEmpty) {
      _message(
        'Approve minutes for a meeting with quorum before recording a resolution.',
      );
      return;
    }
    final title = TextEditingController(),
        detail = TextEditingController(),
        rationale = TextEditingController(),
        yes = TextEditingController(text: '0'),
        no = TextEditingController(text: '0'),
        abstain = TextEditingController(text: '0');
    String meetingId = eligible.first.id;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const AppText('Record resolution'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: meetingId,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Approved meeting',
                        ),
                      ),
                      items: eligible
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: AppText(
                                _text(d.data()['title']),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => meetingId = v);
                      },
                    ),
                    _field(title, 'Resolution title'),
                    _field(detail, 'Resolution wording / decision', lines: 3),
                    _field(rationale, 'Rationale / reference', lines: 2),
                    _field(yes, 'Votes in favour', type: TextInputType.number),
                    _field(no, 'Votes against', type: TextInputType.number),
                    _field(abstain, 'Abstentions', type: TextInputType.number),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final y = int.tryParse(yes.text) ?? -1,
                      n = int.tryParse(no.text) ?? -1,
                      a = int.tryParse(abstain.text) ?? -1;
                  if (title.text.trim().isEmpty ||
                      detail.text.trim().isEmpty ||
                      y < 0 ||
                      n < 0 ||
                      a < 0) {
                    _message(
                      'Complete resolution wording and valid vote counts.',
                    );
                    return;
                  }
                  try {
                    final meeting = eligible
                        .firstWhere((d) => d.id == meetingId)
                        .data();
                    final ref = await _records('rwaResolutions').add({
                      'title': title.text.trim(),
                      'wording': detail.text.trim(),
                      'rationale': rationale.text.trim(),
                      'meetingId': meetingId,
                      'meetingTitle': meeting['title'],
                      'votesFor': y,
                      'votesAgainst': n,
                      'abstentions': a,
                      'status': 'proposed',
                      'reviewNote': '',
                      'createdBy': _uid,
                      'createdByName': widget.adminName,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    await _audit(
                      'resolution_recorded',
                      'resolution',
                      ref.id,
                      'Recorded resolution ${title.text.trim()}',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    _message('Unable to save resolution: $e');
                  }
                },
                child: const AppText('Record resolution'),
              ),
            ],
          ),
        ),
      );
    } finally {
      title.dispose();
      detail.dispose();
      rationale.dispose();
      yes.dispose();
      no.dispose();
      abstain.dispose();
    }
  }

  Future<void> _resolutionStatus(
    String id,
    Map<String, dynamic> data,
    String status,
  ) async {
    final yes = (data['votesFor'] as num?)?.toInt() ?? 0,
        no = (data['votesAgainst'] as num?)?.toInt() ?? 0;
    if (status == 'approved' && yes <= no) {
      _message(
        'A resolution can be approved only when votes in favour exceed votes against.',
      );
      return;
    }
    final note = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: AppText(
            '${status[0].toUpperCase()}${status.substring(1)} resolution',
          ),
          content: _field(note, 'Reviewer note / reason (required)', lines: 3),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (note.text.trim().isEmpty) {
                  _message('Enter a review note.');
                  return;
                }
                try {
                  await _records('rwaResolutions').doc(id).update({
                    'status': status,
                    'reviewNote': note.text.trim(),
                    'reviewedBy': _uid,
                    'reviewedByName': widget.adminName,
                    'reviewedAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  await _audit(
                    'resolution_$status',
                    'resolution',
                    id,
                    '${_text(data['title'])}: ${note.text.trim()}',
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  _message('Unable to update resolution: $e');
                }
              },
              child: const AppText('Confirm'),
            ),
          ],
        ),
      );
    } finally {
      note.dispose();
    }
  }

  Future<void> _actionForm(String resolutionId, String resolutionTitle) async {
    final title = TextEditingController(text: resolutionTitle);
    final owner = TextEditingController();
    final details = TextEditingController();
    DateTime due = DateTime.now().add(const Duration(days: 14));
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const AppText('Create governance action'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(title, 'Action item'),
                    _field(owner, 'Responsible person / role'),
                    _field(details, 'Expected outcome / evidence', lines: 3),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const AppText('Due date'),
                      subtitle: AppText(_date(due)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final d = await _pickDate(due);
                          if (d != null) setLocal(() => due = d);
                        },
                      ),
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
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty || owner.text.trim().isEmpty) {
                    _message('Enter an action and responsible person.');
                    return;
                  }
                  try {
                    final ref = await _records('rwaGovernanceActions').add({
                      'title': title.text.trim(),
                      'owner': owner.text.trim(),
                      'expectedOutcome': details.text.trim(),
                      'resolutionId': resolutionId,
                      'resolutionTitle': resolutionTitle,
                      'dueDate': Timestamp.fromDate(due),
                      'status': 'open',
                      'completionNote': '',
                      'createdBy': _uid,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    await _audit(
                      'action_created',
                      'action',
                      ref.id,
                      'Created action ${title.text.trim()}',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    _message('Unable to create action: $e');
                  }
                },
                child: const AppText('Create action'),
              ),
            ],
          ),
        ),
      );
    } finally {
      title.dispose();
      owner.dispose();
      details.dispose();
    }
  }

  Widget _resolutions() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      _sectionHeader(
        'Resolutions & action items',
        'Record decisions against quorum-confirmed meetings and track their execution.',
        _resolutionForm,
        'Add resolution',
      ),
      const SizedBox(height: 12),
      _streamList(
        'rwaResolutions',
        (d) {
          final x = d.data();
          return Card(
            color: AppTheme.white,
            child: ExpansionTile(
              leading: const Icon(Icons.gavel_outlined, color: _navy),
              title: AppText(
                _text(x['title']),
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: AppText(
                '${_text(x['meetingTitle'])} · votes ${_text(x['votesFor'])}/${_text(x['votesAgainst'])}/${_text(x['abstentions'])}',
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
              trailing: _status(_text(x['status'])),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(_text(x['wording'])),
                      if ((_text(x['rationale'])).isNotEmpty)
                        AppText('Rationale: ${_text(x['rationale'])}'),
                      if ((_text(x['reviewNote'])).isNotEmpty)
                        AppText('Review: ${_text(x['reviewNote'])}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (x['status'] == 'proposed') ...[
                            TextButton(
                              onPressed: () =>
                                  _resolutionStatus(d.id, x, 'approved'),
                              child: const AppText('Approve'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _resolutionStatus(d.id, x, 'rejected'),
                              child: const AppText('Reject'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _resolutionStatus(d.id, x, 'deferred'),
                              child: const AppText('Defer'),
                            ),
                          ],
                          if (x['status'] == 'approved')
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _actionForm(d.id, _text(x['title'])),
                              icon: const Icon(Icons.add_task),
                              label: const AppText('Create action'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        emptyTitle: 'No resolutions recorded',
        emptyNote: 'Resolutions require approved minutes from a quorum-confirmed meeting.',
      ),
      const SizedBox(height: 12),
      const AppText(
        'Action register',
        style: TextStyle(
          color: _navy,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      _streamList(
        'rwaGovernanceActions',
        (d) {
          final x = d.data();
          final due = _dateValue(x['dueDate']);
          final overdue =
              x['status'] == 'open' &&
              due != null &&
              due.isBefore(DateTime.now());
          return Card(
            color: AppTheme.white,
            child: ListTile(
              leading: Icon(
                overdue
                    ? Icons.warning_amber_rounded
                    : Icons.assignment_outlined,
                color: _navy,
              ),
              title: AppText(
                _text(x['title']),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              subtitle: AppText(
                'Owner: ${_text(x['owner'])} · Due: ${_date(x['dueDate'])}\n${_text(x['resolutionTitle'])}',
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'complete') {
                    final c = TextEditingController();
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const AppText('Complete action'),
                        content: _field(
                          c,
                          'Completion note / evidence',
                          lines: 3,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const AppText('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              if (c.text.trim().isEmpty) {
                                _message('Completion evidence is required.');
                                return;
                              }
                              await _records('rwaGovernanceActions')
                                  .doc(d.id)
                                  .update({
                                    'status': 'completed',
                                    'completionNote': c.text.trim(),
                                    'completedAt': FieldValue.serverTimestamp(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                              await _audit(
                                'action_completed',
                                'action',
                                d.id,
                                'Completed ${_text(x['title'])}',
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const AppText('Complete'),
                          ),
                        ],
                      ),
                    );
                    c.dispose();
                  }
                },
                itemBuilder: (_) => [
                  if (x['status'] == 'open')
                    const PopupMenuItem(
                      value: 'complete',
                      child: AppText('Mark completed'),
                    ),
                ],
                child: _status(overdue ? 'overdue' : _text(x['status'])),
              ),
            ),
          );
        },
        emptyTitle: 'No action items',
        emptyNote:
            'Approved resolutions can generate accountable action items.',
      ),
    ],
  );

  DateTime _addMonths(DateTime due, int months) {
    final monthIndex = due.year * 12 + (due.month - 1) + months;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, due.day > lastDay ? lastDay : due.day);
  }

  DateTime _nextComplianceDue(DateTime due, String recurrence) {
    switch (recurrence) {
      case 'monthly':
        return _addMonths(due, 1);
      case 'quarterly':
        return _addMonths(due, 3);
      case 'half_yearly':
        return _addMonths(due, 6);
      case 'yearly':
        return _addMonths(due, 12);
      default:
        return due;
    }
  }

  Future<void> _completeCompliance(
    String id,
    Map<String, dynamic> item,
    String note,
  ) async {
    final recurrence = item['recurrence'] as String? ?? 'one_time';
    final currentDue = _dateValue(item['dueDate']) ?? DateTime.now();
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_records('rwaComplianceRegister').doc(id), {
      'status': 'completed',
      'completionNote': note.trim(),
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (recurrence != 'one_time') {
      final nextDue = _nextComplianceDue(currentDue, recurrence);
      final nextRef = _records('rwaComplianceRegister').doc();
      batch.set(nextRef, {
        'title': item['title'],
        'category': item['category'],
        'owner': item['owner'],
        'authorityReference': item['authorityReference'] ?? '',
        'notes': item['notes'] ?? '',
        'dueDate': Timestamp.fromDate(nextDue),
        'recurrence': recurrence,
        'status': 'open',
        'completionNote': '',
        'previousOccurrenceId': id,
        'createdBy': _uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_records('rwaGovernanceAudit').doc(), {
        'event': 'compliance_item_completed_and_renewed',
        'recordType': 'compliance',
        'recordId': id,
        'summary':
            'Completed ${_text(item['title'])}; next due ${_dateKey(nextDue)}',
        'createdBy': _uid,
        'createdByName': widget.adminName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(_records('rwaGovernanceAudit').doc(), {
        'event': 'compliance_item_completed',
        'recordType': 'compliance',
        'recordId': id,
        'summary': 'Completed ${_text(item['title'])}',
        'createdBy': _uid,
        'createdByName': widget.adminName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    _message(
      recurrence == 'one_time'
          ? 'Compliance item completed.'
          : 'Completed and next recurring obligation created.',
    );
  }

  Future<void> _complianceForm() async {
    final title = TextEditingController();
    final category = TextEditingController(text: 'Safety');
    final owner = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    DateTime due = DateTime.now().add(const Duration(days: 30));
    String recurrence = 'one_time';
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const AppText('Add compliance obligation'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(title, 'Obligation / filing / inspection'),
                    _field(
                      category,
                      'Category',
                      hint: 'Statutory, fire safety, lift, insurance, audit...',
                    ),
                    _field(owner, 'Responsible person / role'),
                    _field(reference, 'Authority / reference number'),
                    _field(notes, 'Notes and evidence expected', lines: 3),
                    DropdownButtonFormField<String>(
                      initialValue: recurrence,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Recurrence'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'one_time',
                          child: AppText('One-time'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: AppText('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'quarterly',
                          child: AppText('Quarterly'),
                        ),
                        DropdownMenuItem(
                          value: 'half_yearly',
                          child: AppText('Half-yearly'),
                        ),
                        DropdownMenuItem(
                          value: 'yearly',
                          child: AppText('Yearly'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => recurrence = v);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const AppText('Due date'),
                      subtitle: AppText(_date(due)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final d = await _pickDate(due);
                          if (d != null) setLocal(() => due = d);
                        },
                      ),
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
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty ||
                      category.text.trim().isEmpty ||
                      owner.text.trim().isEmpty) {
                    _message(
                      'Enter an obligation, category and responsible person.',
                    );
                    return;
                  }
                  try {
                    final ref = await _records('rwaComplianceRegister').add({
                      'title': title.text.trim(),
                      'category': category.text.trim(),
                      'owner': owner.text.trim(),
                      'authorityReference': reference.text.trim(),
                      'notes': notes.text.trim(),
                      'dueDate': Timestamp.fromDate(due),
                      'recurrence': recurrence,
                      'status': 'open',
                      'completionNote': '',
                      'createdBy': _uid,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    await _audit(
                      'compliance_item_created',
                      'compliance',
                      ref.id,
                      'Added ${title.text.trim()} due ${_dateKey(due)}',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    _message('Unable to save compliance item: $e');
                  }
                },
                child: const AppText('Save obligation'),
              ),
            ],
          ),
        ),
      );
    } finally {
      title.dispose();
      category.dispose();
      owner.dispose();
      reference.dispose();
      notes.dispose();
    }
  }

  Widget _compliance() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      _sectionHeader(
        'Compliance register',
        'Track statutory, safety, insurance, audit and contractual due dates.',
        _complianceForm,
        'Add obligation',
      ),
      const SizedBox(height: 12),
      _streamList(
        'rwaComplianceRegister',
        (d) {
          final x = d.data();
          final due = _dateValue(x['dueDate']);
          final overdue =
              x['status'] == 'open' &&
              due != null &&
              due.isBefore(DateTime.now());
          return Card(
            color: AppTheme.white,
            child: ExpansionTile(
              leading: Icon(
                overdue
                    ? Icons.warning_amber_rounded
                    : Icons.fact_check_outlined,
                color: _navy,
              ),
              title: AppText(
                _text(x['title']),
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: AppText(
                '${_text(x['category'])} · due ${_date(x['dueDate'])} · ${_text(x['owner'])}',
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
              trailing: _status(overdue ? 'overdue' : _text(x['status'])),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Recurrence: ${_text(x['recurrence'])} · Reference: ${_text(x['authorityReference'])}',
                      ),
                      AppText(_text(x['notes'])),
                      if ((_text(x['completionNote'])).isNotEmpty)
                        AppText('Closure: ${_text(x['completionNote'])}'),
                      if (x['status'] == 'open')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              final note = TextEditingController();
                              await showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const AppText(
                                    'Complete compliance item',
                                  ),
                                  content: _field(
                                    note,
                                    'Completion note / certificate reference',
                                    lines: 3,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const AppText('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () async {
                                        if (note.text.trim().isEmpty) {
                                          _message(
                                            'Enter completion evidence or reference.',
                                          );
                                          return;
                                        }
                                        await _completeCompliance(
                                          d.id,
                                          x,
                                          note.text.trim(),
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      },
                                      child: const AppText('Complete'),
                                    ),
                                  ],
                                ),
                              );
                              note.dispose();
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const AppText('Mark completed'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        emptyTitle: 'No compliance obligations',
        emptyNote:
            'Add required filings, inspections, renewals and audit dates.',
      ),
    ],
  );

  Future<void> _documentForm() async {
    final title = TextEditingController();
    final category = TextEditingController(text: 'Policy');
    final number = TextEditingController();
    final version = TextEditingController(text: '1.0');
    final custodian = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    DateTime issue = DateTime.now();
    DateTime review = DateTime.now().add(const Duration(days: 365));
    String classification = 'internal';
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const AppText('Register governance document'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(title, 'Document title'),
                    _field(
                      category,
                      'Category',
                      hint: 'Policy, minutes, contract, insurance, audit...',
                    ),
                    _field(number, 'Document / reference number'),
                    _field(version, 'Version'),
                    _field(custodian, 'Document custodian'),
                    _field(
                      reference,
                      'Storage reference / repository location',
                    ),
                    _field(notes, 'Description / review notes', lines: 3),
                    DropdownButtonFormField<String>(
                      initialValue: classification,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Access classification',
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'internal',
                          child: AppText('Internal'),
                        ),
                        DropdownMenuItem(
                          value: 'confidential',
                          child: AppText('Confidential'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => classification = v);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const AppText('Issue / approval date'),
                      subtitle: AppText(_date(issue)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final d = await _pickDate(issue);
                          if (d != null) setLocal(() => issue = d);
                        },
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const AppText('Next review date'),
                      subtitle: AppText(_date(review)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final d = await _pickDate(review);
                          if (d != null) setLocal(() => review = d);
                        },
                      ),
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
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty ||
                      category.text.trim().isEmpty ||
                      custodian.text.trim().isEmpty) {
                    _message('Enter a document title, category and custodian.');
                    return;
                  }
                  try {
                    final ref = await _records('rwaGovernanceDocuments').add({
                      'title': title.text.trim(),
                      'category': category.text.trim(),
                      'documentNumber': number.text.trim(),
                      'version': version.text.trim(),
                      'custodian': custodian.text.trim(),
                      'storageReference': reference.text.trim(),
                      'notes': notes.text.trim(),
                      'classification': classification,
                      'issueDate': Timestamp.fromDate(issue),
                      'reviewDate': Timestamp.fromDate(review),
                      'status': 'active',
                      'createdBy': _uid,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    await _audit(
                      'governance_document_registered',
                      'document',
                      ref.id,
                      'Registered ${title.text.trim()}',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    _message('Unable to register document: $e');
                  }
                },
                child: const AppText('Register document'),
              ),
            ],
          ),
        ),
      );
    } finally {
      title.dispose();
      category.dispose();
      number.dispose();
      version.dispose();
      custodian.dispose();
      reference.dispose();
      notes.dispose();
    }
  }

  Widget _documents() => ListView(
    padding: const EdgeInsets.all(15),
    children: [
      _sectionHeader(
        'Governance document register',
        'Index approved policies, meeting minutes, contracts, insurance and official records.',
        _documentForm,
        'Register document',
      ),
      const SizedBox(height: 12),
      _streamList(
        'rwaGovernanceDocuments',
        (d) {
          final x = d.data();
          final review = _dateValue(x['reviewDate']);
          final due =
              x['status'] == 'active' &&
              review != null &&
              review.isBefore(DateTime.now());
          return Card(
            color: AppTheme.white,
            child: ExpansionTile(
              leading: const Icon(Icons.description_outlined, color: _navy),
              title: AppText(
                _text(x['title']),
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: AppText(
                '${_text(x['category'])} · v${_text(x['version'])} · review ${_date(x['reviewDate'])}',
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
              trailing: _status(due ? 'review_due' : _text(x['status'])),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Document no.: ${_text(x['documentNumber'])} · Custodian: ${_text(x['custodian'])}',
                      ),
                      AppText(
                        'Classification: ${_text(x['classification'])} · Issue date: ${_date(x['issueDate'])}',
                      ),
                      AppText(
                        'Repository reference: ${_text(x['storageReference'])}',
                      ),
                      AppText(_text(x['notes'])),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            final next = x['status'] == 'active'
                                ? 'archived'
                                : 'active';
                            await _records('rwaGovernanceDocuments')
                                .doc(d.id)
                                .update({
                                  'status': next,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                            await _audit(
                              'document_status_changed',
                              'document',
                              d.id,
                              '${_text(x['title'])} set to $next',
                            );
                          },
                          child: AppText(
                            x['status'] == 'active'
                                ? 'Archive entry'
                                : 'Reactivate entry',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        emptyTitle: 'Document register is empty',
        emptyNote: 'Register the location and custodian of approved governance records.',
      ),
    ],
  );
}
// MOHALLAFLOW_RWA_GOVERNANCE_SCREEN_END
