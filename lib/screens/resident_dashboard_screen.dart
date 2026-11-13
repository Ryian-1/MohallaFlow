import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/push_notification_service.dart';

import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../models/user_role.dart';
import 'splash_screen.dart';
import 'visitor_management_screen.dart';
import 'document_repository_screen.dart';
import 'resident_self_service_screen.dart';
import 'maintenance_dues_screen.dart';
import 'recurring_maintenance_billing_screen.dart';
import 'community_events_polls_screen.dart';
import 'community_hub_screen.dart';
import 'move_in_out_screen.dart';
import 'resident_lease_screen.dart';
import 'security_incidents_screen.dart';
import 'emergency_preparedness_screen.dart';
import 'emergency_response_screen.dart';
import 'amenity_bookings_screen.dart';
import 'rwa_committee_workspace_screen.dart';
import 'housekeeping_screen.dart';
import '../widgets/colony_switch_action.dart';
import '../widgets/notification_bell.dart';
import '../widgets/app_text.dart';
import '../widgets/brand_logo.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';
import '../widgets/app_language_toggle.dart';

class ResidentDashboardScreen extends StatefulWidget {
  const ResidentDashboardScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.residentId,
    required this.residentName,
    required this.onSignOut,
  });

  final String colonyId;
  final String colonyName;
  final String residentId;
  final String residentName;
  final Future<void> Function() onSignOut;

  @override
  State<ResidentDashboardScreen> createState() =>
      _ResidentDashboardScreenState();
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen> {
  int _selectedIndex = 0;
  bool _signingOut = false;
  final Set<String> _acknowledgingNoticeIds = <String>{};

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

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> get _resident => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('residents')
      .doc(widget.residentId);

  CollectionReference<Map<String, dynamic>> get _announcements =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('announcements');

  CollectionReference<Map<String, dynamic>> get _complaints => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('complaints');

  CollectionReference<Map<String, dynamic>> get _housekeepingRequests =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('housekeepingRequests');

  CollectionReference<Map<String, dynamic>> get _maintenanceBills =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('maintenanceBills');

  static const List<String> _categories = [
    'Garbage collection',
    'Street cleaning',
    'Lift',
    'Plumbing',
    'Electricity',
    'Water supply',
    'Security',
    'Common area',
    'Other',
  ];

  static const List<String> _priorities = ['low', 'normal', 'high', 'urgent'];

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(text)));
  }

  String _label(String value) {
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().substring(0, 16);
    }
    return 'Date pending';
  }

  String _complaintType(String category) {
    if (category == 'Garbage collection' || category == 'Street cleaning') {
      return 'cleanliness';
    }

    if (category == 'Lift' ||
        category == 'Plumbing' ||
        category == 'Electricity' ||
        category == 'Water supply') {
      return 'maintenance';
    }

    return 'other';
  }

  // =====================================================
  // SIGN OUT
  // =====================================================

  void _navigateToSplashAfterSignOut() {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  Future<void> _signOut() async {
    if (_signingOut) return;

    setState(() => _signingOut = true);

    try {
      // The callback signs out Firebase. Its navigation may use an old
      // LoginScreen context that has already been unmounted.
      await PushNotificationService.unregisterCurrentDevice();

      await widget.onSignOut();

      if (!mounted) return;

      // Complete navigation from this screen if the account is signed out.
      if (FirebaseAuth.instance.currentUser == null) {
        _navigateToSplashAfterSignOut();
      } else {
        setState(() => _signingOut = false);
        _message('Sign-out did not complete. Please try again.');
      }
    } catch (error) {
      if (!mounted) return;

      // Firebase sign-out may already have succeeded before stale-context
      // navigation throws. Do not report that as a sign-out failure.
      if (FirebaseAuth.instance.currentUser == null) {
        _navigateToSplashAfterSignOut();
        return;
      }

      setState(() => _signingOut = false);
      _message('Unable to sign out: $error');
    }
  }

  // =====================================================
  // REUSABLE UI
  // =====================================================

  Widget _heading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(height: 5),
          AppText(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String title, String description, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppTheme.textGrey),
            const SizedBox(height: 14),
            AppText(
              title,
              style: const TextStyle(
                color: AppTheme.navyBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            AppText(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: AppText(
        _label(value).toUpperCase(),
        style: const TextStyle(
          color: AppTheme.navyBlue,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: AppTheme.cardBorderRadius,
          border: Border.all(color: AppTheme.borderGrey),
          boxShadow: AppTheme.quietCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.secondaryNavy, size: 25),
            const SizedBox(height: 12),
            AppText(
              title,
              style: const TextStyle(
                color: AppTheme.navyBlue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // SUBMIT COMPLAINT
  // =====================================================

  Future<void> _showComplaintDialog() async {
    final uid = _uid;

    if (uid == null) {
      _message('Please sign in again.');
      return;
    }

    DocumentSnapshot<Map<String, dynamic>> residentSnapshot;

    try {
      residentSnapshot = await _resident.get();
    } on FirebaseException catch (error) {
      _message(
        'Unable to load your resident profile: '
        '${error.message ?? error.code}',
      );
      return;
    }

    if (!mounted) return;

    if (!residentSnapshot.exists) {
      _message('Your resident record was not found. Contact your Admin.');
      return;
    }

    final residentData = residentSnapshot.data()!;

    if (residentData['residentStatus'] != 'active') {
      _message('Your resident profile is inactive.');
      return;
    }

    final name = residentData['fullName'] as String? ?? widget.residentName;

    String phone = residentData['phoneNumber'] as String? ?? '';
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.length > 10) {
      phone = phone.substring(phone.length - 10);
    }

    final block = residentData['blockId'] as String? ?? '';
    final house = residentData['houseNumber'] as String? ?? '';

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController(
      text: [
        if (block.isNotEmpty) 'Block $block',
        if (house.isNotEmpty) 'House $house',
      ].join(' · '),
    );

    String category = 'Other';
    String priority = 'normal';
    bool saving = false;
    bool saved = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const AppText('Submit a complaint'),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: titleController,
                          maxLength: 120,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Complaint title',
                            ),
                            hintText: AppTranslations.translate(
                              'Briefly describe the issue',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Category'),
                          ),
                          items: _categories.map((value) {
                            return DropdownMenuItem(
                              value: value,
                              child: AppText(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => category = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: locationController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Location'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          maxLength: 2000,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Describe the complaint',
                            ),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Priority'),
                          ),
                          items: _priorities.map((value) {
                            return DropdownMenuItem(
                              value: value,
                              child: AppText(_label(value)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => priority = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const AppText('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            final description = descriptionController.text
                                .trim();
                            final location = locationController.text.trim();

                            if (title.isEmpty ||
                                description.length < 10 ||
                                location.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: AppText(
                                    'Enter a title, location and '
                                    'description of at least 10 characters.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() => saving = true);

                            try {
                              final complaintType = _complaintType(category);
                              final complaintReference = _complaints.doc();
                              final batch = FirebaseFirestore.instance.batch();

                              batch.set(complaintReference, {
                                'title': title,
                                'description': description,
                                'category': category,
                                'complaintType': complaintType,
                                'location': location,
                                'reportedByName': name,
                                'reportedByPhone': phone,
                                'submittedBy': uid,
                                'submittedByName': name,
                                'priority': priority,
                                'status': 'submitted',
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              NotificationService.addResidentComplaintSubmitted(
                                batch: batch,
                                colonyId: widget.colonyId,
                                complaintId: complaintReference.id,
                                residentName: name,
                                category: category,
                                location: location,
                                complaintType: complaintType,
                                createdBy: uid,
                              );

                              await batch.commit();

                              saved = true;

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                            } on FirebaseException catch (error) {
                              setDialogState(() => saving = false);

                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                      SnackBar(
                                        content: AppText(
                                          'Complaint submission failed: '
                                          '${error.message ?? error.code}',
                                        ),
                                      ),
                                    );
                              }
                            } catch (error) {
                              setDialogState(() => saving = false);

                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                      SnackBar(
                                        content: AppText(
                                          'Unable to submit complaint: $error',
                                        ),
                                      ),
                                    );
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppText('Submit complaint'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved && mounted) {
        setState(() => _selectedIndex = 2);
        _message('Your complaint has been submitted successfully.');
      }
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      locationController.dispose();
    }
  }

  // =====================================================
  // ANNOUNCEMENT CARD
  // =====================================================

  Future<void> _acknowledgeNotice(String announcementId) async {
    final uid = _uid;
    if (uid == null) {
      _message('Your session has expired. Please sign in again.');
      return;
    }

    final lockKey = '$announcementId:$uid';
    if (_acknowledgingNoticeIds.contains(lockKey)) return;
    setState(() => _acknowledgingNoticeIds.add(lockKey));

    try {
      final receipt = _announcements
          .doc(announcementId)
          .collection('acknowledgements')
          .doc(uid);
      await receipt.set({
        'acknowledgedBy': uid,
        'residentId': widget.residentId,
        'residentName': widget.residentName,
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });
      _message('Notice acknowledged successfully.');
    } on FirebaseException catch (error) {
      _message('Unable to acknowledge notice: ${error.message ?? error.code}');
    } catch (error) {
      _message('Unable to acknowledge notice: $error');
    } finally {
      if (mounted) {
        setState(() => _acknowledgingNoticeIds.remove(lockKey));
      }
    }
  }

  Widget _noticeAcknowledgementStatus(String announcementId) {
    final uid = _uid;
    if (uid == null) return const SizedBox.shrink();

    final lockKey = '$announcementId:$uid';
    final receipt = _announcements
        .doc(announcementId)
        .collection('acknowledgements')
        .doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: receipt.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const AppText(
            'Acknowledgement status unavailable.',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 10),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        if (snapshot.data!.exists) {
          final acknowledgedAt = snapshot.data!.data()?['acknowledgedAt'];
          final date = acknowledgedAt is Timestamp
              ? acknowledgedAt.toDate().toLocal().toString().substring(0, 16)
              : 'just now';
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderGrey),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.navyBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    'You acknowledged this notice · $date',
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final busy = _acknowledgingNoticeIds.contains(lockKey);
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => _acknowledgeNotice(announcementId),
              icon: busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mark_email_read_outlined, size: 17),
              label: const AppText('Acknowledge notice'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.navyBlue,
                side: const BorderSide(color: AppTheme.borderGrey),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _noticeCard(QueryDocumentSnapshot<Map<String, dynamic>> notice) {
    final data = notice.data();

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
          AppText(
            data['title'] as String? ?? 'Announcement',
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _badge(data['category'] as String? ?? 'General'),
              _badge(data['priority'] as String? ?? 'normal'),
            ],
          ),
          const Divider(height: 22),
          AppText(
            data['message'] as String? ?? '',
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          AppText(
            'Published: ${_formatDate(data['publishedAt'])}',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
          ),
          _noticeAcknowledgementStatus(notice.id),
        ],
      ),
    );
  }

  // =====================================================
  // COMPLAINT CARD
  // =====================================================

  Widget _complaintCard(QueryDocumentSnapshot<Map<String, dynamic>> complaint) {
    final data = complaint.data();

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
          AppText(
            data['title'] as String? ?? 'Complaint',
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          AppText(
            '${data['category'] ?? 'Other'} · ${data['location'] ?? ''}',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
          const SizedBox(height: 10),
          AppText(
            data['description'] as String? ?? '',
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(data['status'] as String? ?? 'submitted'),
              _badge('Priority: ${data['priority'] ?? 'normal'}'),
            ],
          ),
          const SizedBox(height: 9),
          AppText(
            'Submitted: ${_formatDate(data['createdAt'])}',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // PUBLISHED NOTICES
  // =====================================================

  Widget _noticeList({int? limit}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _announcements
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppText(
                'Unable to load notices.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = (snapshot.data?.docs ?? []).toList();

        documents.sort((a, b) {
          final aDate = a.data()['publishedAt'];
          final bDate = b.data()['publishedAt'];

          final aMillis = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
          final bMillis = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;

          return bMillis.compareTo(aMillis);
        });

        final visible = limit == null
            ? documents
            : documents.take(limit).toList();

        if (visible.isEmpty) {
          return _emptyState(
            'No announcements yet',
            'Published colony notices will appear here.',
            Icons.campaign_outlined,
          );
        }

        return ListView.separated(
          shrinkWrap: limit != null,
          physics: limit != null
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: visible.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _noticeCard(visible[index]),
        );
      },
    );
  }

  // =====================================================
  // MY COMPLAINTS
  // =====================================================

  Widget _complaintList() {
    final uid = _uid;

    if (uid == null) {
      return _emptyState(
        'Session expired',
        'Please sign in again.',
        Icons.lock_outline,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _complaints.where('submittedBy', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppText(
                'Unable to load your complaints.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = (snapshot.data?.docs ?? []).toList();

        documents.sort((a, b) {
          final aDate = a.data()['createdAt'];
          final bDate = b.data()['createdAt'];

          final aMillis = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
          final bMillis = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;

          return bMillis.compareTo(aMillis);
        });

        if (documents.isEmpty) {
          return _emptyState(
            'No complaints submitted',
            'Your submitted complaints will appear here.',
            Icons.assignment_outlined,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _complaintCard(documents[index]),
        );
      },
    );
  }

  // =====================================================
  // PROFILE
  // =====================================================

  Widget _profileTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _resident.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppText(
                'Unable to load resident profile.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _emptyState(
            'Resident profile not found',
            'Contact your Colony Admin to verify your registration.',
            Icons.person_outline,
          );
        }

        final data = snapshot.data!.data()!;

        final fields = <String, String>{
          'Full name': data['fullName']?.toString() ?? '',
          'Phone number': data['phoneNumber']?.toString() ?? '',
          'Email': data['email']?.toString() ?? '',
          'Block': data['blockId']?.toString() ?? '',
          'House number': data['houseNumber']?.toString() ?? '',
          'Relationship': data['relationshipToHead']?.toString() ?? '',
          'Resident status': data['residentStatus']?.toString() ?? '',
          'Household ID': data['householdId']?.toString() ?? '',
        };

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _heading('My profile', 'Your registered colony information.'),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: Column(
                children: fields.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: AppText(
                            entry.key,
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: AppText(
                            entry.value.isEmpty ? 'Not provided' : entry.value,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: AppTheme.navyBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // HOME
  // =====================================================

  void _openResidentSelfService() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResidentSelfServiceScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          isAdmin: false,
          residentId: widget.residentId,
          residentName: widget.residentName,
        ),
      ),
    );
  }

  void _openDocumentRepository() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentRepositoryScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          isAdmin: false,
          isResident: true,
          roleKey: 'resident',
          residentId: widget.residentId,
          residentName: widget.residentName,
        ),
      ),
    );
  }

  void _openVisitorManagement() {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitorManagementScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          isAdmin: false,
          residentId: widget.residentId,
          residentName: widget.residentName,
        ),
      ),
    );
  }

  void _openRecurringBillingStatement() {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecurringMaintenanceBillingScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          isAdmin: false,
          residentId: widget.residentId,
          residentName: widget.residentName,
        ),
      ),
    );
  }

  void _openMaintenanceDues() {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MaintenanceDuesScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          isAdmin: false,
          residentId: widget.residentId,
          residentName: widget.residentName,
        ),
      ),
    );
  }

  void _openHousekeepingRequests() {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HousekeepingScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          mode: HousekeepingMode.resident,
          residentId: widget.residentId,
          residentName: widget.residentName,
        ),
      ),
    );
  }

  void _openCommunityHub() {
    if (FirebaseAuth.instance.currentUser == null) {
      _message('Please sign in again.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityHubScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          isAdmin: false,
          currentUserName: widget.residentName,
          residentId: widget.residentId,
        ),
      ),
    );
  }

  void _openCommunityEventsPolls() {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityEventsPollsScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          isAdmin: false,
          residentName: widget.residentName,
        ),
      ),
    );
  }

  void _openAmenityBookings() {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AmenityBookingsScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          isAdmin: false,
          residentId: widget.residentId,
          residentName: widget.residentName,
        ),
      ),
    );
  }

  // MOHALLAFLOW RESIDENT MY LEASE V1
  void _openMyLease() {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResidentLeaseScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          residentId: widget.residentId,
          residentName: widget.residentName,
        ),
      ),
    );
  }

  void _openMoveInOut() {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }
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

  void _openEmergencyResponse() {
    if (FirebaseAuth.instance.currentUser == null) {
      _message('Please sign in again.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmergencyResponseScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          mode: EmergencyResponseMode.resident,
          currentUserName: widget.residentName,
          residentId: widget.residentId,
        ),
      ),
    );
  }

  void _openEmergencyPreparedness() {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmergencyPreparednessScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          currentUserName: widget.residentName,
          isAdmin: false,
        ),
      ),
    );
  }

  void _openSecurityIncidents() {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SecurityIncidentsScreen(
          colonyId: widget.colonyId,
          colonyName: widget.colonyName,
          isAdmin: false,
          currentUserName: widget.residentName,
          residentId: widget.residentId,
        ),
      ),
    );
  }

  // =====================================================
  // RESIDENT COMMUNITY OVERVIEW
  // =====================================================

  Widget _overviewCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.navyBlue, size: 25),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AppText(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 105),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: AppText(
                  value,
                  style: const TextStyle(
                    color: AppTheme.navyBlue,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppTheme.textGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _complaintOverviewCard() {
    final uid = _uid;

    if (uid == null) {
      return _overviewCard(
        icon: Icons.assignment_outlined,
        title: 'Open complaints',
        value: '—',
        subtitle: 'Please sign in again.',
        onTap: () => setState(() => _selectedIndex = 2),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _complaints.where('submittedBy', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return _overviewCard(
            icon: Icons.assignment_outlined,
            title: 'Open complaints',
            value: snapshot.hasError ? '—' : '...',
            subtitle: snapshot.hasError
                ? 'Unable to load complaints.'
                : 'Loading complaints...',
            onTap: () => setState(() => _selectedIndex = 2),
          );
        }

        final documents = snapshot.data!.docs;

        final openCount = documents.where((doc) {
          return [
            'submitted',
            'acknowledged',
            'in_progress',
          ].contains(doc.data()['status']);
        }).length;

        final resolvedCount = documents.where((doc) {
          final status = doc.data()['status'];
          return status == 'resolved' || status == 'closed';
        }).length;

        return _overviewCard(
          icon: Icons.assignment_outlined,
          title: 'Open complaints',
          value: '$openCount',
          subtitle: '$resolvedCount resolved · ${documents.length} total',
          onTap: () => setState(() => _selectedIndex = 2),
        );
      },
    );
  }

  Widget _housekeepingOverviewCard() {
    final uid = _uid;

    if (uid == null) {
      return _overviewCard(
        icon: Icons.cleaning_services_outlined,
        title: 'Active housekeeping',
        value: '—',
        subtitle: 'Please sign in again.',
        onTap: _openHousekeepingRequests,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _housekeepingRequests
          .where('requestedBy', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return _overviewCard(
            icon: Icons.cleaning_services_outlined,
            title: 'Active housekeeping',
            value: snapshot.hasError ? '—' : '...',
            subtitle: snapshot.hasError
                ? 'Unable to load requests.'
                : 'Loading requests...',
            onTap: _openHousekeepingRequests,
          );
        }

        final documents = snapshot.data!.docs;

        final activeCount = documents.where((doc) {
          return [
            'submitted',
            'assigned',
            'in_progress',
          ].contains(doc.data()['status']);
        }).length;

        final completedCount = documents
            .where((doc) => doc.data()['status'] == 'completed')
            .length;

        return _overviewCard(
          icon: Icons.cleaning_services_outlined,
          title: 'Active housekeeping',
          value: '$activeCount',
          subtitle: '$completedCount completed · ${documents.length} total',
          onTap: _openHousekeepingRequests,
        );
      },
    );
  }

  Widget _maintenanceOverviewCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _resident.snapshots(),
      builder: (context, residentSnapshot) {
        if (residentSnapshot.hasError || !residentSnapshot.hasData) {
          return _overviewCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Outstanding dues',
            value: residentSnapshot.hasError ? '—' : '...',
            subtitle: 'Unable to load household information.',
            onTap: _openMaintenanceDues,
          );
        }

        final residentData = residentSnapshot.data!.data();

        if (residentData == null ||
            residentData['residentStatus'] != 'active') {
          return _overviewCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Outstanding dues',
            value: '—',
            subtitle: 'Active resident profile required.',
            onTap: _openMaintenanceDues,
          );
        }

        final householdId = residentData['householdId'] as String? ?? '';

        if (householdId.isEmpty) {
          return _overviewCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Outstanding dues',
            value: '—',
            subtitle: 'No household linked to your profile.',
            onTap: _openMaintenanceDues,
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _maintenanceBills
              .where('householdId', isEqualTo: householdId)
              .snapshots(),
          builder: (context, billSnapshot) {
            if (billSnapshot.hasError || !billSnapshot.hasData) {
              return _overviewCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Outstanding dues',
                value: billSnapshot.hasError ? '—' : '...',
                subtitle: 'Unable to load maintenance bills.',
                onTap: _openMaintenanceDues,
              );
            }

            final bills = billSnapshot.data!.docs;
            num outstanding = 0;

            for (final bill in bills) {
              final data = bill.data();
              final total = data['totalAmount'];
              final paid = data['amountPaid'];

              if (total is! num) continue;

              final paidAmount = paid is num ? paid : 0;
              final remaining = total - paidAmount;

              if (remaining > 0) {
                outstanding += remaining;
              }
            }

            final unpaidCount = bills.where((bill) {
              final status = bill.data()['status'];
              return status == 'unpaid' || status == 'partially_paid';
            }).length;

            return _overviewCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Outstanding dues',
              value: '₹${outstanding.toStringAsFixed(0)}',
              subtitle:
                  '$unpaidCount unpaid or part-paid · ${bills.length} bills',
              onTap: _openMaintenanceDues,
            );
          },
        );
      },
    );
  }

  Widget _committeeWorkspaceAccessCard() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const SizedBox.shrink();

    final grantRef = FirebaseFirestore.instance
        .collection('colonies')
        .doc(widget.colonyId)
        .collection('rwaCommitteePermissions')
        .doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: grantRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final grant = snapshot.data?.data();
        if (grant == null || grant['status'] != 'active') {
          return const SizedBox.shrink();
        }
        final startsAt = grant['startsAt'] is Timestamp
            ? (grant['startsAt'] as Timestamp).toDate()
            : null;
        final expiresAt = grant['expiresAt'] is Timestamp
            ? (grant['expiresAt'] as Timestamp).toDate()
            : null;
        final now = DateTime.now();
        if (startsAt == null ||
            expiresAt == null ||
            now.isBefore(startsAt) ||
            !now.isBefore(expiresAt)) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderGrey),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppTheme.lightGrey,
                child: Icon(
                  Icons.account_balance_outlined,
                  color: AppTheme.navyBlue,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'Committee workspace',
                      style: TextStyle(
                        color: AppTheme.navyBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AppText(
                      '${grant['committeePosition'] ?? 'Committee member'} · delegated access is active',
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RwaCommitteeWorkspaceScreen(
                        colonyId: widget.colonyId,
                        colonyName: widget.colonyName,
                        memberName: widget.residentName,
                      ),
                    ),
                  );
                },
                child: const AppText('Open'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _communityOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'My community overview',
          style: TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const AppText(
          'Live updates on your complaints, services and household dues.',
          style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
        ),
        const SizedBox(height: 13),
        _complaintOverviewCard(),
        const SizedBox(height: 11),
        _housekeepingOverviewCard(),
        const SizedBox(height: 11),
        _maintenanceOverviewCard(),
      ],
    );
  }

  Widget _residentSectionHeading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 21,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.45,
            ),
          ),
          const SizedBox(height: 5),
          AppText(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _residentServiceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.white,
      borderRadius: AppTheme.cardBorderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.cardBorderRadius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 138),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: AppTheme.cardBorderRadius,
            border: Border.all(color: AppTheme.borderGrey),
            boxShadow: AppTheme.quietCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.softNavy,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppTheme.navyBlue, size: 21),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    color: AppTheme.textGrey,
                    size: 17,
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AppText(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _residentServiceGrid(List<Widget> tiles) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 980
            ? 4
            : width >= 640
            ? 3
            : 2;
        const gap = 12.0;
        final tileWidth = (width - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tiles
              .map((tile) => SizedBox(width: tileWidth, child: tile))
              .toList(),
        );
      },
    );
  }

  Widget _homeTab() {
    return LayoutBuilder(
      builder: (context, _) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(25, 26, 25, 25),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: AppTheme.pageBorderRadius,
                    boxShadow: AppTheme.quietCardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'YOUR COMMUNITY',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.7,
                        ),
                      ),
                      const SizedBox(height: 13),
                      AppText(
                        'Welcome back, ${widget.residentName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 27,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        widget.colonyName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _committeeWorkspaceAccessCard(),
                const SizedBox(height: 22),
                _residentSectionHeading(
                  'Quick actions',
                  'The things residents use most, always within reach.',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _quickAction(
                        icon: Icons.add_comment_outlined,
                        title: 'New complaint',
                        onTap: _showComplaintDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickAction(
                        icon: Icons.assignment_outlined,
                        title: 'My complaints',
                        onTap: () => setState(() => _selectedIndex = 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                const SizedBox(height: 26),
                _residentSectionHeading(
                  'Home & account',
                  'Manage the practical details of living in your colony.',
                ),
                _residentServiceGrid([
                  _residentServiceTile(
                    icon: Icons.directions_walk_outlined,
                    title: 'Visitors',
                    subtitle: 'Guest access and visitor records',
                    onTap: _openVisitorManagement,
                  ),
                  _residentServiceTile(
                    icon: Icons.key_outlined,
                    title: 'My lease',
                    subtitle: 'Lease details and renewals',
                    onTap: _openMyLease,
                  ),
                  _residentServiceTile(
                    icon: Icons.manage_accounts_outlined,
                    title: 'My household',
                    subtitle: 'Profile, household and requests',
                    onTap: _openResidentSelfService,
                  ),
                  _residentServiceTile(
                    icon: Icons.folder_copy_outlined,
                    title: 'Documents',
                    subtitle: 'Colony documents and my uploads',
                    onTap: _openDocumentRepository,
                  ),
                  _residentServiceTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Maintenance bills',
                    subtitle: 'Bills, dues and payment records',
                    onTap: _openMaintenanceDues,
                  ),
                  _residentServiceTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Account statement',
                    subtitle: 'Statements and outstanding balances',
                    onTap: _openRecurringBillingStatement,
                  ),
                  _residentServiceTile(
                    icon: Icons.cleaning_services_outlined,
                    title: 'Housekeeping',
                    subtitle: 'Request and follow household help',
                    onTap: _openHousekeepingRequests,
                  ),
                  _residentServiceTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'Move in / move out',
                    subtitle: 'Submit and track relocation requests',
                    onTap: _openMoveInOut,
                  ),
                ]),
                const SizedBox(height: 27),
                _residentSectionHeading(
                  'Safety & support',
                  'Important tools for when you need assistance.',
                ),
                _residentServiceGrid([
                  _residentServiceTile(
                    icon: Icons.sos,
                    title: 'Emergency SOS',
                    subtitle: 'Request urgent assistance',
                    onTap: _openEmergencyResponse,
                  ),
                  _residentServiceTile(
                    icon: Icons.shield_outlined,
                    title: 'Security incidents',
                    subtitle: 'Report incidents and lost property',
                    onTap: _openSecurityIncidents,
                  ),
                  _residentServiceTile(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Emergency contacts',
                    subtitle: 'Contacts and assembly points',
                    onTap: _openEmergencyPreparedness,
                  ),
                ]),
                const SizedBox(height: 27),
                _residentSectionHeading(
                  'Community',
                  'Stay involved and make the most of shared spaces.',
                ),
                _residentServiceGrid([
                  _residentServiceTile(
                    icon: Icons.poll_outlined,
                    title: 'Events & polls',
                    subtitle: 'Community events and resident polls',
                    onTap: _openCommunityEventsPolls,
                  ),
                  _residentServiceTile(
                    icon: Icons.groups_outlined,
                    title: 'Community hub',
                    subtitle: 'Resident directory and discussion forum',
                    onTap: _openCommunityHub,
                  ),
                  _residentServiceTile(
                    icon: Icons.event_available_outlined,
                    title: 'Book facilities',
                    subtitle: 'Reserve shared colony amenities',
                    onTap: _openAmenityBookings,
                  ),
                ]),
                const SizedBox(height: 28),
                _communityOverview(),
                const SizedBox(height: 28),
                _residentSectionHeading(
                  'Community updates',
                  'The latest announcements from your colony.',
                ),
                _noticeList(limit: 3),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // MAIN BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final pages = [_homeTab(), _noticeList(), _complaintList(), _profileTab()];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandLogo(width: 140, height: 31),
            AppText(
              widget.colonyName,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
            ),
          ],
        ),
        actions: [
          const AppLanguageToggle(),
          ColonySwitchAction(
            currentColonyId: widget.colonyId,
            currentColonyName: widget.colonyName,
            currentRole: UserRole.resident,
          ),
          NotificationBell(
            colonyId: widget.colonyId,
            colonyName: widget.colonyName,
            roleKey: 'resident',
          ),
          IconButton(
            tooltip: AppTranslations.translate('Manage visitors'),
            onPressed: _openVisitorManagement,
            icon: const Icon(Icons.directions_walk_outlined),
          ),
          IconButton(
            tooltip: AppTranslations.translate('Submit complaint'),
            onPressed: _showComplaintDialog,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: AppTranslations.translate('Sign out'),
            onPressed: _signingOut ? null : _signOut,
            icon: _signingOut
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: AppTranslations.translate('Home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: AppTranslations.translate('Notices'),
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: AppTranslations.translate('Complaints'),
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: AppTranslations.translate('Profile'),
          ),
        ],
      ),
    );
  }
}
