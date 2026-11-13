import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class RwaCommitteePermissionsScreen extends StatefulWidget {
  const RwaCommitteePermissionsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<RwaCommitteePermissionsScreen> createState() =>
      _RwaCommitteePermissionsScreenState();
}

class _RwaCommitteePermissionsScreenState
    extends State<RwaCommitteePermissionsScreen> {
  static const _navy = AppTheme.navyBlue;
  static const _grey = AppTheme.textGrey;
  static const _border = AppTheme.borderGrey;

  final _firestore = FirebaseFirestore.instance;
  late Future<_Registry> _registryFuture;
  bool _saving = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _records(String name) =>
      _firestore.collection('colonies').doc(widget.colonyId).collection(name);

  static const Map<String, String> _permissionLabels = {
    'residents.view': 'Resident directory — view resident names, household and contact records',
    'complaints.view': 'Complaints — view colony complaints and their details',
    'complaints.update_status':
        'Complaints — acknowledge, move to progress or mark resolved',
    'maintenance.view':
        'Maintenance — view maintenance jobs and assigned vendor details',
    'maintenance.update_status':
        'Maintenance — record work progress and completion notes',
    'announcements.create_draft':
        'Announcements — prepare drafts for Admin review (cannot publish)',
  };

  @override
  void initState() {
    super.initState();
    _registryFuture = _loadRegistry();
  }

  Future<_Registry> _loadRegistry() async {
    final snapshots = await Future.wait([
      _records('rwaCommitteeMembers').get(),
      _records('members').get(),
      _records('residents').get(),
      _records('rwaCommitteePermissions').get(),
    ]);

    final committeeDocs = snapshots[0].docs;
    final membershipDocs = snapshots[1].docs;
    final residentDocs = snapshots[2].docs;
    final permissionDocs = snapshots[3].docs;

    final residentsById = <String, Map<String, dynamic>>{
      for (final doc in residentDocs) doc.id: doc.data(),
    };

    final accounts = <_ResidentAccount>[];
    for (final doc in membershipDocs) {
      final data = doc.data();
      if (data['role'] != 'resident' || data['status'] != 'active') continue;
      final residentId = (data['residentId'] ?? '').toString().trim();
      if (residentId.isEmpty) continue;
      final resident = residentsById[residentId];
      if (resident == null || resident['residentStatus'] == 'inactive') {
        continue;
      }
      accounts.add(
        _ResidentAccount(
          uid: doc.id,
          residentId: residentId,
          name: (resident['fullName'] ?? data['displayName'] ?? 'Resident')
              .toString(),
          phone: (resident['phoneNumber'] ?? '').toString(),
          block: (resident['blockId'] ?? '').toString(),
          house: (resident['houseNumber'] ?? '').toString(),
        ),
      );
    }
    accounts.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    final grants = <String, Map<String, dynamic>>{
      for (final doc in permissionDocs) doc.id: doc.data(),
    };
    final committee =
        committeeDocs
            .map((doc) => _CommitteeMember(id: doc.id, data: doc.data()))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return _Registry(
      committeeMembers: committee,
      accounts: accounts,
      grants: grants,
    );
  }

  void _refresh() => setState(() => _registryFuture = _loadRegistry());

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(text), behavior: SnackBarBehavior.floating),
    );
  }

  DateTime? _asDate(Object? value) =>
      value is Timestamp ? value.toDate() : null;

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59);

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not set';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  bool _grantIsActive(Map<String, dynamic>? grant) {
    if (grant == null || grant['status'] != 'active') return false;
    final start = _asDate(grant['startsAt']);
    final end = _asDate(grant['expiresAt']);
    final now = DateTime.now();
    return start != null &&
        end != null &&
        !now.isBefore(start) &&
        now.isBefore(end);
  }

  Widget _pill(String text, {bool active = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: active ? const Color(0xFFEAF0F7) : AppTheme.lightGrey,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: AppText(
      text.toUpperCase(),
      style: const TextStyle(
        color: _navy,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Future<void> _configureAccess(
    _CommitteeMember member,
    _Registry registry,
  ) async {
    final termEnd = member.termEnd;
    if (member.data['status'] != 'active' ||
        termEnd == null ||
        _day(termEnd).isBefore(_day(DateTime.now()))) {
      _message(
        'Only committee members with a current active term can receive access.',
      );
      return;
    }

    final currentUid = (member.data['linkedUserUid'] ?? '').toString();
    final linkedGrant = currentUid.isEmpty ? null : registry.grants[currentUid];
    final oldGrant =
        linkedGrant != null && linkedGrant['committeeMemberId'] == member.id
        ? linkedGrant
        : null;
    final now = _day(DateTime.now());
    final defaultEnd = _day(termEnd);
    final termStart = member.termStart;
    if (termStart == null || _day(termEnd).isBefore(_day(termStart))) {
      _message('The committee appointment has invalid term dates.');
      return;
    }
    final earliestStart = _day(termStart).isAfter(now) ? _day(termStart) : now;
    final existingStart = _asDate(oldGrant?['startsAt']);
    final initialStart =
        existingStart == null || _day(existingStart).isBefore(earliestStart)
        ? earliestStart
        : _day(existingStart);
    final initialEnd = _asDate(oldGrant?['expiresAt']) ?? defaultEnd;
    final availableAccounts = registry.accounts.where((account) {
      final existingGrant = registry.grants[account.uid];
      if (account.uid == currentUid &&
          (existingGrant == null ||
              existingGrant['committeeMemberId'] == member.id)) {
        return true;
      }
      final linkedElsewhere = registry.committeeMembers.any(
        (other) =>
            other.id != member.id &&
            other.data['status'] == 'active' &&
            other.data['linkedUserUid'] == account.uid,
      );
      final hasOtherActiveGrant =
          existingGrant != null &&
          existingGrant['committeeMemberId'] != member.id &&
          _grantIsActive(existingGrant);
      return !linkedElsewhere && !hasOtherActiveGrant;
    }).toList();

    if (availableAccounts.isEmpty) {
      _message('No eligible active resident accounts are available to link.');
      return;
    }

    String selectedUid = availableAccounts.any((a) => a.uid == currentUid)
        ? currentUid
        : availableAccounts.first.uid;
    final selectedPermissions = <String>{
      if (oldGrant?['permissions'] is List)
        ...((oldGrant!['permissions'] as List).whereType<String>()),
    };
    DateTime startDate = initialStart;
    DateTime endDate = initialEnd.isAfter(defaultEnd) ? defaultEnd : initialEnd;

    final draft = await showDialog<_GrantDraft>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: AppText('Access · ${member.name}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'Link this committee position to an existing active Resident account. The account keeps its Resident login role; the permissions below are additional, colony-specific grants.',
                    style: TextStyle(color: _grey, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUid,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Resident account'),
                      border: OutlineInputBorder(),
                    ),
                    items: availableAccounts.map((account) {
                      return DropdownMenuItem(
                        value: account.uid,
                        child: AppText(
                          '${account.name} · ${account.block.isEmpty ? '—' : account.block}-${account.house} · ${account.phone}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setLocal(() => selectedUid = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  const AppText(
                    'Permission presets',
                    style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      OutlinedButton(
                        onPressed: () => setLocal(() {
                          selectedPermissions
                            ..clear()
                            ..addAll(['residents.view', 'complaints.view']);
                        }),
                        child: const AppText('Resident liaison'),
                      ),
                      OutlinedButton(
                        onPressed: () => setLocal(() {
                          selectedPermissions
                            ..clear()
                            ..addAll([
                              'complaints.view',
                              'complaints.update_status',
                              'maintenance.view',
                              'maintenance.update_status',
                            ]);
                        }),
                        child: const AppText('Operations coordinator'),
                      ),
                      OutlinedButton(
                        onPressed: () => setLocal(() {
                          selectedPermissions
                            ..clear()
                            ..addAll([
                              'complaints.view',
                              'announcements.create_draft',
                            ]);
                        }),
                        child: const AppText('Communications'),
                      ),
                      TextButton(
                        onPressed: () => setLocal(selectedPermissions.clear),
                        child: const AppText('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const AppText(
                    'Individual permissions',
                    style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  ..._permissionLabels.entries.map(
                    (entry) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: selectedPermissions.contains(entry.key),
                      title: AppText(
                        entry.value,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: _navy,
                      onChanged: (value) => setLocal(() {
                        if (value == true) {
                          selectedPermissions.add(entry.key);
                        } else {
                          selectedPermissions.remove(entry.key);
                        }
                      }),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText(
                      'Access starts',
                      style: TextStyle(color: _navy, fontSize: 12),
                    ),
                    subtitle: AppText(_formatDate(startDate)),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                        color: _navy,
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: startDate.isBefore(now)
                              ? now
                              : startDate,
                          firstDate: earliestStart,
                          lastDate: _day(termEnd),
                        );
                        if (picked != null) {
                          setLocal(() => startDate = _day(picked));
                        }
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText(
                      'Access expires',
                      style: TextStyle(color: _navy, fontSize: 12),
                    ),
                    subtitle: AppText(
                      '${_formatDate(endDate)} · capped at committee term end ${_formatDate(termEnd)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.event_busy_outlined, color: _navy),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: endDate.isBefore(startDate)
                              ? startDate
                              : endDate,
                          firstDate: startDate,
                          lastDate: _day(termEnd),
                        );
                        if (picked != null) {
                          setLocal(() => endDate = _day(picked));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const AppText(
                      'Restrictions: delegated users cannot manage committee permissions, change committee appointments, assign maintenance vendors, edit job costs, publish notices, approve payments or modify accounting records. Financial and final administrative authority stays with Admin.',
                      style: TextStyle(color: _grey, fontSize: 10),
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
              onPressed: () {
                if (selectedPermissions.isEmpty) {
                  _message('Select at least one permission.');
                  return;
                }
                if (_day(startDate).isBefore(earliestStart) ||
                    _day(startDate).isBefore(_day(termStart)) ||
                    _day(endDate).isBefore(_day(startDate)) ||
                    _day(endDate).isAfter(_day(termEnd))) {
                  _message(
                    'Choose a valid access period within the committee term.',
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _GrantDraft(
                    userUid: selectedUid,
                    permissions: selectedPermissions.toList()..sort(),
                    startsAt: DateTime(
                      startDate.year,
                      startDate.month,
                      startDate.day,
                    ),
                    expiresAt: _endOfDay(endDate),
                  ),
                );
              },
              child: const AppText('Save access'),
            ),
          ],
        ),
      ),
    );

    if (draft == null) return;
    await _saveGrant(member, draft, registry);
  }

  Future<void> _saveGrant(
    _CommitteeMember member,
    _GrantDraft draft,
    _Registry registry,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final memberRef = _records('rwaCommitteeMembers').doc(member.id);
      final newGrantRef = _records('rwaCommitteePermissions')
          .doc(draft.userUid);
      final account = registry.accounts.firstWhere(
        (a) => a.uid == draft.userUid,
      );
      final oldUid = (member.data['linkedUserUid'] ?? '').toString();
      final oldGrantRef = oldUid.isEmpty || oldUid == draft.userUid
          ? null
          : _records('rwaCommitteePermissions').doc(oldUid);
      final auditRef = _records('rwaGovernanceAudit').doc();

      await _firestore.runTransaction((transaction) async {
        final memberSnapshot = await transaction.get(memberRef);
        final newGrantSnapshot = await transaction.get(newGrantRef);
        DocumentSnapshot<Map<String, dynamic>>? oldGrantSnapshot;
        if (oldGrantRef != null) {
          oldGrantSnapshot = await transaction.get(oldGrantRef);
        }
        if (!memberSnapshot.exists ||
            memberSnapshot.data()?['status'] != 'active') {
          throw StateError('The committee appointment is no longer active.');
        }
        final termStart = _asDate(memberSnapshot.data()?['termStart']);
        final termEnd = _asDate(memberSnapshot.data()?['termEnd']);
        if (termStart == null ||
            termEnd == null ||
            _day(draft.startsAt).isBefore(_day(termStart)) ||
            draft.expiresAt.isAfter(_endOfDay(termEnd))) {
          throw StateError(
            'Access period must remain within the committee term.',
          );
        }
        if (newGrantSnapshot.exists &&
            newGrantSnapshot.data()?['committeeMemberId'] != member.id &&
            _grantIsActive(newGrantSnapshot.data())) {
          throw StateError(
            'This resident account already has active access for another committee appointment.',
          );
        }
        if (draft.permissions.isEmpty ||
            draft.expiresAt.isBefore(draft.startsAt)) {
          throw StateError('The permission or date selection is invalid.');
        }

        if (oldGrantRef != null && oldGrantSnapshot?.exists == true) {
          if (oldGrantSnapshot?.data()?['committeeMemberId'] == member.id) {
            transaction.update(oldGrantRef, {
              'status': 'revoked',
              'updatedBy': _uid,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        transaction.update(memberRef, {
          'linkedUserUid': draft.userUid,
          'linkedAt': FieldValue.serverTimestamp(),
          'linkedBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(newGrantRef, {
          'userUid': draft.userUid,
          'committeeMemberId': member.id,
          'committeeMemberName': member.name,
          'committeePosition': member.position,
          'permissions': draft.permissions,
          'status': 'active',
          'startsAt': Timestamp.fromDate(draft.startsAt),
          'expiresAt': Timestamp.fromDate(draft.expiresAt),
          'createdBy': newGrantSnapshot.data()?['createdBy'] ?? _uid,
          'createdAt':
              newGrantSnapshot.data()?['createdAt'] ??
              FieldValue.serverTimestamp(),
          'updatedBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(auditRef, {
          'event': 'committee_permissions_granted',
          'recordType': 'committee_permission',
          'recordId': draft.userUid,
          'summary':
              'Granted ${draft.permissions.length} delegated permissions to ${member.name} (${member.position}) for ${account.name}; expiry ${_formatDate(draft.expiresAt)}',
          'createdBy': _uid,
          'createdByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      _message('Committee access saved for ${account.name}.');
      _refresh();
    } catch (error) {
      _message('Unable to save delegated access: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeAccess(
    _CommitteeMember member,
    Map<String, dynamic> grant,
  ) async {
    final userUid = (member.data['linkedUserUid'] ?? '').toString();
    if (userUid.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Revoke committee access?'),
        content: AppText(
          'This immediately disables delegated permissions for ${member.name}. The committee appointment record will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Revoke access'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final grantRef = _records('rwaCommitteePermissions').doc(userUid);
      final auditRef = _records('rwaGovernanceAudit').doc();
      await _firestore.runTransaction((transaction) async {
        final current = await transaction.get(grantRef);
        if (!current.exists ||
            current.data()?['committeeMemberId'] != member.id) {
          throw StateError(
            'The permission record no longer matches this committee member.',
          );
        }
        transaction.update(grantRef, {
          'status': 'revoked',
          'updatedBy': _uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(auditRef, {
          'event': 'committee_permissions_revoked',
          'recordType': 'committee_permission',
          'recordId': userUid,
          'summary':
              'Revoked delegated permissions for ${member.name} (${member.position})',
          'createdBy': _uid,
          'createdByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      _message('Delegated access revoked.');
      _refresh();
    } catch (error) {
      _message('Unable to revoke access: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _memberCard(_CommitteeMember member, _Registry registry) {
    final linkedUid = (member.data['linkedUserUid'] ?? '').toString();
    final linkedGrant = linkedUid.isEmpty ? null : registry.grants[linkedUid];
    final isGrantLinkedToThisAppointment =
        linkedGrant != null && linkedGrant['committeeMemberId'] == member.id;
    final grant = isGrantLinkedToThisAppointment ? linkedGrant : null;
    final visibleLinkedUid = isGrantLinkedToThisAppointment ? linkedUid : '';
    final accountMatches = registry.accounts
        .where((a) => a.uid == visibleLinkedUid)
        .toList();
    final account = accountMatches.isEmpty ? null : accountMatches.first;
    final active = _grantIsActive(grant) && member.data['status'] == 'active';
    final permissions = grant?['permissions'] is List
        ? (grant!['permissions'] as List).whereType<String>().toList()
        : <String>[];
    final termEnd = member.termEnd;
    final canConfigure =
        member.data['status'] == 'active' &&
        termEnd != null &&
        !_day(termEnd).isBefore(_day(DateTime.now()));

    return Card(
      color: AppTheme.white,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.lightGrey,
                  child: Icon(Icons.badge_outlined, color: _navy),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        member.name,
                        style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AppText(
                        '${member.position} · term ends ${_formatDate(termEnd)}',
                        style: const TextStyle(color: _grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                _pill(
                  active
                      ? 'Access active'
                      : (grant?['status'] == 'revoked'
                            ? 'Revoked'
                            : 'No access'),
                  active: active,
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppText(
              visibleLinkedUid.isEmpty
                  ? 'No resident login linked'
                  : 'Linked account: ${account?.name ?? 'Account'} · ${account?.block ?? '—'}-${account?.house ?? '—'}',
              style: const TextStyle(color: _grey, fontSize: 11),
            ),
            if (permissions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: permissions
                    .map((permission) => _pill(permission, active: active))
                    .toList(),
              ),
            ],
            if (grant != null) ...[
              const SizedBox(height: 7),
              AppText(
                'Access period: ${_formatDate(_asDate(grant['startsAt']))} – ${_formatDate(_asDate(grant['expiresAt']))}',
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving || !canConfigure
                      ? null
                      : () => _configureAccess(member, registry),
                  icon: const Icon(Icons.tune_outlined, size: 16),
                  label: AppText(
                    grant == null ? 'Assign permissions' : 'Edit permissions',
                  ),
                ),
                if (active)
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _revokeAccess(member, grant!),
                    icon: const Icon(Icons.block_outlined, size: 16),
                    label: const AppText('Revoke'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: _navy,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Committee Delegated Permissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            AppText(
              widget.colonyName,
              style: const TextStyle(color: _grey, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppTranslations.translate('Refresh'),
            onPressed: _saving ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_Registry>(
        future: _registryFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppText(
                  'Unable to load committee accounts and grants: ${snapshot.error}',
                  style: const TextStyle(color: _grey),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }
          final registry = snapshot.data!;
          final activeGrants = registry.grants.values
              .where(_grantIsActive)
              .length;
          final linkedMembers = registry.committeeMembers
              .where(
                (m) => (m.data['linkedUserUid'] ?? '').toString().isNotEmpty,
              )
              .length;
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(15),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'Access control overview',
                          style: TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const AppText(
                          'Give each committee member only the colony operations they need. Grants are linked to existing Resident logins, recorded in the governance audit, and expire no later than the committee term.',
                          style: TextStyle(color: _grey, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _metric(
                                'Committee members',
                                '${registry.committeeMembers.length}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _metric(
                                'Linked accounts',
                                '$linkedMembers',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _metric('Active grants', '$activeGrants'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const AppText(
                    'Committee appointments',
                    style: TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const AppText(
                    'Access is granted to an active colony Resident account. A member must be linked before permissions can be enabled.',
                    style: TextStyle(color: _grey, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  if (registry.committeeMembers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: AppText(
                        'Add committee positions in the Governance > Committee register first.',
                        style: TextStyle(color: _grey),
                      ),
                    )
                  else
                    ...registry.committeeMembers.map(
                      (member) => _memberCard(member, registry),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: const AppText(
                      'Security boundaries: delegated grants are not application roles. Access to Firestore records is checked by security rules on every request. Delegated users cannot grant access to others, change committee appointments, publish notices, assign vendors, alter maintenance costs, verify payments or edit accounting records. Revoke or expire access to remove the grant.',
                      style: TextStyle(color: _grey, fontSize: 10),
                    ),
                  ),
                ],
              ),
              if (_saving)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black12,
                    child: const Center(
                      child: CircularProgressIndicator(color: _navy),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppTheme.lightGrey,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          value,
          style: const TextStyle(
            color: _navy,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        AppText(
          label,
          style: const TextStyle(
            color: _grey,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _CommitteeMember {
  const _CommitteeMember({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;
  String get name => (data['fullName'] ?? 'Committee member').toString();
  String get position => (data['position'] ?? 'Position').toString();
  DateTime? get termStart => data['termStart'] is Timestamp
      ? (data['termStart'] as Timestamp).toDate()
      : null;
  DateTime? get termEnd => data['termEnd'] is Timestamp
      ? (data['termEnd'] as Timestamp).toDate()
      : null;
}

class _ResidentAccount {
  const _ResidentAccount({
    required this.uid,
    required this.residentId,
    required this.name,
    required this.phone,
    required this.block,
    required this.house,
  });
  final String uid;
  final String residentId;
  final String name;
  final String phone;
  final String block;
  final String house;
}

class _Registry {
  const _Registry({
    required this.committeeMembers,
    required this.accounts,
    required this.grants,
  });
  final List<_CommitteeMember> committeeMembers;
  final List<_ResidentAccount> accounts;
  final Map<String, Map<String, dynamic>> grants;
}

class _GrantDraft {
  const _GrantDraft({
    required this.userUid,
    required this.permissions,
    required this.startsAt,
    required this.expiresAt,
  });
  final String userUid;
  final List<String> permissions;
  final DateTime startsAt;
  final DateTime expiresAt;
}
