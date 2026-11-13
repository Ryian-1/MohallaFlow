// MOHALLAFLOW_EMERGENCY_SOS_RAPID_RESPONSE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

enum EmergencyResponseMode { resident, admin, responder }

class EmergencyResponseScreen extends StatefulWidget {
  const EmergencyResponseScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.mode,
    required this.currentUserName,
    this.residentId,
  });

  final String colonyId;
  final String colonyName;
  final EmergencyResponseMode mode;
  final String currentUserName;
  final String? residentId;

  @override
  State<EmergencyResponseScreen> createState() =>
      _EmergencyResponseScreenState();
}

class _EmergencyResponseScreenState extends State<EmergencyResponseScreen> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  CollectionReference<Map<String, dynamic>> get _base => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('emergencyAlerts');
  CollectionReference<Map<String, dynamic>> get _responders => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('emergencyResponders');
  CollectionReference<Map<String, dynamic>> get _emergencyContacts =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('emergencyContacts');
  bool _busy = false;

  void _message(String value) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
    if (value is DateTime) {
      return value.toLocal();
    }
    return null;
  }

  String _dateLabel(dynamic value) {
    final date = _date(value);
    if (date == null) {
      return 'Time pending';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _status(String value) => value
      .split('_')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');

  Future<void> _raiseAlert() async {
    if (_uid == null ||
        widget.residentId == null ||
        widget.residentId!.isEmpty ||
        _busy) {
      _message(
        'Your resident profile could not be verified. Please contact the Admin.',
      );
      return;
    }
    final location = TextEditingController();
    final description = TextEditingController();
    final phone = TextEditingController();
    String category = 'Medical emergency';
    String severity = 'critical';
    String? validation;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const AppText(
            'Raise Emergency SOS',
            style: TextStyle(
              color: AppTheme.navyBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppText(
                    'Use this only for an active emergency. For immediate danger, call verified emergency services directly as well.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Emergency type'),
                    ),
                    items:
                        [
                              'Medical emergency',
                              'Fire / smoke',
                              'Security threat',
                              'Accident / injury',
                              'Lift / entrapment',
                              'Electrical / water hazard',
                              'Other',
                            ]
                            .map(
                              (v) =>
                                  DropdownMenuItem(value: v, child: AppText(v)),
                            )
                            .toList(),
                    onChanged: (v) => setDialog(() => category = v ?? category),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: severity,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Urgency'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'critical',
                        child: AppText('Critical — immediate danger'),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: AppText('High — urgent help needed'),
                      ),
                    ],
                    onChanged: (v) => setDialog(() => severity = v ?? severity),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: location,
                    maxLength: 160,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Exact location'),
                      hintText: AppTranslations.translate(
                        'Block, house, floor, lift or landmark',
                      ),
                    ),
                  ),
                  TextField(
                    controller: description,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'What is happening?',
                      ),
                      hintText: AppTranslations.translate(
                        'Include any immediate assistance needed',
                      ),
                    ),
                  ),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Callback number (optional)',
                      ),
                      hintText: AppTranslations.translate(
                        '10-digit mobile number',
                      ),
                    ),
                  ),
                  if (validation != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppText(
                        validation!,
                        style: const TextStyle(
                          color: AppTheme.navyBlue,
                          fontSize: 12,
                        ),
                      ),
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
                final loc = location.text.trim();
                final desc = description.text.trim();
                final tel = phone.text.trim();
                if (loc.isEmpty || desc.length < 8) {
                  setDialog(
                    () => validation = 'Enter the exact location and at least 8 characters describing the emergency.',
                  );
                  return;
                }
                if (tel.isNotEmpty &&
                    !RegExp(r'^[6-9][0-9]{9}$').hasMatch(tel)) {
                  setDialog(
                    () => validation = 'Enter a valid 10-digit Indian mobile number or leave it blank.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const AppText('Submit SOS'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      location.dispose();
      description.dispose();
      phone.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      final ref = _base.doc();
      final batch = FirebaseFirestore.instance.batch();
      batch.set(ref, {
        'createdByUid': _uid,
        'createdByName': widget.currentUserName,
        'residentId': widget.residentId,
        'category': category,
        'severity': severity,
        'location': location.text.trim(),
        'description': description.text.trim(),
        'contactPhone': phone.text.trim(),
        'status': 'open',
        'assignedResponderUid': '',
        'assignedResponderName': '',
        'acknowledgedAt': null,
        'arrivedAt': null,
        'resolvedAt': null,
        'resolutionSummary': '',
        'escalationLevel': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      });
      batch.set(ref.collection('events').doc('created'), {
        'action': 'created',
        'actorUid': _uid,
        'actorName': widget.currentUserName,
        'note': 'Emergency SOS submitted by resident.',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _message(
        'SOS recorded. Keep this screen open and contact emergency services directly if there is immediate danger.',
      );
    } on FirebaseException catch (error) {
      _message('SOS could not be submitted: ${error.message ?? error.code}');
    } catch (error) {
      _message(
        'SOS could not be submitted. Please call emergency services directly.',
      );
      debugPrint('Emergency SOS submission failed: $error');
    } finally {
      location.dispose();
      description.dispose();
      phone.dispose();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _changeStatus(
    DocumentSnapshot<Map<String, dynamic>> alert,
    String status, {
    String note = '',
  }) async {
    if (_uid == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final data = alert.data()!;
      final ref = alert.reference;
      final event = ref.collection('events').doc();
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      };
      if (status == 'acknowledged') {
        updates['acknowledgedAt'] = FieldValue.serverTimestamp();
        updates['assignedResponderUid'] = _uid;
        updates['assignedResponderName'] = widget.currentUserName;
      }
      if (status == 'on_scene') {
        updates['arrivedAt'] = FieldValue.serverTimestamp();
      }
      if (status == 'resolved') {
        updates['resolvedAt'] = FieldValue.serverTimestamp();
        updates['resolutionSummary'] = note.trim();
      }
      if (status == 'escalated') {
        updates['escalationLevel'] =
            ((data['escalationLevel'] as num?)?.toInt() ?? 0) + 1;
      }
      if (status == 'cancelled') {
        updates['cancelledAt'] = FieldValue.serverTimestamp();
      }
      final batch = FirebaseFirestore.instance.batch();
      batch.update(ref, updates);
      batch.set(event, {
        'action': status,
        'actorUid': _uid,
        'actorName': widget.currentUserName,
        'note': note.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _message('Emergency status updated: ${_status(status)}.');
    } on FirebaseException catch (error) {
      _message('Status update failed: ${error.message ?? error.code}');
    } catch (error) {
      debugPrint('Emergency status update failed: $error');
      _message('Status update failed. Refresh and try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _assignResponder(
    DocumentSnapshot<Map<String, dynamic>> alert,
  ) async {
    try {
      final team = await _responders.where('isActive', isEqualTo: true).get();
      if (!mounted) {
        return;
      }
      if (team.docs.isEmpty) {
        _message('Add an active responder first.');
        return;
      }
      final choice = await showDialog<DocumentSnapshot<Map<String, dynamic>>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const AppText('Assign responder'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: team.docs.map((doc) {
                final d = doc.data();
                return ListTile(
                  title: AppText(d['responderName']?.toString() ?? 'Responder'),
                  subtitle: AppText(d['responderUid']?.toString() ?? doc.id),
                  onTap: () => Navigator.pop(dialogContext, doc),
                );
              }).toList(),
            ),
          ),
        ),
      );
      if (choice == null || _uid == null) {
        return;
      }
      final d = choice.data();
      final batch = FirebaseFirestore.instance.batch();
      batch.update(alert.reference, {
        'assignedResponderUid': d?['responderUid'] ?? choice.id,
        'assignedResponderName': d?['responderName'] ?? 'Responder',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      });
      batch.set(alert.reference.collection('events').doc(), {
        'action': 'assigned',
        'actorUid': _uid,
        'actorName': widget.currentUserName,
        'note': 'Assigned to ${d?['responderName'] ?? choice.id}',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _message('Responder assigned.');
    } on FirebaseException catch (error) {
      _message('Could not assign responder: ${error.message ?? error.code}');
    }
  }

  Future<void> _addResponder() async {
    final uid = TextEditingController();
    final name = TextEditingController();
    final phone = TextEditingController();
    String? errorText;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const AppText('Add emergency responder'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppText(
                  'Use the Firebase UID of an existing MohallaFlow account. This does not create a new user or staff record.',
                  style: TextStyle(fontSize: 12),
                ),
                TextField(
                  controller: uid,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate(
                      'Existing account Firebase UID',
                    ),
                  ),
                ),
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate(
                      'Responder display name',
                    ),
                  ),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate(
                      'Contact number (optional)',
                    ),
                  ),
                ),
                if (errorText != null)
                  AppText(
                    errorText!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.navyBlue,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (uid.text.trim().length < 8 || name.text.trim().isEmpty) {
                  setDialog(
                    () => errorText =
                        'Enter a valid existing UID and responder name.',
                  );
                  return;
                }
                if (phone.text.trim().isNotEmpty &&
                    !RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone.text.trim())) {
                  setDialog(
                    () => errorText =
                        'Enter a valid 10-digit Indian mobile number.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const AppText('Save responder'),
            ),
          ],
        ),
      ),
    );
    if (save == true && _uid != null) {
      try {
        final ref = _responders.doc(uid.text.trim());
        final existing = await ref.get();
        if (existing.exists) {
          await ref.update({
            'responderName': name.text.trim(),
            'contactPhone': phone.text.trim(),
            'isActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await ref.set({
            'responderUid': uid.text.trim(),
            'responderName': name.text.trim(),
            'contactPhone': phone.text.trim(),
            'isActive': true,
            'assignedBy': _uid,
            'assignedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        _message(
          'Responder added. They can open Emergency Response from their Worker dashboard.',
        );
      } on FirebaseException catch (e) {
        _message('Could not add responder: ${e.message ?? e.code}');
      }
    }
    uid.dispose();
    name.dispose();
    phone.dispose();
  }

  Future<void> _toggleResponder(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool active,
  ) async {
    try {
      await doc.reference.update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(
        active ? 'Responder reactivated.' : 'Responder access disabled.',
      );
    } on FirebaseException catch (e) {
      _message('Could not update responder: ${e.message ?? e.code}');
    }
  }

  Future<void> _call(String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) {
      return;
    }
    try {
      final ok = await launchUrl(Uri(scheme: 'tel', path: clean));
      if (!ok) {
        _message('Unable to open the phone dialer.');
      }
    } catch (e) {
      _message('Unable to open the phone dialer.');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _alertStream() {
    if (widget.mode == EmergencyResponseMode.resident) {
      return _base.where('createdByUid', isEqualTo: _uid).limit(50).snapshots();
    }
    if (widget.mode == EmergencyResponseMode.admin) {
      return _base.limit(100).snapshots();
    }
    return _base
        .where('assignedResponderUid', isEqualTo: _uid)
        .limit(100)
        .snapshots();
  }

  Widget _statusChip(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.lightGrey,
      border: Border.all(color: AppTheme.borderGrey),
      borderRadius: BorderRadius.circular(20),
    ),
    child: AppText(
      _status(status).toUpperCase(),
      style: const TextStyle(
        color: AppTheme.navyBlue,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .3,
      ),
    ),
  );

  Widget _alertCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final status = d['status']?.toString() ?? 'open';
    final residentMode = widget.mode == EmergencyResponseMode.resident;
    final adminMode = widget.mode == EmergencyResponseMode.admin;
    return Card(
      color: AppTheme.white,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
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
              children: [
                Expanded(
                  child: AppText(
                    d['category']?.toString() ?? 'Emergency',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 7),
            AppText(
              '${d['severity'] ?? 'high'} urgency · ${_dateLabel(d['createdAt'])}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
            ),
            const SizedBox(height: 7),
            AppText(
              d['location']?.toString() ?? 'Location not supplied',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            AppText(
              d['description']?.toString() ?? '',
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 6),
            if (!residentMode)
              AppText(
                'Reported by ${d['createdByName'] ?? 'Resident'} · ${d['residentId'] ?? ''}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
              ),
            if ((d['assignedResponderName'] ?? '').toString().isNotEmpty)
              AppText(
                'Responder: ${d['assignedResponderName']}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if ((d['contactPhone'] ?? '').toString().isNotEmpty)
              TextButton.icon(
                onPressed: () => _call(d['contactPhone'].toString()),
                icon: const Icon(Icons.call_outlined),
                label: const AppText('Call resident'),
              ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showTimeline(doc),
                  icon: const Icon(Icons.history, size: 16),
                  label: const AppText('Timeline'),
                ),
                if (residentMode && status == 'open')
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _changeStatus(
                            doc,
                            'cancelled',
                            note: 'Cancelled by reporting resident.',
                          ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const AppText('Cancel SOS'),
                  ),
                if (!residentMode &&
                    (status == 'open' || status == 'escalated') &&
                    (adminMode || d['assignedResponderUid'] == _uid))
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _changeStatus(
                            doc,
                            'acknowledged',
                            note: 'Responder acknowledged.',
                          ),
                    icon: const Icon(Icons.done, size: 16),
                    label: const AppText('Acknowledge'),
                  ),
                if (!residentMode &&
                    (status == 'acknowledged' || status == 'escalated') &&
                    (adminMode || d['assignedResponderUid'] == _uid))
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _changeStatus(
                            doc,
                            'responding',
                            note: 'Responder is on the way.',
                          ),
                    icon: const Icon(Icons.directions_run, size: 16),
                    label: const AppText('En route'),
                  ),
                if (!residentMode &&
                    status == 'responding' &&
                    (adminMode || d['assignedResponderUid'] == _uid))
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _changeStatus(
                            doc,
                            'on_scene',
                            note: 'Responder arrived at the location.',
                          ),
                    icon: const Icon(Icons.location_on_outlined, size: 16),
                    label: const AppText('On scene'),
                  ),
                if (!residentMode &&
                    !['resolved', 'cancelled'].contains(status) &&
                    (adminMode || d['assignedResponderUid'] == _uid))
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _changeStatus(
                            doc,
                            'escalated',
                            note: 'Escalated for additional assistance.',
                          ),
                    icon: const Icon(Icons.warning_amber_outlined, size: 16),
                    label: const AppText('Escalate'),
                  ),
                if (!residentMode &&
                    !['resolved', 'cancelled'].contains(status) &&
                    (adminMode || d['assignedResponderUid'] == _uid))
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final note = TextEditingController();
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const AppText('Resolve emergency'),
                                content: TextField(
                                  controller: note,
                                  minLines: 2,
                                  maxLines: 4,
                                  maxLength: 600,
                                  decoration: InputDecoration(
                                    labelText: AppTranslations.translate(
                                      'Resolution / handover summary',
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const AppText('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      if (note.text.trim().length < 5) {
                                        return;
                                      }
                                      Navigator.pop(c, true);
                                    },
                                    child: const AppText('Resolve'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await _changeStatus(
                                doc,
                                'resolved',
                                note: note.text.trim(),
                              );
                            }
                            note.dispose();
                          },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const AppText('Resolve'),
                  ),
                if (adminMode && !['resolved', 'cancelled'].contains(status))
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _assignResponder(doc),
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const AppText('Assign'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _alerts({required bool residentMode, required bool responderMode}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _alertStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppText(
                'Unable to load emergency alerts. Check the Firestore rules and connection.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList();
        docs.sort(
          (a, b) => (_date(b.data()['createdAt']) ?? DateTime(1970)).compareTo(
            _date(a.data()['createdAt']) ?? DateTime(1970),
          ),
        );
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AppText(
                residentMode
                    ? 'No SOS reports submitted from this account.'
                    : responderMode
                    ? 'No alerts are currently assigned to you.'
                    : 'No emergency alerts have been recorded.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textGrey),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: docs.length,
          itemBuilder: (context, index) => _alertCard(docs[index]),
        );
      },
    );
  }

  Widget _contactsWidget() =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _emergencyContacts
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const AppText('Emergency contacts are unavailable.');
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const AppText(
              'No verified emergency contacts are published. Ask the Admin to maintain this list.',
            );
          }
          return Column(
            children: snapshot.data!.docs.map((doc) {
              final d = doc.data();
              final number = d['phone']?.toString() ?? '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.local_phone_outlined,
                  color: AppTheme.navyBlue,
                ),
                title: AppText(d['name']?.toString() ?? 'Contact'),
                subtitle: AppText(
                  '${d['category'] ?? 'Emergency contact'} · $number',
                ),
                trailing: IconButton(
                  onPressed: number.isEmpty ? null : () => _call(number),
                  icon: const Icon(Icons.call, color: AppTheme.navyBlue),
                ),
              );
            }).toList(),
          );
        },
      );

  Widget _residentView() => Scaffold(
    backgroundColor: AppTheme.lightGrey,
    appBar: AppBar(title: const AppText('Emergency SOS & Response')),
    body: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          color: AppTheme.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Need immediate help?',
                  style: TextStyle(
                    color: AppTheme.navyBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const AppText(
                  'Raise an alert for the colony response team. Keep the app open to follow status updates. For immediate danger, contact verified emergency services directly.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _raiseAlert,
                    icon: const Icon(Icons.sos),
                    label: AppText(
                      _busy ? 'Submitting…' : 'RAISE EMERGENCY SOS',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyBlue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const AppText(
          'Verified colony emergency contacts',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.navyBlue,
          ),
        ),
        _contactsWidget(),
        const SizedBox(height: 12),
        const AppText(
          'My SOS reports',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.navyBlue,
          ),
        ),
        _alerts(residentMode: true, responderMode: false),
      ],
    ),
  );

  Widget _responderList() {
    final uid = _uid;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid == null ? null : _responders.doc(uid).snapshots(),
      builder: (context, assignment) {
        if (assignment.hasError) {
          return const Center(
            child: AppText('Responder access could not be verified.'),
          );
        }
        if (!assignment.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!assignment.data!.exists ||
            assignment.data!.data()?['isActive'] != true) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: AppText(
                'You are not currently assigned as an emergency responder. Contact the Colony Admin.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return _alerts(residentMode: false, responderMode: true);
      },
    );
  }

  Widget _team() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(
              child: AppText(
                'Assigned responders',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navyBlue,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _addResponder,
              icon: const Icon(Icons.person_add_alt_1),
              label: const AppText('Add responder'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _responders.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: AppText('Unable to load the responder roster.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs.toList()
              ..sort(
                (a, b) => (a.data()['responderName'] ?? '')
                    .toString()
                    .compareTo((b.data()['responderName'] ?? '').toString()),
              );
            if (docs.isEmpty) {
              return const Center(
                child: AppText(
                  'No responders assigned yet. Add an existing Worker account by Firebase UID.',
                ),
              );
            }
            return ListView(
              children: docs.map((doc) {
                final d = doc.data();
                final active = d['isActive'] == true;
                return ListTile(
                  title: AppText(d['responderName']?.toString() ?? 'Responder'),
                  subtitle: AppText(
                    '${doc.id} · ${active ? 'Active' : 'Disabled'}${(d['contactPhone'] ?? '').toString().isEmpty ? '' : ' · ${d['contactPhone']}'}',
                  ),
                  trailing: Switch(
                    value: active,
                    onChanged: (v) => _toggleResponder(doc, v),
                    activeThumbColor: AppTheme.navyBlue,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    ],
  );

  Future<void> _showTimeline(
    DocumentSnapshot<Map<String, dynamic>> alert,
  ) async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .65,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: AppText(
                  'Emergency response timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyBlue,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: alert.reference.collection('events').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: AppText('Timeline unavailable.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs.toList()
                      ..sort(
                        (a, b) =>
                            (_date(a.data()['createdAt']) ?? DateTime(1970))
                                .compareTo(
                                  _date(b.data()['createdAt']) ??
                                      DateTime(1970),
                                ),
                      );
                    return ListView(
                      children: docs.map((doc) {
                        final d = doc.data();
                        return ListTile(
                          leading: const Icon(
                            Icons.history,
                            color: AppTheme.navyBlue,
                          ),
                          title: AppText(
                            _status(d['action']?.toString() ?? 'updated'),
                          ),
                          subtitle: AppText(
                            '${d['actorName'] ?? 'User'} · ${_dateLabel(d['createdAt'])}\n${d['note'] ?? ''}',
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminView() => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: const AppText('Emergency Response Control'),
        bottom: TabBar(
          tabs: [
            Tab(text: AppTranslations.translate('Live alerts')),
            Tab(text: AppTranslations.translate('Response team')),
          ],
        ),
      ),
      body: TabBarView(
        children: [_alerts(residentMode: false, responderMode: false), _team()],
      ),
    ),
  );

  Widget _responderView() => Scaffold(
    backgroundColor: AppTheme.lightGrey,
    appBar: AppBar(title: const AppText('My Emergency Response')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: AppText(
            'Only alerts assigned to your account appear here. Update status as you acknowledge, travel to and reach the incident.',
            style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
          ),
        ),
        Expanded(child: _responderList()),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    switch (widget.mode) {
      case EmergencyResponseMode.resident:
        return _residentView();
      case EmergencyResponseMode.admin:
        return _adminView();
      case EmergencyResponseMode.responder:
        return _responderView();
    }
  }
}
