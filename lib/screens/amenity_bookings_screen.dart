import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class AmenityBookingsScreen extends StatefulWidget {
  const AmenityBookingsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.isAdmin,
    this.adminName,
    this.residentId,
    this.residentName,
  });

  final String colonyId;
  final String colonyName;
  final bool isAdmin;
  final String? adminName;
  final String? residentId;
  final String? residentName;

  @override
  State<AmenityBookingsScreen> createState() => _AmenityBookingsScreenState();
}

class _AmenityBookingsScreenState extends State<AmenityBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _bookingFilter = 'all';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _amenities => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('amenityFacilities');

  CollectionReference<Map<String, dynamic>> get _bookings => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('amenityBookings');

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

  String _two(int value) => value.toString().padLeft(2, '0');

  String _dateLabel(DateTime date) =>
      '${_two(date.day)}/${_two(date.month)}/${date.year}';

  String _dateKey(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  String _timeLabel(int minutes) =>
      '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';

  DateTime _bookingDate(Map<String, dynamic> data) {
    final value = data['bookingDate'];
    if (value is Timestamp) return value.toDate();
    return DateTime(2000);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
      case 'completed':
        return const Color(0xFF246B8E);
      case 'pending':
        return const Color(0xFF996515);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFB54747);
      default:
        return AppTheme.textGrey;
    }
  }

  // =====================================================
  // ADMIN: CREATE / EDIT FACILITY
  // =====================================================

  Future<void> _editAmenity({
    String? documentId,
    Map<String, dynamic>? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing?['description'] as String? ?? '',
    );
    final locationController = TextEditingController(
      text: existing?['location'] as String? ?? '',
    );
    final capacityController = TextEditingController(
      text: (existing?['capacity'] ?? 20).toString(),
    );
    final rateController = TextEditingController(
      text: (existing?['hourlyRate'] ?? 0).toString(),
    );
    bool isActive = existing?['isActive'] != false;
    final formKey = GlobalKey<FormState>();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: AppText(
              documentId == null ? 'Add facility' : 'Edit facility',
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
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Facility name *',
                          ),
                          hintText: AppTranslations.translate(
                            'Clubhouse, Community Hall, Badminton Court',
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? AppTranslations.translate(
                                'Enter a facility name.',
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate('Description'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: locationController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 160,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Location / Block',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: capacityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: AppTranslations.translate(
                                  'Capacity *',
                                ),
                              ),
                              validator: (value) {
                                final parsed = int.tryParse(value ?? '');
                                if (parsed == null ||
                                    parsed < 1 ||
                                    parsed > 5000) {
                                  return AppTranslations.translate(
                                    'Use 1–5000',
                                  );
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: rateController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: AppTranslations.translate(
                                  'Fee / hour (₹)',
                                ),
                              ),
                              validator: (value) {
                                final parsed = num.tryParse(value ?? '');
                                if (parsed == null ||
                                    parsed < 0 ||
                                    parsed > 1000000) {
                                  return AppTranslations.translate(
                                    'Enter a valid fee',
                                  );
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const AppText('Available for residents'),
                        value: isActive,
                        activeThumbColor: AppTheme.navyBlue,
                        onChanged: (value) =>
                            setDialogState(() => isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                ),
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const AppText('Save facility'),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true) return;
      final uid = _uid;
      if (uid == null) {
        _message('Please sign in again.');
        return;
      }

      final data = <String, dynamic>{
        'name': nameController.text.trim(),
        'description': descriptionController.text.trim(),
        'location': locationController.text.trim(),
        'capacity': int.parse(capacityController.text.trim()),
        'hourlyRate': num.parse(rateController.text.trim()),
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (documentId == null) {
        data.addAll({
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _amenities.add(data);
      } else {
        await _amenities.doc(documentId).update(data);
      }

      _message(documentId == null ? 'Facility added.' : 'Facility updated.');
    } on FirebaseException catch (error) {
      _message('Unable to save facility (${error.code}).');
    } catch (error) {
      _message('Unable to save facility: $error');
    } finally {
      nameController.dispose();
      descriptionController.dispose();
      locationController.dispose();
      capacityController.dispose();
      rateController.dispose();
    }
  }

  // =====================================================
  // RESIDENT: REQUEST A BOOKING
  // =====================================================

  Future<void> _requestBooking(
    QueryDocumentSnapshot<Map<String, dynamic>> amenityDocument,
  ) async {
    final uid = _uid;
    final residentId = widget.residentId;
    final residentName = widget.residentName?.trim() ?? '';

    if (uid == null ||
        residentId == null ||
        residentId.isEmpty ||
        residentName.isEmpty) {
      _message('Your resident profile is not linked. Contact your Admin.');
      return;
    }

    final amenity = amenityDocument.data();
    final capacity = amenity['capacity'] is num
        ? (amenity['capacity'] as num).toInt()
        : 1;
    final rate = amenity['hourlyRate'] is num
        ? (amenity['hourlyRate'] as num).toDouble()
        : 0.0;
    final guestsController = TextEditingController(text: '2');
    final purposeController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 12, minute: 0);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null && dialogContext.mounted) {
                setDialogState(() {
                  selectedDate = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                  );
                });
              }
            }

            Future<void> pickStart() async {
              final picked = await showTimePicker(
                context: dialogContext,
                initialTime: startTime,
              );
              if (picked != null && dialogContext.mounted) {
                setDialogState(() => startTime = picked);
              }
            }

            Future<void> pickEnd() async {
              final picked = await showTimePicker(
                context: dialogContext,
                initialTime: endTime,
              );
              if (picked != null && dialogContext.mounted) {
                setDialogState(() => endTime = picked);
              }
            }

            final startMinutes = startTime.hour * 60 + startTime.minute;
            final endMinutes = endTime.hour * 60 + endTime.minute;
            final duration = endMinutes > startMinutes
                ? (endMinutes - startMinutes) / 60
                : 0.0;
            final estimatedFee = duration * rate;
            final now = DateTime.now();
            final isSameDayAsToday =
                selectedDate.year == now.year &&
                selectedDate.month == now.month &&
                selectedDate.day == now.day;
            final isPastStartTime =
                isSameDayAsToday && startMinutes <= now.hour * 60 + now.minute;

            return AlertDialog(
              title: AppText(
                'Request ${amenity['name'] ?? 'facility'}',
                style: const TextStyle(
                  color: AppTheme.navyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: AppText(_dateLabel(selectedDate)),
                        subtitle: const AppText('Booking date'),
                        trailing: TextButton(
                          onPressed: pickDate,
                          child: const AppText('Change'),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickStart,
                              icon: const Icon(Icons.access_time),
                              label: AppText(
                                'From ${startTime.format(dialogContext)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickEnd,
                              icon: const Icon(Icons.access_time_filled),
                              label: AppText(
                                'To ${endTime.format(dialogContext)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: guestsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Number of attendees *',
                          ),
                          helperText: AppTranslations.translate(
                            'Facility capacity: $capacity',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: purposeController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Purpose of booking *',
                          ),
                          hintText: AppTranslations.translate(
                            'Family gathering, sports practice, event…',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AppText(
                          endMinutes <= startMinutes
                              ? 'End time must be later than start time.'
                              : isPastStartTime
                              ? 'The selected start time has already passed.'
                              : 'Estimated facility fee: ₹${estimatedFee.toStringAsFixed(2)}\nFinal approval and fee are subject to Admin confirmation.',
                          style: const TextStyle(
                            color: AppTheme.navyBlue,
                            fontWeight: FontWeight.w700,
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
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navyBlue,
                  ),
                  onPressed: endMinutes > startMinutes && !isPastStartTime
                      ? () {
                          final attendeeCount = int.tryParse(
                            guestsController.text.trim(),
                          );
                          if (attendeeCount == null ||
                              attendeeCount < 1 ||
                              attendeeCount > capacity) {
                            _message(
                              'Attendees must be between 1 and $capacity.',
                            );
                            return;
                          }
                          if (purposeController.text.trim().isEmpty) {
                            _message('Enter the purpose of booking.');
                            return;
                          }
                          Navigator.pop(dialogContext, true);
                        }
                      : null,
                  child: const AppText('Submit request'),
                ),
              ],
            );
          },
        ),
      );

      if (confirmed != true) return;
      final startMinutes = startTime.hour * 60 + startTime.minute;
      final endMinutes = endTime.hour * 60 + endTime.minute;
      final attendeeCount = int.parse(guestsController.text.trim());
      final durationHours = (endMinutes - startMinutes) / 60;

      final day = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      await _bookings.add({
        'amenityId': amenityDocument.id,
        'amenityName': amenity['name']?.toString() ?? 'Facility',
        'residentId': residentId,
        'residentName': residentName,
        'createdBy': uid,
        'bookingDate': Timestamp.fromDate(day),
        'bookingDateKey': _dateKey(day),
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'attendeeCount': attendeeCount,
        'purpose': purposeController.text.trim(),
        'hourlyRate': rate,
        'estimatedFee': durationHours * rate,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
        'rejectionReason': null,
        'cancelledAt': null,
        'completedAt': null,
      });
      _message('Booking request submitted for Admin approval.');
    } on FirebaseException catch (error) {
      _message('Unable to submit booking (${error.code}).');
    } catch (error) {
      _message('Unable to submit booking: $error');
    } finally {
      guestsController.dispose();
      purposeController.dispose();
    }
  }

  // =====================================================
  // ADMIN: REVIEW BOOKINGS
  // =====================================================

  Future<void> _reviewBooking(
    QueryDocumentSnapshot<Map<String, dynamic>> bookingDocument,
    String nextStatus,
  ) async {
    final uid = _uid;
    if (uid == null) {
      _message('Please sign in again.');
      return;
    }

    final booking = bookingDocument.data();
    String rejectionReason = '';

    if (nextStatus == 'rejected') {
      final controller = TextEditingController();
      try {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const AppText('Reject booking request'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: AppTranslations.translate('Reason for rejection *'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const AppText('Back'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                ),
                onPressed: () {
                  if (controller.text.trim().isEmpty) return;
                  Navigator.pop(dialogContext, true);
                },
                child: const AppText('Reject'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        rejectionReason = controller.text.trim();
      } finally {
        controller.dispose();
      }
    }

    try {
      if (nextStatus == 'approved') {
        final amenityId = booking['amenityId'] as String? ?? '';
        final dayKey = booking['bookingDateKey'] as String? ?? '';
        final start = booking['startMinutes'] as int? ?? 0;
        final end = booking['endMinutes'] as int? ?? 0;
        final attendeeCount = booking['attendeeCount'] is num
            ? (booking['attendeeCount'] as num).toInt()
            : 0;
        final amenitySnapshot = await _amenities.doc(amenityId).get();
        final currentAmenity = amenitySnapshot.data();
        if (!amenitySnapshot.exists || currentAmenity?['isActive'] != true) {
          _message('Cannot approve: this facility is currently inactive.');
          return;
        }
        final currentCapacity = currentAmenity?['capacity'] is num
            ? (currentAmenity!['capacity'] as num).toInt()
            : 0;
        if (attendeeCount > currentCapacity) {
          _message(
            "Cannot approve: attendees exceed the facility's current capacity.",
          );
          return;
        }
        final existing = await _bookings
            .where('amenityId', isEqualTo: amenityId)
            .get();

        for (final otherDocument in existing.docs) {
          if (otherDocument.id == bookingDocument.id) continue;
          final other = otherDocument.data();
          if (other['bookingDateKey'] != dayKey ||
              other['status'] != 'approved') {
            continue;
          }
          final otherStart = other['startMinutes'] is num
              ? (other['startMinutes'] as num).toInt()
              : 0;
          final otherEnd = other['endMinutes'] is num
              ? (other['endMinutes'] as num).toInt()
              : 0;
          if (start < otherEnd && otherStart < end) {
            _message(
              'Cannot approve: this facility already has an approved booking from '
              '${_timeLabel(otherStart)} to ${_timeLabel(otherEnd)} on $dayKey.',
            );
            return;
          }
        }
      }

      final update = <String, dynamic>{
        'status': nextStatus,
        'reviewedBy': uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (nextStatus == 'rejected') {
        update['rejectionReason'] = rejectionReason;
      }
      if (nextStatus == 'completed') {
        update['completedAt'] = FieldValue.serverTimestamp();
      }
      if (nextStatus == 'cancelled') {
        update['cancelledAt'] = FieldValue.serverTimestamp();
      }
      await _bookings.doc(bookingDocument.id).update(update);
      _message('Booking ${_statusLabel(nextStatus).toLowerCase()}.');
    } on FirebaseException catch (error) {
      _message('Unable to update booking (${error.code}).');
    } catch (error) {
      _message('Unable to update booking: $error');
    }
  }

  Future<void> _cancelResidentBooking(
    QueryDocumentSnapshot<Map<String, dynamic>> bookingDocument,
  ) async {
    try {
      await _bookings.doc(bookingDocument.id).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Booking cancelled.');
    } on FirebaseException catch (error) {
      _message('Unable to cancel booking (${error.code}).');
    }
  }

  // =====================================================
  // UI
  // =====================================================

  Widget _facilityCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final active = data['isActive'] == true;
    final capacity = data['capacity'] is num
        ? (data['capacity'] as num).toInt()
        : 0;
    final fee = data['hourlyRate'] is num ? data['hourlyRate'] as num : 0;

    return Card(
      color: AppTheme.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppTheme.borderGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.meeting_room_outlined,
                    color: AppTheme.navyBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        data['name']?.toString() ?? 'Facility',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navyBlue,
                        ),
                      ),
                      if ((data['location'] as String? ?? '').isNotEmpty)
                        AppText(
                          data['location'] as String,
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.isAdmin)
                  IconButton(
                    tooltip: AppTranslations.translate('Edit facility'),
                    onPressed: () =>
                        _editAmenity(documentId: document.id, existing: data),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppTheme.navyBlue,
                    ),
                  ),
              ],
            ),
            if ((data['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              AppText(
                data['description'] as String,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
              ),
            ],
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoPill(Icons.people_outline, 'Capacity $capacity'),
                _infoPill(
                  Icons.currency_rupee,
                  '₹${fee.toStringAsFixed(0)}/hour',
                ),
                if (widget.isAdmin)
                  _infoPill(
                    active
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    active ? 'Active' : 'Inactive',
                  ),
              ],
            ),
            if (!widget.isAdmin) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navyBlue,
                  ),
                  onPressed: active ? () => _requestBooking(document) : null,
                  icon: const Icon(Icons.event_available_outlined),
                  label: const AppText('Request booking'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.navyBlue),
          const SizedBox(width: 5),
          AppText(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.navyBlue),
          ),
        ],
      ),
    );
  }

  Widget _facilitiesTab() {
    Query<Map<String, dynamic>> query = _amenities;
    if (!widget.isAdmin) {
      query = query.where('isActive', isEqualTo: true);
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
                onPressed: () => _editAmenity(),
                icon: const Icon(Icons.add),
                label: const AppText('Add facility'),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: AppText('Unable to load facilities.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs.toList()
                ..sort(
                  (a, b) => (a.data()['name'] ?? '').toString().compareTo(
                    (b.data()['name'] ?? '').toString(),
                  ),
                );
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.meeting_room_outlined,
                          size: 42,
                          color: AppTheme.textGrey,
                        ),
                        const SizedBox(height: 12),
                        AppText(
                          widget.isAdmin
                              ? 'No facilities have been added yet.'
                              : 'No facilities are currently available.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textGrey),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, index) => _facilityCard(docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Query<Map<String, dynamic>> _bookingQuery() {
    if (widget.isAdmin) return _bookings;
    final uid = _uid;
    return _bookings.where('createdBy', isEqualTo: uid ?? '__signed_out__');
  }

  Widget _bookingCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final status = data['status']?.toString() ?? 'pending';
    final date = _bookingDate(data);
    final start = data['startMinutes'] is num
        ? (data['startMinutes'] as num).toInt()
        : 0;
    final end = data['endMinutes'] is num
        ? (data['endMinutes'] as num).toInt()
        : 0;
    final fee = data['estimatedFee'] is num ? data['estimatedFee'] as num : 0;

    return Card(
      color: AppTheme.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 11),
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
                    data['amenityName']?.toString() ?? 'Facility booking',
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AppText(
                    _statusLabel(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppText(
              '${_dateLabel(date)}  ·  ${_timeLabel(start)}–${_timeLabel(end)}',
              style: const TextStyle(
                color: AppTheme.navyBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            if (widget.isAdmin)
              AppText(
                'Resident: ${data['residentName'] ?? 'Unknown'}  ·  ${data['residentId'] ?? ''}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
            AppText(
              'Attendees: ${data['attendeeCount'] ?? '—'}  ·  Estimated fee: ₹${fee.toStringAsFixed(2)}',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
            const SizedBox(height: 7),
            AppText(
              data['purpose']?.toString() ?? '',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
            if (status == 'rejected' &&
                (data['rejectionReason'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              AppText(
                'Reason: ${data['rejectionReason']}',
                style: const TextStyle(color: Color(0xFFB54747), fontSize: 12),
              ),
            ],
            if (widget.isAdmin && status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reviewBooking(document, 'rejected'),
                      child: const AppText('Reject'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navyBlue,
                      ),
                      onPressed: () => _reviewBooking(document, 'approved'),
                      child: const AppText('Approve'),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.isAdmin && status == 'approved') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _reviewBooking(document, 'completed'),
                  icon: const Icon(Icons.task_alt),
                  label: const AppText('Mark completed'),
                ),
              ),
            ],
            if (!widget.isAdmin &&
                (status == 'pending' || status == 'approved')) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancelResidentBooking(document),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const AppText('Cancel booking'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bookingsTab() {
    return Column(
      children: [
        if (widget.isAdmin)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                for (final filter in const [
                  'all',
                  'pending',
                  'approved',
                  'rejected',
                  'completed',
                  'cancelled',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: AppText(
                        filter[0].toUpperCase() + filter.substring(1),
                      ),
                      selected: _bookingFilter == filter,
                      onSelected: (_) =>
                          setState(() => _bookingFilter = filter),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _bookingQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: AppText('Unable to load bookings.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs =
                  snapshot.data!.docs.where((doc) {
                    return !widget.isAdmin || _bookingFilter == 'all'
                        ? true
                        : doc.data()['status'] == _bookingFilter;
                  }).toList()..sort((a, b) {
                    final aDate = a.data()['bookingDate'] is Timestamp
                        ? (a.data()['bookingDate'] as Timestamp).toDate()
                        : DateTime(2000);
                    final bDate = b.data()['bookingDate'] is Timestamp
                        ? (b.data()['bookingDate'] as Timestamp).toDate()
                        : DateTime(2000);
                    return aDate.compareTo(bDate);
                  });
              if (docs.isEmpty) {
                return Center(
                  child: AppText(
                    widget.isAdmin
                        ? 'No booking requests in this filter.'
                        : 'You have no facility bookings yet.',
                    style: const TextStyle(color: AppTheme.textGrey),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, index) => _bookingCard(docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    final firstTab = widget.isAdmin ? 'Facilities' : 'Available facilities';
    final secondTab = widget.isAdmin ? 'Booking requests' : 'My bookings';

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navyBlue,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Facility bookings',
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
        children: [_facilitiesTab(), _bookingsTab()],
      ),
    );
  }
}
