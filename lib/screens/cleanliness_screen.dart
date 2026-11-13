import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/push_notification_service.dart';

import 'package:flutter/services.dart';

import '../models/user_role.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../widgets/colony_switch_action.dart';
import '../widgets/notification_bell.dart';
import 'splash_screen.dart';
import 'document_repository_screen.dart';
import 'worker_attendance_screen.dart';
import '../widgets/app_text.dart';
import '../widgets/brand_logo.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';
import '../widgets/app_language_toggle.dart';

class CleanlinessScreen extends StatefulWidget {
  const CleanlinessScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
    this.currentRole = UserRole.cleanlinessManager,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;
  final UserRole currentRole;

  @override
  State<CleanlinessScreen> createState() => _CleanlinessScreenState();
}

class _CleanlinessScreenState extends State<CleanlinessScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PushNotificationService.initializeForMember(
          context: context,
          colonyId: widget.colonyId,
        );
      }
    });
  }

  bool _isSigningOut = false;

  CollectionReference<Map<String, dynamic>> get _workers => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('cleanlinessWorkers');

  CollectionReference<Map<String, dynamic>> get _workerPrivateProfiles =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('workerPrivateProfiles');

  CollectionReference<Map<String, dynamic>> get _tasks => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('cleanlinessTasks');

  CollectionReference<Map<String, dynamic>> get _complaints => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('complaints');

  static const List<String> _priorities = ['low', 'normal', 'high', 'urgent'];

  static const List<String> _statuses = [
    'assigned',
    'in_progress',
    'completed',
    'cancelled',
  ];

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ==========================================
  // REGISTER CLEANLINESS WORKER
  // ==========================================

  // MOHALLAFLOW_WORKER_PERSONAL_DETAILS_V2_SELF_SERVICE
  Future<void> _openWorkerForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? worker,
  }) async {
    final old = worker?.data() ?? <String, dynamic>{};
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: old['fullName'] as String? ?? '',
    );
    final phoneController = TextEditingController(
      text: old['phoneNumber'] as String? ?? '',
    );
    final areaController = TextEditingController(
      text: old['assignedArea'] as String? ?? '',
    );
    String? formError;
    bool saving = false;
    bool saved = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> saveWorker() async {
              if (saving || !formKey.currentState!.validate()) return;
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) {
                setDialogState(() => formError = 'Please sign in again.');
                return;
              }
              setDialogState(() {
                saving = true;
                formError = null;
              });
              final profile = <String, dynamic>{
                'fullName': nameController.text.trim(),
                'phoneNumber': phoneController.text.trim(),
                'assignedArea': areaController.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              };
              try {
                if (worker == null) {
                  await _workers.add({
                    ...profile,
                    'status': 'active',
                    'createdBy': uid,
                    'createdByName': widget.adminName,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await worker.reference.update(profile);
                }
                saved = true;
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } on FirebaseException catch (error) {
                debugPrint(
                  'Worker profile save failed: ${error.code} ${error.message}',
                );
                setDialogState(() {
                  saving = false;
                  formError =
                      'Unable to save worker details: ${error.message ?? error.code}';
                });
              } catch (error) {
                debugPrint('Worker profile save error: $error');
                setDialogState(() {
                  saving = false;
                  formError =
                      'Unable to save worker details. Please try again.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.white,
              title: AppText(
                worker == null
                    ? 'Register cleanliness worker'
                    : 'Update worker details',
                style: const TextStyle(
                  color: AppTheme.navyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInput(
                          controller: nameController,
                          label: 'Worker name',
                          hint: 'Enter full name',
                          validator: (value) {
                            final name = value?.trim() ?? '';
                            if (name.length < 2 || name.length > 100) {
                              return AppTranslations.translate(
                                'Enter a valid worker name',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildInput(
                          controller: phoneController,
                          label: 'Contact number',
                          hint: '10-digit mobile number',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (value) {
                            final phone = value?.trim() ?? '';
                            return RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)
                                ? null
                                : AppTranslations.translate(
                                    'Enter a valid 10-digit mobile number',
                                  );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildInput(
                          controller: areaController,
                          label: 'Assigned area',
                          hint: 'Example: Blocks A and B',
                        ),
                        const SizedBox(height: 12),
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
                  onPressed: saving ? null : saveWorker,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : AppText(
                          worker == null ? 'Save worker' : 'Save changes',
                        ),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
      areaController.dispose();
    }
    if (saved) {
      _showMessage(
        worker == null
            ? 'Worker registered successfully.'
            : 'Worker details updated.',
      );
    }
  }

  // ==========================================
  // INCOMING CLEANLINESS COMPLAINTS
  // ==========================================

  Future<void> _openIncomingComplaints(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> workerDocuments,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          title: const AppText(
            'Incoming cleanliness complaints',
            style: TextStyle(
              color: AppTheme.navyBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 500,
            height: 440,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _complaints
                  .where('complaintType', isEqualTo: 'cleanliness')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: AppText(
                      'Unable to load complaints.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textGrey),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.navyBlue),
                  );
                }

                final complaints = snapshot.data!.docs.where((complaint) {
                  return complaint.data()['status'] == 'submitted';
                }).toList();

                if (complaints.isEmpty) {
                  return const Center(
                    child: AppText(
                      'No new cleanliness complaints.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: complaints.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final complaint = complaints[index];
                    final data = complaint.data();

                    final title =
                        data['title'] as String? ?? 'Untitled complaint';
                    final location = data['location'] as String? ?? '';
                    final reporter =
                        data['reportedByName'] as String? ?? 'Resident';
                    final description = data['description'] as String? ?? '';
                    final priority = data['priority'] as String? ?? 'normal';

                    return Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            title,
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          AppText(
                            location,
                            style: const TextStyle(
                              color: AppTheme.secondaryNavy,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AppText(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppText(
                            'Reported by: $reporter  ·  Priority: ${_priorityLabel(priority)}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                _openTaskForm(
                                  workerDocuments,
                                  complaint: complaint,
                                );
                              },
                              icon: const Icon(Icons.assignment_turned_in),
                              label: const AppText('Create cleaning task'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.navyBlue,
                                foregroundColor: Colors.white,
                              ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const AppText('Close'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // CREATE AND ASSIGN CLEANLINESS TASK
  // ==========================================

  Future<void> _openTaskForm(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> workerDocuments, {
    DocumentSnapshot<Map<String, dynamic>>? complaint,
  }) async {
    final activeWorkers = workerDocuments.where((worker) {
      return worker.data()['status'] == 'active';
    }).toList();

    if (activeWorkers.isEmpty) {
      _showMessage('Register an active worker before assigning a task.');
      return;
    }

    final formKey = GlobalKey<FormState>();

    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final complaintData = complaint?.data() ?? const <String, dynamic>{};

    if (complaint != null) {
      titleController.text = complaintData['title'] as String? ?? '';
      locationController.text = complaintData['location'] as String? ?? '';
      descriptionController.text =
          complaintData['description'] as String? ?? '';
    }

    String selectedWorkerId = activeWorkers.first.id;
    String selectedPriority = _priorities.contains(complaintData['priority'])
        ? complaintData['priority'] as String
        : 'normal';

    String? formError;
    bool saving = false;
    bool saved = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> saveTask() async {
              if (saving || !formKey.currentState!.validate()) {
                return;
              }

              final uid = FirebaseAuth.instance.currentUser?.uid;

              if (uid == null) {
                setDialogState(() {
                  formError = 'Please sign in again.';
                });
                return;
              }

              final selectedWorker = activeWorkers.firstWhere(
                (worker) => worker.id == selectedWorkerId,
              );

              final workerData = selectedWorker.data();

              setDialogState(() {
                saving = true;
                formError = null;
              });

              try {
                final batch = FirebaseFirestore.instance.batch();
                final taskReference = _tasks.doc();

                batch.set(taskReference, {
                  'title': titleController.text.trim(),
                  'location': locationController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'priority': selectedPriority,
                  'status': 'assigned',
                  'assignedWorkerId': selectedWorker.id,
                  'assignedWorkerName': workerData['fullName'] as String? ?? '',
                  'assignedWorkerPhone':
                      workerData['phoneNumber'] as String? ?? '',
                  'createdBy': uid,
                  'createdByName': widget.adminName,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'completedAt': null,
                  if (complaint != null) 'sourceComplaintId': complaint.id,
                });

                NotificationService.addCleanlinessTaskAssigned(
                  batch: batch,
                  colonyId: widget.colonyId,
                  taskId: taskReference.id,
                  taskTitle: titleController.text.trim(),
                  location: locationController.text.trim(),
                  workerId: selectedWorker.id,
                  workerName: workerData['fullName'] as String? ?? 'Worker',
                  createdBy: uid,
                );

                if (complaint != null) {
                  batch.update(complaint.reference, {
                    'status': 'acknowledged',
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }

                await batch.commit();

                saved = true;

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();
              } on FirebaseException catch (error) {
                debugPrint(
                  'Task creation failed: ${error.code} ${error.message}',
                );

                setDialogState(() {
                  saving = false;
                  formError =
                      'Unable to assign task: '
                      '${error.message ?? error.code}';
                });
              } catch (error) {
                debugPrint('Task creation error: $error');

                setDialogState(() {
                  saving = false;
                  formError = 'Unable to assign task. Please try again.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.white,
              title: const AppText(
                'Create and assign task',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInput(
                          controller: titleController,
                          label: 'Task title',
                          hint: 'Example: Clean Block A entrance',
                        ),
                        const SizedBox(height: 14),
                        _buildInput(
                          controller: locationController,
                          label: 'Task location',
                          hint: 'Example: Block A, main entrance',
                        ),
                        const SizedBox(height: 14),
                        _buildInput(
                          controller: descriptionController,
                          label: 'Task description',
                          hint: 'Describe the work to be completed',
                          maxLines: 4,
                          validator: (value) {
                            final description = value?.trim() ?? '';

                            if (description.length < 10) {
                              return AppTranslations.translate(
                                'Enter at least 10 characters',
                              );
                            }

                            if (description.length > 2000) {
                              return AppTranslations.translate(
                                'Description is too long',
                              );
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedWorkerId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Assign worker',
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: activeWorkers.map((worker) {
                            final data = worker.data();
                            final name =
                                data['fullName'] as String? ?? 'Unnamed worker';
                            final area = data['assignedArea'] as String? ?? '';

                            return DropdownMenuItem<String>(
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
                                    setDialogState(() {
                                      selectedWorkerId = value;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedPriority,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Task priority',
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: _priorities.map((priority) {
                            return DropdownMenuItem<String>(
                              value: priority,
                              child: AppText(_priorityLabel(priority)),
                            );
                          }).toList(),
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      selectedPriority = value;
                                    });
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
                  onPressed: saving ? null : saveTask,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const AppText('Assign task'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();

    if (saved) {
      _showMessage('Task assigned successfully.');
    }
  }

  // ==========================================
  // UPDATE TASK STATUS
  // ==========================================

  Future<void> _updateTaskStatus(
    DocumentSnapshot<Map<String, dynamic>> task,
    String newStatus,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final taskData = task.data() ?? <String, dynamic>{};
      final workerId = taskData['assignedWorkerId']?.toString() ?? '';
      final rawComplaintId = taskData['sourceComplaintId'];
      final sourceComplaintId = rawComplaintId is String
          ? rawComplaintId.trim()
          : '';

      // Complaint-linked tasks must be completed by the assigned Worker.
      // The Worker Dashboard performs task completion and complaint resolution
      // together in one atomic batch, preserving the resident-facing lifecycle.
      if (newStatus == 'completed' && sourceComplaintId.isNotEmpty) {
        _showMessage(
          'The assigned worker must complete this complaint-linked task. The originating complaint will be resolved automatically when the worker reports completion.',
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      batch.update(task.reference, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': newStatus == 'completed'
            ? FieldValue.serverTimestamp()
            : null,
      });

      if (currentUser != null && workerId.isNotEmpty) {
        NotificationService.addCleanlinessTaskStatusChanged(
          batch: batch,
          colonyId: widget.colonyId,
          taskId: task.id,
          taskTitle: taskData['title']?.toString() ?? 'Cleanliness task',
          workerId: workerId,
          newStatus: newStatus,
          createdBy: currentUser.uid,
        );
      }

      await batch.commit();

      _showMessage('Task status changed to ${_statusLabel(newStatus)}.');
    } on FirebaseException catch (error) {
      debugPrint('Task status update failed: ${error.code} ${error.message}');

      _showMessage('Unable to update task: ${error.message ?? error.code}');
    } catch (error) {
      debugPrint('Task status update error: $error');
      _showMessage('Unable to update task.');
    }
  }

  // ==========================================
  // INPUT FIELD
  // ==========================================

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLines > 1 ? 2000 : null,
      decoration: InputDecoration(
        labelText: AppTranslations.translate(label),
        hintText: AppTranslations.translate(hint),
        border: const OutlineInputBorder(),
        counterText: maxLines > 1 ? null : '',
      ),
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return AppTranslations.translate('Please enter $label');
            }

            return null;
          },
    );
  }

  // ==========================================
  // PRIORITY AND STATUS LABELS
  // ==========================================

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High';
      case 'low':
        return 'Low';
      default:
        return 'Normal';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
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

  // ==========================================
  // OPERATIONAL OVERVIEW
  // ==========================================

  Widget _buildOverviewMetric({
    required String label,
    required String value,
    required IconData icon,
    required String detail,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.secondaryNavy),
              const Spacer(),
              if (onTap != null)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: AppTheme.textGrey,
                ),
            ],
          ),
          const SizedBox(height: 10),
          AppText(
            value,
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          AppText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          AppText(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 9,
              height: 1.3,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: content,
      ),
    );
  }

  Widget _buildOperationalOverview({
    required int activeWorkers,
    required int assignedTasks,
    required int inProgressTasks,
    required int completedTasks,
    required int totalTasks,
    required int newComplaints,
    required int openComplaints,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> workers,
  }) {
    final metrics = <Widget>[
      _buildOverviewMetric(
        label: 'Active workers',
        value: '$activeWorkers',
        icon: Icons.people_alt_outlined,
        detail: 'Available cleanliness staff',
      ),
      _buildOverviewMetric(
        label: 'Assigned tasks',
        value: '$assignedTasks',
        icon: Icons.assignment_outlined,
        detail: 'Awaiting work to start',
      ),
      _buildOverviewMetric(
        label: 'In progress',
        value: '$inProgressTasks',
        icon: Icons.cleaning_services_outlined,
        detail: 'Currently being handled',
      ),
      _buildOverviewMetric(
        label: 'Completed tasks',
        value: '$completedTasks',
        icon: Icons.task_alt_rounded,
        detail: '$totalTasks total tasks',
      ),
      _buildOverviewMetric(
        label: 'New complaints',
        value: newComplaints < 0 ? '—' : '$newComplaints',
        icon: Icons.inbox_outlined,
        detail: newComplaints < 0
            ? 'Complaint records could not be retrieved'
            : '$openComplaints open cleanliness complaints',
        onTap: () => _openIncomingComplaints(workers),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Operational overview',
            style: TextStyle(
              color: AppTheme.navyBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const AppText(
            'Live status of cleanliness staff, tasks and incoming complaints.',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 10),
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 950
                  ? 5
                  : constraints.maxWidth >= 570
                  ? 3
                  : 2;
              const spacing = 9.0;
              final itemWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: metrics
                    .map((metric) => SizedBox(width: itemWidth, child: metric))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WORKER DIRECTORY
  // ==========================================

  Widget _buildWorkerDirectory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> workers,
  ) {
    final activeWorkers = workers
        .where((worker) => worker.data()['status'] == 'active')
        .toList();
    return Container(
      width: double.infinity,
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
            children: [
              const Expanded(
                child: AppText(
                  'Worker personal details',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AppText(
                '${activeWorkers.length} active',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const AppText(
            'Operational contact and assignment details. Medical and family emergency details are private to the worker and Admin.',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 10),
          ),
          const SizedBox(height: 11),
          if (activeWorkers.isEmpty)
            const AppText(
              'No workers registered yet.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
            )
          else
            ...activeWorkers.map((worker) {
              final data = worker.data();
              final name = data['fullName'] as String? ?? 'Unnamed worker';
              final phone = data['phoneNumber'] as String? ?? '—';
              final area = data['assignedArea'] as String? ?? '—';
              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppTheme.white,
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            name,
                            style: const TextStyle(
                              color: AppTheme.navyBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AppText(
                            'Contact: $phone',
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 11,
                            ),
                          ),
                          AppText(
                            'Assigned area: $area',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 10,
                            ),
                          ),
                          if (widget.currentRole == UserRole.admin)
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: _workerPrivateProfiles
                                  .doc(worker.id)
                                  .snapshots(),
                              builder: (context, privateSnapshot) {
                                if (privateSnapshot.hasError) {
                                  return const AppText(
                                    'Worker has not consented to share private medical/emergency details.',
                                    style: TextStyle(
                                      color: AppTheme.textGrey,
                                      fontSize: 10,
                                    ),
                                  );
                                }
                                final privateData = privateSnapshot.data
                                    ?.data();
                                if (privateData == null) {
                                  return const AppText(
                                    'Medical and emergency details not provided.',
                                    style: TextStyle(
                                      color: AppTheme.textGrey,
                                      fontSize: 10,
                                    ),
                                  );
                                }
                                final bloodGroup =
                                    privateData['bloodGroup'] as String? ??
                                    'Not provided';
                                final familyName =
                                    privateData['familyMemberName']
                                        as String? ??
                                    '';
                                final familyPhone =
                                    privateData['familyMemberPhone']
                                        as String? ??
                                    '';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      'Blood group: $bloodGroup',
                                      style: const TextStyle(
                                        color: AppTheme.textDark,
                                        fontSize: 11,
                                      ),
                                    ),
                                    AppText(
                                      'Emergency contact: ${familyName.isEmpty ? 'Not provided' : familyName}',
                                      style: const TextStyle(
                                        color: AppTheme.textDark,
                                        fontSize: 11,
                                      ),
                                    ),
                                    AppText(
                                      'Emergency phone: ${familyPhone.isEmpty ? 'Not provided' : familyPhone}',
                                      style: const TextStyle(
                                        color: AppTheme.textDark,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppTranslations.translate('Edit worker details'),
                      onPressed: () => _openWorkerForm(worker: worker),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppTheme.navyBlue,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==========================================
  // TASK CARD
  // ==========================================

  Widget _buildTaskCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final title = data['title'] as String? ?? 'Untitled task';
    final location = data['location'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final workerName = data['assignedWorkerName'] as String? ?? 'Unassigned';
    final priority = data['priority'] as String? ?? 'normal';
    final status = data['status'] as String? ?? 'assigned';
    final rawComplaintId = data['sourceComplaintId'];
    final isComplaintLinkedTask =
        rawComplaintId is String && rawComplaintId.trim().isNotEmpty;

    final createdAt = data['createdAt'];
    final dateLabel = createdAt is Timestamp
        ? createdAt.toDate().toLocal().toString().substring(0, 16)
        : 'Date pending';

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
                  title,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: AppTranslations.translate('Update task status'),
                onSelected: (value) {
                  _updateTaskStatus(document, value);
                },
                itemBuilder: (context) {
                  return _statuses
                      .where(
                        (statusOption) =>
                            !isComplaintLinkedTask ||
                            statusOption != 'completed',
                      )
                      .map(
                        (statusOption) {
                          return PopupMenuItem<String>(
                            value: statusOption,
                            child: AppText(_statusLabel(statusOption)),
                          );
                        },
                      )
                      .toList();
                },
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppTheme.secondaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusBadge(status),
              AppText(
                'Priority: ${_priorityLabel(priority)}',
                style: const TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (isComplaintLinkedTask && status != 'completed') ...[
            const SizedBox(height: 9),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.textGrey,
                  size: 14,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: AppText(
                    'The assigned worker completes this task to resolve the resident complaint.',
                    style: TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 11),
          AppText(
            location,
            style: const TextStyle(
              color: AppTheme.secondaryNavy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          AppText(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderGrey),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: AppTheme.textGrey,
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: AppText(
                  'Assigned to: $workerName',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: AppTheme.textGrey,
                size: 14,
              ),
              const SizedBox(width: 7),
              AppText(
                dateLabel,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText(
        _statusLabel(status).toUpperCase(),
        style: const TextStyle(
          color: AppTheme.navyBlue,
          fontSize: 9,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ==========================================
  // MAIN SCREEN
  // ==========================================

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
      await PushNotificationService.unregisterCurrentDevice();

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } catch (error, stackTrace) {
      debugPrint('Cleanliness sign-out error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => _isSigningOut = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Unable to sign out. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        title: Row(
          children: [
            const BrandMonogram(width: 30, height: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText(
                    'Cleanliness Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  AppText(
                    widget.colonyName,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          const AppLanguageToggle(),
          ColonySwitchAction(
            currentColonyId: widget.colonyId,
            currentColonyName: widget.colonyName,
            currentRole: widget.currentRole,
          ),
          IconButton(
            tooltip: AppTranslations.translate('Worker attendance'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorkerAttendanceScreen(
                    colonyId: widget.colonyId,
                    colonyName: widget.colonyName,
                    isManager: true,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.fact_check_outlined),
          ),
          NotificationBell(
            colonyId: widget.colonyId,
            colonyName: widget.colonyName,
            roleKey: widget.currentRole == UserRole.admin
                ? 'admin'
                : 'cleanliness_manager',
          ),
          IconButton(
            tooltip: AppTranslations.translate('Shared colony documents'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DocumentRepositoryScreen(
                  colonyId: widget.colonyId,
                  colonyName: widget.colonyName,
                  isAdmin: widget.currentRole == UserRole.admin,
                  roleKey: widget.currentRole == UserRole.admin
                      ? 'admin'
                      : 'cleanliness_manager',
                  adminName: widget.adminName,
                ),
              ),
            ),
            icon: const Icon(
              Icons.folder_shared_outlined,
              color: AppTheme.navyBlue,
            ),
          ),
          IconButton(
            tooltip: AppTranslations.translate('Sign out'),
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded, color: AppTheme.navyBlue),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _workers.orderBy('fullName').snapshots(),
        builder: (context, workerSnapshot) {
          if (workerSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppText(
                  'Unable to load workers.\n${workerSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textGrey, height: 1.5),
                ),
              ),
            );
          }

          if (workerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.navyBlue),
            );
          }

          final workers = workerSnapshot.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _tasks.orderBy('createdAt', descending: true).snapshots(),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppText(
                      'Unable to load tasks.\n${taskSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              }

              if (taskSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.navyBlue),
                );
              }

              final tasks = taskSnapshot.data?.docs ?? [];

              final assignedCount = tasks.where((task) {
                return task.data()['status'] == 'assigned';
              }).length;

              final activeCount = tasks.where((task) {
                return task.data()['status'] == 'in_progress';
              }).length;

              final completedCount = tasks.where((task) {
                return task.data()['status'] == 'completed';
              }).length;

              final activeWorkers = workers.where((worker) {
                return worker.data()['status'] == 'active';
              }).length;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _complaints
                    .where('complaintType', isEqualTo: 'cleanliness')
                    .snapshots(),
                builder: (context, complaintSnapshot) {
                  final complaints = complaintSnapshot.data?.docs ?? [];

                  final newComplaintCount = complaints.where((complaint) {
                    return complaint.data()['status'] == 'submitted';
                  }).length;

                  final openComplaintCount = complaints.where((complaint) {
                    return [
                      'submitted',
                      'acknowledged',
                      'in_progress',
                    ].contains(complaint.data()['status']);
                  }).length;

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _openWorkerForm,
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                ),
                                label: const AppText('Add worker'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.white,
                                  foregroundColor: AppTheme.navyBlue,
                                  elevation: 0,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _openTaskForm(workers),
                                icon: const Icon(Icons.add_task_rounded),
                                label: const AppText('Assign task'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.navyBlue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openIncomingComplaints(workers),
                                icon: const Icon(Icons.inbox_outlined),
                                label: const AppText('Incoming complaints'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.navyBlue,
                                  side: const BorderSide(
                                    color: AppTheme.borderGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildOperationalOverview(
                            activeWorkers: activeWorkers,
                            assignedTasks: assignedCount,
                            inProgressTasks: activeCount,
                            completedTasks: completedCount,
                            totalTasks: tasks.length,
                            newComplaints: complaintSnapshot.hasError
                                ? -1
                                : newComplaintCount,
                            openComplaints: complaintSnapshot.hasError
                                ? -1
                                : openComplaintCount,
                            workers: workers,
                          ),
                          if (complaintSnapshot.hasError) ...[
                            const SizedBox(height: 8),
                            const AppText(
                              'Complaint metrics are temporarily unavailable. '
                              'The task register remains available.',
                              style: TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 10,
                              ),
                            ),
                          ] else if (!complaintSnapshot.hasData) ...[
                            const SizedBox(height: 8),
                            const AppText(
                              'Loading cleanliness complaint metrics…',
                              style: TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                          const SizedBox(height: 15),
                          _buildWorkerDirectory(workers),
                          const SizedBox(height: 19),
                          Row(
                            children: [
                              const Expanded(
                                child: AppText(
                                  'Cleaning task register',
                                  style: TextStyle(
                                    color: AppTheme.textDark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              AppText(
                                '${tasks.length} total',
                                style: const TextStyle(
                                  color: AppTheme.textGrey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          tasks.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.cleaning_services_outlined,
                                        size: 46,
                                        color: AppTheme.textGrey,
                                      ),
                                      const SizedBox(height: 12),
                                      const AppText(
                                        'No cleaning tasks yet',
                                        style: TextStyle(
                                          color: AppTheme.textDark,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const AppText(
                                        'Add a worker and assign the first task.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppTheme.textGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      OutlinedButton.icon(
                                        onPressed: _openWorkerForm,
                                        icon: const Icon(
                                          Icons.person_add_alt_1,
                                        ),
                                        label: const AppText(
                                          'Register a worker',
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: tasks.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 11),
                                  itemBuilder: (context, index) {
                                    return _buildTaskCard(tasks[index]);
                                  },
                                ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
