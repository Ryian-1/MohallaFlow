import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/push_notification_service.dart';

import 'splash_screen.dart';

import '../theme/app_theme.dart';
import '../models/user_role.dart';
import 'housekeeping_screen.dart';
import 'document_repository_screen.dart';
import 'gate_operations_screen.dart';
import 'worker_attendance_screen.dart';
import 'emergency_response_screen.dart';
import 'staff_leave_management_screen.dart';
import '../widgets/colony_switch_action.dart';

import '../widgets/notification_bell.dart';
import '../widgets/app_text.dart';
import '../widgets/brand_logo.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';
import '../widgets/app_language_toggle.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.workerId,
    required this.workerName,
    required this.onSignOut,
  });

  final String colonyId;
  final String colonyName;
  final String workerId;
  final String workerName;
  final Future<void> Function() onSignOut;

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
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

  CollectionReference<Map<String, dynamic>> get _tasks => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('cleanlinessTasks');

  DocumentReference<Map<String, dynamic>> get _workerProfile =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('cleanlinessWorkers')
          .doc(widget.workerId);

  DocumentReference<Map<String, dynamic>> get _workerPrivateProfile =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('workerPrivateProfiles')
          .doc(widget.workerId);

  Widget _buildWorkerWelcomeHeading() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _workerProfile.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final rawName = data?['fullName'];
        final displayName = rawName is String && rawName.trim().isNotEmpty
            ? rawName.trim()
            : widget.workerName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'YOUR WORKSPACE',
              style: TextStyle(
                color: AppTheme.textGrey,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 7),
            AppText(
              'Welcome, $displayName',
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 28,
                height: 1.12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMyProfileCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _workerProfile.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _profileMessageCard(
            'Unable to load your profile: ${snapshot.error}',
            onRetry: () => setState(() {}),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _profileMessageCard(
            'Loading your personal details…',
            loading: true,
          );
        }
        if (snapshot.data?.exists != true) {
          return _profileMessageCard(
            'Your worker profile was not found. Please contact the Admin.',
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _workerPrivateProfile.snapshots(),
          builder: (context, privateSnapshot) {
            if (privateSnapshot.hasError) {
              return _profileMessageCard(
                'Unable to load your private details: ${privateSnapshot.error}',
                onRetry: () => setState(() {}),
              );
            }
            final data = <String, dynamic>{
              ...(snapshot.data!.data() ?? <String, dynamic>{}),
              ...(privateSnapshot.data?.data() ?? <String, dynamic>{}),
            };
            final name = data['fullName'] as String? ?? widget.workerName;
            final phone = data['phoneNumber'] as String? ?? 'Not provided';
            final bloodGroup = data['bloodGroup'] as String? ?? 'Not provided';
            final area = data['assignedArea'] as String? ?? 'Not assigned';
            final familyName = data['familyMemberName'] as String? ?? '';
            final familyPhone = data['familyMemberPhone'] as String? ?? '';
            final emergencyContact = familyName.isEmpty && familyPhone.isEmpty
                ? 'Not provided'
                : '$familyName · $familyPhone';

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: AppTheme.cardBorderRadius,
                border: Border.all(color: AppTheme.borderGrey),
                boxShadow: AppTheme.quietCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: AppText(
                          'My personal details',
                          style: TextStyle(
                            color: AppTheme.navyBlue,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _openWorkerProfileEditor(data),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const AppText('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.navyBlue,
                        ),
                      ),
                    ],
                  ),
                  AppText(
                    'Name: $name',
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AppText(
                    'Contact number: $phone',
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AppText(
                    'Blood group: $bloodGroup',
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AppText(
                    'Assigned area: $area',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AppText(
                    'Family / emergency contact: $emergencyContact',
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _profileMessageCard(
    String message, {
    bool loading = false,
    VoidCallback? onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.navyBlue,
              ),
            )
          else
            const Icon(
              Icons.info_outline_rounded,
              color: AppTheme.textGrey,
              size: 18,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
                if (onRetry != null)
                  TextButton(onPressed: onRetry, child: const AppText('Retry')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWorkerProfileEditor(Map<String, dynamic> current) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: current['fullName'] as String? ?? widget.workerName,
    );
    final phoneController = TextEditingController(
      text: current['phoneNumber'] as String? ?? '',
    );
    final familyNameController = TextEditingController(
      text: current['familyMemberName'] as String? ?? '',
    );
    final familyPhoneController = TextEditingController(
      text: current['familyMemberPhone'] as String? ?? '',
    );
    const bloodGroups = [
      'Not provided',
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
      'O+',
      'O-',
    ];
    final savedBloodGroup = current['bloodGroup'] as String?;
    String bloodGroup = bloodGroups.contains(savedBloodGroup)
        ? savedBloodGroup!
        : 'Not provided';
    bool privateDetailsConsent = current['consentStatus'] == 'granted';
    bool saving = false;
    bool saved = false;
    String? formError;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            String? familyNameValidator(String? value) {
              final name = value?.trim() ?? '';
              final phone = familyPhoneController.text.trim();
              if (name.isEmpty && phone.isEmpty) return null;
              if (name.length < 2 || name.length > 100) {
                return AppTranslations.translate(
                  'Enter a valid family member name',
                );
              }
              return null;
            }

            String? familyPhoneValidator(String? value) {
              final phone = value?.trim() ?? '';
              final name = familyNameController.text.trim();
              if (phone.isEmpty && name.isEmpty) return null;
              if (name.length < 2) {
                return AppTranslations.translate(
                  'Enter the family member name',
                );
              }
              if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
                return AppTranslations.translate(
                  'Enter a valid 10-digit mobile number',
                );
              }
              return null;
            }

            Future<void> saveProfile() async {
              if (saving || !formKey.currentState!.validate()) return;
              final hasPrivateDetails =
                  bloodGroup != 'Not provided' ||
                  familyNameController.text.trim().isNotEmpty ||
                  familyPhoneController.text.trim().isNotEmpty;
              final legacyDetailsPendingConsent =
                  current['consentStatus'] == 'pending';
              if (hasPrivateDetails &&
                  !privateDetailsConsent &&
                  !legacyDetailsPendingConsent) {
                setDialogState(() {
                  formError = 'Consent is required to save medical or emergency contact details.';
                });
                return;
              }
              setDialogState(() {
                saving = true;
                formError = null;
              });
              try {
                final batch = FirebaseFirestore.instance.batch();
                batch.update(_workerProfile, {
                  'fullName': nameController.text.trim(),
                  'phoneNumber': phoneController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                batch.set(_workerPrivateProfile, {
                  'bloodGroup': privateDetailsConsent
                      ? bloodGroup
                      : 'Not provided',
                  'familyMemberName': privateDetailsConsent
                      ? familyNameController.text.trim()
                      : '',
                  'familyMemberPhone': privateDetailsConsent
                      ? familyPhoneController.text.trim()
                      : '',
                  'consentStatus': hasPrivateDetails && privateDetailsConsent
                      ? 'granted'
                      : (hasPrivateDetails && legacyDetailsPendingConsent
                            ? 'pending'
                            : 'not_provided'),
                  'consentAt': hasPrivateDetails && privateDetailsConsent
                      ? (current['consentStatus'] == 'granted'
                            ? current['consentAt'] ??
                                  FieldValue.serverTimestamp()
                            : FieldValue.serverTimestamp())
                      : null,
                  'privacyNoticeVersion': 'worker-private-v1',
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                await batch.commit();
                saved = true;
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              } on FirebaseException catch (error) {
                debugPrint(
                  'Worker self-profile update failed: ${error.code} ${error.message}',
                );
                setDialogState(() {
                  saving = false;
                  formError =
                      'Unable to save details: ${error.message ?? error.code}';
                });
              } catch (error) {
                debugPrint('Worker self-profile update error: $error');
                setDialogState(() {
                  saving = false;
                  formError = 'Unable to save details. Please try again.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.white,
              title: const AppText(
                'Edit my personal details',
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
                        TextFormField(
                          controller: nameController,
                          maxLength: 100,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Full name'),
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                          validator: (value) {
                            final name = value?.trim() ?? '';
                            return name.length >= 2 && name.length <= 100
                                ? null
                                : AppTranslations.translate(
                                    'Enter a valid name',
                                  );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Contact number',
                            ),
                            hintText: AppTranslations.translate(
                              '10-digit mobile number',
                            ),
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
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
                        DropdownButtonFormField<String>(
                          initialValue: bloodGroup,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Blood group'),
                            border: OutlineInputBorder(),
                          ),
                          items: bloodGroups
                              .map(
                                (group) => DropdownMenuItem<String>(
                                  value: group,
                                  child: AppText(group),
                                ),
                              )
                              .toList(),
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() => bloodGroup = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: familyNameController,
                          maxLength: 100,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Family member name',
                            ),
                            hintText: AppTranslations.translate(
                              'Optional emergency contact',
                            ),
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                          validator: familyNameValidator,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: familyPhoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Family member phone number',
                            ),
                            hintText: AppTranslations.translate(
                              '10-digit mobile number',
                            ),
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                          validator: familyPhoneValidator,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGrey,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderGrey),
                          ),
                          child: const AppText(
                            'Blood group and family emergency contact are optional. They are stored separately from your operational worker profile. Only you can view them by default. The Colony Admin can view them only after you consent, for safety and emergency response.',
                            style: TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (bloodGroup != 'Not provided' ||
                            familyNameController.text.isNotEmpty ||
                            familyPhoneController.text.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: saving
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        privateDetailsConsent = false;
                                        bloodGroup = 'Not provided';
                                        familyNameController.clear();
                                        familyPhoneController.clear();
                                      });
                                    },
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const AppText('Remove private details'),
                            ),
                          ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: privateDetailsConsent,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const AppText(
                            'I consent to sharing these private details with the Colony Admin for safety and emergency response.',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 12,
                            ),
                          ),
                          onChanged: saving
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    privateDetailsConsent = value ?? false;
                                    if (!privateDetailsConsent) {
                                      bloodGroup = 'Not provided';
                                      familyNameController.clear();
                                      familyPhoneController.clear();
                                    }
                                  });
                                },
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AppText(
                            'Assigned area is managed by the Admin and cannot be edited here.',
                            style: TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
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
                  onPressed: saving ? null : saveProfile,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const AppText('Save changes'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
      familyNameController.dispose();
      familyPhoneController.dispose();
    }
    if (saved) _showMessage('Your personal details were updated.');
  }

  bool _updatingTask = false;

  // ==========================================
  // SHOW MESSAGE
  // ==========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ==========================================
  // SIGN OUT
  // ==========================================

  Future<void> _confirmSignOut() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          title: const AppText(
            'Sign out?',
            style: TextStyle(
              color: AppTheme.navyBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const AppText(
            'Are you sure you want to sign out of MohallaFlow?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Sign out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        try {
          await PushNotificationService.unregisterCurrentDevice();

          await widget.onSignOut();
        } catch (callbackError, callbackStackTrace) {
          debugPrint('Worker sign-out callback error: $callbackError');
          debugPrintStack(stackTrace: callbackStackTrace);
        }

        // Ensure Firebase is signed out even if the original
        // callback only performed navigation or used an old context.
        if (FirebaseAuth.instance.currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      } catch (error, stackTrace) {
        debugPrint('Worker sign-out error: $error');
        debugPrintStack(stackTrace: stackTrace);

        if (!mounted) return;

        // If Firebase signed out but navigation failed,
        // finish navigation using the active Worker screen context.
        if (FirebaseAuth.instance.currentUser == null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
            (route) => false,
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Unable to sign out. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ==========================================

  void _openEmergencyResponse() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmergencyResponseScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          mode: EmergencyResponseMode.responder,
          currentUserName: widget.workerName,
        ),
      ),
    );
  }

  void _openHousekeepingTasks() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HousekeepingScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          mode: HousekeepingMode.worker,
          workerId: widget.workerId,
          workerName: widget.workerName,
        ),
      ),
    );
  }

  // UPDATE TASK STATUS
  // ==========================================

  Future<void> _updateTaskStatus(
    DocumentSnapshot<Map<String, dynamic>> task,
    String newStatus,
  ) async {
    if (_updatingTask) return;

    setState(() {
      _updatingTask = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(task.reference, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'completedAt': newStatus == 'completed'
            ? FieldValue.serverTimestamp()
            : null,
      });

      final sourceComplaintId =
          task.data()?['sourceComplaintId']?.toString().trim() ?? '';
      if (newStatus == 'completed' && sourceComplaintId.isNotEmpty) {
        final complaintReference = FirebaseFirestore.instance
            .collection('colonies')
            .doc(widget.colonyId)
            .collection('complaints')
            .doc(sourceComplaintId);

        batch.update(complaintReference, {
          'status': 'resolved',
          'updatedAt': FieldValue.serverTimestamp(),
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolutionTaskId': task.id,
        });
      }

      await batch.commit();

      _showMessage(
        newStatus == 'in_progress'
            ? 'Task started successfully.'
            : 'Task marked as completed.',
      );
    } on FirebaseException catch (error) {
      debugPrint('Worker task update failed: ${error.code} ${error.message}');

      _showMessage('Unable to update task: ${error.message ?? error.code}');
    } catch (error) {
      debugPrint('Worker task update error: $error');
      _showMessage('Unable to update task.');
    } finally {
      if (mounted) {
        setState(() {
          _updatingTask = false;
        });
      }
    }
  }

  // ==========================================
  // STATUS LABEL
  // ==========================================

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

  // ==========================================
  // SUMMARY COUNTER
  // ==========================================

  Widget _buildCount(String label, int count) {
    return Column(
      children: [
        AppText(
          '$count',
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        AppText(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
        ),
      ],
    );
  }

  // ==========================================
  // STATUS BADGE
  // ==========================================

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ==========================================
  // TASK CARD
  // ==========================================

  Widget _buildTaskCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final String title = data['title'] as String? ?? 'Untitled task';

    final String location = data['location'] as String? ?? '';

    final String description = data['description'] as String? ?? '';

    final String priority = data['priority'] as String? ?? 'normal';

    final String status = data['status'] as String? ?? 'assigned';

    final Object? createdAt = data['createdAt'];

    final String dateLabel = createdAt is Timestamp
        ? createdAt.toDate().toLocal().toString().substring(0, 16)
        : 'Date pending';

    return Container(
      key: ValueKey<String>('worker-task-${document.id}'),
      padding: const EdgeInsets.all(17),
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
                  title,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(status),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppTheme.secondaryNavy,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: AppText(
                  location,
                  style: const TextStyle(
                    color: AppTheme.secondaryNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 11),

          AppText(
            description,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 13,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 15,
                color: AppTheme.textGrey,
              ),
              const SizedBox(width: 6),
              AppText(
                'Priority: ${_priorityLabel(priority)}',
                style: const TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: AppTheme.textGrey,
              ),
              const SizedBox(width: 6),
              AppText(
                dateLabel,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
              ),
            ],
          ),

          if (status == 'assigned') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: _updatingTask
                    ? null
                    : () => _updateTaskStatus(document, 'in_progress'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const AppText('Start task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],

          if (status == 'in_progress') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: _updatingTask
                    ? null
                    : () => _updateTaskStatus(document, 'completed'),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const AppText('Mark as completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],

          if (status == 'completed') ...[
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: AppTheme.secondaryNavy,
                  size: 19,
                ),
                SizedBox(width: 8),
                AppText(
                  'Task completed successfully',
                  style: TextStyle(
                    color: AppTheme.secondaryNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // HOUSEKEEPING WORKLOAD SUMMARY
  // ==========================================

  Widget _buildHousekeepingSummary(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    Widget summaryCard(Widget child) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        child: child,
      );
    }

    if (snapshot.hasError) {
      return summaryCard(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Unable to load housekeeping jobs.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
            AppText('${snapshot.error}'),
            TextButton(
              onPressed: () => setState(() {}),
              child: const AppText('Retry'),
            ),
            TextButton(
              onPressed: _openHousekeepingTasks,
              child: const AppText('Open jobs'),
            ),
          ],
        ),
      );
    }

    if (!snapshot.hasData) {
      return summaryCard(
        const Row(
          children: [
            SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.navyBlue,
              ),
            ),
            SizedBox(width: 11),
            AppText(
              'Loading housekeeping jobs...',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final documents = snapshot.data!.docs;

    final assignedCount = documents
        .where((doc) => doc.data()['status'] == 'assigned')
        .length;

    final activeCount = documents
        .where((doc) => doc.data()['status'] == 'in_progress')
        .length;

    final completedCount = documents
        .where((doc) => doc.data()['status'] == 'completed')
        .length;

    return summaryCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cleaning_services_outlined,
                color: AppTheme.secondaryNavy,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: AppText(
                  'My housekeeping jobs (${documents.length})',
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openHousekeepingTasks,
                child: const AppText('Open jobs'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildCount('Assigned', assignedCount)),
              Container(width: 1, height: 40, color: AppTheme.borderGrey),
              Expanded(child: _buildCount('In progress', activeCount)),
              Container(width: 1, height: 40, color: AppTheme.borderGrey),
              Expanded(child: _buildCount('Completed', completedCount)),
            ],
          ),
          if (documents.isEmpty) ...[
            const SizedBox(height: 8),
            const Center(
              child: AppText(
                'No housekeeping jobs assigned yet.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // EMPTY STATE
  // ==========================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 55,
            color: AppTheme.textGrey,
          ),
          const SizedBox(height: 15),
          const AppText(
            'No tasks assigned yet',
            style: TextStyle(
              color: AppTheme.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const AppText(
            'Your assigned cleaning tasks will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _workerActionMenuItem(
    String value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppTheme.navyBlue),
          const SizedBox(width: 12),
          AppText(AppTranslations.translate(label)),
        ],
      ),
    );
  }

  Widget _buildGateOperationsAction() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('gateOperators')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data == null ||
            data['isActive'] != true ||
            data['workerId'] != widget.workerId) {
          return const SizedBox.shrink();
        }
        return IconButton(
          tooltip: AppTranslations.translate('Gate operations'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GateOperationsScreen(
                colonyId: widget.colonyId,
                colonyName: widget.colonyName,
                isAdmin: false,
                workerId: widget.workerId,
                workerName: widget.workerName,
              ),
            ),
          ),
          icon: const Icon(Icons.security_outlined),
        );
      },
    );
  }

  // ==========================================
  // MAIN SCREEN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navyBlue,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const BrandLogo(width: 145, height: 33),
        actions: [
          const AppLanguageToggle(),
          ColonySwitchAction(
            currentColonyId: widget.colonyId,
            currentColonyName: widget.colonyName,
            currentRole: UserRole.worker,
          ),
          NotificationBell(
            colonyId: widget.colonyId,
            colonyName: widget.colonyName,
            roleKey: 'worker',
            workerId: widget.workerId,
          ),
          _buildGateOperationsAction(),
          PopupMenuButton<String>(
            tooltip: AppTranslations.translate('More actions'),
            onSelected: (action) {
              switch (action) {
                case 'attendance':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WorkerAttendanceScreen(
                        colonyId: widget.colonyId,
                        colonyName: widget.colonyName,
                        isManager: false,
                        workerId: widget.workerId,
                        workerName: widget.workerName,
                      ),
                    ),
                  );
                  break;
                case 'emergency':
                  _openEmergencyResponse();
                  break;
                case 'leave':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StaffLeaveManagementScreen(
                        colonyId: widget.colonyId,
                        colonyName: widget.colonyName,
                        isAdmin: false,
                        workerId: widget.workerId,
                        workerName: widget.workerName,
                      ),
                    ),
                  );
                  break;
                case 'housekeeping':
                  _openHousekeepingTasks();
                  break;
                case 'documents':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DocumentRepositoryScreen(
                        colonyId: widget.colonyId,
                        colonyName: widget.colonyName,
                        isAdmin: false,
                        roleKey: 'worker',
                      ),
                    ),
                  );
                  break;
                case 'sign_out':
                  _confirmSignOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              _workerActionMenuItem(
                'attendance',
                Icons.fact_check_outlined,
                'My attendance',
              ),
              _workerActionMenuItem(
                'emergency',
                Icons.sos,
                'Emergency response',
              ),
              _workerActionMenuItem(
                'leave',
                Icons.event_available_outlined,
                'My leave',
              ),
              _workerActionMenuItem(
                'housekeeping',
                Icons.cleaning_services_outlined,
                'My housekeeping tasks',
              ),
              _workerActionMenuItem(
                'documents',
                Icons.folder_shared_outlined,
                'Shared colony documents',
              ),
              _workerActionMenuItem(
                'sign_out',
                Icons.logout_rounded,
                'Sign out',
              ),
            ],
          ),
          const SizedBox(width: 7),
        ],
      ),
      body: uid == null
          ? const Center(child: AppText('Please sign in again.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _tasks
                  .where('assignedWorkerId', isEqualTo: widget.workerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 40),
                          const SizedBox(height: 10),
                          const AppText(
                            'Unable to load your assigned tasks.',
                            textAlign: TextAlign.center,
                          ),
                          AppText(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => setState(() {}),
                            child: const AppText('Retry'),
                          ),
                        ],
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

                documents.sort((a, b) {
                  final aDate = a.data()['createdAt'];
                  final bDate = b.data()['createdAt'];

                  final DateTime aTime = aDate is Timestamp
                      ? aDate.toDate()
                      : DateTime.fromMillisecondsSinceEpoch(0);

                  final DateTime bTime = bDate is Timestamp
                      ? bDate.toDate()
                      : DateTime.fromMillisecondsSinceEpoch(0);

                  return bTime.compareTo(aTime);
                });

                final int assignedCount = documents.where((task) {
                  return task.data()['status'] == 'assigned';
                }).length;

                final int activeCount = documents.where((task) {
                  return task.data()['status'] == 'in_progress';
                }).length;

                final int completedCount = documents.where((task) {
                  return task.data()['status'] == 'completed';
                }).length;

                return Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWorkerWelcomeHeading(),

                      const SizedBox(height: 5),

                      AppText(
                        widget.colonyName,
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 15),

                      _buildMyProfileCard(),

                      const SizedBox(height: 18),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 17,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppTheme.borderGrey),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildCount('Assigned', assignedCount),
                            ),
                            Container(
                              width: 1,
                              height: 43,
                              color: AppTheme.borderGrey,
                            ),
                            Expanded(
                              child: _buildCount('In progress', activeCount),
                            ),
                            Container(
                              width: 1,
                              height: 43,
                              color: AppTheme.borderGrey,
                            ),
                            Expanded(
                              child: _buildCount('Completed', completedCount),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 19),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('colonies')
                            .doc(widget.colonyId)
                            .collection('housekeepingRequests')
                            .where(
                              'assignedWorkerId',
                              isEqualTo: widget.workerId,
                            )
                            .snapshots(),
                        builder: (context, snapshot) {
                          return _buildHousekeepingSummary(snapshot);
                        },
                      ),

                      const SizedBox(height: 23),

                      Row(
                        children: [
                          const Expanded(
                            child: AppText(
                              'My cleaning tasks',
                              style: TextStyle(
                                color: AppTheme.textDark,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          AppText(
                            '${documents.length} total',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Expanded(
                        child: documents.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                itemCount: documents.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _buildTaskCard(documents[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
