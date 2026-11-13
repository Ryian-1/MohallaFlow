import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class CommunityEventsPollsScreen extends StatefulWidget {
  const CommunityEventsPollsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.isAdmin,
    this.adminName,
    this.residentName,
  });

  final String colonyId;
  final String colonyName;
  final bool isAdmin;
  final String? adminName;
  final String? residentName;

  @override
  State<CommunityEventsPollsScreen> createState() =>
      _CommunityEventsPollsScreenState();
}

class _CommunityEventsPollsScreenState extends State<CommunityEventsPollsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _events => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('communityEvents');

  CollectionReference<Map<String, dynamic>> get _polls => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('communityPolls');

  CollectionReference<Map<String, dynamic>> _rsvps(String eventId) =>
      _events.doc(eventId).collection('rsvps');

  CollectionReference<Map<String, dynamic>> _votes(String pollId) =>
      _polls.doc(pollId).collection('votes');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  DateTime _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _dateLabel(DateTime value) =>
      '${_two(value.day)}/${_two(value.month)}/${value.year}';

  String _timeLabel(DateTime value) =>
      '${_two(value.hour)}:${_two(value.minute)}';

  String _dateTimeLabel(DateTime value) =>
      '${_dateLabel(value)} at ${_timeLabel(value)}';

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
      case 'attending':
        return const Color(0xFF246B8E);
      case 'draft':
      case 'pending':
        return const Color(0xFF996515);
      case 'cancelled':
      case 'closed':
      case 'not_attending':
        return const Color(0xFFB54747);
      default:
        return AppTheme.textGrey;
    }
  }

  Widget _statusPill(String value) {
    final label = value.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor(value).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText(
        label.toUpperCase(),
        style: TextStyle(
          color: _statusColor(value),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }

  // =====================================================
  // ADMIN: EVENT CREATION AND EDITING
  // =====================================================

  Future<void> _editEvent({
    String? eventId,
    Map<String, dynamic>? existing,
  }) async {
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    final venueController = TextEditingController(
      text: existing?['venue']?.toString() ?? '',
    );
    DateTime startsAt = existing == null
        ? DateTime.now().add(const Duration(days: 1))
        : _asDate(existing['startsAt']);
    DateTime endsAt = existing == null
        ? DateTime.now().add(const Duration(days: 1, hours: 2))
        : _asDate(existing['endsAt']);
    String status = existing?['status']?.toString() == 'published'
        ? 'published'
        : 'draft';
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    Future<DateTime?> pickDateTime(DateTime current) async {
      final date = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 1095)),
      );
      if (date == null || !mounted) return null;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: AppText(
              eventId == null
                  ? 'Create community event'
                  : 'Edit community event',
              style: const TextStyle(
                color: AppTheme.navyBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate('Event title *'),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? AppTranslations.translate('Enter an event title.')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        maxLength: 1500,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate('Description *'),
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 5
                            ? AppTranslations.translate(
                                'Add a short event description.',
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: venueController,
                        maxLength: 160,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Venue / location *',
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? AppTranslations.translate('Enter the venue.')
                            : null,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.event_outlined,
                          color: AppTheme.navyBlue,
                        ),
                        title: const AppText('Starts'),
                        subtitle: AppText(_dateTimeLabel(startsAt)),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: () async {
                          final value = await pickDateTime(startsAt);
                          if (value != null) {
                            setDialogState(() => startsAt = value);
                          }
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.event_available_outlined,
                          color: AppTheme.navyBlue,
                        ),
                        title: const AppText('Ends'),
                        subtitle: AppText(_dateTimeLabel(endsAt)),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: () async {
                          final value = await pickDateTime(endsAt);
                          if (value != null) {
                            setDialogState(() => endsAt = value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate('Visibility'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'draft',
                            child: AppText('Save as draft'),
                          ),
                          DropdownMenuItem(
                            value: 'published',
                            child: AppText('Publish to residents'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => status = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (!endsAt.isAfter(startsAt)) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: AppText(
                                'Event end must be after its start.',
                              ),
                            ),
                          );
                          return;
                        }
                        final uid = _uid;
                        if (uid == null) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: AppText('Please sign in again.'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        final fields = <String, dynamic>{
                          'title': titleController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'venue': venueController.text.trim(),
                          'startsAt': Timestamp.fromDate(startsAt),
                          'endsAt': Timestamp.fromDate(endsAt),
                          'status': status,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        try {
                          if (eventId == null) {
                            await _events.add({
                              ...fields,
                              'createdBy': uid,
                              'createdByName':
                                  widget.adminName ?? 'Administrator',
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            await _events.doc(eventId).update(fields);
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _message(
                            eventId == null
                                ? 'Event created.'
                                : 'Event updated.',
                          );
                        } on FirebaseException catch (error) {
                          setDialogState(() => saving = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: AppText(
                                  'Unable to save event (${error.code}).',
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          setDialogState(() => saving = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: AppText(
                                  'Unable to save event: $error',
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        height: 17,
                        width: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : AppText(eventId == null ? 'Save event' : 'Update event'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      descriptionController.dispose();
      venueController.dispose();
    }
  }

  Future<void> _cancelEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Cancel this event?'),
        content: const AppText(
          'Residents will no longer see this event or be able to RSVP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Keep event'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Cancel event'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _events.doc(eventId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Event cancelled.');
    } on FirebaseException catch (error) {
      _message('Unable to cancel event (${error.code}).');
    }
  }

  Future<void> _showRsvps(String eventId, String eventTitle) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'Event RSVPs',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navyBlue,
                            ),
                          ),
                          AppText(
                            eventTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _rsvps(eventId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: AppText('Unable to load RSVPs.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs.toList()
                      ..sort(
                        (a, b) => (a.data()['userName'] ?? '')
                            .toString()
                            .compareTo((b.data()['userName'] ?? '').toString()),
                      );
                    final attending = docs
                        .where((doc) => doc.data()['status'] == 'attending')
                        .length;
                    if (docs.isEmpty) {
                      return const Center(
                        child: AppText('No residents have responded yet.'),
                      );
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AppText(
                              '$attending attending · ${docs.length - attending} not attending',
                              style: const TextStyle(
                                color: AppTheme.navyBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final data = docs[index].data();
                              final attending = data['status'] == 'attending';
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.lightGrey,
                                  child: Icon(
                                    attending ? Icons.check : Icons.remove,
                                    color: AppTheme.navyBlue,
                                  ),
                                ),
                                title: AppText(
                                  data['userName']?.toString() ?? 'Resident',
                                ),
                                trailing: _statusPill(
                                  attending ? 'attending' : 'not_attending',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

  Future<void> _saveRsvp(String eventId, String status) async {
    final uid = _uid;
    if (uid == null) {
      _message('Please sign in again.');
      return;
    }
    final reference = _rsvps(eventId).doc(uid);
    try {
      final current = await reference.get();
      if (current.exists) {
        await reference.update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await reference.set({
          'userId': uid,
          'userName': widget.residentName ?? 'Resident',
          'status': status,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      _message(
        status == 'attending'
            ? 'Your RSVP has been recorded.'
            : 'Your response has been updated.',
      );
    } on FirebaseException catch (error) {
      _message('Unable to save RSVP (${error.code}).');
    }
  }

  // =====================================================
  // ADMIN: POLL CREATION AND RESULTS
  // =====================================================

  Future<void> _editPoll({
    String? pollId,
    Map<String, dynamic>? existing,
  }) async {
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final questionController = TextEditingController(
      text: existing?['question']?.toString() ?? '',
    );
    final oldOptions = existing?['options'];
    final optionsController = TextEditingController(
      text: oldOptions is List
          ? oldOptions.map((e) => e.toString()).join('\n')
          : '',
    );
    DateTime closesAt = existing == null
        ? DateTime.now().add(const Duration(days: 7))
        : _asDate(existing['closesAt']);
    String status = existing?['status']?.toString() == 'published'
        ? 'published'
        : 'draft';
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    Future<DateTime?> pickCloseDate() async {
      final date = await showDatePicker(
        context: context,
        initialDate: closesAt,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 730)),
      );
      if (date == null || !mounted) return null;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(closesAt),
      );
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: AppText(
              pollId == null ? 'Create resident poll' : 'Edit draft poll',
              style: const TextStyle(
                color: AppTheme.navyBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate('Poll title *'),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? AppTranslations.translate('Enter a title.')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: questionController,
                        maxLength: 300,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate('Question *'),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? AppTranslations.translate(
                                'Enter the poll question.',
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: optionsController,
                        maxLength: 700,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Options * (one per line)',
                          ),
                          hintText: AppTranslations.translate(
                            'Option 1\nOption 2\nOption 3',
                          ),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          final options = (value ?? '')
                              .split('\n')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toSet();
                          if (options.length < 2 || options.length > 8) {
                            return AppTranslations.translate(
                              'Enter 2–8 distinct options, one per line.',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.timer_outlined,
                          color: AppTheme.navyBlue,
                        ),
                        title: const AppText('Voting closes'),
                        subtitle: AppText(_dateTimeLabel(closesAt)),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: () async {
                          final value = await pickCloseDate();
                          if (value != null) {
                            setDialogState(() => closesAt = value);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate('Visibility'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'draft',
                            child: AppText('Save as draft'),
                          ),
                          DropdownMenuItem(
                            value: 'published',
                            child: AppText('Publish to residents'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => status = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (!closesAt.isAfter(DateTime.now())) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: AppText(
                                'Choose a future closing date and time.',
                              ),
                            ),
                          );
                          return;
                        }
                        final uid = _uid;
                        if (uid == null) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: AppText('Please sign in again.'),
                            ),
                          );
                          return;
                        }
                        final options = optionsController.text
                            .split('\n')
                            .map((value) => value.trim())
                            .where((value) => value.isNotEmpty)
                            .toSet()
                            .toList(growable: false);
                        setDialogState(() => saving = true);
                        final fields = <String, dynamic>{
                          'title': titleController.text.trim(),
                          'question': questionController.text.trim(),
                          'options': options,
                          'closesAt': Timestamp.fromDate(closesAt),
                          'status': status,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        try {
                          if (pollId == null) {
                            await _polls.add({
                              ...fields,
                              'createdBy': uid,
                              'createdByName':
                                  widget.adminName ?? 'Administrator',
                              'createdAt': FieldValue.serverTimestamp(),
                              'results': <String, int>{},
                              'resultsPublished': false,
                            });
                          } else {
                            await _polls.doc(pollId).update(fields);
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          _message(
                            pollId == null ? 'Poll created.' : 'Poll updated.',
                          );
                        } on FirebaseException catch (error) {
                          setDialogState(() => saving = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: AppText(
                                  'Unable to save poll (${error.code}).',
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          setDialogState(() => saving = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: AppText('Unable to save poll: $error'),
                              ),
                            );
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : AppText(pollId == null ? 'Save poll' : 'Update poll'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      questionController.dispose();
      optionsController.dispose();
    }
  }

  Future<void> _publishPollResults(
    QueryDocumentSnapshot<Map<String, dynamic>> pollDocument,
  ) async {
    final pollReference = _polls.doc(pollDocument.id);
    final data = pollDocument.data();
    final options = (data['options'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    try {
      // Close voting first so no new votes can be created while results are counted.
      if (data['status'] != 'closed') {
        await pollReference.update({
          'status': 'closed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      final voteSnapshot = await _votes(pollDocument.id).get();
      final counts = <String, int>{for (final option in options) option: 0};
      for (final vote in voteSnapshot.docs) {
        final option = vote.data()['option']?.toString();
        if (option != null && counts.containsKey(option)) {
          counts[option] = counts[option]! + 1;
        }
      }
      await pollReference.update({
        'results': counts,
        'resultsPublished': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Poll closed. Results are now visible to residents.');
    } on FirebaseException catch (error) {
      _message(
        'Unable to publish results (${error.code}). The poll may be closed; retry publishing results.',
      );
    } catch (error) {
      _message('Unable to publish results: $error');
    }
  }

  Future<void> _castVote(
    QueryDocumentSnapshot<Map<String, dynamic>> pollDocument,
  ) async {
    final uid = _uid;
    if (uid == null) {
      _message('Please sign in again.');
      return;
    }
    final options =
        (pollDocument.data()['options'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false);
    if (options.length < 2) {
      _message('This poll has no valid voting options.');
      return;
    }
    String selected = options.first;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: AppText(
            pollDocument.data()['question']?.toString() ?? 'Cast your vote',
          ),
          content: SizedBox(
            width: 420,
            child: RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) {
                  setDialogState(() => selected = value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map(
                      (option) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: option,
                        title: AppText(option),
                        activeColor: AppTheme.navyBlue,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const AppText('Back'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.navyBlue),
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const AppText('Submit vote'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      await _votes(pollDocument.id).doc(uid).set({
        'userId': uid,
        'userName': widget.residentName ?? 'Resident',
        'option': choice,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _message('Your vote has been recorded. It cannot be changed.');
    } on FirebaseException catch (error) {
      if (error.code == 'already-exists') {
        _message('You have already voted in this poll.');
      } else {
        _message('Unable to submit vote (${error.code}).');
      }
    }
  }

  // =====================================================
  // EVENT CARDS
  // =====================================================

  Widget _eventCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final startsAt = _asDate(data['startsAt']);
    final endsAt = _asDate(data['endsAt']);
    final title = data['title']?.toString() ?? 'Community event';

    return Card(
      color: AppTheme.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
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
                Container(
                  width: 48,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppText(
                        startsAt.day.toString(),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navyBlue,
                        ),
                      ),
                      AppText(
                        _monthLabel(startsAt.month),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AppText(
                        '${_dateTimeLabel(startsAt)} – ${_timeLabel(endsAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isAdmin)
                  _statusPill(data['status']?.toString() ?? 'draft'),
              ],
            ),
            const SizedBox(height: 12),
            AppText(
              data['description']?.toString() ?? '',
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: AppTheme.textGrey,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: AppText(
                    data['venue']?.toString() ?? 'Venue not specified',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            if (widget.isAdmin)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showRsvps(document.id, title),
                    icon: const Icon(Icons.people_outline, size: 17),
                    label: const AppText('View RSVPs'),
                  ),
                  if (data['status'] != 'cancelled')
                    OutlinedButton.icon(
                      onPressed: () =>
                          _editEvent(eventId: document.id, existing: data),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const AppText('Edit'),
                    ),
                  if (data['status'] == 'published')
                    TextButton.icon(
                      onPressed: () => _cancelEvent(document.id),
                      icon: const Icon(Icons.event_busy_outlined, size: 17),
                      label: const AppText('Cancel event'),
                    ),
                ],
              )
            else
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _rsvps(document.id)
                    .doc(_uid ?? '__signed_out__')
                    .snapshots(),
                builder: (context, rsvpSnapshot) {
                  if (rsvpSnapshot.hasError) {
                    return Row(
                      children: [
                        Expanded(
                          child: AppText(
                            'Unable to verify your RSVP: ${rsvpSnapshot.error}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const AppText('Retry'),
                        ),
                      ],
                    );
                  }
                  if (!rsvpSnapshot.hasData) {
                    return const LinearProgressIndicator(minHeight: 2);
                  }
                  final rsvp = rsvpSnapshot.data?.data();
                  final status = rsvp?['status']?.toString();
                  final past = !endsAt.isAfter(DateTime.now());
                  return Row(
                    children: [
                      Expanded(
                        child: AppText(
                          status == 'attending'
                              ? 'You are attending'
                              : status == 'not_attending'
                              ? 'You marked not attending'
                              : past
                              ? 'This event has ended'
                              : 'Are you attending?',
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!past)
                        FilledButton.tonal(
                          onPressed:
                              rsvpSnapshot.connectionState ==
                                  ConnectionState.waiting
                              ? null
                              : () => _saveRsvp(
                                  document.id,
                                  status == 'attending'
                                      ? 'not_attending'
                                      : 'attending',
                                ),
                          child: AppText(
                            status == 'attending'
                                ? 'Cancel RSVP'
                                : 'I’m attending',
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[(month - 1).clamp(0, 11).toInt()];
  }

  Widget _eventsTab() {
    Query<Map<String, dynamic>> query = _events;
    if (!widget.isAdmin) query = query.where('status', isEqualTo: 'published');
    if (widget.isAdmin) {
      // All event records are available to Admin for draft and cancellation management.
    }
    return Column(
      children: [
        if (widget.isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                ),
                onPressed: () => _editEvent(),
                icon: const Icon(Icons.add),
                label: const AppText('Create event'),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: AppText('Unable to load community events.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs.toList()
                ..sort(
                  (a, b) =>
                      _asDate(a.data()['startsAt'])
                          .compareTo(_asDate(b.data()['startsAt'])),
                );
              if (docs.isEmpty) {
                return _emptyState(
                  Icons.event_note_outlined,
                  widget.isAdmin
                      ? 'No events created yet'
                      : 'No upcoming community events',
                  widget.isAdmin
                      ? 'Create an event to share it with residents.'
                      : 'Events published by your colony administrator will appear here.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, index) => _eventCard(docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  // =====================================================
  // POLL CARDS AND VOTING
  // =====================================================

  Widget _pollResults(Map<String, dynamic> data) {
    final options = (data['options'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    final raw = data['results'];
    final results = raw is Map ? raw : const <String, dynamic>{};
    final total = options.fold<int>(0, (accumulator, option) {
      final value = results[option];
      return accumulator + (value is num ? value.toInt() : 0);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Published results',
          style: TextStyle(
            color: AppTheme.navyBlue,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        for (final option in options) ...[
          Row(
            children: [
              Expanded(
                child: AppText(
                  option,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              AppText(
                '${results[option] ?? 0}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: total == 0
                  ? 0
                  : ((results[option] is num
                                ? (results[option] as num).toDouble()
                                : 0) /
                            total)
                        .clamp(0.0, 1.0)
                        .toDouble(),
              backgroundColor: AppTheme.lightGrey,
              color: AppTheme.secondaryNavy,
            ),
          ),
          const SizedBox(height: 9),
        ],
        AppText(
          '$total total vote${total == 1 ? '' : 's'}',
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
        ),
      ],
    );
  }

  Widget _pollCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final options = (data['options'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false);
    final closesAt = _asDate(data['closesAt']);
    final status = data['status']?.toString() ?? 'draft';
    final resultsPublished = data['resultsPublished'] == true;

    return Card(
      color: AppTheme.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
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
                const Icon(
                  Icons.poll_outlined,
                  color: AppTheme.navyBlue,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppText(
                    data['title']?.toString() ?? 'Resident poll',
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (widget.isAdmin) _statusPill(status),
              ],
            ),
            const SizedBox(height: 9),
            AppText(
              data['question']?.toString() ?? '',
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            AppText(
              status == 'closed'
                  ? 'Voting closed'
                  : 'Voting closes ${_dateTimeLabel(closesAt)}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                children: [
                  if (status == 'draft')
                    OutlinedButton.icon(
                      onPressed: () =>
                          _editPoll(pollId: document.id, existing: data),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const AppText('Edit draft'),
                    ),
                  if (status == 'published' ||
                      (status == 'closed' && !resultsPublished))
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navyBlue,
                      ),
                      onPressed: () => _publishPollResults(document),
                      icon: const Icon(Icons.assessment_outlined, size: 17),
                      label: AppText(
                        status == 'closed'
                            ? 'Publish results'
                            : 'Close & publish results',
                      ),
                    ),
                ],
              ),
              if (resultsPublished) ...[
                const Divider(height: 20),
                _pollResults(data),
              ],
              if (status == 'published') ...[
                const SizedBox(height: 5),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _votes(document.id).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Row(
                        children: [
                          Expanded(
                            child: AppText(
                              'Unable to load vote count: ${snapshot.error}',
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {}),
                            child: const AppText('Retry'),
                          ),
                        ],
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator(minHeight: 2);
                    }
                    final count = snapshot.data!.docs.length;
                    return AppText(
                      '$count resident vote${count == 1 ? '' : 's'} received',
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ],
            ] else if (resultsPublished) ...[
              const Divider(height: 20),
              _pollResults(data),
            ] else ...[
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _votes(document.id)
                    .doc(_uid ?? '__signed_out__')
                    .snapshots(),
                builder: (context, voteSnapshot) {
                  if (voteSnapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Unable to check your voting status: ${voteSnapshot.error}',
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 11,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const AppText('Retry'),
                        ),
                      ],
                    );
                  }
                  if (voteSnapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator(minHeight: 2);
                  }
                  final voted = voteSnapshot.data?.exists == true;
                  final canVote =
                      status == 'published' && closesAt.isAfter(DateTime.now());
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (voted)
                        const AppText(
                          'Your vote has been recorded. You can vote only once.',
                          style: TextStyle(
                            color: AppTheme.secondaryNavy,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (canVote)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.navyBlue,
                            ),
                            onPressed: () => _castVote(document),
                            icon: const Icon(Icons.how_to_vote_outlined),
                            label: const AppText('Cast your vote'),
                          ),
                        )
                      else
                        const AppText(
                          'Voting is closed.',
                          style: TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      if (options.isNotEmpty && canVote && !voted)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: AppText(
                            '${options.length} options · one vote per resident',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pollsTab() {
    Query<Map<String, dynamic>> query = _polls;
    if (!widget.isAdmin) {
      query = query.where('status', whereIn: ['published', 'closed']);
    }
    return Column(
      children: [
        if (widget.isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                ),
                onPressed: () => _editPoll(),
                icon: const Icon(Icons.add),
                label: const AppText('Create poll'),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: AppText('Unable to load resident polls.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs.toList()
                ..sort(
                  (a, b) =>
                      _asDate(b.data()['closesAt'])
                          .compareTo(_asDate(a.data()['closesAt'])),
                );
              if (docs.isEmpty) {
                return _emptyState(
                  Icons.poll_outlined,
                  widget.isAdmin ? 'No polls created yet' : 'No active polls',
                  widget.isAdmin
                      ? 'Create a poll to collect resident feedback.'
                      : 'Polls published by your colony administrator will appear here.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, index) => _pollCard(docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _emptyState(IconData icon, String title, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.textGrey),
            const SizedBox(height: 13),
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

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final firstTab = widget.isAdmin ? 'Manage events' : 'Community events';
    final secondTab = widget.isAdmin ? 'Manage polls' : 'Resident polls';
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navyBlue,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Community events & polls',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            AppText(
              widget.colonyName,
              style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.navyBlue,
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: AppTheme.navyBlue,
          tabs: [
            Tab(text: firstTab),
            Tab(text: secondTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_eventsTab(), _pollsTab()],
      ),
    );
  }
}
