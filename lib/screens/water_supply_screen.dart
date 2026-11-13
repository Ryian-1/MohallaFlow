import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../services/notification_service.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class WaterSupplyScreen extends StatefulWidget {
  const WaterSupplyScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<WaterSupplyScreen> createState() => _WaterSupplyScreenState();
}

class _WaterSupplyScreenState extends State<WaterSupplyScreen> {
  CollectionReference<Map<String, dynamic>> get _suppliers => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('waterSuppliers');

  CollectionReference<Map<String, dynamic>> get _deliveries => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('waterDeliveries');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static const List<String> _serviceTypes = [
    'Water Tanker',
    'Water Supplier',
    'Water Transport',
    'Other',
  ];

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(value)));
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

  String _dateLabel(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().substring(0, 16);
    }
    return 'Date not available';
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

  Widget _sectionHeading(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(height: 4),
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
            Icon(icon, size: 45, color: AppTheme.textGrey),
            const SizedBox(height: 14),
            AppText(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.navyBlue,
              ),
            ),
            const SizedBox(height: 7),
            AppText(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // REGISTER A WATER SUPPLIER
  // =====================================================

  Future<void> _addSupplier() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    String serviceType = 'Water Tanker';
    bool saving = false;
    bool saved = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const AppText('Register water supplier'),
                content: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Company / supplier name',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: contactController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Contact person',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Contact phone number',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Email (optional)',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: serviceType,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Service type',
                            ),
                          ),
                          items: _serviceTypes.map((value) {
                            return DropdownMenuItem(
                              value: value,
                              child: AppText(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => serviceType = value);
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
                            final uid = _uid;
                            final name = nameController.text.trim();
                            final phone = phoneController.text.trim();

                            if (uid == null || name.isEmpty || phone.isEmpty) {
                              _message('Supplier name and phone are required.');
                              return;
                            }

                            setDialogState(() => saving = true);

                            try {
                              await _suppliers.add({
                                'supplierName': name,
                                'contactPerson': contactController.text.trim(),
                                'phoneNumber': phone,
                                'email': emailController.text.trim(),
                                'serviceType': serviceType,
                                'status': 'active',
                                'createdBy': uid,
                                'createdByName': widget.adminName,
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

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
                                          'Supplier registration failed: '
                                          '${error.message ?? error.code}',
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
                        : const AppText('Register supplier'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved) _message('Water supplier registered successfully.');
    } finally {
      nameController.dispose();
      contactController.dispose();
      phoneController.dispose();
      emailController.dispose();
    }
  }

  // =====================================================
  // RECORD A TANKER DELIVERY
  // =====================================================

  Future<void> _addDelivery() async {
    final uid = _uid;

    if (uid == null) {
      _message('Please sign in again.');
      return;
    }

    try {
      final supplierSnapshot = await _suppliers
          .where('status', isEqualTo: 'active')
          .get();

      if (!mounted) return;

      final suppliers = supplierSnapshot.docs.toList()
        ..sort(
          (a, b) => (a.data()['supplierName'] as String? ?? '').compareTo(
            b.data()['supplierName'] as String? ?? '',
          ),
        );

      if (suppliers.isEmpty) {
        _message('Register an active water supplier first.');
        return;
      }

      final vehicleController = TextEditingController();
      final quantityController = TextEditingController();
      final costController = TextEditingController();
      final locationController = TextEditingController(
        text: 'Colony water storage tank',
      );
      final notesController = TextEditingController();

      String? selectedSupplierId = suppliers.first.id;
      String deliveryStatus = 'scheduled';
      String paymentStatus = 'pending';
      DateTime deliveryDate = DateTime.now();
      bool saving = false;
      bool saved = false;

      try {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                Future<void> chooseDate() async {
                  final selected = await showDatePicker(
                    context: dialogContext,
                    initialDate: deliveryDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );

                  if (selected != null) {
                    setDialogState(() => deliveryDate = selected);
                  }
                }

                return AlertDialog(
                  title: const AppText('Record tanker delivery'),
                  content: SizedBox(
                    width: 480,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedSupplierId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Water supplier',
                              ),
                            ),
                            items: suppliers.map((supplier) {
                              final data = supplier.data();
                              return DropdownMenuItem(
                                value: supplier.id,
                                child: AppText(
                                  data['supplierName'] as String? ?? 'Supplier',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() => selectedSupplierId = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: chooseDate,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: AppText(
                              'Delivery date: '
                              '${deliveryDate.day.toString().padLeft(2, '0')}/'
                              '${deliveryDate.month.toString().padLeft(2, '0')}/'
                              '${deliveryDate.year}',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: vehicleController,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Tanker / vehicle number',
                              ),
                              hintText: AppTranslations.translate(
                                'e.g. DL01AB1234',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: quantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Quantity delivered (litres)',
                              ),
                              hintText: AppTranslations.translate('e.g. 10000'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: costController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Delivery cost (₹)',
                              ),
                              hintText: AppTranslations.translate('e.g. 2500'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: locationController,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Delivery location',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Distribution notes (optional)',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: deliveryStatus,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Delivery status',
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'scheduled',
                                child: AppText('Scheduled'),
                              ),
                              DropdownMenuItem(
                                value: 'delivered',
                                child: AppText('Delivered'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => deliveryStatus = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: paymentStatus,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Payment status',
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'pending',
                                child: AppText('Pending'),
                              ),
                              DropdownMenuItem(
                                value: 'paid',
                                child: AppText('Paid'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => paymentStatus = value);
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
                              final quantity = double.tryParse(
                                quantityController.text.trim(),
                              );
                              final cost = double.tryParse(
                                costController.text.trim(),
                              );

                              if (selectedSupplierId == null ||
                                  quantity == null ||
                                  quantity <= 0 ||
                                  cost == null ||
                                  cost < 0 ||
                                  locationController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                      const SnackBar(
                                        content: AppText(
                                          'Enter a supplier, valid quantity, '
                                          'cost and delivery location.',
                                        ),
                                      ),
                                    );
                                return;
                              }

                              final supplier = suppliers.firstWhere(
                                (item) => item.id == selectedSupplierId,
                              );
                              final supplierData = supplier.data();

                              setDialogState(() => saving = true);

                              try {
                                final deliveryRef = _deliveries.doc();
                                final batch = FirebaseFirestore.instance
                                    .batch();
                                batch.set(deliveryRef, {
                                  'supplierId': supplier.id,
                                  'supplierName':
                                      supplierData['supplierName'] ?? '',
                                  'supplierPhone':
                                      supplierData['phoneNumber'] ?? '',
                                  'vehicleNumber': vehicleController.text
                                      .trim(),
                                  'quantityLitres': quantity,
                                  'cost': cost,
                                  'paymentStatus': paymentStatus,
                                  'status': deliveryStatus,
                                  'deliveryDate': Timestamp.fromDate(
                                    DateTime(
                                      deliveryDate.year,
                                      deliveryDate.month,
                                      deliveryDate.day,
                                    ),
                                  ),
                                  'deliveryLocation': locationController.text
                                      .trim(),
                                  'distributionNotes': notesController.text
                                      .trim(),
                                  'createdBy': uid,
                                  'createdByName': widget.adminName,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                  'completedAt': deliveryStatus == 'delivered'
                                      ? FieldValue.serverTimestamp()
                                      : null,
                                });
                                NotificationService.addWaterDeliveryUpdated(
                                  batch: batch,
                                  colonyId: widget.colonyId,
                                  deliveryId: deliveryRef.id,
                                  location:
                                      locationController.text.trim().isEmpty
                                      ? widget.colonyName
                                      : locationController.text.trim(),
                                  newStatus: deliveryStatus,
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
                                            'Delivery could not be saved: '
                                            '${error.message ?? error.code}',
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
                          : const AppText('Save delivery'),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (saved) _message('Tanker delivery recorded successfully.');
      } finally {
        vehicleController.dispose();
        quantityController.dispose();
        costController.dispose();
        locationController.dispose();
        notesController.dispose();
      }
    } on FirebaseException catch (error) {
      _message('Unable to load suppliers: ${error.message ?? error.code}');
    } catch (error) {
      _message('Unable to start delivery form: $error');
    }
  }

  // =====================================================
  // UPDATE DELIVERY STATUS OR PAYMENT
  // =====================================================

  Future<void> _updateDelivery(
    QueryDocumentSnapshot<Map<String, dynamic>> delivery,
    String action,
  ) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (action == 'delivered') {
      updates['status'] = 'delivered';
      updates['completedAt'] = FieldValue.serverTimestamp();
    } else if (action == 'cancelled') {
      updates['status'] = 'cancelled';
      updates['completedAt'] = null;
    } else if (action == 'scheduled') {
      updates['status'] = 'scheduled';
      updates['completedAt'] = null;
    } else if (action == 'paid' || action == 'pending') {
      updates['paymentStatus'] = action;
    } else {
      return;
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _message('Please sign in again.');
        return;
      }
      final batch = FirebaseFirestore.instance.batch();
      batch.update(delivery.reference, updates);
      final data = delivery.data();
      if ((action == 'delivered' ||
              action == 'cancelled' ||
              action == 'scheduled') &&
          data['status'] != action) {
        NotificationService.addWaterDeliveryUpdated(
          batch: batch,
          colonyId: widget.colonyId,
          deliveryId: delivery.id,
          location: data['deliveryLocation'] as String? ?? widget.colonyName,
          newStatus: action,
          createdBy: uid,
        );
      }
      await batch.commit();
      _message('Delivery record updated.');
    } on FirebaseException catch (error) {
      _message('Update failed: ${error.message ?? error.code}');
    }
  }

  // =====================================================
  // ACTIVATE / DEACTIVATE SUPPLIER
  // =====================================================

  Future<void> _toggleSupplier(
    QueryDocumentSnapshot<Map<String, dynamic>> supplier,
  ) async {
    final current = supplier.data()['status'] as String? ?? 'active';
    final next = current == 'active' ? 'inactive' : 'active';

    try {
      await supplier.reference.update({
        'status': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Supplier marked ${_label(next)}.');
    } on FirebaseException catch (error) {
      _message('Supplier update failed: ${error.message ?? error.code}');
    }
  }

  // =====================================================
  // DELIVERY CARD
  // =====================================================

  Widget _deliveryCard(QueryDocumentSnapshot<Map<String, dynamic>> delivery) {
    final data = delivery.data();

    final supplier = data['supplierName'] as String? ?? 'Unknown supplier';
    final vehicle = data['vehicleNumber'] as String? ?? 'Not recorded';
    final location = data['deliveryLocation'] as String? ?? '';
    final notes = data['distributionNotes'] as String? ?? '';
    final status = data['status'] as String? ?? 'scheduled';
    final payment = data['paymentStatus'] as String? ?? 'pending';
    final quantity = data['quantityLitres'] as num? ?? 0;
    final cost = data['cost'] as num? ?? 0;

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
            children: [
              Expanded(
                child: AppText(
                  supplier,
                  style: const TextStyle(
                    color: AppTheme.navyBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: AppTranslations.translate('Delivery actions'),
                onSelected: (value) => _updateDelivery(delivery, value),
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[];

                  if (status == 'scheduled') {
                    items.add(
                      const PopupMenuItem(
                        value: 'delivered',
                        child: AppText('Mark delivered'),
                      ),
                    );
                    items.add(
                      const PopupMenuItem(
                        value: 'cancelled',
                        child: AppText('Cancel delivery'),
                      ),
                    );
                  }

                  if (status == 'cancelled') {
                    items.add(
                      const PopupMenuItem(
                        value: 'scheduled',
                        child: AppText('Reschedule'),
                      ),
                    );
                  }

                  if (payment == 'pending') {
                    items.add(
                      const PopupMenuItem(
                        value: 'paid',
                        child: AppText('Mark payment paid'),
                      ),
                    );
                  } else {
                    items.add(
                      const PopupMenuItem(
                        value: 'pending',
                        child: AppText('Mark payment pending'),
                      ),
                    );
                  }

                  return items;
                },
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_badge(status), _badge('Payment: $payment')],
          ),
          const Divider(height: 24),
          _detailRow(
            Icons.water_drop_outlined,
            '${quantity.toStringAsFixed(0)} litres',
          ),
          _detailRow(Icons.currency_rupee, '₹${cost.toStringAsFixed(2)}'),
          _detailRow(Icons.local_shipping_outlined, vehicle),
          _detailRow(Icons.location_on_outlined, location),
          _detailRow(
            Icons.calendar_month_outlined,
            _dateLabel(data['deliveryDate']),
          ),
          if ((data['supplierPhone'] as String? ?? '').isNotEmpty)
            _detailRow(Icons.phone_outlined, data['supplierPhone'] as String),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            AppText(
              'Distribution notes: $notes',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.secondaryNavy),
          const SizedBox(width: 9),
          Expanded(
            child: AppText(
              value,
              style: const TextStyle(color: AppTheme.textDark, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SUPPLIER CARD
  // =====================================================

  Widget _supplierCard(QueryDocumentSnapshot<Map<String, dynamic>> supplier) {
    final data = supplier.data();
    final status = data['status'] as String? ?? 'active';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.water_drop_outlined,
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  data['supplierName'] as String? ?? 'Unnamed supplier',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyBlue,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  '${data['serviceType'] ?? 'Water Supplier'} · '
                  '${data['contactPerson'] ?? ''}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  data['phoneNumber'] as String? ?? '',
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 12,
                  ),
                ),
                if ((data['email'] as String? ?? '').isNotEmpty)
                  AppText(
                    data['email'] as String,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 7),
                _badge(status),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => _toggleSupplier(supplier),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: AppText(
                  status == 'active' ? 'Mark inactive' : 'Mark active',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // DELIVERY TAB
  // =====================================================

  Widget _buildDeliveriesTab() {
    return Column(
      children: [
        _sectionHeading(
          'Tanker deliveries',
          'Record and track colony water supply deliveries.',
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _deliveries
                .orderBy('deliveryDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppText(
                      'Unable to load deliveries.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final documents = snapshot.data?.docs ?? [];

              if (documents.isEmpty) {
                return _emptyState(
                  'No tanker deliveries recorded',
                  'Register a supplier and record the first delivery.',
                  Icons.local_shipping_outlined,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: documents.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _deliveryCard(documents[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  // =====================================================
  // SUPPLIER TAB
  // =====================================================

  Widget _buildSuppliersTab() {
    return Column(
      children: [
        _sectionHeading(
          'Water supplier directory',
          'Manage tanker companies and water suppliers.',
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _suppliers.orderBy('supplierName').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppText(
                      'Unable to load suppliers.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final documents = snapshot.data?.docs ?? [];

              if (documents.isEmpty) {
                return _emptyState(
                  'No water suppliers registered',
                  'Register your tanker operators and suppliers here.',
                  Icons.water_drop_outlined,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: documents.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _supplierCard(documents[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  // =====================================================
  // MAIN SCREEN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Water Supply Management',
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
              tooltip: AppTranslations.translate('Record tanker delivery'),
              onPressed: _addDelivery,
              icon: const Icon(Icons.add_task_outlined),
            ),
            IconButton(
              tooltip: AppTranslations.translate('Register water supplier'),
              onPressed: _addSupplier,
              icon: const Icon(Icons.person_add_alt_1_outlined),
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
                icon: Icon(Icons.local_shipping_outlined),
                text: AppTranslations.translate('Deliveries'),
              ),
              Tab(
                icon: Icon(Icons.water_drop_outlined),
                text: AppTranslations.translate('Suppliers'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildDeliveriesTab(), _buildSuppliersTab()],
        ),
      ),
    );
  }
}
