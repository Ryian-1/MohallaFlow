import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../services/notification_service.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

enum HousekeepingMode { resident, admin, worker }

class HousekeepingScreen extends StatefulWidget {
  const HousekeepingScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.mode,
    this.residentId,
    this.residentName,
    this.adminName,
    this.workerId,
    this.workerName,
  });

  final String colonyId;
  final String colonyName;
  final HousekeepingMode mode;
  final String? residentId;
  final String? residentName;
  final String? adminName;
  final String? workerId;
  final String? workerName;

  @override
  State<HousekeepingScreen> createState() => _HousekeepingScreenState();
}

class _HousekeepingScreenState extends State<HousekeepingScreen> {
  CollectionReference<Map<String, dynamic>> get _requests => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('housekeepingRequests');

  CollectionReference<Map<String, dynamic>> get _workers => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('cleanlinessWorkers');

  CollectionReference<Map<String, dynamic>> get _residents => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('residents');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static const List<String> _serviceTypes = [
    'Home cleaning',
    'Deep cleaning',
    'Bathroom cleaning',
    'Kitchen cleaning',
    'Common area cleaning',
    'Garbage removal',
    'Other housekeeping',
  ];

  static const List<String> _timeSlots = [
    'Morning (8 AM – 12 PM)',
    'Afternoon (12 PM – 4 PM)',
    'Evening (4 PM – 7 PM)',
    'Flexible',
  ];

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  String get _screenTitle {
    switch (widget.mode) {
      case HousekeepingMode.resident:
        return 'My housekeeping requests';
      case HousekeepingMode.admin:
        return 'Housekeeping management';
      case HousekeepingMode.worker:
        return 'My housekeeping tasks';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _dateLabel(Object? value) {
    if (value is! Timestamp) return 'Date pending';

    final date = value.toDate().toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _requestStream() {
    switch (widget.mode) {
      case HousekeepingMode.admin:
        return _requests.orderBy('createdAt', descending: true).snapshots();

      case HousekeepingMode.resident:
        return _requests
            .where('requestedBy', isEqualTo: _uid ?? '')
            .snapshots();

      case HousekeepingMode.worker:
        return _requests
            .where('assignedWorkerId', isEqualTo: widget.workerId ?? '')
            .snapshots();
    }
  }

  Future<void> _openRequestForm() async {
    final uid = _uid;
    final residentId = widget.residentId;

    if (uid == null || residentId == null || residentId.isEmpty) {
      _showMessage('Your resident account could not be verified.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final descriptionController = TextEditingController();

    String serviceType = _serviceTypes.first;
    String preferredTime = 'Flexible';
    DateTime preferredDate = DateTime.now().add(const Duration(days: 1));

    bool saving = false;
    String? formError;
    bool saved = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> saveRequest() async {
              if (saving || !formKey.currentState!.validate()) return;

              setDialogState(() {
                saving = true;
                formError = null;
              });

              try {
                final residentSnapshot = await _residents.doc(residentId).get();

                if (!residentSnapshot.exists) {
                  throw StateError(
                    'Your resident record was not found. Contact your Admin.',
                  );
                }

                final residentData = residentSnapshot.data() ?? {};

                if (residentData['residentStatus'] != 'active') {
                  throw StateError('Your resident account is not active.');
                }

                final householdId =
                    residentData['householdId'] as String? ?? '';

                if (householdId.isEmpty) {
                  throw StateError(
                    'Your household is not linked to your profile.',
                  );
                }

                final blockId = residentData['blockId'] as String? ?? '';
                final houseNumber =
                    residentData['houseNumber'] as String? ?? '';
                final residentName =
                    residentData['fullName'] as String? ??
                    widget.residentName ??
                    'Resident';

                final location = [
                  if (blockId.isNotEmpty) 'Block $blockId',
                  if (houseNumber.isNotEmpty) 'House $houseNumber',
                ].join(' · ');

                final requestRef = _requests.doc();
                final batch = FirebaseFirestore.instance.batch();
                batch.set(requestRef, {
                  'title': serviceType,
                  'serviceType': serviceType,
                  'description': descriptionController.text.trim(),
                  'preferredDate': Timestamp.fromDate(
                    DateTime(
                      preferredDate.year,
                      preferredDate.month,
                      preferredDate.day,
                    ),
                  ),
                  'preferredTime': preferredTime,
                  'status': 'submitted',
                  'requestedBy': uid,
                  'requestedByName': residentName,
                  'residentId': residentId,
                  'residentName': residentName,
                  'householdId': householdId,
                  'blockId': blockId,
                  'houseNumber': houseNumber,
                  'location': location,
                  'assignedWorkerId': null,
                  'assignedWorkerName': null,
                  'assignedWorkerPhone': null,
                  'assignedBy': null,
                  'assignedAt': null,
                  'completedAt': null,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                NotificationService.addHousekeepingSubmitted(
                  batch: batch,
                  colonyId: widget.colonyId,
                  requestId: requestRef.id,
                  serviceType: serviceType,
                  location: location.isEmpty ? widget.colonyName : location,
                  residentName: residentName,
                  createdBy: uid,
                );
                await batch.commit();

                saved = true;

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              } catch (error) {
                debugPrint('Housekeeping request failed: $error');

                if (!dialogContext.mounted) return;

                setDialogState(() {
                  saving = false;
                  formError = error is StateError
                      ? error.message.toString()
                      : 'Unable to submit the request. Please try again.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.white,
              title: const AppText(
                'New housekeeping request',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: serviceType,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Service required',
                            ),
                          ),
                          items: _serviceTypes.map((item) {
                            return DropdownMenuItem(
                              value: item,
                              child: AppText(item),
                            );
                          }).toList(),
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() => serviceType = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: descriptionController,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 1000,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Additional details',
                            ),
                            hintText: AppTranslations.translate(
                              'Describe what needs to be cleaned or serviced.',
                            ),
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().length < 5) {
                              return AppTranslations.translate(
                                'Please provide at least 5 characters.',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        const AppText(
                          'Preferred date',
                          style: TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        OutlinedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: preferredDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 90),
                                    ),
                                  );

                                  if (picked != null) {
                                    setDialogState(
                                      () => preferredDate = picked,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: AppText(
                            _dateLabel(Timestamp.fromDate(preferredDate)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: preferredTime,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Preferred time',
                            ),
                          ),
                          items: _timeSlots.map((item) {
                            return DropdownMenuItem(
                              value: item,
                              child: AppText(
                                item,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() => preferredTime = value);
                                  }
                                },
                        ),
                        if (formError != null) ...[
                          const SizedBox(height: 14),
                          AppText(
                            formError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const AppText('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : saveRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navyBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const AppText('Submit request'),
                ),
              ],
            );
          },
        );
      },
    );

    descriptionController.dispose();

    if (saved) {
      _showMessage('Housekeeping request submitted successfully.');
    }
  }

  Future<void> _assignRequest(
    DocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    try {
      final workerSnapshot = await _workers
          .where('status', isEqualTo: 'active')
          .get();

      if (!mounted) return;

      final activeWorkers = workerSnapshot.docs;

      if (activeWorkers.isEmpty) {
        _showMessage(
          'Register an active worker in Cleanliness before assigning.',
        );
        return;
      }

      String selectedWorkerId = activeWorkers.first.id;
      bool saving = false;
      String? formError;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> saveAssignment() async {
                if (saving) return;

                setDialogState(() {
                  saving = true;
                  formError = null;
                });

                try {
                  final selectedWorker = activeWorkers.firstWhere(
                    (worker) => worker.id == selectedWorkerId,
                  );

                  final data = selectedWorker.data();
                  final uid = _uid;

                  if (uid == null) {
                    throw StateError('Please sign in again.');
                  }

                  final batch = FirebaseFirestore.instance.batch();
                  batch.update(request.reference, {
                    'assignedWorkerId': selectedWorker.id,
                    'assignedWorkerName': data['fullName'] as String? ?? '',
                    'assignedWorkerPhone': data['phoneNumber'] as String? ?? '',
                    'assignedBy': uid,
                    'assignedAt': FieldValue.serverTimestamp(),
                    'status': 'assigned',
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  final requestData = request.data() ?? {};
                  if (requestData['status'] != 'assigned' ||
                      requestData['assignedWorkerId'] != selectedWorker.id) {
                    NotificationService.addHousekeepingAssigned(
                      batch: batch,
                      colonyId: widget.colonyId,
                      requestId: request.id,
                      serviceType:
                          requestData['serviceType'] as String? ??
                          requestData['title'] as String? ??
                          'Housekeeping request',
                      workerId: selectedWorker.id,
                      residentUid: requestData['requestedBy'] as String? ?? '',
                      createdBy: uid,
                    );
                  }
                  await batch.commit();

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();

                  _showMessage('Housekeeping worker assigned.');
                } catch (error) {
                  debugPrint('Housekeeping assignment failed: $error');

                  if (!dialogContext.mounted) return;

                  setDialogState(() {
                    saving = false;
                    formError = 'Unable to assign worker: $error';
                  });
                }
              }

              return AlertDialog(
                title: const AppText('Assign housekeeping worker'),
                content: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedWorkerId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Select active worker',
                          ),
                        ),
                        items: activeWorkers.map((worker) {
                          final name =
                              worker.data()['fullName'] as String? ??
                              'Unnamed worker';
                          final area =
                              worker.data()['assignedArea'] as String? ?? '';

                          return DropdownMenuItem(
                            value: worker.id,
                            child: AppText(
                              area.isEmpty ? name : '$name · $area',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(
                                    () => selectedWorkerId = value,
                                  );
                                }
                              },
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        AppText(
                          formError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const AppText('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: saving ? null : saveAssignment,
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppText('Assign worker'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on FirebaseException catch (error) {
      _showMessage('Unable to load workers: ${error.message ?? error.code}');
    } catch (error) {
      _showMessage('Unable to assign this request: $error');
    }
  }

  Future<void> _updateWorkerStatus(
    DocumentSnapshot<Map<String, dynamic>> request,
    String newStatus,
  ) async {
    try {
      final uid = _uid;
      if (uid == null) {
        _showMessage('Please sign in again.');
        return;
      }
      final batch = FirebaseFirestore.instance.batch();
      batch.update(request.reference, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': newStatus == 'completed'
            ? FieldValue.serverTimestamp()
            : null,
      });
      final data = request.data() ?? {};
      if (data['status'] != newStatus) {
        NotificationService.addHousekeepingUpdated(
          batch: batch,
          colonyId: widget.colonyId,
          requestId: request.id,
          serviceType:
              data['serviceType'] as String? ??
              data['title'] as String? ??
              'Housekeeping request',
          newStatus: newStatus,
          residentUid: data['requestedBy'] as String? ?? '',
          createdBy: uid,
        );
      }
      await batch.commit();

      _showMessage(
        newStatus == 'in_progress'
            ? 'Housekeeping job started.'
            : 'Housekeeping job completed.',
      );
    } on FirebaseException catch (error) {
      debugPrint('Housekeeping worker update failed: $error');
      _showMessage('Unable to update task: ${error.message ?? error.code}');
    } catch (error) {
      _showMessage('Unable to update task: $error');
    }
  }

  Future<void> _cancelRequest(
    DocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const AppText('Cancel request?'),
          content: const AppText(
            'Are you sure you want to cancel this housekeeping request?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Keep request'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Cancel request'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await request.reference.update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Housekeeping request cancelled.');
    } on FirebaseException catch (error) {
      _showMessage('Unable to cancel request: ${error.message ?? error.code}');
    }
  }

  Widget _buildRequestCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final String serviceType =
        data['serviceType'] as String? ?? 'Housekeeping request';
    final String description = data['description'] as String? ?? '';
    final String location = data['location'] as String? ?? '';
    final String status = data['status'] as String? ?? 'submitted';
    final String preferredTime = data['preferredTime'] as String? ?? 'Flexible';
    final String workerName = data['assignedWorkerName'] as String? ?? '';
    final String residentName = data['residentName'] as String? ?? 'Resident';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(15),
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
                  serviceType,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText(
                  _statusLabel(status).toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.navyBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (location.isNotEmpty)
            AppText(
              location,
              style: const TextStyle(
                color: AppTheme.secondaryNavy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (widget.mode != HousekeepingMode.resident) ...[
            const SizedBox(height: 5),
            AppText(
              'Resident: $residentName',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
          ],
          const SizedBox(height: 9),
          AppText(
            description,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppTheme.textGrey,
              ),
              const SizedBox(width: 6),
              AppText(
                _dateLabel(data['preferredDate']),
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.access_time_outlined,
                size: 14,
                color: AppTheme.textGrey,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: AppText(
                  preferredTime,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (workerName.isNotEmpty) ...[
            const SizedBox(height: 10),
            AppText(
              'Assigned worker: $workerName',
              style: const TextStyle(
                color: AppTheme.secondaryNavy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (widget.mode == HousekeepingMode.admin &&
              (status == 'submitted' || status == 'assigned')) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _assignRequest(document),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: AppText(
                  status == 'assigned' ? 'Reassign worker' : 'Assign worker',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          if (widget.mode == HousekeepingMode.resident &&
              status == 'submitted') ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cancelRequest(document),
                child: const AppText('Cancel request'),
              ),
            ),
          ],
          if (widget.mode == HousekeepingMode.worker &&
              status == 'assigned') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _updateWorkerStatus(document, 'in_progress'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const AppText('Start job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          if (widget.mode == HousekeepingMode.worker &&
              status == 'in_progress') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _updateWorkerStatus(document, 'completed'),
                icon: const Icon(Icons.check_circle_outline),
                label: const AppText('Mark as completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final String title;
    final String subtitle;

    switch (widget.mode) {
      case HousekeepingMode.resident:
        title = 'No housekeeping requests';
        subtitle = 'Your submitted requests will appear here.';
      case HousekeepingMode.admin:
        title = 'No housekeeping requests yet';
        subtitle = 'Resident requests will appear here when submitted.';
      case HousekeepingMode.worker:
        title = 'No housekeeping jobs assigned';
        subtitle = 'Jobs assigned to you will appear here.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cleaning_services_outlined,
              size: 52,
              color: AppTheme.textGrey,
            ),
            const SizedBox(height: 14),
            AppText(
              title,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            AppText(
              subtitle,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final uid = _uid;

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navyBlue,
        elevation: 0,
        title: AppText(
          _screenTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: widget.mode == HousekeepingMode.resident
          ? FloatingActionButton.extended(
              onPressed: _openRequestForm,
              backgroundColor: AppTheme.navyBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const AppText('New request'),
            )
          : null,
      body: uid == null
          ? const Center(child: AppText('Please sign in again.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _requestStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppText(
                        'Unable to load housekeeping requests.\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          height: 1.5,
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.navyBlue),
                  );
                }

                final documents = [...snapshot.data!.docs];

                if (widget.mode != HousekeepingMode.admin) {
                  documents.sort((a, b) {
                    final aDate = a.data()['createdAt'];
                    final bDate = b.data()['createdAt'];

                    final aMillis = aDate is Timestamp
                        ? aDate.millisecondsSinceEpoch
                        : 0;
                    final bMillis = bDate is Timestamp
                        ? bDate.millisecondsSinceEpoch
                        : 0;

                    return bMillis.compareTo(aMillis);
                  });
                }

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            widget.colonyName,
                            style: const TextStyle(
                              color: AppTheme.navyBlue,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          AppText(
                            '${documents.length} housekeeping '
                            '${documents.length == 1 ? 'record' : 'records'}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: documents.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                              itemCount: documents.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _buildRequestCard(documents[index]);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
