// WORKER_ATTENDANCE_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_locale_controller.dart';

/// Native daily check-in/check-out for a linked colony worker, or a manager's
/// date-wise attendance register. No GPS/location collection is performed.
class WorkerAttendanceScreen extends StatefulWidget {
  const WorkerAttendanceScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.isManager,
    this.workerId,
    this.workerName,
  });

  final String colonyId;
  final String colonyName;
  final bool isManager;
  final String? workerId;
  final String? workerName;

  @override
  State<WorkerAttendanceScreen> createState() => _WorkerAttendanceScreenState();
}

class _WorkerAttendanceScreenState extends State<WorkerAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  CollectionReference<Map<String, dynamic>> get _attendance => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('workerAttendance');

  CollectionReference<Map<String, dynamic>> get _workers => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('cleanlinessWorkers');

  String _dateKey(DateTime date) {
    final d = date.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String get _todayKey => _dateKey(DateTime.now());

  String get _todayDocumentId => '${widget.workerId}_$_todayKey';

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _checkIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final workerId = widget.workerId;
    if (uid == null || workerId == null || workerId.isEmpty || _saving) {
      _message('Please sign in again to record attendance.');
      return;
    }

    setState(() => _saving = true);
    try {
      final reference = _attendance.doc(_todayDocumentId);
      // The deterministic worker/date document ID plus create-only rules
      // prevents duplicate daily records, including concurrent taps.
      await reference.set({
        'workerId': workerId,
        'workerUid': uid,
        'workerName': widget.workerName?.trim().isNotEmpty == true
            ? widget.workerName!.trim()
            : 'Worker',
        'attendanceDateKey': _todayKey,
        'checkInAt': FieldValue.serverTimestamp(),
        'checkOutAt': null,
        'status': 'checked_in',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Check-in recorded successfully.');
    } on FirebaseException catch (error) {
      debugPrint('Worker check-in failed: ${error.code} ${error.message}');
      _message('Unable to check in: ${error.message ?? error.code}');
    } catch (error) {
      debugPrint('Worker check-in error: $error');
      _message('Unable to check in. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkOut() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _attendance.doc(_todayDocumentId).update({
        'checkOutAt': FieldValue.serverTimestamp(),
        'status': 'checked_out',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Check-out recorded successfully.');
    } on FirebaseException catch (error) {
      debugPrint('Worker check-out failed: ${error.code} ${error.message}');
      _message('Unable to check out: ${error.message ?? error.code}');
    } catch (error) {
      debugPrint('Worker check-out error: $error');
      _message('Unable to check out. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: 'Select attendance date',
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  String _timeLabel(Object? value) {
    if (value is! Timestamp) return 'Pending';
    return TimeOfDay.fromDateTime(value.toDate().toLocal()).format(context);
  }

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE1E6ED)),
    ),
    child: child,
  );

  Widget _metric(String label, String value, IconData icon) => Expanded(
    child: _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.navyBlue, size: 20),
          const SizedBox(height: 10),
          AppText(
            value,
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          AppText(
            label,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _buildWorkerView() {
    if (widget.workerId == null || widget.workerId!.isEmpty) {
      return const Center(child: AppText('Worker profile is not linked.'));
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        AppText(
          'Welcome, ${widget.workerName ?? 'Worker'}',
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const AppText(
          'Record your attendance for today.',
          style: TextStyle(color: AppTheme.textGrey),
        ),
        const SizedBox(height: 18),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _attendance.doc(_todayDocumentId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _panel(
                child: AppText(
                  'Unable to load today\'s attendance.\n${snapshot.error}',
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _panel(
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.navyBlue),
                ),
              );
            }
            final exists = snapshot.data?.exists ?? false;
            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final status = data['status'] as String? ?? '';
            final checkedOut = status == 'checked_out';
            return _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'TODAY\'S ATTENDANCE',
                    style: TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    _todayKey,
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!exists) ...[
                    const AppText(
                      'You have not checked in yet.',
                      style: TextStyle(color: AppTheme.textGrey),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _checkIn,
                        icon: const Icon(Icons.login_rounded),
                        label: AppText(_saving ? 'Please wait…' : 'Check in'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navyBlue,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ] else ...[
                    _timeRow('Check-in time', _timeLabel(data['checkInAt'])),
                    const SizedBox(height: 9),
                    _timeRow(
                      'Check-out time',
                      checkedOut
                          ? _timeLabel(data['checkOutAt'])
                          : 'Not checked out',
                    ),
                    const SizedBox(height: 14),
                    if (checkedOut)
                      const AppText(
                        'Attendance completed for today.',
                        style: TextStyle(
                          color: AppTheme.navyBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _checkOut,
                          icon: const Icon(Icons.logout_rounded),
                          label: AppText(
                            _saving ? 'Please wait…' : 'Check out',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.navyBlue,
                            side: const BorderSide(color: AppTheme.navyBlue),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        const AppText(
          'Attendance history',
          style: TextStyle(
            color: AppTheme.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _attendance
              .where('workerId', isEqualTo: widget.workerId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _panel(
                child: AppText('Unable to load history.\n${snapshot.error}'),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.navyBlue),
                ),
              );
            }
            final records = [...?snapshot.data?.docs];
            records.sort(
              (a, b) => (b.data()['attendanceDateKey'] as String? ?? '')
                  .compareTo(a.data()['attendanceDateKey'] as String? ?? ''),
            );
            if (records.isEmpty) {
              return _panel(
                child: const AppText(
                  'No attendance records yet.',
                  style: TextStyle(color: AppTheme.textGrey),
                ),
              );
            }
            return Column(
              children: records.take(30).map((record) {
                final data = record.data();
                final complete = data['status'] == 'checked_out';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _panel(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: AppTheme.navyBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                data['attendanceDateKey'] as String? ??
                                    'Date unavailable',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AppText(
                                'In ${_timeLabel(data['checkInAt'])}  •  Out ${complete ? _timeLabel(data['checkOutAt']) : '—'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _statusPill(complete ? 'Completed' : 'Checked in'),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _timeRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      AppText(
        label,
        style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
      ),
      AppText(
        value,
        style: const TextStyle(
          color: AppTheme.textDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _statusPill(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF0F7),
      borderRadius: BorderRadius.circular(30),
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

  Widget _buildManagerView() {
    final key = _dateKey(_selectedDate);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _workers.where('status', isEqualTo: 'active').snapshots(),
      builder: (context, workerSnapshot) {
        if (workerSnapshot.hasError) {
          return Center(
            child: AppText('Unable to load workers.\n${workerSnapshot.error}'),
          );
        }
        if (workerSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }
        final workers = [...?workerSnapshot.data?.docs];
        workers.sort(
          (a, b) => (a.data()['fullName'] as String? ?? '').compareTo(
            b.data()['fullName'] as String? ?? '',
          ),
        );
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _attendance
              .where('attendanceDateKey', isEqualTo: key)
              .snapshots(),
          builder: (context, attendanceSnapshot) {
            if (attendanceSnapshot.hasError) {
              return Center(
                child: AppText(
                  'Unable to load attendance.\n${attendanceSnapshot.error}',
                ),
              );
            }
            if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.navyBlue),
              );
            }
            final records = attendanceSnapshot.data?.docs ?? [];
            final byWorker = <String, Map<String, dynamic>>{};
            for (final record in records) {
              final data = record.data();
              final id = data['workerId'] as String?;
              if (id != null) byWorker[id] = data;
            }
            final present = workers
                .where((worker) => byWorker.containsKey(worker.id))
                .length;
            final notMarked = workers.length - present;
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                AppText(
                  'Worker attendance',
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const AppText(
                  'Daily check-in register for active colony workers.',
                  style: TextStyle(color: AppTheme.textGrey),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: AppText(key),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.navyBlue,
                    side: const BorderSide(color: Color(0xFFE1E6ED)),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _metric(
                      'Checked in',
                      '$present',
                      Icons.how_to_reg_outlined,
                    ),
                    const SizedBox(width: 10),
                    _metric(
                      'No check-in',
                      '$notMarked',
                      Icons.person_off_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AppText(
                  'Active workers (${workers.length})',
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (workers.isEmpty)
                  _panel(
                    child: const AppText(
                      'No active workers are registered.',
                      style: TextStyle(color: AppTheme.textGrey),
                    ),
                  )
                else
                  ...workers.map((worker) {
                    final data = worker.data();
                    final attendance = byWorker[worker.id];
                    final checked = attendance != null;
                    final complete = attendance?['status'] == 'checked_out';
                    final name = data['fullName'] as String? ?? 'Worker';
                    final area = data['assignedArea'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _panel(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFEAF0F7),
                              foregroundColor: AppTheme.navyBlue,
                              child: AppText(
                                name.isNotEmpty
                                    ? name.substring(0, 1).toUpperCase()
                                    : 'W',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    name,
                                    style: const TextStyle(
                                      color: AppTheme.textDark,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (area.isNotEmpty)
                                    AppText(
                                      area,
                                      style: const TextStyle(
                                        color: AppTheme.textGrey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  if (checked)
                                    AppText(
                                      'Check-in ${_timeLabel(attendance['checkInAt'])}${complete ? '  •  Check-out ${_timeLabel(attendance['checkOutAt'])}' : ''}',
                                      style: const TextStyle(
                                        color: AppTheme.textGrey,
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _statusPill(
                              !checked
                                  ? 'No check-in'
                                  : complete
                                  ? 'Completed'
                                  : 'On duty',
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                const AppText(
                  '“No check-in” means no attendance record exists for this date; it is not a manually confirmed absence.',
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            );
          },
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
              widget.isManager ? 'Worker Attendance' : 'My Attendance',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            AppText(
              widget.colonyName,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
          ],
        ),
      ),
      body: widget.isManager ? _buildManagerView() : _buildWorkerView(),
    );
  }
}
// WORKER_ATTENDANCE_SCREEN_END
