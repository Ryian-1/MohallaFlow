import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../widgets/app_text.dart';
import '../widgets/app_selectable_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  CollectionReference<Map<String, dynamic>> get _complaints => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('complaints');

  static const Map<String, String> _categories = {
    'Garbage collection': 'cleanliness',
    'Street cleaning': 'cleanliness',
    'Lift': 'maintenance',
    'Plumbing': 'maintenance',
    'Electricity': 'maintenance',
    'Water supply': 'maintenance',
    'Security': 'other',
    'Common area': 'other',
    'Other': 'other',
  };

  static const List<String> _statuses = [
    'submitted',
    'acknowledged',
    'in_progress',
    'resolved',
    'closed',
  ];

  static const List<String> _statusFilters = [
    'all',
    'submitted',
    'acknowledged',
    'in_progress',
    'resolved',
    'closed',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all';
  String _selectedTypeFilter = 'all';
  String _selectedPriorityFilter = 'all';
  bool _newestFirst = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ==========================================
  // CREATE COMPLAINT
  // ==========================================

  Future<void> _openComplaintForm() async {
    final formKey = GlobalKey<FormState>();

    final reporterController = TextEditingController();
    final phoneController = TextEditingController();
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();

    String selectedCategory = 'Garbage collection';
    String selectedPriority = 'normal';

    String? formError;
    bool saving = false;
    bool saved = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submitComplaint() async {
              if (saving || !formKey.currentState!.validate()) {
                return;
              }

              final String? uid = FirebaseAuth.instance.currentUser?.uid;

              if (uid == null) {
                setDialogState(() {
                  formError = 'Please sign in again.';
                });
                return;
              }

              setDialogState(() {
                saving = true;
                formError = null;
              });

              final String complaintType = _categories[selectedCategory]!;

              // Keep this document schema aligned with validComplaint in the
              // deployed Firestore rules. Complaint fields are immutable after
              // creation; only status and updatedAt can be changed later.
              final Map<String, dynamic> complaintData = {
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'category': selectedCategory,
                'complaintType': complaintType,
                'location': locationController.text.trim(),
                'reportedByName': reporterController.text.trim(),
                'reportedByPhone': phoneController.text.trim(),
                'submittedBy': uid,
                'submittedByName': widget.adminName,
                'priority': selectedPriority,
                'status': 'submitted',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              };

              try {
                await _complaints.add(complaintData);

                saved = true;

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();
              } on FirebaseException catch (error) {
                debugPrint(
                  'Complaint creation failed: '
                  '${error.code} ${error.message}',
                );

                setDialogState(() {
                  saving = false;
                  formError =
                      'Unable to register complaint: '
                      '${error.message ?? error.code}';
                });
              } catch (error) {
                debugPrint('Complaint creation error: $error');

                setDialogState(() {
                  saving = false;
                  formError = 'Unable to register complaint. Please try again.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.white,
              title: const AppText(
                'Register complaint',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'Complainant details',
                          style: TextStyle(
                            color: AppTheme.navyBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInput(
                          controller: reporterController,
                          label: 'Resident name',
                          hint: 'Enter resident name',
                        ),
                        const SizedBox(height: 14),
                        _buildInput(
                          controller: phoneController,
                          label: 'Resident mobile number',
                          hint: '10-digit number (optional)',
                          requiredField: false,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (value) {
                            final phone = value?.trim() ?? '';

                            if (phone.isNotEmpty &&
                                !RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
                              return AppTranslations.translate(
                                'Enter a valid 10-digit number',
                              );
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        const AppText(
                          'Complaint information',
                          style: TextStyle(
                            color: AppTheme.navyBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Complaint category',
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: _categories.keys.map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: AppText(category),
                            );
                          }).toList(),
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      selectedCategory = value;
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 14),
                        _buildInput(
                          controller: titleController,
                          label: 'Complaint title',
                          hint: 'Briefly describe the issue',
                          validator: (value) {
                            final title = value?.trim() ?? '';

                            if (title.isEmpty) {
                              return AppTranslations.translate(
                                'Please enter Complaint title',
                              );
                            }

                            if (title.length > 120) {
                              return AppTranslations.translate(
                                'Title must be 120 characters or fewer',
                              );
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildInput(
                          controller: locationController,
                          label: 'Location',
                          hint: 'Example: Block A, near the lift',
                        ),
                        const SizedBox(height: 14),
                        _buildInput(
                          controller: descriptionController,
                          label: 'Detailed description',
                          hint: 'Explain the problem in detail',
                          maxLines: 4,
                          validator: (value) {
                            final text = value?.trim() ?? '';

                            if (text.length < 10) {
                              return AppTranslations.translate(
                                'Please provide at least 10 characters',
                              );
                            }

                            if (text.length > 2000) {
                              return AppTranslations.translate(
                                'Description is too long',
                              );
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedPriority,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Priority'),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'low',
                              child: AppText('Low'),
                            ),
                            DropdownMenuItem(
                              value: 'normal',
                              child: AppText('Normal'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: AppText('High'),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: AppText('Urgent'),
                            ),
                          ],
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
                  onPressed: saving ? null : submitComplaint,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const AppText('Submit complaint'),
                ),
              ],
            );
          },
        );
      },
    );

    reporterController.dispose();
    phoneController.dispose();
    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();

    if (saved) {
      _showMessage('Complaint registered successfully.');
    }
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool requiredField = true,
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
            if (requiredField && (value == null || value.trim().isEmpty)) {
              return AppTranslations.translate('Please enter $label');
            }
            return null;
          },
    );
  }

  // ==========================================
  // UPDATE COMPLAINT STATUS
  // ==========================================

  Future<void> _updateStatus(
    DocumentSnapshot<Map<String, dynamic>> complaint,
    String newStatus,
  ) async {
    if (!_statuses.contains(newStatus)) return;

    try {
      // Firestore rules permit only status and updatedAt to change on a
      // complaint. Keep that update and the resident notification atomic.
      final complaintData = complaint.data() ?? <String, dynamic>{};
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final batch = FirebaseFirestore.instance.batch();

      batch.update(complaint.reference, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final recipientUserId =
          complaintData['submittedBy']?.toString().trim() ?? '';
      if (currentUid != null && recipientUserId.isNotEmpty) {
        NotificationService.addComplaintStatusChanged(
          batch: batch,
          colonyId: widget.colonyId,
          complaintId: complaint.id,
          complaintTitle:
              complaintData['title']?.toString() ?? 'Your complaint',
          newStatus: newStatus,
          recipientUserId: recipientUserId,
          createdBy: currentUid,
        );
      }

      await batch.commit();

      _showMessage('Complaint status changed to ${_statusLabel(newStatus)}.');
    } on FirebaseException catch (error) {
      debugPrint(
        'Complaint status update failed: ${error.code} ${error.message}',
      );

      _showMessage(
        'Unable to update complaint: ${error.message ?? error.code}',
      );
    } catch (error) {
      debugPrint('Complaint status update error: $error');
      _showMessage('Unable to update complaint.');
    }
  }

  // ==========================================
  // FILTERING AND SEARCH
  // ==========================================

  List<DocumentSnapshot<Map<String, dynamic>>> _filterComplaints(
    List<DocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final String query = _searchController.text.trim().toLowerCase();

    final filtered = documents.where((document) {
      final data = document.data() ?? <String, dynamic>{};
      final String status = data['status']?.toString() ?? 'submitted';
      final String type = data['complaintType']?.toString() ?? 'other';
      final String priority = data['priority']?.toString() ?? 'normal';

      if (_selectedStatusFilter != 'all' && status != _selectedStatusFilter) {
        return false;
      }

      if (_selectedTypeFilter != 'all' && type != _selectedTypeFilter) {
        return false;
      }

      if (_selectedPriorityFilter != 'all' &&
          priority != _selectedPriorityFilter) {
        return false;
      }

      if (query.isEmpty) return true;

      final searchable = [
        document.id,
        data['title'],
        data['description'],
        data['category'],
        data['complaintType'],
        data['location'],
        data['reportedByName'],
        data['reportedByPhone'],
        data['submittedByName'],
        data['priority'],
        data['status'],
      ].whereType<Object>().join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();

    filtered.sort((first, second) {
      final firstDate = first.data()?['createdAt'];
      final secondDate = second.data()?['createdAt'];
      final firstMillis = firstDate is Timestamp
          ? firstDate.millisecondsSinceEpoch
          : 0;
      final secondMillis = secondDate is Timestamp
          ? secondDate.millisecondsSinceEpoch
          : 0;

      return _newestFirst
          ? secondMillis.compareTo(firstMillis)
          : firstMillis.compareTo(secondMillis);
    });

    return filtered;
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _selectedStatusFilter != 'all' ||
      _selectedTypeFilter != 'all' ||
      _selectedPriorityFilter != 'all' ||
      !_newestFirst;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatusFilter = 'all';
      _selectedTypeFilter = 'all';
      _selectedPriorityFilter = 'all';
      _newestFirst = true;
    });
  }

  // ==========================================
  // STATUS LABEL
  // ==========================================

  String _statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'acknowledged':
        return 'Acknowledged';
      case 'in_progress':
        return 'In progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  Widget _buildStatusBadge(String status) {
    final Color background;
    final Color foreground;

    switch (status) {
      case 'submitted':
        background = const Color(0xFFFFF3E0);
        foreground = const Color(0xFF9A5B00);
        break;
      case 'acknowledged':
        background = const Color(0xFFEAF0F7);
        foreground = AppTheme.navyBlue;
        break;
      case 'in_progress':
        background = const Color(0xFFE8F1FF);
        foreground = const Color(0xFF245D9C);
        break;
      case 'resolved':
      case 'closed':
        background = const Color(0xFFE7F5EC);
        foreground = const Color(0xFF21653B);
        break;
      default:
        background = const Color(0xFFEAF0F7);
        foreground = AppTheme.navyBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText(
        _statusLabel(status).toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }

  // ==========================================
  // PRIORITY LABEL
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

  // ==========================================
  // COMPLAINT DETAILS
  // ==========================================

  Future<void> _showComplaintDetails(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data() ?? <String, dynamic>{};
    final String title = data['title'] as String? ?? 'Untitled complaint';
    final String category = data['category'] as String? ?? 'Other';
    final String complaintType = data['complaintType'] as String? ?? 'other';
    final String location = data['location'] as String? ?? 'Not provided';
    final String reporter = data['reportedByName'] as String? ?? 'Not provided';
    final String phone = data['reportedByPhone'] as String? ?? '';
    final String description =
        data['description'] as String? ?? 'No description provided.';
    final String priority = data['priority'] as String? ?? 'normal';
    final String status = data['status'] as String? ?? 'submitted';
    final String submittedByName =
        data['submittedByName'] as String? ?? 'Not available';
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
    final String dateLabel = createdAt == null
        ? 'Date pending'
        : createdAt.toDate().toLocal().toString().substring(0, 16);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 14, 8),
          contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          title: Row(
            children: [
              const Expanded(
                child: AppText(
                  'Complaint details',
                  style: TextStyle(
                    color: AppTheme.navyBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppTranslations.translate('Close'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildStatusBadge(status),
                      _buildPriorityBadge(priority),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _detailSection('Complaint information', [
                    _detailRow('Category', category),
                    _detailRow('Complaint type', _typeLabel(complaintType)),
                    _detailRow('Location', location),
                    _detailRow('Submitted on', dateLabel),
                    _detailRow('Complaint reference', document.id),
                  ]),
                  const SizedBox(height: 16),
                  _detailSection('Complainant details', [
                    _detailRow('Resident name', reporter),
                    _detailRow(
                      'Mobile number',
                      phone.isEmpty ? 'Not provided' : phone,
                    ),
                    _detailRow('Recorded by', submittedByName),
                  ]),
                  const SizedBox(height: 16),
                  const AppText(
                    'Full description',
                    style: TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AppSelectableText(
                      description,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
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

  Widget _detailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          title,
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderGrey),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: AppText(
              label,
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppSelectableText(
              value,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    final Color color = switch (priority) {
      'urgent' => const Color(0xFFB42318),
      'high' => const Color(0xFFB54708),
      'low' => const Color(0xFF667085),
      _ => AppTheme.secondaryNavy,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText(
        'PRIORITY: ${_priorityLabel(priority).toUpperCase()}',
        style: TextStyle(
          color: color,
          fontSize: 9,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'cleanliness':
        return 'Cleanliness';
      case 'maintenance':
        return 'Maintenance';
      default:
        return 'Other';
    }
  }

  // ==========================================
  // COMPLAINT CARD
  // ==========================================

  Widget _buildComplaintCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final String title = data['title'] as String? ?? 'Untitled complaint';
    final String category = data['category'] as String? ?? 'Other';
    final String location = data['location'] as String? ?? '';
    final String reporter = data['reportedByName'] as String? ?? '';
    final String priority = data['priority'] as String? ?? 'normal';
    final String status = data['status'] as String? ?? 'submitted';
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;

    final String dateLabel = createdAt == null
        ? 'Date pending'
        : createdAt.toDate().toLocal().toString().substring(0, 16);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
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
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: AppTranslations.translate('Update complaint status'),
                  onSelected: (value) {
                    _updateStatus(document, value);
                  },
                  itemBuilder: (context) {
                    return _statuses.map((statusOption) {
                      return PopupMenuItem<String>(
                        value: statusOption,
                        child: Row(
                          children: [
                            if (statusOption == status)
                              const Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: AppTheme.secondaryNavy,
                              )
                            else
                              const SizedBox(width: 17),
                            const SizedBox(width: 8),
                            AppText(_statusLabel(statusOption)),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.secondaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStatusBadge(status),
                _buildPriorityBadge(priority),
              ],
            ),
            const SizedBox(height: 12),
            AppText(
              '$category · $location',
              style: const TextStyle(
                color: AppTheme.secondaryNavy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            AppText(
              data['description'] as String? ?? '',
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            const Divider(color: AppTheme.borderGrey),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: AppTheme.textGrey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AppText(
                    reporter.isEmpty ? 'Resident not provided' : reporter,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showComplaintDetails(document),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const AppText('Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.secondaryNavy,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppTheme.textGrey,
                ),
                const SizedBox(width: 7),
                AppText(
                  dateLabel,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SUMMARY COUNTS
  // ==========================================

  Widget _buildCount(String label, int count) {
    return Column(
      children: [
        AppText(
          '$count',
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        AppText(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildStatusFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusFilters.map((status) {
          final bool selected = _selectedStatusFilter == status;
          final String label = status == 'all' ? 'All' : _statusLabel(status);

          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: AppText(label),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedStatusFilter = status;
                });
              },
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.textDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: AppTheme.navyBlue,
              backgroundColor: AppTheme.white,
              side: BorderSide(
                color: selected ? AppTheme.navyBlue : AppTheme.borderGrey,
              ),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> options,
    required String Function(String) labelBuilder,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.all(color: AppTheme.borderGrey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: AppText(
                labelBuilder(option),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(int totalCount, int visibleCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: AppTranslations.translate(
              'Search title, resident, location or complaint ID',
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: AppTranslations.translate('Clear search'),
                    onPressed: () {
                      setState(_searchController.clear);
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: AppTheme.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderGrey),
            ),
          ),
        ),
        const SizedBox(height: 11),
        _buildStatusFilters(),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                value: _selectedTypeFilter,
                options: const ['all', 'cleanliness', 'maintenance', 'other'],
                labelBuilder: (value) =>
                    value == 'all' ? 'All types' : _typeLabel(value),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedTypeFilter = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFilterDropdown(
                value: _selectedPriorityFilter,
                options: const ['all', 'low', 'normal', 'high', 'urgent'],
                labelBuilder: (value) =>
                    value == 'all' ? 'All priorities' : _priorityLabel(value),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedPriorityFilter = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: _newestFirst
                  ? AppTranslations.translate('Newest first')
                  : AppTranslations.translate('Oldest first'),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _newestFirst = !_newestFirst;
                  });
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.white,
                  side: const BorderSide(color: AppTheme.borderGrey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  _newestFirst ? Icons.south_rounded : Icons.north_rounded,
                  color: AppTheme.secondaryNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppText(
                'Showing $visibleCount of $totalCount complaints',
                style: const TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_hasActiveFilters)
              TextButton(
                onPressed: _clearFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                ),
                child: const AppText('Clear filters'),
              ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // MAIN SCREEN
  // ==========================================

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
            const AppText(
              'Complaint Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            AppText(
              widget.colonyName,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComplaintForm,
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const AppText(
          'Register complaint',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _complaints.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppText(
                  'Unable to load complaints.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textGrey, height: 1.6),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.navyBlue),
            );
          }

          final documents = snapshot.data?.docs ?? [];
          final int submittedCount = documents.where((doc) {
            return doc.data()['status'] == 'submitted';
          }).length;
          final int activeCount = documents.where((doc) {
            final status = doc.data()['status'];
            return status == 'acknowledged' || status == 'in_progress';
          }).length;
          final int resolvedCount = documents.where((doc) {
            return doc.data()['status'] == 'resolved';
          }).length;
          final int closedCount = documents.where((doc) {
            return doc.data()['status'] == 'closed';
          }).length;

          final visibleDocuments = _filterComplaints(documents);

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppTheme.borderGrey),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildCount('Submitted', submittedCount)),
                      Container(
                        width: 1,
                        height: 42,
                        color: AppTheme.borderGrey,
                      ),
                      Expanded(child: _buildCount('Active', activeCount)),
                      Container(
                        width: 1,
                        height: 42,
                        color: AppTheme.borderGrey,
                      ),
                      Expanded(child: _buildCount('Resolved', resolvedCount)),
                      Container(
                        width: 1,
                        height: 42,
                        color: AppTheme.borderGrey,
                      ),
                      Expanded(child: _buildCount('Closed', closedCount)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const AppText(
                  'Complaint register',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _buildSearchAndFilters(
                  documents.length,
                  visibleDocuments.length,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: visibleDocuments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                documents.isEmpty
                                    ? Icons.assignment_outlined
                                    : Icons.search_off_rounded,
                                color: AppTheme.textGrey,
                                size: 46,
                              ),
                              const SizedBox(height: 12),
                              AppText(
                                documents.isEmpty
                                    ? 'No complaints registered'
                                    : 'No matching complaints',
                                style: const TextStyle(
                                  color: AppTheme.textDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AppText(
                                documents.isEmpty
                                    ? 'Register the first complaint to begin tracking.'
                                    : 'Try changing your search or filters.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppTheme.textGrey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 15),
                              if (documents.isEmpty)
                                OutlinedButton.icon(
                                  onPressed: _openComplaintForm,
                                  icon: const Icon(Icons.add),
                                  label: const AppText(
                                    'Register first complaint',
                                  ),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: _clearFilters,
                                  icon: const Icon(Icons.filter_alt_off),
                                  label: const AppText('Clear filters'),
                                ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 82, top: 4),
                          itemCount: visibleDocuments.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 11),
                          itemBuilder: (context, index) {
                            return _buildComplaintCard(visibleDocuments[index]);
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
