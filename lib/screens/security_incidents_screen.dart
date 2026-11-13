import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class SecurityIncidentsScreen extends StatefulWidget {
  const SecurityIncidentsScreen({
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
  State<SecurityIncidentsScreen> createState() =>
      _SecurityIncidentsScreenState();
}

class _SecurityIncidentsScreenState extends State<SecurityIncidentsScreen> {
  static const List<String> _incidentCategories = [
    'Suspicious activity',
    'Accident or injury',
    'Property damage',
    'Fire or electrical hazard',
    'Noise or disturbance',
    'Other',
  ];

  static const List<String> _severities = ['low', 'medium', 'high', 'critical'];

  static const List<String> _itemCategories = [
    'Keys',
    'Wallet or ID',
    'Phone or electronics',
    'Clothing or accessories',
    'Pet',
    'Other',
  ];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _incidents => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('securityIncidents');

  CollectionReference<Map<String, dynamic>> get _items => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('lostFoundItems');

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _dateLabel(dynamic value) {
    final date = _asDate(value);
    if (date == null) return 'Date not available';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
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

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
      case 'high':
        return const Color(0xFF8A3030);
      case 'medium':
        return const Color(0xFF8A5A20);
      default:
        return AppTheme.secondaryNavy;
    }
  }

  Widget _pill(String label, {Color? color}) {
    final tone = color ?? AppTheme.secondaryNavy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: AppText(
        label.toUpperCase(),
        style: TextStyle(
          color: tone,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final tabs = widget.isAdmin
        ? [
            Tab(text: AppTranslations.translate('Incidents')),
            Tab(text: AppTranslations.translate('Lost & Found')),
            Tab(text: AppTranslations.translate('Claim Reviews')),
          ]
        : [
            Tab(text: AppTranslations.translate('My Reports')),
            Tab(text: AppTranslations.translate('Lost & Found')),
          ];

    final pages = widget.isAdmin
        ? [_buildIncidentsTab(), _buildLostFoundTab(), _buildClaimReviewsTab()]
        : [_buildIncidentsTab(), _buildLostFoundTab()];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          title: const AppText(
            'Security & Lost and Found',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppTheme.navyBlue,
            unselectedLabelColor: AppTheme.textGrey,
            indicatorColor: AppTheme.navyBlue,
            tabs: tabs,
          ),
        ),
        body: TabBarView(children: pages),
      ),
    );
  }

  Widget _buildIncidentsTab() {
    final uid = _uid;
    if (uid == null) {
      return _emptyState(
        'Session expired',
        'Sign in again to access incident reports.',
        Icons.lock_outline_rounded,
      );
    }

    final query = widget.isAdmin
        ? _incidents.snapshots()
        : _incidents.where('reportedByUid', isEqualTo: uid).snapshots();

    return Column(
      children: [
        if (!widget.isAdmin)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderGrey),
            ),
            child: const AppText(
              'For immediate danger, contact local emergency services or your colony security team directly. This report form is not an emergency response service.',
              style: TextStyle(
                color: AppTheme.textGrey,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showIncidentDialog,
              icon: const Icon(Icons.add_alert_outlined),
              label: AppText(
                widget.isAdmin ? 'Log an incident' : 'Report an incident',
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _emptyState(
                  'Unable to load reports',
                  'Check your connection or contact your Admin.',
                  Icons.error_outline_rounded,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aDate =
                      _asDate(a.data()['createdAt']) ?? DateTime(2000);
                  final bDate =
                      _asDate(b.data()['createdAt']) ?? DateTime(2000);
                  return bDate.compareTo(aDate);
                });
              if (docs.isEmpty) {
                return _emptyState(
                  widget.isAdmin ? 'No incidents recorded' : 'No reports yet',
                  widget.isAdmin
                      ? 'Resident and Admin incident reports will appear here.'
                      : 'Use Report an incident to document a safety or security issue.',
                  Icons.shield_outlined,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: docs.length,
                itemBuilder: (context, index) => _incidentCard(docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _incidentCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final severity = data['severity'] as String? ?? 'low';
    final status = data['status'] as String? ?? 'open';
    return Card(
      color: AppTheme.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppText(
                    data['title'] as String? ?? 'Untitled incident',
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _pill(_label(status)),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _pill(_label(severity), color: _severityColor(severity)),
                _pill(data['category'] as String? ?? 'Other'),
              ],
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
            const SizedBox(height: 10),
            _metaLine(
              Icons.place_outlined,
              data['location'] as String? ?? 'Location not provided',
            ),
            _metaLine(Icons.schedule_outlined, _dateLabel(data['occurredAt'])),
            if (widget.isAdmin) ...[
              _metaLine(
                Icons.person_outline_rounded,
                '${data['reportedByName'] ?? 'Unknown'} · ${data['reportedByRole'] ?? 'resident'}',
              ),
              if ((data['assignedTo'] as String? ?? '').isNotEmpty)
                _metaLine(
                  Icons.assignment_ind_outlined,
                  'Assigned to ${data['assignedTo']}',
                ),
              if ((data['adminNotes'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AppText(
                    'Admin notes: ${data['adminNotes']}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _editIncident(doc),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const AppText('Update report'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLostFoundTab() {
    final uid = _uid;
    if (uid == null) {
      return _emptyState(
        'Session expired',
        'Sign in again.',
        Icons.lock_outline_rounded,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showLostFoundDialog,
              icon: const Icon(Icons.add_box_outlined),
              label: const AppText('Report lost or found item'),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _items.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _emptyState(
                  'Unable to load items',
                  'Please try again.',
                  Icons.error_outline_rounded,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aDate =
                      _asDate(a.data()['createdAt']) ?? DateTime(2000);
                  final bDate =
                      _asDate(b.data()['createdAt']) ?? DateTime(2000);
                  return bDate.compareTo(aDate);
                });
              if (docs.isEmpty) {
                return _emptyState(
                  'No lost or found items',
                  'Reports submitted by colony members will appear here.',
                  Icons.search_off_rounded,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: docs.length,
                itemBuilder: (context, index) => _lostFoundCard(docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _lostFoundCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final itemType = data['itemType'] as String? ?? 'lost';
    final status = data['status'] as String? ?? 'open';
    final isClaimable =
        itemType == 'found' && status == 'open' && !widget.isAdmin;
    return Card(
      color: AppTheme.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
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
                Expanded(
                  child: AppText(
                    data['title'] as String? ?? 'Untitled item',
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _pill(itemType == 'found' ? 'Found item' : 'Lost item'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _pill(_label(status)),
                _pill(data['category'] as String? ?? 'Other'),
              ],
            ),
            const SizedBox(height: 9),
            AppText(
              data['description'] as String? ?? '',
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 9),
            _metaLine(
              Icons.place_outlined,
              data['location'] as String? ?? 'Location not provided',
            ),
            _metaLine(Icons.event_outlined, _dateLabel(data['itemDate'])),
            if (widget.isAdmin &&
                (data['adminNotes'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: AppText(
                  'Admin notes: ${data['adminNotes']}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(height: 9),
            if (widget.isAdmin)
              Row(
                children: [
                  if (itemType == 'found')
                    TextButton.icon(
                      onPressed: () => _showItemClaims(doc),
                      icon: const Icon(Icons.people_outline_rounded, size: 17),
                      label: const AppText('View claims'),
                    ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _editLostFoundItem(doc),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const AppText('Manage'),
                  ),
                ],
              )
            else if (isClaimable)
              _myClaimAction(doc),
          ],
        ),
      ),
    );
  }

  Widget _myClaimAction(QueryDocumentSnapshot<Map<String, dynamic>> item) {
    final uid = _uid;
    if (uid == null) return const SizedBox.shrink();
    final claimRef = item.reference.collection('claims').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: claimRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  'Unable to check your existing claim: ${snapshot.error}',
                  textAlign: TextAlign.end,
                ),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const AppText('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (!snapshot.data!.exists) {
          return Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _showClaimDialog(item),
              icon: const Icon(Icons.assignment_turned_in_outlined, size: 17),
              label: const AppText('I can identify this item'),
            ),
          );
        }
        final claim = snapshot.data!.data() ?? <String, dynamic>{};
        return Align(
          alignment: Alignment.centerRight,
          child: _pill(
            'Claim ${_label(claim['status'] as String? ?? 'pending')}',
          ),
        );
      },
    );
  }

  Widget _buildClaimReviewsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _items.where('itemType', isEqualTo: 'found').snapshots(),
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
                  const AppText('Unable to load claim queue.'),
                  AppText('${snapshot.error}', textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const AppText('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final foundItems = snapshot.data!.docs;
        if (foundItems.isEmpty) {
          return _emptyState(
            'No found items',
            'Claims will appear here when residents report found property.',
            Icons.inbox_outlined,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [for (final item in foundItems) _pendingClaimsCard(item)],
        );
      },
    );
  }

  Widget _pendingClaimsCard(QueryDocumentSnapshot<Map<String, dynamic>> item) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: item.reference
          .collection('claims')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            color: AppTheme.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AppText('Unable to load claim details: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        return Card(
          color: AppTheme.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderGrey),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  item.data()['title'] as String? ?? 'Found item',
                  style: const TextStyle(
                    color: AppTheme.navyBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                for (final claim in snapshot.data!.docs) _claimRow(item, claim),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _claimRow(
    QueryDocumentSnapshot<Map<String, dynamic>> item,
    QueryDocumentSnapshot<Map<String, dynamic>> claim,
  ) {
    final data = claim.data();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderGrey)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            data['claimantName'] as String? ?? 'Resident',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          if ((data['message'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AppText(
                data['message'] as String,
                style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _reviewClaim(item, claim, approve: true),
                child: const AppText('Approve claim'),
              ),
              TextButton(
                onPressed: () => _reviewClaim(item, claim, approve: false),
                child: const AppText('Reject claim'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.textGrey),
          const SizedBox(width: 7),
          Expanded(
            child: AppText(
              text,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
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
            Icon(icon, size: 44, color: AppTheme.textGrey),
            const SizedBox(height: 12),
            AppText(
              title,
              style: const TextStyle(
                color: AppTheme.navyBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showIncidentDialog() async {
    if (_uid == null) {
      _message('Please sign in again.');
      return;
    }
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    String category = _incidentCategories.first;
    String severity = 'medium';
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const AppText('Report an incident'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Title'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Category'),
                      ),
                      items: _incidentCategories
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: AppText(value),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => category = value);
                              }
                            },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: severity,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Severity'),
                      ),
                      items: _severities
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: AppText(_label(value)),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => severity = value);
                              }
                            },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: locationController,
                      maxLength: 160,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Location within colony',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      maxLength: 2000,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('What happened?'),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final description = descriptionController.text.trim();
                        final location = locationController.text.trim();
                        if (title.isEmpty ||
                            description.length < 10 ||
                            location.isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: AppText(
                                'Enter a title, location and at least 10 characters of detail.',
                              ),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await _incidents.add({
                            'reportedByUid': _uid,
                            'reportedByName': widget.currentUserName,
                            'reportedByRole': widget.isAdmin
                                ? 'admin'
                                : 'resident',
                            'reporterResidentId': widget.isAdmin
                                ? ''
                                : (widget.residentId ?? ''),
                            'category': category,
                            'severity': severity,
                            'title': title,
                            'description': description,
                            'location': location,
                            'occurredAt': FieldValue.serverTimestamp(),
                            'status': 'open',
                            'assignedTo': '',
                            'adminNotes': '',
                            'resolvedAt': null,
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _message('Incident report submitted.');
                        } on FirebaseException catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: AppText(
                                error.message ?? 'Unable to submit report.',
                              ),
                            ),
                          );
                        } catch (_) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: AppText(
                                'Unable to submit report. Please try again.',
                              ),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppText('Submit report'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      locationController.dispose();
    }
  }

  Future<void> _editIncident(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    String status = data['status'] as String? ?? 'open';
    final assignedController = TextEditingController(
      text: data['assignedTo'] as String? ?? '',
    );
    final notesController = TextEditingController(
      text: data['adminNotes'] as String? ?? '',
    );
    bool saving = false;
    const statuses = [
      'open',
      'investigating',
      'action_required',
      'resolved',
      'closed',
    ];
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const AppText('Update incident'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: statuses.contains(status) ? status : 'open',
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Status'),
                      ),
                      items: statuses
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: AppText(_label(value)),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => status = value);
                              }
                            },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: assignedController,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Assigned to (optional)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesController,
                      maxLength: 2000,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Admin notes'),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          await doc.reference.update({
                            'status': status,
                            'assignedTo': assignedController.text.trim(),
                            'adminNotes': notesController.text.trim(),
                            'resolvedAt': status == 'resolved'
                                ? FieldValue.serverTimestamp()
                                : null,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _message('Incident updated.');
                        } on FirebaseException catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: AppText(
                                error.message ?? 'Unable to update incident.',
                              ),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppText('Save changes'),
              ),
            ],
          ),
        ),
      );
    } finally {
      assignedController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _showLostFoundDialog() async {
    if (_uid == null) return;
    String itemType = 'lost';
    String category = _itemCategories.first;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    bool saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const AppText('Report lost or found property'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: itemType,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Report type'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'lost',
                          child: AppText('I lost this item'),
                        ),
                        DropdownMenuItem(
                          value: 'found',
                          child: AppText('I found this item'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => itemType = value);
                              }
                            },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Item name'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Category'),
                      ),
                      items: _itemCategories
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: AppText(value),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => category = value);
                              }
                            },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: locationController,
                      maxLength: 160,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Where was it lost or found?',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      maxLength: 1200,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Identifying details (avoid sensitive personal information)',
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final location = locationController.text.trim();
                        final description = descriptionController.text.trim();
                        if (title.isEmpty ||
                            location.isEmpty ||
                            description.length < 5) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: AppText(
                                'Enter the item, location and identifying details.',
                              ),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await _items.add({
                            'itemType': itemType,
                            'title': title,
                            'description': description,
                            'category': category,
                            'location': location,
                            'itemDate': FieldValue.serverTimestamp(),
                            'reportedByUid': _uid,
                            'status': 'open',
                            'adminNotes': '',
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _message('Lost and found report published.');
                        } on FirebaseException catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: AppText(
                                error.message ?? 'Unable to save item.',
                              ),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppText('Publish report'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      locationController.dispose();
    }
  }

  Future<void> _editLostFoundItem(
    QueryDocumentSnapshot<Map<String, dynamic>> item,
  ) async {
    final data = item.data();
    final itemType = data['itemType'] as String? ?? 'lost';
    String status = data['status'] as String? ?? 'open';
    final notesController = TextEditingController(
      text: data['adminNotes'] as String? ?? '',
    );
    final statuses = itemType == 'found'
        ? ['open', 'returned', 'closed']
        : ['open', 'closed'];
    bool saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const AppText('Manage lost and found item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: statuses.contains(status) ? status : 'open',
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Status'),
                  ),
                  items: statuses
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: AppText(_label(value)),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setDialogState(() => status = value);
                          }
                        },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Admin notes'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          await item.reference.update({
                            'status': status,
                            'adminNotes': notesController.text.trim(),
                            'closedAt': status == 'open'
                                ? null
                                : FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _message('Item status updated.');
                        } on FirebaseException catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: AppText(
                                error.message ?? 'Unable to update item.',
                              ),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppText('Save changes'),
              ),
            ],
          ),
        ),
      );
    } finally {
      notesController.dispose();
    }
  }

  Future<void> _showClaimDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> item,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    final messageController = TextEditingController();
    bool saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const AppText('Request to identify this item'),
            content: TextField(
              controller: messageController,
              maxLength: 1000,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: AppTranslations.translate(
                  'How can you identify it?',
                ),
                alignLabelWithHint: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final note = messageController.text.trim();
                        if (note.length < 5) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: AppText(
                                'Provide a few identifying details.',
                              ),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await item.reference
                              .collection('claims')
                              .doc(uid)
                              .set({
                                'claimantUid': uid,
                                'claimantResidentId': widget.residentId ?? '',
                                'claimantName': widget.currentUserName,
                                'message': note,
                                'status': 'pending',
                                'decisionNote': '',
                                'reviewedBy': '',
                                'reviewedAt': null,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _message('Claim request sent to Admin for review.');
                        } on FirebaseException catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: AppText(
                                error.message ?? 'Unable to submit claim.',
                              ),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppText('Submit claim'),
              ),
            ],
          ),
        ),
      );
    } finally {
      messageController.dispose();
    }
  }

  Future<void> _showItemClaims(
    QueryDocumentSnapshot<Map<String, dynamic>> item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('Claims · ${item.data()['title'] ?? 'Found item'}'),
        content: SizedBox(
          width: 520,
          height: 420,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: item.reference.collection('claims').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: AppText('Unable to load claims.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: AppText('No claim requests yet.'));
              }
              return ListView(
                children: snapshot.data!.docs.map((claim) {
                  final data = claim.data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: AppText(
                      data['claimantName'] as String? ?? 'Resident',
                    ),
                    subtitle: AppText(
                      '${data['message'] ?? ''}\nStatus: ${_label(data['status'] as String? ?? 'pending')}',
                    ),
                    isThreeLine: true,
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewClaim(
    QueryDocumentSnapshot<Map<String, dynamic>> item,
    QueryDocumentSnapshot<Map<String, dynamic>> claim, {
    required bool approve,
  }) async {
    final current = claim.data();
    if ((current['status'] as String? ?? '') != 'pending') return;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(claim.reference, {
      'status': approve ? 'approved' : 'rejected',
      'decisionNote': approve
          ? 'Claim approved by Admin.'
          : 'Claim rejected by Admin.',
      'reviewedBy': _uid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    if (approve) {
      batch.update(item.reference, {
        'status': 'returned',
        'adminNotes': 'Claim approved; item marked as returned.',
        'closedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    try {
      await batch.commit();
      _message(
        approve
            ? 'Claim approved and item marked returned.'
            : 'Claim rejected.',
      );
    } on FirebaseException catch (error) {
      _message(error.message ?? 'Unable to review claim.');
    }
  }
}
