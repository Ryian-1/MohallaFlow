import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../services/notification_service.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  CollectionReference<Map<String, dynamic>> get _announcements =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('announcements');

  CollectionReference<Map<String, dynamic>> _acknowledgements(
    String announcementId,
  ) => _announcements.doc(announcementId).collection('acknowledgements');

  String _acknowledgementDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().substring(0, 16);
    }
    return 'Time pending';
  }

  Widget _acknowledgementTracker(String announcementId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _acknowledgements(announcementId)
          .orderBy('acknowledgedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: AppText(
              'Acknowledgement data is unavailable.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        final receipts = snapshot.data!.docs;
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: const Icon(
            Icons.mark_email_read_outlined,
            color: AppTheme.navyBlue,
          ),
          title: AppText(
            'Resident acknowledgements (${receipts.length})',
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: const AppText(
            'Residents who confirmed this notice',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 10),
          ),
          children: receipts.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppText(
                        'No residents have acknowledged this notice yet.',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ]
              : receipts.map((receipt) {
                  final data = receipt.data();
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const CircleAvatar(
                      radius: 15,
                      backgroundColor: AppTheme.lightGrey,
                      child: Icon(
                        Icons.person_outline,
                        size: 17,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    title: AppText(
                      data['residentName'] as String? ?? 'Resident',
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: AppText(
                      'Resident ID: ${data['residentId'] ?? '—'} · ${_acknowledgementDate(data['acknowledgedAt'])}',
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 10,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.navyBlue,
                      size: 18,
                    ),
                  );
                }).toList(),
        );
      },
    );
  }

  static const List<String> _categories = [
    'General',
    'Maintenance',
    'Water Supply',
    'Security',
    'Events',
    'Emergency',
  ];

  static const List<String> _priorities = ['normal', 'important', 'urgent'];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
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
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.navyBlue,
              ),
            ),
            const SizedBox(height: 7),
            AppText(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ==========================================
  // CREATE ANNOUNCEMENT
  // ==========================================

  Future<void> _createAnnouncement() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    String category = 'General';
    String priority = 'normal';
    bool saving = false;
    bool saved = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> saveNotice(String status) async {
                final uid = _uid;
                final title = titleController.text.trim();
                final message = messageController.text.trim();

                if (uid == null) {
                  _message('Please sign in again.');
                  return;
                }

                if (title.isEmpty || message.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: AppText('Enter both notice title and message.'),
                    ),
                  );
                  return;
                }

                if (title.length > 120 || message.length > 3000) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: AppText(
                        'Title or message exceeds the allowed length.',
                      ),
                    ),
                  );
                  return;
                }

                setDialogState(() => saving = true);

                try {
                  final announcementRef = _announcements.doc();
                  final batch = FirebaseFirestore.instance.batch();
                  batch.set(announcementRef, {
                    'title': title,
                    'message': message,
                    'category': category,
                    'priority': priority,
                    'status': status,
                    'createdBy': uid,
                    'createdByName': widget.adminName,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                    'publishedAt': status == 'published'
                        ? FieldValue.serverTimestamp()
                        : null,
                    'archivedAt': null,
                  });
                  if (status == 'published') {
                    NotificationService.addAnnouncementPublished(
                      batch: batch,
                      colonyId: widget.colonyId,
                      announcementId: announcementRef.id,
                      title: title,
                      category: category,
                      createdBy: uid,
                    );
                  }
                  await batch.commit();

                  saved = true;

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                } on FirebaseException catch (error) {
                  setDialogState(() => saving = false);

                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: AppText(
                          'Unable to save notice: '
                          '${error.message ?? error.code}',
                        ),
                      ),
                    );
                  }
                } catch (error) {
                  setDialogState(() => saving = false);

                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: AppText('Unable to save notice: $error'),
                      ),
                    );
                  }
                }
              }

              return AlertDialog(
                title: const AppText('Create announcement'),
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
                              'Announcement title',
                            ),
                            hintText: AppTranslations.translate(
                              'Enter a clear notice title',
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
                        const SizedBox(height: 12),
                        TextField(
                          controller: messageController,
                          maxLines: 6,
                          maxLength: 3000,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Announcement message',
                            ),
                            hintText: AppTranslations.translate(
                              'Write the complete notice here...',
                            ),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const AppText(
                          'Save as a draft or publish immediately.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ],
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
                  OutlinedButton(
                    onPressed: saving ? null : () => saveNotice('draft'),
                    child: const AppText('Save draft'),
                  ),
                  ElevatedButton(
                    onPressed: saving ? null : () => saveNotice('published'),
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppText('Publish now'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved) {
        _message('Announcement saved successfully.');
      }
    } finally {
      titleController.dispose();
      messageController.dispose();
    }
  }

  // ==========================================
  // PUBLISH / ARCHIVE
  // ==========================================

  Future<void> _changeStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> notice,
    String newStatus,
  ) async {
    try {
      final uid = _uid;
      if (uid == null) {
        _message('Please sign in again.');
        return;
      }
      final batch = FirebaseFirestore.instance.batch();
      batch.update(notice.reference, {
        'status': newStatus,
        'publishedAt': newStatus == 'published'
            ? FieldValue.serverTimestamp()
            : notice.data()['publishedAt'],
        'archivedAt': newStatus == 'archived'
            ? FieldValue.serverTimestamp()
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (newStatus == 'published' && notice.data()['status'] != 'published') {
        NotificationService.addAnnouncementPublished(
          batch: batch,
          colonyId: widget.colonyId,
          announcementId: notice.id,
          title: notice.data()['title'] as String? ?? 'Colony update',
          category: notice.data()['category'] as String? ?? 'General',
          createdBy: uid,
        );
      }
      await batch.commit();

      _message('Announcement ${_label(newStatus)} successfully.');
    } on FirebaseException catch (error) {
      _message(
        'Unable to update announcement: '
        '${error.message ?? error.code}',
      );
    } catch (error) {
      _message('Unable to update announcement: $error');
    }
  }

  // ==========================================
  // ANNOUNCEMENT CARD
  // ==========================================

  Widget _noticeCard(QueryDocumentSnapshot<Map<String, dynamic>> notice) {
    final data = notice.data();

    final title = data['title'] as String? ?? 'Untitled notice';
    final message = data['message'] as String? ?? '';
    final category = data['category'] as String? ?? 'General';
    final priority = data['priority'] as String? ?? 'normal';
    final status = data['status'] as String? ?? 'draft';

    final createdAt = data['createdAt'];
    final publishedAt = data['publishedAt'];

    String formatDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate().toLocal().toString().substring(0, 16);
      }
      return 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
                    color: AppTheme.navyBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: AppTranslations.translate('Announcement actions'),
                onSelected: (value) {
                  _changeStatus(notice, value);
                },
                itemBuilder: (context) {
                  if (status == 'published') {
                    return const [
                      PopupMenuItem(
                        value: 'archived',
                        child: AppText('Archive announcement'),
                      ),
                    ];
                  }

                  if (status == 'draft') {
                    return const [
                      PopupMenuItem(
                        value: 'published',
                        child: AppText('Publish announcement'),
                      ),
                      PopupMenuItem(
                        value: 'archived',
                        child: AppText('Archive draft'),
                      ),
                    ];
                  }

                  return const [
                    PopupMenuItem(
                      value: 'published',
                      child: AppText('Republish announcement'),
                    ),
                  ];
                },
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_badge(category), _badge(priority), _badge(status)],
          ),
          const Divider(height: 24),
          AppText(
            message,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          AppText(
            'Created: ${formatDate(createdAt)}',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
          ),
          if (publishedAt is Timestamp) ...[
            const SizedBox(height: 4),
            AppText(
              'Published: ${formatDate(publishedAt)}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
            ),
          ],
          if (status != 'draft') ...[
            const Divider(height: 22),
            _acknowledgementTracker(notice.id),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // ANNOUNCEMENT LIST
  // ==========================================

  Widget _buildNoticeList(String status) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _announcements.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppText(
                'Unable to load announcements.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = (snapshot.data?.docs ?? []).where((document) {
          return document.data()['status'] == status;
        }).toList();

        if (documents.isEmpty) {
          if (status == 'published') {
            return _emptyState(
              'No published announcements',
              'Create and publish your first colony notice.',
              Icons.campaign_outlined,
            );
          }

          if (status == 'draft') {
            return _emptyState(
              'No saved drafts',
              'Save unfinished announcements here.',
              Icons.drafts_outlined,
            );
          }

          return _emptyState(
            'No archived notices',
            'Archived announcements will appear here.',
            Icons.archive_outlined,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          itemCount: documents.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _noticeCard(documents[index]),
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Notices & Announcements',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              AppText(
                widget.colonyName,
                style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: AppTranslations.translate('Create announcement'),
              onPressed: _createAnnouncement,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppTheme.navyBlue,
            unselectedLabelColor: AppTheme.textGrey,
            indicatorColor: AppTheme.navyBlue,
            tabs: [
              Tab(
                icon: Icon(Icons.campaign_outlined),
                text: AppTranslations.translate('Published'),
              ),
              Tab(
                icon: Icon(Icons.drafts_outlined),
                text: AppTranslations.translate('Drafts'),
              ),
              Tab(
                icon: Icon(Icons.archive_outlined),
                text: AppTranslations.translate('Archived'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildNoticeList('published'),
            _buildNoticeList('draft'),
            _buildNoticeList('archived'),
          ],
        ),
      ),
    );
  }
}
