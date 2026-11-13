// COLONY_ASSET_INVENTORY_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Admin module for fixed colony assets, service history and consumable stock.
/// All writes are colony-scoped and stock movements are committed atomically.
class ColonyAssetInventoryScreen extends StatefulWidget {
  const ColonyAssetInventoryScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<ColonyAssetInventoryScreen> createState() =>
      _ColonyAssetInventoryScreenState();
}

class _ColonyAssetInventoryScreenState
    extends State<ColonyAssetInventoryScreen> {
  CollectionReference<Map<String, dynamic>> get _colony => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('colonyAssets');

  CollectionReference<Map<String, dynamic>> get _items => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('inventoryItems');

  CollectionReference<Map<String, dynamic>> get _movements => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('inventoryTransactions');

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const List<String> _assetCategories = [
    'Lift',
    'Generator',
    'Water Pump',
    'CCTV',
    'Fire Safety',
    'Electrical',
    'Plumbing',
    'Other',
  ];
  static const List<String> _assetConditions = ['good', 'fair', 'poor'];
  static const List<String> _assetStatuses = [
    'active',
    'under_maintenance',
    'retired',
  ];
  static const List<String> _inventoryCategories = [
    'Cleaning',
    'Electrical',
    'Plumbing',
    'Safety',
    'Gardening',
    'Other',
  ];
  static const List<String> _units = [
    'piece',
    'box',
    'packet',
    'litre',
    'kg',
    'metre',
    'pair',
    'set',
  ];

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _dateLabel(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value;
    return 'Not recorded';
  }

  String _money(Object? value) {
    final amount = value is num ? value.toDouble() : 0.0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  Widget _sectionHeader(
    String title,
    String subtitle,
    VoidCallback action,
    String actionLabel,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                AppText(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: action,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: AppText(actionLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.navyBlue,
              side: const BorderSide(color: AppTheme.borderGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String title, String detail, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppTheme.textGrey),
          const SizedBox(height: 10),
          AppText(
            title,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          AppText(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _assetsTab() {
    return Column(
      children: [
        _sectionHeader(
          'Colony assets',
          'Track equipment, ownership details, condition and service records.',
          () => _showAssetForm(),
          'Add asset',
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _colony.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _empty(
                  'Unable to load assets',
                  'Check your connection and Firestore rules.',
                  Icons.error_outline_rounded,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.navyBlue),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _empty(
                  'No assets registered yet',
                  'Add colony equipment such as lifts, generators, pumps and CCTV systems.',
                  Icons.precision_manufacturing_outlined,
                );
              }
              final records = [...docs]
                ..sort(
                  (a, b) => (a.data()['name'] as String? ?? '')
                      .toLowerCase()
                      .compareTo(
                        (b.data()['name'] as String? ?? '').toLowerCase(),
                      ),
                );
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final doc = records[index];
                  final data = doc.data();
                  final status = data['status'] as String? ?? 'active';
                  final condition = data['condition'] as String? ?? 'good';
                  final retired = status == 'retired';
                  return Card(
                    color: AppTheme.white,
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: const BorderSide(color: AppTheme.borderGrey),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.precision_manufacturing_outlined,
                                  color: AppTheme.navyBlue,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      data['name'] as String? ??
                                          'Unnamed asset',
                                      style: const TextStyle(
                                        color: AppTheme.textDark,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    AppText(
                                      '${data['category'] ?? 'Other'} · ${data['location'] ?? 'Location not set'}',
                                      style: const TextStyle(
                                        color: AppTheme.textGrey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _showAssetForm(doc: doc);
                                  if (value == 'service') {
                                    _showServiceHistory(doc);
                                  }
                                  if (value == 'retire') {
                                    _setAssetStatus(doc, 'retired');
                                  }
                                  if (value == 'reactivate') {
                                    _setAssetStatus(doc, 'active');
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: AppText('Edit asset'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'service',
                                    child: AppText('Service history'),
                                  ),
                                  if (!retired)
                                    const PopupMenuItem(
                                      value: 'retire',
                                      child: AppText('Mark retired'),
                                    ),
                                  if (retired)
                                    const PopupMenuItem(
                                      value: 'reactivate',
                                      child: AppText('Reactivate'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _tag('Tag: ${data['assetTag'] ?? '—'}'),
                              _tag('Condition: ${condition.toUpperCase()}'),
                              _tag(
                                'Status: ${status.replaceAll('_', ' ').toUpperCase()}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AppText(
                            'Serial: ${_dateLabel(data['serialNumber'])}  ·  Warranty: ${_dateLabel(data['warrantyUntil'])}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                          if ((data['notes'] as String? ?? '')
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            AppText(
                              data['notes'] as String,
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _showServiceHistory(doc),
                              icon: const Icon(
                                Icons.build_circle_outlined,
                                size: 17,
                              ),
                              label: const AppText('Service records'),
                            ),
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
  }

  Widget _tag(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.lightGrey,
      borderRadius: BorderRadius.circular(20),
    ),
    child: AppText(
      value,
      style: const TextStyle(
        color: AppTheme.secondaryNavy,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Future<void> _setAssetStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    try {
      await doc.reference.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(
        status == 'retired' ? 'Asset marked as retired.' : 'Asset reactivated.',
      );
    } on FirebaseException catch (error) {
      _message('Unable to update asset: ${error.message ?? error.code}');
    }
  }

  Future<void> _showAssetForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final formKey = GlobalKey<FormState>();
    final tag = TextEditingController(text: data['assetTag'] as String? ?? '');
    final name = TextEditingController(text: data['name'] as String? ?? '');
    final location = TextEditingController(
      text: data['location'] as String? ?? '',
    );
    final serial = TextEditingController(
      text: data['serialNumber'] as String? ?? '',
    );
    final purchase = TextEditingController(
      text: data['purchaseDate'] as String? ?? '',
    );
    final warranty = TextEditingController(
      text: data['warrantyUntil'] as String? ?? '',
    );
    final notes = TextEditingController(text: data['notes'] as String? ?? '');
    String category = data['category'] as String? ?? _assetCategories.first;
    String condition = data['condition'] as String? ?? 'good';
    String status = data['status'] as String? ?? 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: AppText(
            doc == null ? 'Register colony asset' : 'Edit colony asset',
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(tag, 'Asset tag / ID', required: true),
                    _field(name, 'Asset name', required: true),
                    _field(location, 'Location / block', required: true),
                    _field(serial, 'Serial number (optional)'),
                    _dropdown(
                      'Category',
                      category,
                      _assetCategories,
                      (value) => setDialogState(() => category = value),
                    ),
                    _dropdown(
                      'Condition',
                      condition,
                      _assetConditions,
                      (value) => setDialogState(() => condition = value),
                    ),
                    if (doc != null)
                      _dropdown(
                        'Status',
                        status,
                        _assetStatuses,
                        (value) => setDialogState(() => status = value),
                      ),
                    _field(purchase, 'Purchase date (YYYY-MM-DD)'),
                    _field(warranty, 'Warranty expiry (YYYY-MM-DD)'),
                    _field(notes, 'Notes', maxLines: 3),
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
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const AppText('Save asset'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      final assetData = <String, dynamic>{
        'assetTag': tag.text.trim(),
        'name': name.text.trim(),
        'category': category,
        'location': location.text.trim(),
        'serialNumber': serial.text.trim(),
        'purchaseDate': purchase.text.trim(),
        'warrantyUntil': warranty.text.trim(),
        'condition': condition,
        'status': status,
        'notes': notes.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      try {
        if (doc == null) {
          assetData['createdBy'] = _uid;
          assetData['createdAt'] = FieldValue.serverTimestamp();
          await _colony.add(assetData);
        } else {
          await doc.reference.update(assetData);
        }
        _message(doc == null ? 'Asset registered.' : 'Asset updated.');
      } on FirebaseException catch (error) {
        _message('Unable to save asset: ${error.message ?? error.code}');
      }
    }
    tag.dispose();
    name.dispose();
    location.dispose();
    serial.dispose();
    purchase.dispose();
    warranty.dispose();
    notes.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: AppTranslations.translate(label)),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return AppTranslations.translate('This field is required.');
              }
              return null;
            }
          : null,
    ),
  );

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: AppTranslations.translate(label)),
      items: options
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: AppText(item.replaceAll('_', ' ')),
            ),
          )
          .toList(),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    ),
  );

  Future<void> _showServiceHistory(
    QueryDocumentSnapshot<Map<String, dynamic>> asset,
  ) async {
    final logs = asset.reference.collection('serviceLogs');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('Service history · ${asset.data()['name'] ?? 'Asset'}'),
        content: SizedBox(
          width: 480,
          height: 420,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _showServiceForm(asset),
                  icon: const Icon(Icons.add_rounded),
                  label: const AppText('Add service record'),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: logs.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: AppText('Unable to load service history.'),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.navyBlue,
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _empty(
                        'No service records',
                        'Record repairs, inspections and preventive maintenance.',
                        Icons.history_rounded,
                      );
                    }
                    final sorted = [...docs]
                      ..sort(
                        (a, b) => (b.data()['serviceDate'] as String? ?? '')
                            .compareTo(
                              a.data()['serviceDate'] as String? ?? '',
                            ),
                      );
                    return ListView.builder(
                      itemCount: sorted.length,
                      itemBuilder: (_, index) {
                        final item = sorted[index].data();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: AppText(
                            item['description'] as String? ?? 'Service',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: AppText(
                            '${item['serviceDate'] ?? ''} · ${item['vendorName'] ?? 'No vendor'}\nNext: ${item['nextServiceDate'] ?? 'Not scheduled'}',
                          ),
                          isThreeLine: true,
                          trailing: AppText(_money(item['cost'])),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
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

  Future<void> _showServiceForm(
    QueryDocumentSnapshot<Map<String, dynamic>> asset,
  ) async {
    final key = GlobalKey<FormState>();
    final date = TextEditingController(text: _todayKey());
    final vendor = TextEditingController();
    final description = TextEditingController();
    final cost = TextEditingController(text: '0');
    final nextDate = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Add service record'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(date, 'Service date (YYYY-MM-DD)', required: true),
                  _field(vendor, 'Vendor / technician'),
                  _field(
                    description,
                    'Work performed',
                    required: true,
                    maxLines: 3,
                  ),
                  _field(
                    cost,
                    'Service cost (₹)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _field(nextDate, 'Next service date (YYYY-MM-DD)'),
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
          ElevatedButton(
            onPressed: () {
              if (key.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const AppText('Save record'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      final amount = double.tryParse(cost.text.trim()) ?? 0;
      if (amount < 0) {
        _message('Service cost cannot be negative.');
      } else {
        try {
          await asset.reference.collection('serviceLogs').add({
            'serviceDate': date.text.trim(),
            'vendorName': vendor.text.trim(),
            'description': description.text.trim(),
            'cost': amount,
            'nextServiceDate': nextDate.text.trim(),
            'createdBy': _uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          _message('Service record saved.');
        } on FirebaseException catch (error) {
          _message(
            'Unable to save service record: ${error.message ?? error.code}',
          );
        }
      }
    }
    date.dispose();
    vendor.dispose();
    description.dispose();
    cost.dispose();
    nextDate.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Widget _inventoryTab() {
    return Column(
      children: [
        _sectionHeader(
          'Inventory & consumables',
          'Monitor stock on hand, minimum levels and issue history.',
          () => _showInventoryForm(),
          'Add item',
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _items.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _empty(
                  'Unable to load inventory',
                  'Check your connection and Firestore rules.',
                  Icons.error_outline_rounded,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.navyBlue),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _empty(
                  'No inventory items yet',
                  'Add cleaning supplies, electrical spares, plumbing parts and other consumables.',
                  Icons.inventory_2_outlined,
                );
              }
              final records = [...docs]
                ..sort(
                  (a, b) => (a.data()['name'] as String? ?? '')
                      .toLowerCase()
                      .compareTo(
                        (b.data()['name'] as String? ?? '').toLowerCase(),
                      ),
                );
              final active = records
                  .where((doc) => doc.data()['active'] != false)
                  .toList();
              final low = active.where((doc) {
                final d = doc.data();
                return (d['quantityOnHand'] as num? ?? 0) <=
                    (d['reorderLevel'] as num? ?? 0);
              }).length;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    margin: const EdgeInsets.only(bottom: 11),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppTheme.borderGrey),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _summaryMetric(
                            'Active items',
                            '${active.length}',
                            Icons.inventory_2_outlined,
                          ),
                        ),
                        Expanded(
                          child: _summaryMetric(
                            'Low stock',
                            '$low',
                            Icons.warning_amber_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...records.map((doc) {
                    final data = doc.data();
                    final quantity = (data['quantityOnHand'] as num? ?? 0)
                        .toDouble();
                    final reorder = (data['reorderLevel'] as num? ?? 0)
                        .toDouble();
                    final isLow =
                        data['active'] != false && quantity <= reorder;
                    return Card(
                      color: AppTheme.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText(
                                        data['name'] as String? ??
                                            'Inventory item',
                                        style: const TextStyle(
                                          color: AppTheme.textDark,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      AppText(
                                        '${data['category'] ?? 'Other'} · SKU ${data['sku'] ?? '—'} · ${data['storageLocation'] ?? 'Storage not set'}',
                                        style: const TextStyle(
                                          color: AppTheme.textGrey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showInventoryForm(doc: doc);
                                    }
                                    if (value == 'in') {
                                      _showMovementForm(doc, 'stock_in');
                                    }
                                    if (value == 'out') {
                                      _showMovementForm(doc, 'stock_out');
                                    }
                                    if (value == 'adjust') {
                                      _showMovementForm(doc, 'adjustment');
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: AppText('Edit item'),
                                    ),
                                    PopupMenuItem(
                                      value: 'in',
                                      child: AppText('Add stock'),
                                    ),
                                    PopupMenuItem(
                                      value: 'out',
                                      child: AppText('Issue stock'),
                                    ),
                                    PopupMenuItem(
                                      value: 'adjust',
                                      child: AppText('Set physical count'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                AppText(
                                  '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2)} ${data['unit'] ?? 'unit'}',
                                  style: const TextStyle(
                                    color: AppTheme.navyBlue,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                if (isLow)
                                  _tag('LOW STOCK')
                                else
                                  _tag('IN STOCK'),
                              ],
                            ),
                            const SizedBox(height: 5),
                            AppText(
                              'Reorder at ${reorder.toStringAsFixed(0)} ${data['unit'] ?? 'unit'} · Unit cost ${_money(data['unitCost'])}',
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _showMovementForm(doc, 'stock_in'),
                                    icon: const Icon(Icons.add_box_outlined),
                                    label: const AppText('Stock in'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _showMovementForm(doc, 'stock_out'),
                                    icon: const Icon(Icons.outbox_outlined),
                                    label: const AppText('Issue stock'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _summaryMetric(String label, String value, IconData icon) => Row(
    children: [
      Icon(icon, color: AppTheme.navyBlue, size: 19),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            value,
            style: const TextStyle(
              color: AppTheme.navyBlue,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          AppText(
            label,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
          ),
        ],
      ),
    ],
  );

  Future<void> _showInventoryForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final key = GlobalKey<FormState>();
    final name = TextEditingController(text: data['name'] as String? ?? '');
    final sku = TextEditingController(text: data['sku'] as String? ?? '');
    final storage = TextEditingController(
      text: data['storageLocation'] as String? ?? '',
    );
    final reorder = TextEditingController(text: '${data['reorderLevel'] ?? 0}');
    final cost = TextEditingController(text: '${data['unitCost'] ?? 0}');
    final opening = TextEditingController(text: '0');
    String category = data['category'] as String? ?? _inventoryCategories.first;
    String unit = data['unit'] as String? ?? 'piece';
    bool active = data['active'] as bool? ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: AppText(
            doc == null ? 'Add inventory item' : 'Edit inventory item',
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(name, 'Item name', required: true),
                    _field(sku, 'SKU / internal code'),
                    _dropdown(
                      'Category',
                      category,
                      _inventoryCategories,
                      (value) => setDialogState(() => category = value),
                    ),
                    _dropdown(
                      'Unit',
                      unit,
                      _units.map((e) => e.trim()).toList(),
                      (value) => setDialogState(() => unit = value),
                    ),
                    _field(
                      reorder,
                      'Reorder level',
                      required: true,
                      keyboardType: TextInputType.number,
                    ),
                    _field(
                      cost,
                      'Unit cost (₹)',
                      required: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    _field(storage, 'Storage location'),
                    if (doc == null)
                      _field(
                        opening,
                        'Opening quantity',
                        required: true,
                        keyboardType: TextInputType.number,
                      ),
                    if (doc != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: active,
                        title: const AppText('Item active'),
                        onChanged: (value) =>
                            setDialogState(() => active = value),
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
            ElevatedButton(
              onPressed: () {
                if (key.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const AppText('Save item'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      final reorderValue = int.tryParse(reorder.text.trim());
      final costValue = double.tryParse(cost.text.trim());
      final openingValue = int.tryParse(opening.text.trim()) ?? 0;
      if (reorderValue == null ||
          reorderValue < 0 ||
          costValue == null ||
          costValue < 0 ||
          openingValue < 0) {
        _message('Enter valid non-negative stock and cost values.');
      } else {
        try {
          if (doc == null) {
            final itemRef = _items.doc();
            final movementRef = _movements.doc();
            await FirebaseFirestore.instance.runTransaction((
              transaction,
            ) async {
              transaction.set(itemRef, {
                'name': name.text.trim(),
                'sku': sku.text.trim(),
                'category': category,
                'unit': unit,
                'quantityOnHand': openingValue,
                'reorderLevel': reorderValue,
                'unitCost': costValue,
                'storageLocation': storage.text.trim(),
                'active': true,
                'createdBy': _uid,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (openingValue > 0) {
                transaction.set(movementRef, {
                  'inventoryItemId': itemRef.id,
                  'itemName': name.text.trim(),
                  'transactionType': 'stock_in',
                  'quantity': openingValue,
                  'previousQuantity': 0,
                  'resultingQuantity': openingValue,
                  'change': openingValue,
                  'reason': 'Opening stock',
                  'reference': '',
                  'performedBy': _uid,
                  'performedByName': widget.adminName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
            });
          } else {
            await doc.reference.update({
              'name': name.text.trim(),
              'sku': sku.text.trim(),
              'category': category,
              'unit': unit,
              'reorderLevel': reorderValue,
              'unitCost': costValue,
              'storageLocation': storage.text.trim(),
              'active': active,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          _message(
            doc == null ? 'Inventory item added.' : 'Inventory item updated.',
          );
        } on FirebaseException catch (error) {
          _message(
            'Unable to save inventory item: ${error.message ?? error.code}',
          );
        }
      }
    }
    name.dispose();
    sku.dispose();
    storage.dispose();
    reorder.dispose();
    cost.dispose();
    opening.dispose();
  }

  Future<void> _showMovementForm(
    QueryDocumentSnapshot<Map<String, dynamic>> item,
    String type,
  ) async {
    final data = item.data();
    if (data['active'] == false) {
      _message(
        'This inventory item is inactive. Reactivate it before recording stock.',
      );
      return;
    }
    final quantity = TextEditingController();
    final reason = TextEditingController();
    final reference = TextEditingController();
    final key = GlobalKey<FormState>();
    final isAdjustment = type == 'adjustment';
    final label = type == 'stock_in'
        ? 'Add stock'
        : type == 'stock_out'
        ? 'Issue stock'
        : 'Set physical stock count';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(label),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppText(
                    '${data['name'] ?? 'Item'} · Current: ${data['quantityOnHand'] ?? 0} ${data['unit'] ?? ''}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  quantity,
                  isAdjustment ? 'Physical count' : 'Quantity',
                  required: true,
                  keyboardType: TextInputType.number,
                ),
                _field(reason, 'Reason / purpose', required: true, maxLines: 2),
                _field(reference, 'Reference (optional)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (key.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const AppText('Save movement'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      final amount = int.tryParse(quantity.text.trim());
      if (amount == null || amount < 0 || (!isAdjustment && amount == 0)) {
        _message(
          isAdjustment
              ? 'Enter a valid physical count.'
              : 'Quantity must be greater than zero.',
        );
      } else {
        try {
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final fresh = await transaction.get(item.reference);
            if (!fresh.exists) {
              throw StateError('Inventory item no longer exists.');
            }
            final currentData = fresh.data() ?? <String, dynamic>{};
            final current = (currentData['quantityOnHand'] as num? ?? 0)
                .toInt();
            int resulting;
            if (type == 'stock_in') {
              resulting = current + amount;
            } else if (type == 'stock_out') {
              if (amount > current) {
                throw StateError('Insufficient stock. Available: $current.');
              }
              resulting = current - amount;
            } else {
              resulting = amount;
            }
            final delta = resulting - current;
            final movementRef = _movements.doc();
            transaction.update(item.reference, {
              'quantityOnHand': resulting,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            transaction.set(movementRef, {
              'inventoryItemId': item.id,
              'itemName': currentData['name'] as String? ?? 'Inventory item',
              'transactionType': type,
              'quantity': amount,
              'previousQuantity': current,
              'resultingQuantity': resulting,
              'change': delta,
              'reason': reason.text.trim(),
              'reference': reference.text.trim(),
              'performedBy': _uid,
              'performedByName': widget.adminName,
              'createdAt': FieldValue.serverTimestamp(),
            });
          });
          _message('Inventory movement saved.');
        } on StateError catch (error) {
          _message(error.message.toString());
        } on FirebaseException catch (error) {
          _message('Unable to update stock: ${error.message ?? error.code}');
        }
      }
    }
    quantity.dispose();
    reason.dispose();
    reference.dispose();
  }

  Widget _movementsTab(BuildContext tabContext) {
    return Column(
      children: [
        _sectionHeader(
          'Stock movement history',
          'Audit trail of stock received, issued and physical-count adjustments.',
          () => DefaultTabController.of(tabContext).animateTo(1),
          'View inventory',
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _movements
                .orderBy('createdAt', descending: true)
                .limit(150)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _empty(
                  'Unable to load stock history',
                  'Check your connection and Firestore rules.',
                  Icons.error_outline_rounded,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.navyBlue),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _empty(
                  'No stock movements yet',
                  'All stock-in, issue and adjustment records will appear here.',
                  Icons.history_rounded,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final type =
                      data['transactionType'] as String? ?? 'adjustment';
                  final change = (data['change'] as num? ?? 0).toInt();
                  final sign = change > 0 ? '+' : '';
                  final when = data['createdAt'];
                  final dateLabel = when is Timestamp
                      ? when.toDate().toLocal().toString().substring(0, 16)
                      : 'Recently recorded';
                  return Card(
                    elevation: 0,
                    color: AppTheme.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                      side: const BorderSide(color: AppTheme.borderGrey),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.lightGrey,
                        child: Icon(
                          type == 'stock_in'
                              ? Icons.add_rounded
                              : type == 'stock_out'
                              ? Icons.remove_rounded
                              : Icons.tune_rounded,
                          color: AppTheme.navyBlue,
                        ),
                      ),
                      title: AppText(
                        data['itemName'] as String? ?? 'Inventory item',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      subtitle: AppText(
                        '${type.replaceAll('_', ' ').toUpperCase()} · ${data['reason'] ?? ''}\n${data['performedByName'] ?? 'Admin'} · $dateLabel',
                      ),
                      isThreeLine: true,
                      trailing: AppText(
                        '$sign$change',
                        style: const TextStyle(
                          color: AppTheme.navyBlue,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
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
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: AppTheme.lightGrey,
            appBar: AppBar(
              title: const AppText(
                'Assets & Inventory',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              bottom: TabBar(
                labelColor: AppTheme.navyBlue,
                unselectedLabelColor: AppTheme.textGrey,
                indicatorColor: AppTheme.navyBlue,
                tabs: [
                  Tab(
                    icon: Icon(Icons.precision_manufacturing_outlined),
                    text: AppTranslations.translate('Assets'),
                  ),
                  Tab(
                    icon: Icon(Icons.inventory_2_outlined),
                    text: AppTranslations.translate('Inventory'),
                  ),
                  Tab(
                    icon: Icon(Icons.history_rounded),
                    text: AppTranslations.translate('Movements'),
                  ),
                ],
              ),
            ),
            body: Builder(
              builder: (tabContext) => TabBarView(
                children: [
                  _assetsTab(),
                  _inventoryTab(),
                  _movementsTab(tabContext),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
// COLONY_ASSET_INVENTORY_SCREEN_END
