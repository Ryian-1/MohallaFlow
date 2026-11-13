import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class EmergencyPreparednessScreen extends StatefulWidget {
  const EmergencyPreparednessScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.currentUserName,
    required this.isAdmin,
  });

  final String colonyId;
  final String colonyName;
  final String currentUserName;
  final bool isAdmin;

  @override
  State<EmergencyPreparednessScreen> createState() =>
      _EmergencyPreparednessScreenState();
}

class _EmergencyPreparednessScreenState
    extends State<EmergencyPreparednessScreen> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _records(String name) =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection(name);

  static const Map<String, String> _collections = {
    'contacts': 'emergencyContacts',
    'assembly': 'emergencyAssemblyPoints',
    'readiness': 'emergencyReadinessChecks',
    'command': 'emergencyCommandLogs',
    'drills': 'emergencyDrills',
  };

  String _titleFor(String kind) => switch (kind) {
    'contacts' => 'Emergency contacts',
    'assembly' => 'Assembly points',
    'readiness' => 'Readiness checklist',
    'command' => 'Incident command log',
    'drills' => 'Emergency drills',
    _ => 'Emergency preparedness',
  };

  String _emptyFor(String kind) => switch (kind) {
    'contacts' => 'No emergency contacts have been published.',
    'assembly' => 'No assembly points have been published.',
    'readiness' => 'No readiness checks have been recorded.',
    'command' => 'No command log entries have been recorded.',
    'drills' => 'No emergency drills have been scheduled.',
    _ => 'No records found.',
  };

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    return null;
  }

  String _dateLabel(dynamic value) {
    final date = _date(value);
    if (date == null) return 'Date not set';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  Query<Map<String, dynamic>> _queryFor(String kind) {
    Query<Map<String, dynamic>> query = _records(_collections[kind]!);
    if (!widget.isAdmin && (kind == 'contacts' || kind == 'assembly')) {
      query = query.where('isActive', isEqualTo: true);
    }
    if (!widget.isAdmin && kind == 'drills') {
      query = query.where('residentVisible', isEqualTo: true);
    }
    return query;
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final kinds = widget.isAdmin
        ? const ['contacts', 'assembly', 'readiness', 'command', 'drills']
        : const ['contacts', 'assembly', 'drills'];
    final tabs = kinds.map((kind) => Tab(text: _titleFor(kind))).toList();

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          title: const AppText(
            'Emergency Preparedness',
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
        body: Column(
          children: [
            if (!widget.isAdmin)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: const AppText(
                  'For immediate danger, contact verified local emergency services and colony security directly. MohallaFlow is a preparedness record, not an emergency dispatch service.',
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(children: kinds.map(_buildTab).toList()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String kind) {
    return Column(
      children: [
        if (widget.isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addRecord(kind),
                icon: const Icon(Icons.add_rounded),
                label: AppText('Add ${_titleFor(kind).toLowerCase()}'),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _queryFor(kind).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _emptyState(
                  'Unable to load ${_titleFor(kind).toLowerCase()}',
                  'Check your connection or contact your Colony Admin.',
                  Icons.error_outline_rounded,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aDate = _date(
                    a.data()['scheduledAt'] ??
                        a.data()['updatedAt'] ??
                        a.data()['createdAt'],
                  );
                  final bDate = _date(
                    b.data()['scheduledAt'] ??
                        b.data()['updatedAt'] ??
                        b.data()['createdAt'],
                  );
                  return (bDate ?? DateTime(2000)).compareTo(
                    aDate ?? DateTime(2000),
                  );
                });
              if (docs.isEmpty) {
                return _emptyState(
                  _titleFor(kind),
                  _emptyFor(kind),
                  Icons.shield_outlined,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                itemCount: docs.length,
                itemBuilder: (context, index) => _recordCard(kind, docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _recordCard(
    String kind,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final title = (data['name'] ?? data['title'] ?? 'Untitled').toString();
    final status =
        (data['status'] ?? ((data['isActive'] == true) ? 'active' : 'inactive'))
            .toString();
    final subtitle = switch (kind) {
      'contacts' =>
        [data['category'], data['phone'], data['location']]
            .where(
              (value) => value != null && value.toString().trim().isNotEmpty,
            )
            .join(' · '),
      'assembly' =>
        [
              data['location'],
              if (data['capacity'] != null) 'Capacity ${data['capacity']}',
            ]
            .where(
              (value) => value != null && value.toString().trim().isNotEmpty,
            )
            .join(' · '),
      'readiness' =>
        [data['category'], data['location'], data['assignedTo']]
            .where(
              (value) => value != null && value.toString().trim().isNotEmpty,
            )
            .join(' · '),
      'command' =>
        [data['severity'], data['location'], data['commandLead']]
            .where(
              (value) => value != null && value.toString().trim().isNotEmpty,
            )
            .join(' · '),
      'drills' =>
        [data['drillType'], _dateLabel(data['scheduledAt']), data['location']]
            .where(
              (value) => value != null && value.toString().trim().isNotEmpty,
            )
            .join(' · '),
      _ => '',
    };
    final detail = switch (kind) {
      'contacts' => data['instructions'] ?? '',
      'assembly' => data['instructions'] ?? data['accessNotes'] ?? '',
      'readiness' => data['notes'] ?? '',
      'command' => data['actionSummary'] ?? '',
      'drills' => data['notes'] ?? '',
      _ => '',
    };

    return Card(
      color: AppTheme.white,
      margin: const EdgeInsets.only(bottom: 11),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                _statusPill(status),
                if (widget.isAdmin)
                  PopupMenuButton<String>(
                    tooltip: AppTranslations.translate('Update status'),
                    onSelected: (value) => _changeStatus(kind, doc.id, value),
                    itemBuilder: (_) => _actionsFor(kind, data)
                        .map(
                          (entry) => PopupMenuItem<String>(
                            value: entry,
                            child: AppText(_humanize(entry)),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 5),
              AppText(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (detail.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 9),
              AppText(
                detail.toString(),
                style: const TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            if (kind == 'contacts' &&
                (data['alternatePhone'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AppText(
                  'Alternate: ${data['alternatePhone']}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ),
            if (kind == 'drills' &&
                (data['assemblyPoint'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AppText(
                  'Assembly point: ${data['assemblyPoint']}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ),
            if (kind == 'drills' && data['expectedParticipants'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AppText(
                  'Expected: ${data['expectedParticipants']} · Recorded: ${data['participantCount'] ?? 0}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ),
            if (kind == 'drills' &&
                (data['outcome'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: AppText(
                  'Outcome: ${data['outcome']}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ),
            if (kind == 'drills' &&
                (data['correctiveActions'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: AppText(
                  'Follow-up: ${data['correctiveActions']}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _actionsFor(String kind, Map<String, dynamic> data) {
    if (kind == 'contacts' || kind == 'assembly') {
      return data['isActive'] == true ? ['archive'] : ['activate'];
    }
    return switch (kind) {
      'readiness' => const ['ready', 'attention', 'not_ready'],
      'command' => const ['open', 'contained', 'resolved'],
      'drills' => const ['planned', 'completed', 'cancelled', 'record_outcome'],
      _ => const [],
    };
  }

  Future<void> _changeStatus(String kind, String id, String value) async {
    final uid = _uid;
    if (!widget.isAdmin || uid == null) return;
    if (kind == 'drills' && value == 'record_outcome') {
      await _recordDrillOutcome(id);
      return;
    }
    final update = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    };
    if (kind == 'contacts' || kind == 'assembly') {
      update['isActive'] = value == 'activate';
    } else {
      update['status'] = value;
      if (kind == 'command') {
        update['resolvedAt'] = value == 'resolved'
            ? FieldValue.serverTimestamp()
            : null;
      }
    }
    try {
      await _records(_collections[kind]!).doc(id).update(update);
      if (mounted) _message('${_titleFor(kind)} updated.');
    } catch (error) {
      if (mounted) _message('Unable to update record: $error');
    }
  }

  Future<void> _recordDrillOutcome(String id) async {
    final participants = TextEditingController();
    final outcome = TextEditingController();
    final corrective = TextEditingController();
    try {
      final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const AppText('Record drill outcome'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: participants,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Participants who attended',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: outcome,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Observations / outcome',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: corrective,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Corrective actions / owner / due date',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (outcome.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: AppText('Enter the drill observations.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'participants': participants.text.trim(),
                  'outcome': outcome.text.trim(),
                  'corrective': corrective.text.trim(),
                });
              },
              child: const AppText('Save outcome'),
            ),
          ],
        ),
      );
      if (values == null || !mounted) return;
      final uid = _uid;
      if (uid == null) return;
      await _records(_collections['drills']!).doc(id).update({
        'participantCount': int.tryParse(values['participants'] ?? '') ?? 0,
        'outcome': values['outcome'],
        'correctiveActions': values['corrective'],
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
      if (mounted) _message('Drill outcome saved.');
    } catch (error) {
      if (mounted) _message('Unable to save drill outcome: $error');
    } finally {
      participants.dispose();
      outcome.dispose();
      corrective.dispose();
    }
  }

  Future<void> _addRecord(String kind) async {
    if (!widget.isAdmin) return;
    final fields = _fieldsFor(kind);
    final controllers = {
      for (final field in fields)
        field.key: TextEditingController(text: field.initialValue),
    };
    try {
      final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) {
          String? validationMessage;
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: AppText('Add ${_titleFor(kind).toLowerCase()}'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final field in fields) ...[
                        TextField(
                          controller: controllers[field.key],
                          keyboardType: field.keyboardType,
                          maxLines: field.maxLines,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(field.label),
                            hintText: AppTranslations.translate(field.hint),
                          ),
                        ),
                        const SizedBox(height: 9),
                      ],
                      if (validationMessage != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppText(
                            validationMessage!,
                            style: const TextStyle(color: Color(0xFF8A3030)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const AppText('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final missing = fields.where(
                      (field) =>
                          field.isRequired &&
                          (controllers[field.key]?.text.trim().isEmpty ?? true),
                    );
                    if (missing.isNotEmpty) {
                      setDialogState(() {
                        validationMessage =
                            'Complete: ${missing.map((field) => field.label).join(', ')}.';
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, {
                      for (final field in fields)
                        field.key: controllers[field.key]!.text.trim(),
                    });
                  },
                  child: const AppText('Save record'),
                ),
              ],
            ),
          );
        },
      );
      if (values == null || !mounted) return;
      final uid = _uid;
      if (uid == null) {
        _message('Session expired. Sign in again.');
        return;
      }
      final payload = _payloadFor(kind, values, uid);
      await _records(_collections[kind]!).add(payload);
      if (mounted) _message('${_titleFor(kind)} added.');
    } catch (error) {
      if (mounted) _message('Unable to save record: $error');
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  List<_EmergencyField> _fieldsFor(String kind) => switch (kind) {
    'contacts' => const [
      _EmergencyField('name', 'Contact / service name', isRequired: true),
      _EmergencyField(
        'category',
        'Category',
        isRequired: true,
        hint: 'Police, fire, ambulance, hospital, security',
      ),
      _EmergencyField(
        'phone',
        'Primary phone',
        isRequired: true,
        keyboardType: TextInputType.phone,
      ),
      _EmergencyField(
        'alternatePhone',
        'Alternate phone',
        keyboardType: TextInputType.phone,
      ),
      _EmergencyField('location', 'Address / location'),
      _EmergencyField('instructions', 'Notes / instructions', maxLines: 3),
    ],
    'assembly' => const [
      _EmergencyField('name', 'Assembly point name', isRequired: true),
      _EmergencyField('location', 'Location / directions', isRequired: true),
      _EmergencyField(
        'capacity',
        'Approximate capacity',
        keyboardType: TextInputType.number,
        hint: 'Number of people',
      ),
      _EmergencyField('accessNotes', 'Accessibility notes'),
      _EmergencyField('instructions', 'Evacuation instructions', maxLines: 3),
    ],
    'readiness' => const [
      _EmergencyField('title', 'Resource / inspection item', isRequired: true),
      _EmergencyField(
        'category',
        'Category',
        isRequired: true,
        hint: 'Fire extinguisher, first aid, exit, alarm',
      ),
      _EmergencyField('location', 'Location', isRequired: true),
      _EmergencyField('assignedTo', 'Responsible person / vendor'),
      _EmergencyField('notes', 'Inspection notes', maxLines: 3),
    ],
    'command' => const [
      _EmergencyField('title', 'Incident title', isRequired: true),
      _EmergencyField('incidentType', 'Incident type', isRequired: true),
      _EmergencyField(
        'severity',
        'Severity',
        isRequired: true,
        hint: 'low, medium, high or critical',
      ),
      _EmergencyField('location', 'Location', isRequired: true),
      _EmergencyField('commandLead', 'Incident lead', isRequired: true),
      _EmergencyField('actionSummary', 'Actions / handover notes', maxLines: 4),
    ],
    'drills' => [
      const _EmergencyField('title', 'Drill name', isRequired: true),
      const _EmergencyField(
        'drillType',
        'Drill type',
        isRequired: true,
        hint: 'Fire, evacuation, earthquake, medical',
      ),
      _EmergencyField(
        'scheduledDate',
        'Scheduled date (YYYY-MM-DD)',
        isRequired: true,
        initialValue: DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String()
            .substring(0, 10),
      ),
      const _EmergencyField('location', 'Starting location', isRequired: true),
      const _EmergencyField('assemblyPoint', 'Assembly point'),
      const _EmergencyField(
        'expectedParticipants',
        'Expected participants',
        keyboardType: TextInputType.number,
      ),
      const _EmergencyField('notes', 'Briefing / drill notes', maxLines: 3),
    ],
    _ => const [],
  };

  Map<String, dynamic> _payloadFor(
    String kind,
    Map<String, String> values,
    String uid,
  ) {
    final common = <String, dynamic>{
      'createdBy': uid,
      'createdByName': widget.currentUserName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    };
    switch (kind) {
      case 'contacts':
        return {
          ...common,
          'name': values['name'],
          'category': values['category'],
          'phone': values['phone'],
          'alternatePhone': values['alternatePhone'] ?? '',
          'location': values['location'] ?? '',
          'instructions': values['instructions'] ?? '',
          'isActive': true,
        };
      case 'assembly':
        return {
          ...common,
          'name': values['name'],
          'location': values['location'],
          'capacity': int.tryParse(values['capacity'] ?? '') ?? 0,
          'accessNotes': values['accessNotes'] ?? '',
          'instructions': values['instructions'] ?? '',
          'isActive': true,
          'residentVisible': true,
        };
      case 'readiness':
        return {
          ...common,
          'title': values['title'],
          'category': values['category'],
          'location': values['location'],
          'assignedTo': values['assignedTo'] ?? '',
          'notes': values['notes'] ?? '',
          'status': 'attention',
        };
      case 'command':
        final severity = (values['severity'] ?? '').toLowerCase();
        if (!const ['low', 'medium', 'high', 'critical'].contains(severity)) {
          throw const FormatException(
            'Severity must be low, medium, high or critical.',
          );
        }
        return {
          ...common,
          'title': values['title'],
          'incidentType': values['incidentType'],
          'severity': severity,
          'location': values['location'],
          'commandLead': values['commandLead'],
          'actionSummary': values['actionSummary'] ?? '',
          'status': 'open',
          'resolvedAt': null,
        };
      case 'drills':
        final parsedDate = DateTime.tryParse(values['scheduledDate'] ?? '');
        if (parsedDate == null) {
          throw const FormatException('Use a valid YYYY-MM-DD drill date.');
        }
        return {
          ...common,
          'title': values['title'],
          'drillType': values['drillType'],
          'scheduledAt': Timestamp.fromDate(
            DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 9),
          ),
          'location': values['location'],
          'assemblyPoint': values['assemblyPoint'] ?? '',
          'expectedParticipants':
              int.tryParse(values['expectedParticipants'] ?? '') ?? 0,
          'participantCount': 0,
          'notes': values['notes'] ?? '',
          'outcome': '',
          'correctiveActions': '',
          'status': 'planned',
          'residentVisible': true,
        };
      default:
        throw ArgumentError('Unknown emergency record type: $kind');
    }
  }

  Widget _statusPill(String status) {
    final label = _humanize(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: AppText(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.secondaryNavy,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _humanize(String value) => value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  Widget _emptyState(String title, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppTheme.secondaryNavy),
            const SizedBox(height: 12),
            AppText(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.navyBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyField {
  const _EmergencyField(
    this.key,
    this.label, {
    this.isRequired = false,
    this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.initialValue = '',
  });

  final String key;
  final String label;
  final bool isRequired;
  final String? hint;
  final int maxLines;
  final TextInputType keyboardType;
  final String initialValue;
}
