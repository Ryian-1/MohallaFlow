// MOHALLAFLOW_STAFF_LEAVE_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class StaffLeaveManagementScreen extends StatefulWidget {
  const StaffLeaveManagementScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.isAdmin,
    this.adminName = '',
    this.workerId,
    this.workerName,
  });

  final String colonyId;
  final String colonyName;
  final bool isAdmin;
  final String adminName;
  final String? workerId;
  final String? workerName;

  @override
  State<StaffLeaveManagementScreen> createState() =>
      _StaffLeaveManagementScreenState();
}

class _StaffLeaveManagementScreenState
    extends State<StaffLeaveManagementScreen> {
  DateTime _selectedAdminDate = DateTime.now();

  CollectionReference<Map<String, dynamic>> get _requests => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('staffLeaveRequests');

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String _dateKey(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _dateLabel(Object? value) {
    if (value is Timestamp) value = value.toDate();
    if (value is DateTime) {
      return '${value.day.toString().padLeft(2, '0')}/'
          '${value.month.toString().padLeft(2, '0')}/${value.year}';
    }
    if (value is String && value.length == 10) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return '${parsed.day.toString().padLeft(2, '0')}/'
            '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
      }
    }
    return '—';
  }

  int _days(String start, String end) {
    final a = DateTime.tryParse(start);
    final b = DateTime.tryParse(end);
    if (a == null || b == null || b.isBefore(a)) return 0;
    return b.difference(a).inDays + 1;
  }

  String _leaveType(String? value) => switch (value) {
    'casual' => 'Casual leave',
    'sick' => 'Sick leave',
    'emergency' => 'Emergency leave',
    'unpaid' => 'Unpaid leave',
    _ => 'Leave',
  };

  String _statusLabel(String? value) =>
      (value ?? 'unknown').replaceAll('_', ' ').toUpperCase();

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.borderGrey),
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
      _statusLabel(value),
      style: const TextStyle(
        color: AppTheme.navyBlue,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? firstDate}) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: firstDate ?? DateTime(DateTime.now().year - 2),
        lastDate: DateTime(DateTime.now().year + 3),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.navyBlue),
          ),
          child: child!,
        ),
      );

  Future<void> _submitRequest() async {
    final workerId = widget.workerId?.trim() ?? '';
    if (workerId.isEmpty || _uid.isEmpty) {
      _message('Your worker profile is not linked. Contact the Colony Admin.');
      return;
    }
    final reason = TextEditingController();
    var leaveType = 'casual';
    var start = DateTime.now();
    var end = DateTime.now();
    var saving = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const AppText('Request leave'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: leaveType,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Leave type'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'casual',
                        child: AppText('Casual leave'),
                      ),
                      DropdownMenuItem(
                        value: 'sick',
                        child: AppText('Sick leave'),
                      ),
                      DropdownMenuItem(
                        value: 'emergency',
                        child: AppText('Emergency leave'),
                      ),
                      DropdownMenuItem(
                        value: 'unpaid',
                        child: AppText('Unpaid leave'),
                      ),
                    ],
                    onChanged: saving
                        ? null
                        : (v) => setLocal(() => leaveType = v ?? leaveType),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText('Start date'),
                    subtitle: AppText(_dateLabel(start)),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: saving
                          ? null
                          : () async {
                              final picked = await _pickDate(start);
                              if (picked != null) {
                                setLocal(() {
                                  start = picked;
                                  if (end.isBefore(start)) {
                                    end = start;
                                  }
                                });
                              }
                            },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText('End date'),
                    subtitle: AppText(_dateLabel(end)),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: saving
                          ? null
                          : () async {
                              final picked = await _pickDate(
                                end,
                                firstDate: start,
                              );
                              if (picked != null) {
                                setLocal(() => end = picked);
                              }
                            },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      '${_days(_dateKey(start), _dateKey(end))} calendar day(s)',
                      style: const TextStyle(
                        color: AppTheme.navyBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reason,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Reason'),
                      hintText: AppTranslations.translate(
                        'Add a brief explanation for your request',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const AppText(
                    'The Admin will decide whether approved leave is paid or unpaid according to colony policy.',
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
                      final startKey = _dateKey(start);
                      final endKey = _dateKey(end);
                      final days = _days(startKey, endKey);
                      if (reason.text.trim().length < 5 ||
                          reason.text.trim().length > 500 ||
                          days < 1 ||
                          days > 31) {
                        _message(
                          'Enter a reason (5–500 characters) and a leave period of 1–31 calendar days.',
                        );
                        return;
                      }
                      setLocal(() => saving = true);
                      try {
                        final existing = await _requests
                            .where('workerId', isEqualTo: workerId)
                            .get();
                        for (final item in existing.docs) {
                          final data = item.data();
                          if (![
                            'pending',
                            'approved',
                          ].contains(data['status'])) {
                            continue;
                          }
                          final oldStart =
                              data['startDateKey'] as String? ?? '';
                          final oldEnd = data['endDateKey'] as String? ?? '';
                          if (oldStart.isNotEmpty &&
                              oldEnd.isNotEmpty &&
                              startKey.compareTo(oldEnd) <= 0 &&
                              endKey.compareTo(oldStart) >= 0) {
                            setLocal(() => saving = false);
                            _message(
                              'This request overlaps an existing pending or approved leave request.',
                            );
                            return;
                          }
                        }
                        await _requests.add({
                          'workerId': workerId,
                          'workerUid': _uid,
                          'workerName':
                              widget.workerName?.trim().isNotEmpty == true
                              ? widget.workerName!.trim()
                              : 'Worker',
                          'leaveType': leaveType,
                          'startDateKey': startKey,
                          'endDateKey': endKey,
                          'requestedDays': days,
                          'reason': reason.text.trim(),
                          'status': 'pending',
                          'payTreatment': null,
                          'reviewNotes': '',
                          'submittedAt': FieldValue.serverTimestamp(),
                          'reviewedBy': null,
                          'reviewedByName': '',
                          'reviewedAt': null,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        setLocal(() => saving = false);
                        _message('Could not submit leave request: $error');
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppText('Submit request'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (accepted == true) {
      _message('Leave request submitted for Admin review.');
    }
  }

  Future<void> _withdraw(DocumentSnapshot<Map<String, dynamic>> doc) async {
    if (doc.data()?['status'] != 'pending') {
      return;
    }
    try {
      await doc.reference.update({
        'status': 'withdrawn',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Leave request withdrawn.');
    } catch (error) {
      _message('Could not withdraw request: $error');
    }
  }

  Future<void> _review(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool approve,
  }) async {
    final data = doc.data() ?? <String, dynamic>{};
    if (data['status'] != 'pending') {
      _message('This request has already been reviewed. Refresh the list.');
      return;
    }
    final notes = TextEditingController();
    var treatment = 'paid';
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: AppText(
            approve ? 'Approve leave request' : 'Reject leave request',
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  '${data['workerName'] ?? 'Worker'} · ${_dateLabel(data['startDateKey'])} – ${_dateLabel(data['endDateKey'])}',
                ),
                if (approve) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: treatment,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Payroll treatment'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'paid',
                        child: AppText('Paid leave'),
                      ),
                      DropdownMenuItem(
                        value: 'unpaid',
                        child: AppText('Unpaid leave'),
                      ),
                    ],
                    onChanged: (v) =>
                        setLocal(() => treatment = v ?? treatment),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  minLines: approve ? 1 : 2,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: approve
                        ? AppTranslations.translate('Admin note (optional)')
                        : AppTranslations.translate(
                            'Reason for rejection (required)',
                          ),
                    border: const OutlineInputBorder(),
                  ),
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
              child: AppText(approve ? 'Approve' : 'Reject'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) {
      notes.dispose();
      return;
    }
    final note = notes.text.trim();
    if ((!approve && note.length < 5) || note.length > 500) {
      _message('A rejection reason of at least 5 characters is required.');
      notes.dispose();
      return;
    }
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final fresh = await transaction.get(doc.reference);
        final current = fresh.data();
        if (!fresh.exists ||
            current == null ||
            current['status'] != 'pending') {
          throw StateError('This request has already been reviewed.');
        }
        transaction.update(doc.reference, {
          'status': approve ? 'approved' : 'rejected',
          'payTreatment': approve ? treatment : 'not_applicable',
          'reviewNotes': note,
          'reviewedBy': _uid,
          'reviewedByName': widget.adminName,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      _message(
        approve
            ? 'Leave approved. It will be imported into a new payroll draft.'
            : 'Leave request rejected.',
      );
    } catch (error) {
      _message('Could not review leave request: $error');
    } finally {
      notes.dispose();
    }
  }

  Widget _requestCard(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool admin,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    final status = data['status'] as String? ?? 'unknown';
    final start = data['startDateKey'] as String? ?? '';
    final end = data['endDateKey'] as String? ?? '';
    final days = (data['requestedDays'] as num?)?.toInt() ?? _days(start, end);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: AppTheme.navyBlue,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        admin
                            ? (data['workerName'] as String? ?? 'Worker')
                            : _leaveType(data['leaveType'] as String?),
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AppText(
                        '${_leaveType(data['leaveType'] as String?)} · ${_dateLabel(start)} – ${_dateLabel(end)} · $days day(s)',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 11,
                        ),
                      ),
                      if (admin)
                        AppText(
                          'Worker ID: ${data['workerId'] ?? '—'}',
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                _status(status),
              ],
            ),
            const SizedBox(height: 9),
            AppText(
              data['reason'] as String? ?? '',
              style: const TextStyle(color: AppTheme.textDark, fontSize: 12),
            ),
            if (status == 'approved') ...[
              const SizedBox(height: 5),
              AppText(
                'Payroll: ${data['payTreatment'] == 'paid' ? 'Paid leave' : 'Unpaid leave'}',
                style: const TextStyle(
                  color: AppTheme.navyBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if ((data['reviewNotes'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 5),
              AppText(
                'Admin note: ${data['reviewNotes']}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
              ),
            ],
            if (admin && status == 'pending') ...[
              const Divider(height: 18),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _review(doc, approve: false),
                    child: const AppText('Reject'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _review(doc, approve: true),
                    icon: const Icon(Icons.check, size: 16),
                    label: const AppText('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyBlue,
                    ),
                  ),
                ],
              ),
            ],
            if (!admin && status == 'pending') ...[
              const Divider(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _withdraw(doc),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const AppText('Withdraw request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _adminView() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _requests.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: AppText('Unable to load leave requests. ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyBlue),
        );
      }
      final docs = [...snapshot.data!.docs];
      docs.sort(
        (a, b) => (b.data()['startDateKey'] as String? ?? '').compareTo(
          a.data()['startDateKey'] as String? ?? '',
        ),
      );
      final pending = docs.where((d) => d.data()['status'] == 'pending').length;
      final selectedKey = _dateKey(_selectedAdminDate);
      final selectedDayLeaves = docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'approved' &&
            (data['startDateKey'] as String? ?? '').compareTo(selectedKey) <=
                0 &&
            (data['endDateKey'] as String? ?? '').compareTo(selectedKey) >= 0;
      }).toList();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Pending requests',
                  '$pending',
                  Icons.pending_actions_outlined,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _metric(
                  'Total requests',
                  '${docs.length}',
                  Icons.event_note_outlined,
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
                  'Colony leave calendar',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const AppText(
                  'Select a date to see approved leave for that day.',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                ),
                CalendarDatePicker(
                  initialDate: _selectedAdminDate,
                  firstDate: DateTime(DateTime.now().year - 2, 1),
                  lastDate: DateTime(DateTime.now().year + 3, 12, 31),
                  onDateChanged: (value) =>
                      setState(() => _selectedAdminDate = value),
                ),
                const Divider(),
                AppText(
                  'Approved leave on ${_dateLabel(selectedKey)}',
                  style: const TextStyle(
                    color: AppTheme.navyBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (selectedDayLeaves.isEmpty)
                  const AppText(
                    'No approved leave recorded for this date.',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                  )
                else
                  ...selectedDayLeaves.map(
                    (doc) => _requestCard(doc, admin: true),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const AppText(
            'All staff leave requests',
            style: TextStyle(
              color: AppTheme.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          if (docs.isEmpty)
            _panel(
              child: const AppText(
                'No leave requests have been submitted.',
                style: TextStyle(color: AppTheme.textGrey),
              ),
            )
          else
            ...docs.map((doc) => _requestCard(doc, admin: true)),
        ],
      );
    },
  );

  Widget _metric(String title, String value, IconData icon) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.secondaryNavy, size: 20),
        const SizedBox(height: 7),
        AppText(
          value,
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        AppText(
          title,
          style: const TextStyle(
            color: AppTheme.textGrey,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _workerView() {
    final workerId = widget.workerId?.trim() ?? '';
    if (workerId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: AppText(
            'Your worker profile is not linked to this account. Contact the Colony Admin.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requests.where('workerId', isEqualTo: workerId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: AppText(
              'Unable to load your leave history. ${snapshot.error}',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }
        final docs = [...snapshot.data!.docs];
        docs.sort(
          (a, b) => (b.data()['startDateKey'] as String? ?? '').compareTo(
            a.data()['startDateKey'] as String? ?? '',
          ),
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Hello, ${widget.workerName ?? 'Worker'}',
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const AppText(
                    'Submit a leave request and track its approval status. The Admin decides paid or unpaid treatment.',
                    style: TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 11),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitRequest,
                      icon: const Icon(Icons.add),
                      label: const AppText('Request leave'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navyBlue,
                        foregroundColor: AppTheme.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AppText(
              'My leave history',
              style: TextStyle(
                color: AppTheme.textDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            if (docs.isEmpty)
              _panel(
                child: const AppText(
                  'No leave requests yet.',
                  style: TextStyle(color: AppTheme.textGrey),
                ),
              )
            else
              ...docs.map((doc) => _requestCard(doc, admin: false)),
          ],
        );
      },
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              widget.isAdmin ? 'Staff Leave Management' : 'My Leave',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            AppText(
              widget.colonyName,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
            ),
          ],
        ),
      ),
      body: widget.isAdmin ? _adminView() : _workerView(),
    );
  }
}
// MOHALLAFLOW_STAFF_LEAVE_SCREEN_END
