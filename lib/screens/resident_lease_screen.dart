import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'move_in_out_screen.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class ResidentLeaseScreen extends StatefulWidget {
  const ResidentLeaseScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.residentId,
    required this.residentName,
  });

  final String colonyId;
  final String colonyName;
  final String residentId;
  final String residentName;

  @override
  State<ResidentLeaseScreen> createState() => _ResidentLeaseScreenState();
}

class _ResidentLeaseScreenState extends State<ResidentLeaseScreen> {
  CollectionReference<Map<String, dynamic>> get _leases => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('tenantLeases');

  CollectionReference<Map<String, dynamic>> get _renewalRequests =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('tenantLeaseRenewalRequests');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _date(Object? value) {
    if (value is! Timestamp) return 'Not available';
    final date = value.toDate().toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _money(Object? value) {
    final amount = value is num ? value : 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _leaseStatus(Map<String, dynamic> data) {
    if (data['status'] == 'terminated') return 'Terminated';
    final start = data['leaseStart'];
    final end = data['leaseEnd'];
    final today = DateUtils.dateOnly(DateTime.now());
    if (end is Timestamp && DateUtils.dateOnly(end.toDate()).isBefore(today)) {
      return 'Expired';
    }
    if (start is Timestamp &&
        DateUtils.dateOnly(start.toDate()).isAfter(today)) {
      return 'Upcoming';
    }
    if (end is Timestamp) {
      final days = DateUtils.dateOnly(end.toDate()).difference(today).inDays;
      if (days <= 30) return 'Expires soon';
    }
    return 'Active';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return AppTheme.navyBlue;
      case 'Upcoming':
      case 'Expires soon':
        return const Color(0xFF8A641D);
      default:
        return AppTheme.textGrey;
    }
  }

  Future<void> _requestRenewal(
    QueryDocumentSnapshot<Map<String, dynamic>> lease,
  ) async {
    final uid = _uid;
    if (uid == null) {
      _message('Please sign in again.');
      return;
    }
    final data = lease.data();
    if (data['status'] != 'active' ||
        data['tenantResidentId'] != widget.residentId) {
      _message('This lease is not eligible for a renewal request.');
      return;
    }
    final end = data['leaseEnd'];
    if (end is! Timestamp) {
      _message('The lease end date is unavailable. Please contact the Admin.');
      return;
    }
    final endDate = DateUtils.dateOnly(end.toDate());
    final firstAllowed = endDate.add(const Duration(days: 1));
    if (firstAllowed.isAfter(DateTime(2100))) {
      _message(
        'The lease end date is outside the supported renewal date range.',
      );
      return;
    }
    final defaultDate = DateTime(
      firstAllowed.year + 1,
      firstAllowed.month,
      firstAllowed.day,
    );
    if (!mounted) return;
    final requestedEnd = await showDatePicker(
      context: context,
      initialDate: defaultDate.isAfter(DateTime(2100))
          ? firstAllowed
          : defaultDate,
      firstDate: firstAllowed,
      lastDate: DateTime(2100),
      helpText: 'Requested new lease end date',
    );
    if (requestedEnd == null || !mounted) return;

    final noteController = TextEditingController();
    String? note;
    try {
      note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.white,
          title: const AppText('Request lease renewal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Requested end date: ${_date(Timestamp.fromDate(requestedEnd))}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                maxLength: 400,
                decoration: InputDecoration(
                  labelText: AppTranslations.translate(
                    'Message to Admin (optional)',
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.navyBlue,
                foregroundColor: AppTheme.white,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, noteController.text.trim()),
              child: const AppText('Submit request'),
            ),
          ],
        ),
      );
    } finally {
      noteController.dispose();
    }
    if (note == null || !mounted) return;

    try {
      final previousSnapshot = await _renewalRequests
          .where('tenantResidentId', isEqualTo: widget.residentId)
          .get();
      if (!mounted) return;
      final previous = previousSnapshot.docs
          .where((doc) => doc.data()['leaseId'] == lease.id)
          .toList();
      previous.sort((a, b) {
        final aAt = a.data()['requestedAt'];
        final bAt = b.data()['requestedAt'];
        final aDate = aAt is Timestamp ? aAt.toDate() : DateTime(1970);
        final bDate = bAt is Timestamp ? bAt.toDate() : DateTime(1970);
        return bDate.compareTo(aDate);
      });
      final latest = previous.isEmpty ? null : previous.first;
      if (latest?.data()['status'] == 'pending') {
        _message('A renewal request is already awaiting Admin review.');
        return;
      }

      final payload = <String, dynamic>{
        'leaseId': lease.id,
        'tenantResidentId': widget.residentId,
        'requesterUid': uid,
        'householdId': data['householdId'] ?? '',
        'tenantName': data['tenantName'] ?? widget.residentName,
        'blockId': data['blockId'] ?? '',
        'houseNumber': data['houseNumber'] ?? '',
        'currentLeaseEnd': end,
        'requestedEndDate': Timestamp.fromDate(requestedEnd),
        'note': note,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (latest != null && latest.data()['status'] == 'rejected') {
        await latest.reference.update({
          'requestedEndDate': payload['requestedEndDate'],
          'currentLeaseEnd': end,
          'note': note,
          'status': 'pending',
          'requestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'reviewNote': FieldValue.delete(),
          'reviewedBy': FieldValue.delete(),
          'reviewedAt': FieldValue.delete(),
        });
      } else {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await _renewalRequests.add(payload);
      }
      _message('Lease renewal request submitted to the Colony Admin.');
    } on FirebaseException catch (error) {
      _message('Unable to submit renewal request (${error.code}).');
    } catch (error) {
      _message('Unable to submit renewal request: $error');
    }
  }

