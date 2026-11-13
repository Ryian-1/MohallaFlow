// MOHALLAFLOW_RESIDENT_DIRECTORY_COMMUNITY_FORUM
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.isAdmin,
    required this.currentUserName,
    this.residentId,
  });

  final String colonyId;
  final String colonyName;
  final bool isAdmin;
  final String currentUserName;
  final String? residentId;

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  CollectionReference<Map<String, dynamic>> get _profiles =>
      _colony.collection('communityDirectoryProfiles');
  CollectionReference<Map<String, dynamic>> get _posts =>
      _colony.collection('communityPosts');
  DocumentReference<Map<String, dynamic>> get _colony =>
      FirebaseFirestore.instance.collection('colonies').doc(widget.colonyId);
  final _displayName = TextEditingController();
  final _about = TextEditingController();
  final _interests = TextEditingController();
  Map<String, dynamic>? _residentMaster;
  Map<String, dynamic>? _myProfile;
  bool _profileBusy = true;
  bool _showLocation = false;
  bool _showPhone = false;
  bool _visible = false;
  bool _saving = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    if (!widget.isAdmin) {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _displayName.dispose();
    _about.dispose();
    _interests.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadProfile() async {
    final uid = _uid;
    final residentId = widget.residentId;
    if (uid == null || residentId == null || residentId.isEmpty) {
      if (mounted) {
        setState(() => _profileBusy = false);
      }
      return;
    }
    try {
      final results = await Future.wait([
        _colony.collection('residents').doc(residentId).get(),
        _profiles.doc(uid).get(),
      ]);
      final master = results[0].data();
      final profile = results[1].data();
      if (!mounted) {
        return;
      }
      setState(() {
        _residentMaster = master;
        _myProfile = profile;
        _displayName.text =
            profile?['displayName']?.toString() ??
            master?['fullName']?.toString() ??
            widget.currentUserName;
        _about.text = profile?['about']?.toString() ?? '';
        _interests.text = (profile?['interests'] is List)
            ? (profile?['interests'] as List).join(', ')
            : '';
        _showLocation = profile?['showLocation'] == true;
        _showPhone = profile?['showPhone'] == true;
        _visible = profile?['isVisible'] == true;
        _profileBusy = false;
      });
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => _profileBusy = false);
      }
      _message('Could not load your profile: ${e.message ?? e.code}');
    }
  }

  Future<void> _saveProfile() async {
    final uid = _uid;
    final master = _residentMaster;
    if (uid == null || master == null || widget.residentId == null || _saving) {
      _message(
        'Your linked resident record is unavailable. Contact the Admin.',
      );
      return;
    }
    final displayName = _displayName.text.trim();
    final about = _about.text.trim();
    final interests = _interests.text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .take(8)
        .toList();
    if (displayName.isEmpty || displayName.length > 80) {
      _message('Display name must be 1–80 characters.');
      return;
    }
    if (about.length > 240 || interests.any((v) => v.length > 32)) {
      _message(
        'About is limited to 240 characters; each interest is limited to 32.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final ref = _profiles.doc(uid);
      final current = await ref.get();
      final currentData = current.data();
      if (currentData?['moderationHidden'] == true && _visible) {
        _message(
          'Your directory profile is hidden by the Admin. Contact the Admin before publishing again.',
        );
        return;
      }
      final Object? consentTimestamp;
      if (!_visible) {
        consentTimestamp = null;
      } else if (currentData?['isVisible'] == true) {
        consentTimestamp = currentData?['consentAt'];
      } else {
        consentTimestamp = FieldValue.serverTimestamp();
      }
      final payload = <String, dynamic>{
        'residentUid': uid,
        'residentId': widget.residentId,
        'displayName': displayName,
        'showLocation': _showLocation,
        'blockId': _showLocation ? (master['blockId']?.toString() ?? '') : '',
        'houseNumber': _showLocation
            ? (master['houseNumber']?.toString() ?? '')
            : '',
        'showPhone': _showPhone,
        'phoneNumber': _showPhone
            ? (master['phoneNumber']?.toString() ?? '')
            : '',
        'about': about,
        'interests': interests,
        'isVisible': _visible,
        'consentAt': consentTimestamp,
        'moderationHidden': currentData?['moderationHidden'] == true,
        'moderatedBy': currentData?['moderatedBy'] ?? '',
        'moderatedAt': currentData?['moderatedAt'],
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!current.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      } else {
        payload['createdAt'] = currentData?['createdAt'];
      }
      await ref.set(payload);
      if (mounted) {
        final saved = await ref.get();
        setState(() => _myProfile = saved.data());
      }
      _message(
        _visible
            ? 'Your resident directory profile is published.'
            : 'Your directory profile is saved privately.',
      );
    } on FirebaseException catch (e) {
      _message('Profile could not be saved: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('Community profile save failed: $e');
      _message(
        'Profile could not be saved. Check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _createPost() async {
    if (_uid == null || widget.residentId == null || _saving) {
      return;
    }
    final title = TextEditingController();
    final body = TextEditingController();
    String category = 'General discussion';
    String? error;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const AppText('Start a colony discussion'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Category'),
                    ),
                    items:
                        [
                              'General discussion',
                              'Recommendations',
                              'Community help',
                              'Buy / sell / exchange',
                              'Local update',
                            ]
                            .map(
                              (v) =>
                                  DropdownMenuItem(value: v, child: AppText(v)),
                            )
                            .toList(),
                    onChanged: (v) => setDialog(() => category = v ?? category),
                  ),
                  TextField(
                    controller: title,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Title'),
                    ),
                  ),
                  TextField(
                    controller: body,
                    minLines: 3,
                    maxLines: 7,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Message'),
                    ),
                  ),
                  if (error != null)
                    AppText(
                      error!,
                      style: const TextStyle(
                        color: AppTheme.navyBlue,
                        fontSize: 12,
                      ),
                    ),
                  const AppText(
                    'Keep posts respectful. Do not publish private contact details, access codes, medical records or another resident’s personal information.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textGrey),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty || body.text.trim().length < 5) {
                  setDialog(
                    () => error =
                        'Add a title and a message of at least 5 characters.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const AppText('Publish'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      setState(() => _saving = true);
      try {
        await _posts.add({
          'authorUid': _uid,
          'authorName': widget.currentUserName,
          'residentId': widget.residentId,
          'category': category,
          'title': title.text.trim(),
          'body': body.text.trim(),
          'status': 'published',
          'moderationNote': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _message('Your discussion has been published.');
      } on FirebaseException catch (e) {
        _message('Post could not be published: ${e.message ?? e.code}');
      } finally {
        if (mounted) {
          setState(() => _saving = false);
        }
      }
    }
    title.dispose();
    body.dispose();
  }

  Future<void> _openComments(
    DocumentSnapshot<Map<String, dynamic>> post,
  ) async {
    final input = TextEditingController();
    final comments = post.reference.collection('comments');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: AppText(
                    'Discussion: ${post.data()?['title'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: comments
                        .where('status', isEqualTo: 'published')
                        .limit(100)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: AppText('Comments are unavailable.'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs.toList()
                        ..sort(
                          (a, b) =>
                              _asDate(a.data()['createdAt'])
                                  .compareTo(_asDate(b.data()['createdAt'])),
                        );
                      if (docs.isEmpty) {
                        return const Center(
                          child: AppText(
                            'No replies yet. Start the discussion.',
                          ),
                        );
                      }
                      return ListView(
                        children: docs.map((doc) {
                          final d = doc.data();
                          return ListTile(
                            title: AppText(
                              d['authorName']?.toString() ?? 'Resident',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: AppText(d['body']?.toString() ?? ''),
                            trailing: d['authorUid'] == _uid
                                ? IconButton(
                                    tooltip: AppTranslations.translate(
                                      'Remove my reply',
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await doc.reference.update({
                                        'status': 'deleted_by_author',
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                    },
                                  )
                                : null,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 3,
                          maxLength: 1000,
                          decoration: InputDecoration(
                            hintText: AppTranslations.translate(
                              'Write a respectful reply',
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final text = input.text.trim();
                          if (text.isEmpty || _uid == null) {
                            return;
                          }
                          try {
                            await comments.add({
                              'authorUid': _uid,
                              'authorName': widget.currentUserName,
                              'body': text,
                              'status': 'published',
                              'createdAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            input.clear();
                          } on FirebaseException catch (e) {
                            _message(
                              'Reply could not be added: ${e.message ?? e.code}',
                            );
                          }
                        },
                        icon: const Icon(Icons.send, color: AppTheme.navyBlue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    input.dispose();
  }

  Future<void> _reportPost(DocumentSnapshot<Map<String, dynamic>> post) async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    String reason = 'Inappropriate content';
    final details = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const AppText('Report discussion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                items:
                    [
                          'Inappropriate content',
                          'Harassment or bullying',
                          'Spam or misleading',
                          'Privacy or personal information',
                          'Other',
                        ]
                        .map(
                          (v) => DropdownMenuItem(value: v, child: AppText(v)),
                        )
                        .toList(),
                onChanged: (v) => setDialog(() => reason = v ?? reason),
              ),
              TextField(
                controller: details,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppTranslations.translate(
                    'Additional details (optional)',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const AppText('Submit report'),
            ),
          ],
        ),
      ),
    );
    if (submit == true) {
      try {
        await post.reference.collection('reports').doc(uid).set({
          'reporterUid': uid,
          'reporterName': widget.currentUserName,
          'reason': reason,
          'details': details.text.trim(),
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
          'reviewedBy': '',
          'reviewedAt': null,
          'moderatorNote': '',
        });
        _message('Report submitted to the Admin moderation queue.');
      } on FirebaseException catch (e) {
        _message(
          e.code == 'already-exists'
              ? 'You have already reported this discussion.'
              : 'Report could not be submitted: ${e.message ?? e.code}',
        );
      }
    }
    details.dispose();
  }

  DateTime _asDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _moderatePost(
    DocumentSnapshot<Map<String, dynamic>> post,
    String status,
  ) async {
    if (_uid == null) {
      return;
    }
    final note = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: AppText(
          '${status == 'published'
              ? 'Restore'
              : status == 'closed'
              ? 'Close'
              : 'Hide'} discussion',
        ),
        content: TextField(
          controller: note,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AppTranslations.translate('Moderation note (optional)'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const AppText('Confirm'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        batch.update(post.reference, {
          'status': status,
          'moderationNote': note.text.trim(),
          'moderatedBy': _uid,
          'moderatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        batch.set(post.reference.collection('moderationEvents').doc(), {
          'action': status,
          'actorUid': _uid,
          'actorName': widget.currentUserName,
          'note': note.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
        _message('Discussion moderation updated.');
      } on FirebaseException catch (e) {
        _message('Moderation failed: ${e.message ?? e.code}');
      }
    }
    note.dispose();
  }

  Future<void> _moderateProfile(
    DocumentSnapshot<Map<String, dynamic>> profile,
    bool hide,
  ) async {
    if (_uid == null) {
      return;
    }
    try {
      await profile.reference.update({
        'isVisible': false,
        'moderationHidden': hide,
        'moderatedBy': _uid,
        'moderatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(
        hide
            ? 'Directory profile hidden. The resident must contact Admin before republishing.'
            : 'Moderation restriction removed. The resident may choose to republish.',
      );
    } on FirebaseException catch (e) {
      _message('Directory moderation failed: ${e.message ?? e.code}');
    }
  }

  Future<void> _reviewReports(
    DocumentSnapshot<Map<String, dynamic>> post,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(c).size.height * .65,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: post.reference.collection('reports').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: AppText('Report queue unavailable.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: AppText('No reports for this discussion.'),
                );
              }
              return ListView(
                children: docs.map((doc) {
                  final d = doc.data();
                  final open = d['status'] == 'open';
                  return ListTile(
                    title: AppText(d['reason']?.toString() ?? 'Report'),
                    subtitle: AppText(
                      '${d['reporterName'] ?? d['reporterUid'] ?? 'Resident'} · ${d['details'] ?? ''}',
                    ),
                    trailing: open
                        ? PopupMenuButton<String>(
                            onSelected: (v) async {
                              try {
                                await doc.reference.update({
                                  'status': v,
                                  'reviewedBy': _uid,
                                  'reviewedAt': FieldValue.serverTimestamp(),
                                  'moderatorNote': v == 'dismissed'
                                      ? 'Reviewed by Admin.'
                                      : 'Action taken by Admin.',
                                });
                              } on FirebaseException catch (e) {
                                _message(
                                  'Could not update report: ${e.message ?? e.code}',
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'reviewed',
                                child: AppText('Mark reviewed'),
                              ),
                              PopupMenuItem(
                                value: 'dismissed',
                                child: AppText('Dismiss report'),
                              ),
                            ],
                          )
                        : AppText(d['status']?.toString() ?? ''),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _profileEditor() {
    if (_profileBusy) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_residentMaster == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AppText(
            'No linked resident record was found. Ask the Admin to verify your resident profile before using the directory.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final hidden = _myProfile?['moderationHidden'] == true;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppText(
          'Resident directory profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.navyBlue,
          ),
        ),
        const SizedBox(height: 5),
        const AppText(
          'Your profile is private until you explicitly publish it. Phone and house location are hidden unless you separately enable each option.',
          style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textGrey),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _displayName,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: AppTranslations.translate('Display name'),
          ),
        ),
        TextField(
          controller: _about,
          maxLength: 240,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AppTranslations.translate('About (optional)'),
            hintText: AppTranslations.translate('A short introduction'),
          ),
        ),
        TextField(
          controller: _interests,
          decoration: InputDecoration(
            labelText: AppTranslations.translate('Interests (comma-separated)'),
            hintText: AppTranslations.translate('Reading, sports, pets'),
          ),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _showLocation,
          onChanged: (v) => setState(() => _showLocation = v),
          activeThumbColor: AppTheme.navyBlue,
          title: const AppText('Show my block and house number'),
          subtitle: const AppText(
            'Uses the verified location on your resident record.',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _showPhone,
          onChanged: (v) => setState(() => _showPhone = v),
          activeThumbColor: AppTheme.navyBlue,
          title: const AppText('Share my mobile number'),
          subtitle: const AppText(
            'Only publish the number already held on your resident record.',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _visible,
          onChanged: hidden ? null : (v) => setState(() => _visible = v),
          activeThumbColor: AppTheme.navyBlue,
          title: const AppText('Publish my directory profile'),
          subtitle: AppText(
            hidden
                ? 'This profile is currently restricted by the Admin.'
                : 'Residents in this colony can find your published profile.',
          ),
        ),
        if (hidden)
          const AppText(
            'Your profile was hidden by the Admin after a moderation review. You cannot republish it until the restriction is removed.',
            style: TextStyle(fontSize: 12, color: AppTheme.navyBlue),
          ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving ? null : _saveProfile,
          icon: const Icon(Icons.save_outlined),
          label: AppText(_saving ? 'Saving…' : 'Save privacy settings'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.navyBlue,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (_myProfile != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AppText(
              'Last updated: ${_asDate(_myProfile?['updatedAt']).toLocal()}',
              style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
            ),
          ),
      ],
    );
  }

  Widget _directory({
    required bool admin,
  }) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: admin
        ? _profiles.limit(250).snapshots()
        : _profiles.where('isVisible', isEqualTo: true).limit(200).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: AppText(
            'Directory could not be loaded. Check Firestore access and connection.',
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs =
          snapshot.data!.docs.where((doc) {
            final d = doc.data();
            if (!admin && d['isVisible'] != true) {
              return false;
            }
            final text =
                '${d['displayName'] ?? ''} ${d['blockId'] ?? ''} ${d['houseNumber'] ?? ''} ${d['about'] ?? ''} ${(d['interests'] is List ? (d['interests'] as List).join(' ') : '')}';
            return text.toLowerCase().contains(_search.toLowerCase());
          }).toList()..sort(
            (a, b) => (a.data()['displayName'] ?? '').toString().compareTo(
              (b.data()['displayName'] ?? '').toString(),
            ),
          );
      if (docs.isEmpty) {
        return const Center(
          child: AppText('No published resident profiles found.'),
        );
      }
      return ListView.builder(
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          final d = doc.data();
          final visible = d['isVisible'] == true;
          final hidden = d['moderationHidden'] == true;
          return Card(
            color: AppTheme.white,
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.lightGrey,
                child: Icon(Icons.person_outline, color: AppTheme.navyBlue),
              ),
              title: AppText(
                d['displayName']?.toString() ?? 'Resident',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: AppText(
                [
                  if (d['showLocation'] == true)
                    '${d['blockId'] ?? ''} · ${d['houseNumber'] ?? ''}',
                  if (d['showPhone'] == true &&
                      (d['phoneNumber'] ?? '').toString().isNotEmpty)
                    d['phoneNumber'].toString(),
                  if ((d['about'] ?? '').toString().isNotEmpty)
                    d['about'].toString(),
                  if (d['interests'] is List)
                    (d['interests'] as List).join(' · '),
                  if (admin)
                    '${visible ? 'Published' : 'Private'}${hidden ? ' · Admin restricted' : ''}',
                ].join('\n'),
              ),
              trailing: admin
                  ? PopupMenuButton<String>(
                      onSelected: (v) => _moderateProfile(doc, v == 'hide'),
                      itemBuilder: (_) => [
                        if (!hidden)
                          const PopupMenuItem(
                            value: 'hide',
                            child: AppText('Hide profile'),
                          ),
                        if (hidden)
                          const PopupMenuItem(
                            value: 'restore',
                            child: AppText('Remove restriction'),
                          ),
                      ],
                    )
                  : null,
            ),
          );
        },
      );
    },
  );

  Widget _forum({required bool admin}) => Column(
    children: [
      if (!admin)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: AppTranslations.translate('Search discussions'),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _createPost,
                icon: const Icon(Icons.add),
                label: const AppText('Post'),
              ),
            ],
          ),
        ),
      if (admin)
        const Padding(
          padding: EdgeInsets.all(12),
          child: AppText(
            'Admin moderation queue: hide content, close discussions, restore posts and review resident reports.',
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
        ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: admin
              ? _posts.limit(200).snapshots()
              : _posts
                    .where('status', isEqualTo: 'published')
                    .limit(100)
                    .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: AppText('Community discussions are unavailable.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs =
                snapshot.data!.docs.where((doc) {
                  final d = doc.data();
                  if (!admin && d['status'] != 'published') {
                    return false;
                  }
                  final content =
                      '${d['title'] ?? ''} ${d['body'] ?? ''} ${d['category'] ?? ''}';
                  return content.toLowerCase().contains(
                        _search.toLowerCase(),
                      ) &&
                      (admin || d['status'] == 'published');
                }).toList()..sort(
                  (a, b) =>
                      _asDate(b.data()['createdAt'])
                          .compareTo(_asDate(a.data()['createdAt'])),
                );
            if (docs.isEmpty) {
              return const Center(
                child: AppText('No community discussions yet.'),
              );
            }
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final d = doc.data();
                final status = d['status']?.toString() ?? 'published';
                return Card(
                  color: AppTheme.white,
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                d['title']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                            ),
                            if (admin)
                              AppText(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textGrey,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          '${d['category'] ?? 'General discussion'} · ${d['authorName'] ?? 'Resident'} · ${_asDate(d['createdAt']).toLocal()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppText(
                          d['body']?.toString() ?? '',
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => _openComments(doc),
                              icon: const Icon(Icons.forum_outlined, size: 16),
                              label: const AppText('Replies'),
                            ),
                            if (!admin && d['authorUid'] != _uid)
                              TextButton.icon(
                                onPressed: () => _reportPost(doc),
                                icon: const Icon(Icons.flag_outlined, size: 16),
                                label: const AppText('Report'),
                              ),
                            if (!admin &&
                                d['authorUid'] == _uid &&
                                status == 'published')
                              TextButton.icon(
                                onPressed: () => doc.reference.update({
                                  'status': 'deleted_by_author',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                ),
                                label: const AppText('Remove my post'),
                              ),
                            if (admin)
                              TextButton.icon(
                                onPressed: () => _reviewReports(doc),
                                icon: const Icon(Icons.flag_outlined, size: 16),
                                label: const AppText('Reports'),
                              ),
                            if (admin && status == 'published')
                              TextButton(
                                onPressed: () => _moderatePost(doc, 'hidden'),
                                child: const AppText('Hide'),
                              ),
                            if (admin && status == 'published')
                              TextButton(
                                onPressed: () => _moderatePost(doc, 'closed'),
                                child: const AppText('Close'),
                              ),
                            if (admin && status != 'published')
                              TextButton(
                                onPressed: () =>
                                    _moderatePost(doc, 'published'),
                                child: const AppText('Restore'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  Widget _residentView() => DefaultTabController(
    length: 3,
    child: Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: AppText('Community Hub · ${widget.colonyName}'),
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: AppTranslations.translate('Directory')),
            Tab(text: AppTranslations.translate('Discussions')),
            Tab(text: AppTranslations.translate('My profile')),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: AppTranslations.translate('Find residents'),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              Expanded(child: _directory(admin: false)),
            ],
          ),
          _forum(admin: false),
          _profileEditor(),
        ],
      ),
    ),
  );

  Widget _adminView() => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: AppText('Community Hub · ${widget.colonyName}'),
        bottom: TabBar(
          tabs: [
            Tab(text: AppTranslations.translate('Directory moderation')),
            Tab(text: AppTranslations.translate('Forum moderation')),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: AppTranslations.translate(
                      'Search directory profiles',
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              Expanded(child: _directory(admin: true)),
            ],
          ),
          _forum(admin: true),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return widget.isAdmin ? _adminView() : _residentView();
  }
}
