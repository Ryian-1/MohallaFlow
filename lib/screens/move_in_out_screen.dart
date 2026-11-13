// MOHALLAFLOW_MOVE_IN_OUT_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Resident move-out requests and Admin-controlled move-in scheduling.
/// Offboarding updates the resident, membership and request in one batch.
class MoveInOutScreen extends StatefulWidget {
  const MoveInOutScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.isAdmin,
    this.adminName,
    this.residentId,
    this.residentName,
  });

  final String colonyId;
  final String colonyName;
  final bool isAdmin;
  final String? adminName;
  final String? residentId;
  final String? residentName;

  @override
  State<MoveInOutScreen> createState() => _MoveInOutScreenState();
}

class _MoveInOutScreenState extends State<MoveInOutScreen>
    with SingleTickerProviderStateMixin {
  late final TabController? _tabs;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _colony =>
      _db.collection('colonies').doc(widget.colonyId);
  CollectionReference<Map<String, dynamic>> get _requests =>
      _colony.collection('moveRequests');
  CollectionReference<Map<String, dynamic>> get _households =>
      _colony.collection('households');
  CollectionReference<Map<String, dynamic>> get _residents =>
      _colony.collection('residents');
  CollectionReference<Map<String, dynamic>> get _bills =>
      _colony.collection('maintenanceBills');

  @override
  void initState() {
    super.initState();
    _tabs = widget.isAdmin ? TabController(length: 2, vsync: this) : null;
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _dateLabel(Object? value) {
    if (value is! Timestamp) return 'Date not set';
    final d = value.toDate().toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _label(String value) => value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
      case 'completed':
        return const Color(0xFF246B8E);
      case 'pending':
      case 'scheduled':
        return const Color(0xFF996515);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFB54747);
      default:
        return AppTheme.textGrey;
    }
  }

  Widget _tag(String text, String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _statusColor(status).withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(30),
    ),
    child: AppText(
      text,
      style: TextStyle(
        color: _statusColor(status),
        fontSize: 10,
        fontWeight: FontWeight.w800,
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

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navyBlue,
        elevation: 0,
        title: AppText(
          widget.isAdmin ? 'Move-In & Move-Out' : 'My Move-Out Requests',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: widget.isAdmin
            ? TabBar(
                controller: _tabs,
                labelColor: AppTheme.navyBlue,
                unselectedLabelColor: AppTheme.textGrey,
                indicatorColor: AppTheme.navyBlue,
                tabs: [
                  Tab(text: AppTranslations.translate('Move requests')),
                  Tab(text: AppTranslations.translate('Schedule move-in')),
                ],
              )
            : null,
      ),
      body: widget.isAdmin
          ? TabBarView(
              controller: _tabs,
              children: [_adminRequests(), _adminMoveIns()],
            )
          : _residentRequests(),
      floatingActionButton: !widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _requestMoveOut,
              backgroundColor: AppTheme.navyBlue,
              foregroundColor: AppTheme.white,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const AppText('Request move-out'),
            )
          : null,
    );
  }

  // =====================================================
  // RESIDENT: CREATE AND REVIEW OWN MOVE-OUT REQUESTS
  // =====================================================

  Future<void> _requestMoveOut() async {
    final uid = _uid;
    final residentId = widget.residentId;
    if (uid == null || residentId == null || residentId.trim().isEmpty) {
      _message('Your resident profile is not linked. Contact your Admin.');
      return;
    }

    final residentRef = _residents.doc(residentId);
    late DocumentSnapshot<Map<String, dynamic>> residentSnapshot;
    late QuerySnapshot<Map<String, dynamic>> existing;
    try {
      residentSnapshot = await residentRef.get();
      existing = await _requests.where('requesterUid', isEqualTo: uid).get();
    } on FirebaseException catch (error) {
      _message('Unable to load your move-out details (${error.code}).');
      return;
    }
    if (!mounted) return;
    if (!residentSnapshot.exists) {
      _message('Resident record not found. Contact your Admin.');
      return;
    }
    final resident = residentSnapshot.data() ?? <String, dynamic>{};
    if (resident['residentStatus'] != 'active') {
      _message('This resident profile is not active.');
      return;
    }

    final hasOpenRequest = existing.docs.any((doc) {
      final data = doc.data();
      return data['requesterResidentId'] == residentId &&
          ['pending', 'approved'].contains(data['status']);
    });
    if (hasOpenRequest) {
      _message('You already have a pending or approved move-out request.');
      return;
    }

    final companyController = TextEditingController();
    final vehicleController = TextEditingController();
    final notesController = TextEditingController();
    DateTime movingDate = DateTime.now().add(const Duration(days: 7));
    final formKey = GlobalKey<FormState>();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const AppText('Request move-out'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppText(
                          'Household: Block ${resident['blockId'] ?? ''} · '
                          'House ${resident['houseNumber'] ?? ''}',
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const AppText('Proposed moving date'),
                        subtitle: AppText(
                          _dateLabel(Timestamp.fromDate(movingDate)),
                        ),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: movingDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null && dialogContext.mounted) {
                            setDialogState(() => movingDate = picked);
                          }
                        },
                      ),
                      TextFormField(
                        controller: companyController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Moving company (optional)',
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: vehicleController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Moving vehicle number (optional)',
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: notesController,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Additional details (optional)',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const AppText(
                        'Your request will be reviewed by the Colony Admin. '
                        'Outstanding maintenance dues must be cleared before '
                        'the move-out can be completed.',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const AppText('Submit request'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      final householdId = resident['householdId'] as String? ?? '';
      if (householdId.isEmpty) {
        _message('Your resident record has no linked household.');
        return;
      }
      await _requests.add({
        'requestType': 'move_out',
        'status': 'pending',
        'householdId': householdId,
        'blockId': resident['blockId'] ?? '',
        'houseNumber': resident['houseNumber'] ?? '',
        'householdHeadName': resident['fullName'] ?? widget.residentName ?? '',
        'scheduledDate': Timestamp.fromDate(
          DateTime(movingDate.year, movingDate.month, movingDate.day),
        ),
        'movingCompany': companyController.text.trim(),
        'vehicleRegistration': vehicleController.text.trim().toUpperCase(),
        'occupantCount': 1,
        'notes': notesController.text.trim(),
        'requestedBy': uid,
        'requestedByName': widget.residentName?.trim().isNotEmpty == true
            ? widget.residentName!.trim()
            : (resident['fullName'] as String? ?? 'Resident'),
        'requesterUid': uid,
        'requesterResidentId': residentId,
        'newHouseholdHeadName': '',
        'newPrimaryPhone': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Move-out request submitted for Admin review.');
    } on FirebaseException catch (error) {
      _message('Unable to submit request (${error.code}).');
    } catch (error) {
      _message('Unable to submit move-out request: $error');
    } finally {
      companyController.dispose();
      vehicleController.dispose();
      notesController.dispose();
    }
  }

  Widget _residentRequests() {
    final uid = _uid;
    if (uid == null) {
      return _empty(
        'Sign-in required',
        'Please sign in again.',
        Icons.lock_outline,
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requests.where('requesterUid', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _empty(
            'Unable to load requests',
            'Check your connection and Firestore rules.',
            Icons.error_outline,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }
        final docs = [...?snapshot.data?.docs];
        docs.sort((a, b) {
          final av = a.data()['createdAt'];
          final bv = b.data()['createdAt'];
          final ad = av is Timestamp ? av : Timestamp(0, 0);
          final bd = bv is Timestamp ? bv : Timestamp(0, 0);
          return bd.compareTo(ad);
        });
        if (docs.isEmpty) {
          return _empty(
            'No move-out requests',
            'Submit a request when you are planning to move out of the colony.',
            Icons.local_shipping_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final status = data['status'] as String? ?? 'pending';
            return Card(
              color: AppTheme.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.borderGrey),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          color: AppTheme.navyBlue,
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: AppText(
                            'Move-out request',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _tag(_label(status), status),
                      ],
                    ),
                    const SizedBox(height: 9),
                    AppText(
                      'Block ${data['blockId'] ?? ''} · House ${data['houseNumber'] ?? ''}',
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 12,
                      ),
                    ),
                    AppText(
                      'Proposed date: ${_dateLabel(data['scheduledDate'])}',
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 12,
                      ),
                    ),
                    if ((data['notes'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      AppText(
                        data['notes'] as String,
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (status == 'pending')
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _cancelOwnRequest(doc),
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const AppText('Cancel request'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelOwnRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final uid = _uid;
    if (uid == null || doc.data()['status'] != 'pending') return;
    try {
      await doc.reference.update({
        'status': 'cancelled',
        'cancelledBy': uid,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Move-out request cancelled.');
    } on FirebaseException catch (error) {
      _message('Unable to cancel request (${error.code}).');
    }
  }

  // =====================================================
  // ADMIN: REVIEW MOVE-OUT REQUESTS
  // =====================================================

  Widget _adminRequests() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requests.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _empty(
            'Unable to load move requests',
            'Check your connection and Firestore rules.',
            Icons.error_outline,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _empty(
            'No move requests yet',
            'Resident move-out requests and scheduled move-ins will appear here.',
            Icons.local_shipping_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          itemCount: docs.length,
          itemBuilder: (context, index) => _adminRequestCard(docs[index]),
        );
      },
    );
  }

  Widget _adminRequestCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final type = data['requestType'] as String? ?? 'move_out';
    final status = data['status'] as String? ?? 'pending';
    final isMoveOut = type == 'move_out';
    return Card(
      color: AppTheme.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isMoveOut ? Icons.logout_rounded : Icons.login_rounded,
                  color: AppTheme.navyBlue,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: AppText(
                    isMoveOut ? 'Resident move-out' : 'Scheduled move-in',
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _tag(_label(status), status),
              ],
            ),
            const SizedBox(height: 9),
            AppText(
              '${data['requestedByName'] ?? 'Resident'} · '
              'Block ${data['blockId'] ?? ''} · House ${data['houseNumber'] ?? ''}',
              style: const TextStyle(color: AppTheme.textDark, fontSize: 12),
            ),
            if (!isMoveOut)
              AppText(
                'Incoming head: ${data['newHouseholdHeadName'] ?? ''} · '
                '${data['occupantCount'] ?? 1} occupant(s)',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
            AppText(
              'Moving date: ${_dateLabel(data['scheduledDate'])}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
            if ((data['movingCompany'] as String? ?? '').isNotEmpty)
              AppText(
                'Mover: ${data['movingCompany']}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
            if ((data['vehicleRegistration'] as String? ?? '').isNotEmpty)
              AppText(
                'Vehicle: ${data['vehicleRegistration']}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
            if ((data['notes'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: AppText(
                  data['notes'] as String,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 9),
            if (isMoveOut && status == 'pending')
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _setMoveOutDecision(doc, 'rejected'),
                    child: const AppText('Reject'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyBlue,
                    ),
                    onPressed: () => _setMoveOutDecision(doc, 'approved'),
                    child: const AppText('Approve'),
                  ),
                ],
              ),
            if (isMoveOut && status == 'approved')
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navyBlue,
                  ),
                  onPressed: () => _completeMoveOut(doc),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const AppText('Check dues & complete'),
                ),
              ),
            if (!isMoveOut && status == 'scheduled')
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navyBlue,
                  ),
                  onPressed: () => _completeMoveIn(doc),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const AppText('Mark move-in completed'),
                ),
              ),
            if (status == 'completed' && !isMoveOut)
              const AppText(
                'Move-in completed. Add incoming occupants in Residents.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setMoveOutDecision(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    final uid = _uid;
    if (uid == null || !['approved', 'rejected'].contains(status)) return;
    try {
      final now = FieldValue.serverTimestamp();
      await doc.reference.update({
        'status': status,
        'updatedAt': now,
        if (status == 'approved') 'approvedBy': uid,
        if (status == 'approved') 'approvedAt': now,
        if (status == 'rejected') 'rejectedBy': uid,
        if (status == 'rejected') 'rejectedAt': now,
      });
      _message(
        status == 'approved'
            ? 'Move-out request approved.'
            : 'Move-out request rejected.',
      );
    } on FirebaseException catch (error) {
      _message('Unable to update request (${error.code}).');
    }
  }

  Future<void> _completeMoveOut(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    final data = doc.data();
    if (data['status'] != 'approved') return;
    final householdId = data['householdId'] as String? ?? '';
    final residentId = data['requesterResidentId'] as String? ?? '';
    final requesterUid = data['requesterUid'] as String? ?? '';
    if (householdId.isEmpty || residentId.isEmpty || requesterUid.isEmpty) {
      _message('The request is missing resident or household linkage.');
      return;
    }

    try {
      final bills = await _bills
          .where('householdId', isEqualTo: householdId)
          .get();
      if (!mounted) return;
      var outstanding = 0.0;
      for (final bill in bills.docs) {
        final billData = bill.data();
        final total = billData['totalAmount'] is num
            ? (billData['totalAmount'] as num).toDouble()
            : 0.0;
        final paid = billData['amountPaid'] is num
            ? (billData['amountPaid'] as num).toDouble()
            : 0.0;
        outstanding += (total - paid).clamp(0, double.infinity).toDouble();
      }
      if (outstanding > 0.009) {
        _message(
          'Outstanding maintenance dues: ₹${outstanding.toStringAsFixed(2)}. Clear them in Maintenance Dues before completing move-out.',
        );
        return;
      }

      final residentRef = _residents.doc(residentId);
      final householdRef = _households.doc(householdId);
      final memberRef = _colony.collection('members').doc(requesterUid);
      final residentSnapshot = await residentRef.get();
      final householdSnapshot = await householdRef.get();
      if (!mounted) return;
      if (!residentSnapshot.exists || !householdSnapshot.exists) {
        _message('Resident or household record is missing.');
        return;
      }
      final residentData = residentSnapshot.data() ?? <String, dynamic>{};
      if (residentData['residentStatus'] != 'active' ||
          residentData['householdId'] != householdId) {
        _message(
          'The resident is no longer active or linked to this household.',
        );
        return;
      }

      // Admin can list resident records, but membership documents are private.
      // The tightly scoped member update rule validates this membership during
      // the atomic batch, so no client-side read of the member document occurs.
      final activeResidents = await _residents
          .where('householdId', isEqualTo: householdId)
          .get();
      if (!mounted) return;
      final remainingActiveResidents = activeResidents.docs.where((
        residentDoc,
      ) {
        return residentDoc.id != residentId &&
            residentDoc.data()['residentStatus'] == 'active';
      }).length;
      final isLastActiveResident = remainingActiveResidents == 0;

      final batch = _db.batch();
      batch.update(residentRef, {
        'residentStatus': 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(memberRef, {
        'status': 'inactive',
        'moveOutRequestId': doc.id,
      });
      if (isLastActiveResident) {
        batch.update(householdRef, {
          'occupancyStatus': 'vacant',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(doc.reference, {
        'status': 'completed',
        'completedBy': uid,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _message(
        isLastActiveResident
            ? 'Move-out completed. Household is now marked vacant.'
            : 'Move-out completed. Other active household residents remain registered.',
      );
    } on FirebaseException catch (error) {
      _message('Unable to complete move-out (${error.code}).');
    } catch (error) {
      _message('Unable to complete move-out: $error');
    }
  }

  // =====================================================
  // ADMIN: SCHEDULE AND COMPLETE MOVE-INS
  // =====================================================

  Widget _adminMoveIns() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Incoming households',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  AppText(
                    'Schedule an approved move-in for a vacant household.',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _scheduleMoveIn,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const AppText('Schedule'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _requests
              .where('requestType', isEqualTo: 'move_in')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _empty(
                'Unable to load move-ins',
                'Check Firestore rules.',
                Icons.error_outline,
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.navyBlue),
              );
            }
            final docs = [...?snapshot.data?.docs];
            docs.sort((a, b) {
              final av = a.data()['scheduledDate'];
              final bv = b.data()['scheduledDate'];
              final ad = av is Timestamp ? av : Timestamp(0, 0);
              final bd = bv is Timestamp ? bv : Timestamp(0, 0);
              return ad.compareTo(bd);
            });
            if (docs.isEmpty) {
              return _empty(
                'No move-ins scheduled',
                'Use Schedule to register an incoming household.',
                Icons.login_outlined,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
              itemCount: docs.length,
              itemBuilder: (context, index) => _adminRequestCard(docs[index]),
            );
          },
        ),
      ),
    ],
  );

  Future<void> _scheduleMoveIn() async {
    final uid = _uid;
    if (uid == null) {
      _message('Please sign in again.');
      return;
    }
    late QuerySnapshot<Map<String, dynamic>> vacantSnapshot;
    late QuerySnapshot<Map<String, dynamic>> moveInSnapshot;
    try {
      vacantSnapshot = await _households
          .where('occupancyStatus', isEqualTo: 'vacant')
          .get();
      moveInSnapshot = await _requests
          .where('requestType', isEqualTo: 'move_in')
          .get();
    } on FirebaseException catch (error) {
      _message('Unable to load vacant households (${error.code}).');
      return;
    }
    if (!mounted) return;
    final scheduledHouseholdIds = moveInSnapshot.docs
        .where((doc) => doc.data()['status'] == 'scheduled')
        .map((doc) => doc.data()['householdId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final availableHouseholds = vacantSnapshot.docs
        .where((doc) => !scheduledHouseholdIds.contains(doc.id))
        .toList();
    if (availableHouseholds.isEmpty) {
      _message(
        'There are no vacant households without an existing scheduled move-in.',
      );
      return;
    }

    final headController = TextEditingController();
    final phoneController = TextEditingController();
    final companyController = TextEditingController();
    final vehicleController = TextEditingController();
    final occupantsController = TextEditingController(text: '1');
    final notesController = TextEditingController();
    String? selectedHouseholdId = availableHouseholds.first.id;
    DateTime movingDate = DateTime.now().add(const Duration(days: 1));
    final formKey = GlobalKey<FormState>();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const AppText('Schedule move-in'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedHouseholdId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Vacant household',
                          ),
                        ),
                        items: availableHouseholds.map((doc) {
                          final d = doc.data();
                          return DropdownMenuItem(
                            value: doc.id,
                            child: AppText(
                              'Block ${d['blockId'] ?? ''} · House ${d['houseNumber'] ?? ''}',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setDialogState(() => selectedHouseholdId = value),
                      ),
                      TextFormField(
                        controller: headController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Incoming household head',
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? AppTranslations.translate(
                                'Enter household head name',
                              )
                            : null,
                      ),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Primary mobile number',
                          ),
                        ),
                        validator: (value) =>
                            value == null ||
                                !RegExp(r'^[6-9][0-9]{9}$')
                                    .hasMatch(value.trim())
                            ? AppTranslations.translate(
                                'Enter a valid 10-digit Indian mobile number',
                              )
                            : null,
                      ),
                      TextFormField(
                        controller: occupantsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Number of occupants',
                          ),
                        ),
                        validator: (value) {
                          final n = int.tryParse(value ?? '');
                          return n == null || n < 1 || n > 30
                              ? AppTranslations.translate(
                                  'Enter 1–30 occupants',
                                )
                              : null;
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const AppText('Scheduled moving date'),
                        subtitle: AppText(
                          _dateLabel(Timestamp.fromDate(movingDate)),
                        ),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: movingDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null && dialogContext.mounted) {
                            setDialogState(() => movingDate = picked);
                          }
                        },
                      ),
                      TextFormField(
                        controller: companyController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Moving company (optional)',
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: vehicleController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Moving vehicle number (optional)',
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Notes (optional)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                ),
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const AppText('Schedule move-in'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || selectedHouseholdId == null) return;
      final household = availableHouseholds
          .firstWhere((doc) => doc.id == selectedHouseholdId)
          .data();
      await _requests.add({
        'requestType': 'move_in',
        'status': 'scheduled',
        'householdId': selectedHouseholdId,
        'blockId': household['blockId'] ?? '',
        'houseNumber': household['houseNumber'] ?? '',
        'householdHeadName': household['householdHeadName'] ?? '',
        'scheduledDate': Timestamp.fromDate(
          DateTime(movingDate.year, movingDate.month, movingDate.day),
        ),
        'movingCompany': companyController.text.trim(),
        'vehicleRegistration': vehicleController.text.trim().toUpperCase(),
        'occupantCount': int.parse(occupantsController.text.trim()),
        'notes': notesController.text.trim(),
        'requestedBy': uid,
        'requestedByName': widget.adminName?.trim().isNotEmpty == true
            ? widget.adminName!.trim()
            : 'Colony Admin',
        'requesterUid': '',
        'requesterResidentId': '',
        'newHouseholdHeadName': headController.text.trim(),
        'newPrimaryPhone': phoneController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Move-in scheduled.');
    } on FirebaseException catch (error) {
      _message('Unable to schedule move-in (${error.code}).');
    } catch (error) {
      _message('Unable to schedule move-in: $error');
    } finally {
      headController.dispose();
      phoneController.dispose();
      companyController.dispose();
      vehicleController.dispose();
      occupantsController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _completeMoveIn(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final uid = _uid;
    if (uid == null || doc.data()['status'] != 'scheduled') return;
    final data = doc.data();
    final householdId = data['householdId'] as String? ?? '';
    if (householdId.isEmpty) {
      _message('The scheduled move-in has no household linked.');
      return;
    }
    try {
      final householdRef = _households.doc(householdId);
      final householdSnapshot = await householdRef.get();
      if (!mounted) return;
      if (!householdSnapshot.exists ||
          householdSnapshot.data()?['occupancyStatus'] != 'vacant') {
        _message(
          'This household is no longer vacant. Refresh and review the record.',
        );
        return;
      }
      final batch = _db.batch();
      batch.update(householdRef, {
        'occupancyStatus': 'occupied',
        'householdHeadName': data['newHouseholdHeadName'],
        'primaryPhone': data['newPrimaryPhone'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(doc.reference, {
        'status': 'completed',
        'completedBy': uid,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _message(
        'Move-in completed. Add the incoming occupants in the Residents module.',
      );
    } on FirebaseException catch (error) {
      _message('Unable to complete move-in (${error.code}).');
    } catch (error) {
      _message('Unable to complete move-in: $error');
    }
  }
}
// MOHALLAFLOW_MOVE_IN_OUT_SCREEN_END