  void _openMoveOut() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MoveInOutScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          isAdmin: false,
          residentId: widget.residentId,
          residentName: widget.residentName,
        ),
      ),
    );
  }

  Widget _requestStatus(String leaseId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _renewalRequests
          .where('tenantResidentId', isEqualTo: widget.residentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final matches = snapshot.data!.docs
            .where((doc) => doc.data()['leaseId'] == leaseId)
            .toList();
        if (matches.isEmpty) return const SizedBox.shrink();
        matches.sort((a, b) {
          final aAt = a.data()['requestedAt'];
          final bAt = b.data()['requestedAt'];
          final aDate = aAt is Timestamp ? aAt.toDate() : DateTime(1970);
          final bDate = bAt is Timestamp ? bAt.toDate() : DateTime(1970);
          return bDate.compareTo(aDate);
        });
        final request = matches.first.data();
        final status = request['status'] as String? ?? '';
        if (status.isEmpty) return const SizedBox.shrink();
        final label = switch (status) {
          'pending' => 'Renewal request pending Admin review',
          'approved' =>
            'Renewal approved · new end ${_date(request['requestedEndDate'])}',
          'rejected' =>
            'Renewal request declined${(request['reviewNote'] as String? ?? '').isEmpty ? '' : ': ${request['reviewNote']}'}',
          _ => 'Renewal request: $status',
        };
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(10),
          ),
          child: AppText(
            label,
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  Widget _leaseCard(QueryDocumentSnapshot<Map<String, dynamic>> lease) {
    final data = lease.data();
    final status = _leaseStatus(data);
    final canRenew =
        data['status'] == 'active' && data['leaseEnd'] is Timestamp;
    final canMoveOut = data['status'] == 'active';
    final unit = '${data['blockId'] ?? ''}-${data['houseNumber'] ?? ''}';

    return Card(
      color: AppTheme.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.key_outlined, color: AppTheme.navyBlue),
                const SizedBox(width: 9),
                Expanded(
                  child: AppText(
                    'Unit $unit',
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AppText(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _detail(
              'Tenant',
              data['tenantName']?.toString() ?? widget.residentName,
            ),
            _detail(
              'Lease period',
              '${_date(data['leaseStart'])} – ${_date(data['leaseEnd'])}',
            ),
            _detail('Monthly rent', _money(data['monthlyRent'])),
            _detail('Security deposit', _money(data['securityDeposit'])),
            if ((data['agreementReference'] as String? ?? '').trim().isNotEmpty)
              _detail(
                'Agreement reference',
                data['agreementReference'].toString(),
              ),
            _requestStatus(lease.id),
            if (canRenew || canMoveOut) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 9,
                runSpacing: 8,
                children: [
                  if (canRenew)
                    OutlinedButton.icon(
                      onPressed: () => _requestRenewal(lease),
                      icon: const Icon(Icons.autorenew_outlined, size: 18),
                      label: const AppText('Request renewal'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.navyBlue,
                        side: const BorderSide(color: AppTheme.borderGrey),
                      ),
                    ),
                  if (canMoveOut)
                    OutlinedButton.icon(
                      onPressed: _openMoveOut,
                      icon: const Icon(Icons.logout_outlined, size: 18),
                      label: const AppText('Request move-out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.navyBlue,
                        side: const BorderSide(color: AppTheme.borderGrey),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: AppText(
            label,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ),
        Expanded(
          flex: 6,
          child: AppText(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
        title: const AppText(
          'My Lease',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _leases
            .where('tenantResidentId', isEqualTo: widget.residentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppText('Unable to load your lease: ${snapshot.error}'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.navyBlue),
            );
          }
          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
            final aStart = a.data()['leaseStart'];
            final bStart = b.data()['leaseStart'];
            final aDate = aStart is Timestamp
                ? aStart.toDate()
                : DateTime(1970);
            final bDate = bStart is Timestamp
                ? bStart.toDate()
                : DateTime(1970);
            return bDate.compareTo(aDate);
          });
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.key_off_outlined,
                      size: 46,
                      color: AppTheme.textGrey,
                    ),
                    const SizedBox(height: 12),
                    const AppText(
                      'No lease record found',
                      style: TextStyle(
                        color: AppTheme.navyBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const AppText(
                      'Your Colony Admin has not linked a lease to your resident profile yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openMoveOut,
                      icon: const Icon(Icons.logout_outlined),
                      label: const AppText('Move-In / Move-Out requests'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const AppText(
                'Your tenancy details',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const AppText(
                'Review your registered lease terms and send requests to the Colony Admin.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
              const SizedBox(height: 15),
              ...docs.map(_leaseCard),
            ],
          );
        },
      ),
    );
  }
}
