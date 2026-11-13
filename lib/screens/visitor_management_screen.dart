import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../services/notification_service.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class VisitorManagementScreen extends StatefulWidget {
  const VisitorManagementScreen({
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
  State<VisitorManagementScreen> createState() =>
      _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen> {
  String _selectedFilter = 'all';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _visitors => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('visitors');

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'Date not available';

    final date = value.toDate().toLocal();

    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}'
        '  ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'expected':
        return 'Expected';
      case 'checked_in':
        return 'Checked in';
      case 'checked_out':
        return 'Checked out';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'expected':
        return const Color(0xFF996515);
      case 'checked_in':
        return const Color(0xFF246B8E);
      case 'checked_out':
        return const Color(0xFF526477);
      case 'cancelled':
        return const Color(0xFFB54747);
      default:
        return AppTheme.textGrey;
    }
  }

  DateTime _recordDate(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final value = document.data()['expectedAt'];

    if (value is Timestamp) return value.toDate();

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // =====================================================
  // CREATE VISITOR RECORD
  // =====================================================

  Future<void> _createVisitor() async {
    final uid = _uid;

    if (uid == null) {
      _message('Please sign in again.');
      return;
    }

    if (!widget.isAdmin &&
        (widget.residentId == null || widget.residentId!.isEmpty)) {
      _message('Your resident profile is not linked. Contact your Admin.');
      return;
    }

    final visitorNameController = TextEditingController();
    final phoneController = TextEditingController();
    final purposeController = TextEditingController();
    final hostNameController = TextEditingController(
      text: widget.isAdmin ? '' : widget.residentName ?? '',
    );
    final hostUnitController = TextEditingController();

    DateTime expectedAt = DateTime.now().add(const Duration(hours: 1));

    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> selectDateTime() async {
                final pickedDate = await showDatePicker(
                  context: dialogContext,
                  initialDate: expectedAt.isBefore(DateTime.now())
                      ? DateTime.now()
                      : expectedAt,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );

                if (pickedDate == null || !dialogContext.mounted) return;

                final pickedTime = await showTimePicker(
                  context: dialogContext,
                  initialTime: TimeOfDay.fromDateTime(expectedAt),
                );

                if (pickedTime == null || !dialogContext.mounted) return;

                setDialogState(() {
                  expectedAt = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                });
              }

              return AlertDialog(
                title: AppText(
                  widget.isAdmin
                      ? 'Record a walk-in visitor'
                      : 'Pre-register a visitor',
                  style: const TextStyle(
                    color: AppTheme.navyBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: SizedBox(
                  width: 430,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: visitorNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Visitor full name *',
                            ),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Visitor phone number *',
                            ),
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: purposeController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Purpose of visit *',
                            ),
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (widget.isAdmin) ...[
                          const Divider(),
                          const AppText(
                            'Resident being visited',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navyBlue,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: hostNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Resident / host name *',
                              ),
                              prefixIcon: Icon(Icons.home_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: hostUnitController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Block / flat number (optional)',
                              ),
                              prefixIcon: Icon(Icons.apartment_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGrey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppTheme.secondaryNavy,
                                  size: 19,
                                ),
                                SizedBox(width: 9),
                                Expanded(
                                  child: AppText(
                                    'This entry will be recorded as a walk-in '
                                    'with an immediate check-in.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGrey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.home_outlined,
                                  color: AppTheme.secondaryNavy,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: AppText(
                                    'Visiting: ${widget.residentName ?? 'Resident'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.navyBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          const AppText(
                            'Expected arrival',
                            style: TextStyle(
                              color: AppTheme.navyBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: selectDateTime,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: AppText(
                              '${_twoDigits(expectedAt.day)}/'
                              '${_twoDigits(expectedAt.month)}/'
                              '${expectedAt.year}  '
                              '${_twoDigits(expectedAt.hour)}:'
                              '${_twoDigits(expectedAt.minute)}',
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const AppText(
                          '* Required fields',
                          style: TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const AppText('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyBlue,
                    ),
                    onPressed: () {
                      final name = visitorNameController.text.trim();
                      final phone = phoneController.text.trim();
                      final purpose = purposeController.text.trim();
                      final host = hostNameController.text.trim();

                      final digits = phone.replaceAll(RegExp(r'[\s()+-]'), '');

                      String? error;

                      if (name.isEmpty) {
                        error = 'Enter the visitor name.';
                      } else if (!RegExp(r'^\d{7,15}$').hasMatch(digits)) {
                        error = 'Enter a valid visitor phone number.';
                      } else if (purpose.isEmpty) {
                        error = 'Enter the purpose of the visit.';
                      } else if (widget.isAdmin && host.isEmpty) {
                        error = 'Enter the resident or host name.';
                      } else if (!widget.isAdmin &&
                          !expectedAt.isAfter(DateTime.now())) {
                        error = 'Choose a future arrival time.';
                      }

                      if (error != null) {
                        _message(error);
                        return;
                      }

                      Navigator.of(dialogContext).pop(true);
                    },
                    child: AppText(
                      widget.isAdmin ? 'Record visitor' : 'Register',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true) return;

      final now = DateTime.now();
      final isWalkIn = widget.isAdmin;

      final visitorRef = _visitors.doc();
      final batch = FirebaseFirestore.instance.batch();
      batch.set(visitorRef, {
        'visitorName': visitorNameController.text.trim(),
        'visitorPhone': phoneController.text.trim(),
        'purpose': purposeController.text.trim(),
        'hostName': widget.isAdmin
            ? hostNameController.text.trim()
            : widget.residentName ?? '',
        'hostUnit': widget.isAdmin ? hostUnitController.text.trim() : '',
        'hostResidentId': widget.isAdmin ? null : widget.residentId,
        'hostUid': widget.isAdmin ? null : uid,
        'visitType': isWalkIn ? 'walk_in' : 'pre_registered',
        'status': isWalkIn ? 'checked_in' : 'expected',
        'expectedAt': Timestamp.fromDate(isWalkIn ? now : expectedAt),
        'checkedInAt': isWalkIn ? FieldValue.serverTimestamp() : null,
        'checkedOutAt': null,
        'cancelledAt': null,
        'createdBy': uid,
        'createdByRole': isWalkIn ? 'admin' : 'resident',
        'createdByName': isWalkIn
            ? widget.adminName ?? 'Admin'
            : widget.residentName ?? 'Resident',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
      if (!isWalkIn) {
        NotificationService.addVisitorRegistered(
          batch: batch,
          colonyId: widget.colonyId,
          visitorId: visitorRef.id,
          visitorName: visitorNameController.text.trim(),
          hostName: widget.residentName ?? 'Resident',
          createdBy: uid,
        );
      }
      await batch.commit();

      if (mounted) {
        _message(
          isWalkIn
              ? 'Walk-in visitor recorded and checked in.'
              : 'Visitor pre-registered successfully.',
        );
      }
    } on FirebaseException catch (error) {
      _message('Unable to save visitor: ${error.message ?? error.code}');
    } catch (error) {
      _message('Unable to save visitor: $error');
    } finally {
      visitorNameController.dispose();
      phoneController.dispose();
      purposeController.dispose();
      hostNameController.dispose();
      hostUnitController.dispose();
    }
  }

  // =====================================================
  // UPDATE VISITOR STATUS
  // =====================================================

  Future<void> _updateStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> visitor,
    String newStatus,
  ) async {
    final uid = _uid;

    if (uid == null) {
      _message('Please sign in again.');
      return;
    }

    final data = visitor.data();

    if (!widget.isAdmin) {
      if (newStatus != 'cancelled' ||
          data['hostUid'] != uid ||
          data['status'] != 'expected') {
        _message('You can only cancel your own expected visits.');
        return;
      }
    }

    final Map<String, dynamic> updates = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    };

    if (newStatus == 'checked_in') {
      updates['checkedInAt'] = FieldValue.serverTimestamp();
    } else if (newStatus == 'checked_out') {
      updates['checkedOutAt'] = FieldValue.serverTimestamp();
    } else if (newStatus == 'cancelled') {
      updates['cancelledAt'] = FieldValue.serverTimestamp();
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(visitor.reference, updates);
      final hostUid = data['hostUid'] as String? ?? '';
      if (widget.isAdmin &&
          data['status'] != newStatus &&
          (newStatus == 'checked_in' || newStatus == 'checked_out') &&
          hostUid.isNotEmpty) {
        NotificationService.addVisitorStatusChanged(
          batch: batch,
          colonyId: widget.colonyId,
          visitorId: visitor.id,
          visitorName: data['visitorName'] as String? ?? 'Your visitor',
          newStatus: newStatus,
          hostUid: hostUid,
          createdBy: uid,
        );
      }
      await batch.commit();

      if (mounted) {
        _message('Visitor status updated to ${_statusLabel(newStatus)}.');
      }
    } on FirebaseException catch (error) {
      _message('Unable to update visitor: ${error.message ?? error.code}');
    } catch (error) {
      _message('Unable to update visitor: $error');
    }
  }

  // =====================================================
  // VISITOR CARD
  // =====================================================

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(30),
      ),
      child: AppText(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _visitorCard(QueryDocumentSnapshot<Map<String, dynamic>> visitor) {
    final data = visitor.data();

    final visitorName = data['visitorName'] as String? ?? 'Unknown visitor';
    final phone = data['visitorPhone'] as String? ?? '';
    final purpose = data['purpose'] as String? ?? '';
    final hostName = data['hostName'] as String? ?? 'Not specified';
    final hostUnit = data['hostUnit'] as String? ?? '';
    final status = data['status'] as String? ?? 'unknown';
    final visitType = data['visitType'] as String? ?? '';
    final expectedAt = _formatDate(data['expectedAt']);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppText(
                  visitorName,
                  style: const TextStyle(
                    color: AppTheme.navyBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                size: 16,
                color: AppTheme.textGrey,
              ),
              const SizedBox(width: 7),
              AppText(phone, style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.home_outlined,
                size: 16,
                color: AppTheme.textGrey,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: AppText(
                  hostUnit.isEmpty
                      ? 'Host: $hostName'
                      : 'Host: $hostName · $hostUnit',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.event_outlined,
                size: 16,
                color: AppTheme.textGrey,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: AppText(
                  expectedAt,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (purpose.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notes_outlined,
                  size: 16,
                  color: AppTheme.textGrey,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: AppText(purpose, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
          if (widget.isAdmin || status == 'expected') ...[
            const Divider(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!widget.isAdmin && status == 'expected')
                  TextButton.icon(
                    onPressed: () => _updateStatus(visitor, 'cancelled'),
                    icon: const Icon(Icons.cancel_outlined, size: 17),
                    label: const AppText('Cancel visit'),
                  ),
                if (widget.isAdmin &&
                    (status == 'expected' || status == 'checked_in'))
                  PopupMenuButton<String>(
                    tooltip: AppTranslations.translate('Update visitor status'),
                    onSelected: (value) => _updateStatus(visitor, value),
                    itemBuilder: (context) => [
                      if (status == 'expected')
                        const PopupMenuItem(
                          value: 'checked_in',
                          child: AppText('Mark checked in'),
                        ),
                      if (status == 'expected')
                        const PopupMenuItem(
                          value: 'cancelled',
                          child: AppText('Cancel visit'),
                        ),
                      if (status == 'checked_in')
                        const PopupMenuItem(
                          value: 'checked_out',
                          child: AppText('Mark checked out'),
                        ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        children: [
                          AppText(
                            'Update status',
                            style: TextStyle(
                              color: AppTheme.secondaryNavy,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: AppTheme.secondaryNavy,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (visitType == 'walk_in')
            const Align(
              alignment: Alignment.centerLeft,
              child: AppText(
                'Walk-in entry',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =====================================================
  // VISITOR LIST
  // =====================================================

  Widget _visitorList() {
    final uid = _uid;

    if (!widget.isAdmin && uid == null) {
      return const Center(child: AppText('Please sign in again.'));
    }

    final Query<Map<String, dynamic>> query = widget.isAdmin
        ? _visitors
        : _visitors.where('hostUid', isEqualTo: uid);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  const AppText(
                    'Unable to load visitor records.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  AppText(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }

        final records = snapshot.data?.docs.toList() ?? [];

        records.sort((a, b) => _recordDate(b).compareTo(_recordDate(a)));

        final visibleRecords = records.where((record) {
          final status = record.data()['status'] as String? ?? 'unknown';

          switch (_selectedFilter) {
            case 'expected':
              return status == 'expected';
            case 'inside':
              return status == 'checked_in';
            case 'closed':
              return status == 'checked_out' || status == 'cancelled';
            default:
              return true;
          }
        }).toList();

        if (visibleRecords.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_walk_outlined,
                    color: AppTheme.secondaryNavy,
                    size: 46,
                  ),
                  const SizedBox(height: 12),
                  AppText(
                    widget.isAdmin
                        ? 'No visitor records found'
                        : 'You have no registered visitors',
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 7),
                  AppText(
                    widget.isAdmin
                        ? 'New walk-in entries will appear here.'
                        : 'Pre-register a visitor to create your first entry.',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 95),
          itemCount: visibleRecords.length,
          separatorBuilder: (_, _) => const SizedBox(height: 11),
          itemBuilder: (context, index) {
            return _visitorCard(visibleRecords[index]);
          },
        );
      },
    );
  }

  // =====================================================
  // MAIN SCREEN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              widget.isAdmin ? 'Visitor Management' : 'My Visitors',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            AppText(widget.colonyName, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.isAdmin)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 5),
              child: Row(
                children: [
                  _filterChip('All', 'all'),
                  const SizedBox(width: 7),
                  _filterChip('Expected', 'expected'),
                  const SizedBox(width: 7),
                  _filterChip('Inside', 'inside'),
                  const SizedBox(width: 7),
                  _filterChip('History', 'closed'),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'Your visitor registrations',
                      style: TextStyle(
                        color: AppTheme.navyBlue,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AppText(
                      'View upcoming visits and their check-in status.',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: _visitorList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createVisitor,
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: AppText(
          widget.isAdmin ? 'Record walk-in' : 'Pre-register visitor',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _selectedFilter == value;

    return ChoiceChip(
      label: AppText(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedFilter = value);
      },
      selectedColor: AppTheme.navyBlue,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.navyBlue,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      backgroundColor: AppTheme.white,
      side: BorderSide(
        color: selected ? AppTheme.navyBlue : AppTheme.borderGrey,
      ),
    );
  }
}
