// PREVENTIVE_MAINTENANCE_AMC_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Admin-only preventive maintenance calendar and AMC register.
/// Completing a plan writes to the existing asset serviceLogs history.
class PreventiveMaintenanceScreen extends StatefulWidget {
  const PreventiveMaintenanceScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<PreventiveMaintenanceScreen> createState() =>
      _PreventiveMaintenanceScreenState();
}

class _PreventiveMaintenanceScreenState
    extends State<PreventiveMaintenanceScreen> {
  CollectionReference<Map<String, dynamic>> get _colony => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('colonyAssets');

  CollectionReference<Map<String, dynamic>> get _plans => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('preventiveMaintenancePlans');

  CollectionReference<Map<String, dynamic>> get _contracts => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('assetAmcContracts');

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const List<String> _frequencies = [
    'monthly',
    'quarterly',
    'half_yearly',
    'yearly',
  ];

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
    );
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  DateTime? _parseDate(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  String _money(Object? value) =>
      '₹${(value is num ? value.toDouble() : 0).toStringAsFixed(2)}';

  String _frequencyLabel(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  DateTime _addFrequency(DateTime from, String frequency) {
    final months = switch (frequency) {
      'monthly' => 1,
      'quarterly' => 3,
      'half_yearly' => 6,
      'yearly' => 12,
      _ => 1,
    };
    final targetMonth = from.month - 1 + months;
    final year = from.year + targetMonth ~/ 12;
    final month = targetMonth % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, from.day > lastDay ? lastDay : from.day);
  }

  String _dueLabel(String value) {
    final date = _parseDate(value);
    if (date == null) return 'Date not set';
    final today = DateTime.now();
    final startToday = DateTime(today.year, today.month, today.day);
    final days = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(startToday).inDays;
    if (days < 0) {
      return 'Overdue by ${days.abs()} day${days.abs() == 1 ? '' : 's'}';
    }
    if (days == 0) return 'Due today';
    if (days <= 30) return 'Due in $days day${days == 1 ? '' : 's'}';
    return 'Scheduled';
  }

  Color _dueColor(String value) {
    final date = _parseDate(value);
    if (date == null) return AppTheme.textGrey;
    final now = DateTime.now();
    final days = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return const Color(0xFF9B2C2C);
    if (days <= 30) return AppTheme.secondaryNavy;
    return AppTheme.textGrey;
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
            textAlign: TextAlign.center,
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

  Widget _tag(String value, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.lightGrey,
      borderRadius: BorderRadius.circular(20),
    ),
    child: AppText(
      value,
      style: TextStyle(
        color: color ?? AppTheme.secondaryNavy,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          backgroundColor: AppTheme.white,
          foregroundColor: AppTheme.navyBlue,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Preventive Maintenance & AMC',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              AppText(
                widget.colonyName,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: AppTranslations.translate('Add maintenance record'),
              onSelected: (value) {
                if (value == 'plan') _showPlanForm();
                if (value == 'contract') _showContractForm();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'plan',
                  child: AppText('Add maintenance plan'),
                ),
                PopupMenuItem(
                  value: 'contract',
                  child: AppText('Add AMC contract'),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
          bottom: TabBar(
            labelColor: AppTheme.navyBlue,
            unselectedLabelColor: AppTheme.textGrey,
            indicatorColor: AppTheme.navyBlue,
            tabs: [
              Tab(
                icon: Icon(Icons.event_repeat_outlined),
                text: AppTranslations.translate('Plans'),
              ),
              Tab(
                icon: Icon(Icons.warning_amber_rounded),
                text: AppTranslations.translate('Due soon'),
              ),
              Tab(
                icon: Icon(Icons.description_outlined),
                text: AppTranslations.translate('AMC contracts'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _plansTab(dueOnly: false),
            _plansTab(dueOnly: true),
            _contractsTab(),
          ],
        ),
      ),
    );
  }

  Widget _plansTab({
    required bool dueOnly,
  }) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _plans.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _empty(
          'Unable to load maintenance plans',
          'Check your connection and the deployed Firestore rules.',
          Icons.error_outline_rounded,
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyBlue),
        );
      }
      final today = DateTime.now();
      final limit = today.add(const Duration(days: 30));
      final records =
          snapshot.data?.docs.where((doc) {
            final data = doc.data();
            if (data['status'] != 'active') return false;
            if (!dueOnly) return true;
            final due = _parseDate(data['nextDueDate']);
            return due != null &&
                !due.isAfter(DateTime(limit.year, limit.month, limit.day));
          }).toList() ??
          [];
      records.sort(
        (a, b) => (a.data()['nextDueDate'] as String? ?? '9999-99-99')
            .compareTo(b.data()['nextDueDate'] as String? ?? '9999-99-99'),
      );
      if (records.isEmpty) {
        return _empty(
          dueOnly
              ? 'Nothing due in the next 30 days'
              : 'No maintenance plans yet',
          dueOnly ? 'Overdue and upcoming active plans will appear here.' : 'Create recurring service plans for lifts, generators, pumps, CCTV and other assets.',
          dueOnly ? Icons.task_alt_rounded : Icons.event_repeat_outlined,
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        itemCount: records.length,
        itemBuilder: (context, index) {
          final doc = records[index];
          final data = doc.data();
          final due = data['nextDueDate'] as String? ?? '';
          final status = data['status'] as String? ?? 'active';
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.lightGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.precision_manufacturing_outlined,
                          color: AppTheme.navyBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              data['taskName'] as String? ?? 'Maintenance plan',
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            AppText(
                              '${data['assetName'] ?? 'Asset'} · ${data['assetTag'] ?? ''}',
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
                          if (value == 'edit') _showPlanForm(doc: doc);
                          if (value == 'history') _showPlanHistory(doc);
                          if (value == 'pause') _setPlanStatus(doc, 'paused');
                          if (value == 'resume') _setPlanStatus(doc, 'active');
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: AppText('Edit plan'),
                          ),
                          const PopupMenuItem(
                            value: 'history',
                            child: AppText('Completion history'),
                          ),
                          if (status == 'active')
                            const PopupMenuItem(
                              value: 'pause',
                              child: AppText('Pause plan'),
                            ),
                          if (status == 'paused')
                            const PopupMenuItem(
                              value: 'resume',
                              child: AppText('Resume plan'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _tag(
                        'Every ${_frequencyLabel(data['frequency'] as String? ?? 'monthly')}',
                      ),
                      _tag(_dueLabel(due), color: _dueColor(due)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  AppText(
                    'Next due: ${due.isEmpty ? 'Not set' : due} · Vendor: ${data['vendorName'] ?? 'Not assigned'}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                  AppText(
                    'Estimated cost: ${_money(data['estimatedCost'])}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                  if ((data['notes'] as String? ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    AppText(
                      data['notes'] as String,
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _showCompletionForm(doc),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 17,
                      ),
                      label: const AppText('Mark service completed'),
                      style: FilledButton.styleFrom(
                        foregroundColor: AppTheme.navyBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  Widget _contractsTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(
          children: [
            const Expanded(
              child: AppText(
                'Asset warranty and AMC coverage',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _showContractForm,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const AppText('Add contract'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _contracts.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _empty(
                'Unable to load AMC contracts',
                'Check your connection and the deployed Firestore rules.',
                Icons.error_outline_rounded,
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.navyBlue),
              );
            }
            final docs = snapshot.data?.docs.toList() ?? [];
            docs.sort(
              (a, b) => (a.data()['endDate'] as String? ?? '').compareTo(
                b.data()['endDate'] as String? ?? '',
              ),
            );
            if (docs.isEmpty) {
              return _empty(
                'No AMC contracts recorded',
                'Register service agreements, annual maintenance contracts and warranty coverage.',
                Icons.description_outlined,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 18),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final end = _parseDate(data['endDate']);
                final today = DateTime.now();
                final expired =
                    end != null &&
                    end.isBefore(
                      DateTime(today.year, today.month, today.day),
                    ) &&
                    data['status'] != 'cancelled';
                final status = data['status'] == 'cancelled'
                    ? 'Cancelled'
                    : expired
                    ? 'Expired'
                    : 'Active';
                final tone = status == 'Active'
                    ? AppTheme.secondaryNavy
                    : status == 'Expired'
                    ? const Color(0xFF9B2C2C)
                    : AppTheme.textGrey;
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
                            Expanded(
                              child: AppText(
                                data['contractNumber'] as String? ??
                                    'AMC contract',
                                style: const TextStyle(
                                  color: AppTheme.textDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            _tag(status.toUpperCase(), color: tone),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showContractForm(doc: doc);
                                }
                                if (value == 'cancel') {
                                  _setContractStatus(doc, 'cancelled');
                                }
                                if (value == 'activate') {
                                  _setContractStatus(doc, 'active');
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: AppText('Edit contract'),
                                ),
                                if (data['status'] != 'cancelled')
                                  const PopupMenuItem(
                                    value: 'cancel',
                                    child: AppText('Cancel contract'),
                                  ),
                                if (data['status'] == 'cancelled')
                                  const PopupMenuItem(
                                    value: 'activate',
                                    child: AppText('Reactivate contract'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        AppText(
                          '${data['assetName'] ?? 'Asset'} · ${data['vendorName'] ?? 'Vendor not set'}',
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppText(
                          '${data['startDate'] ?? ''} to ${data['endDate'] ?? ''} · Annual cost ${_money(data['annualCost'])}',
                          style: const TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 11,
                          ),
                        ),
                        if ((data['vendorPhone'] as String? ?? '').isNotEmpty)
                          AppText(
                            'Vendor contact: ${data['vendorPhone']}',
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        if ((data['coverage'] as String? ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 5),
                          AppText(
                            data['coverage'] as String,
                            style: const TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        ],
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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadAssets({
    bool includeRetired = false,
  }) async {
    final snapshot = await _colony.get();
    return snapshot.docs
        .where((doc) => includeRetired || doc.data()['status'] != 'retired')
        .toList();
  }

  Future<void> _showPlanForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assets;
    try {
      assets = await _loadAssets(includeRetired: doc != null);
    } on FirebaseException catch (error) {
      _message('Unable to load assets: ${error.message ?? error.code}');
      return;
    }
    if (!mounted) return;
    if (assets.isEmpty) {
      _message('Add a colony asset before creating a maintenance plan.');
      return;
    }
    final data = doc?.data() ?? <String, dynamic>{};
    String? assetId = data['assetId'] as String? ?? assets.first.id;
    String frequency = data['frequency'] as String? ?? 'quarterly';
    final task = TextEditingController(text: data['taskName'] as String? ?? '');
    final due = TextEditingController(
      text: data['nextDueDate'] as String? ?? '',
    );
    final vendor = TextEditingController(
      text: data['vendorName'] as String? ?? '',
    );
    final cost = TextEditingController(text: '${data['estimatedCost'] ?? 0}');
    final notes = TextEditingController(text: data['notes'] as String? ?? '');
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: AppText(
            doc == null ? 'Create maintenance plan' : 'Edit maintenance plan',
          ),
          content: SizedBox(
            width: 470,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: assetId,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Colony asset'),
                      ),
                      items: assets
                          .map(
                            (asset) => DropdownMenuItem(
                              value: asset.id,
                              child: AppText(
                                '${asset.data()['name'] ?? 'Asset'} · ${asset.data()['assetTag'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => assetId = value),
                      validator: (value) => value == null
                          ? AppTranslations.translate('Select an asset')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: task,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Maintenance activity *',
                        ),
                        hintText: AppTranslations.translate(
                          'e.g. Lift safety inspection',
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? AppTranslations.translate('Enter an activity')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Frequency'),
                      ),
                      items: _frequencies
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: AppText(_frequencyLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => frequency = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: due,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Next due date *'),
                        hintText: AppTranslations.translate('YYYY-MM-DD'),
                      ),
                      validator: (value) => _parseDate(value) == null
                          ? AppTranslations.translate(
                              'Enter date as YYYY-MM-DD',
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: vendor,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Preferred vendor / technician',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: cost,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Estimated service cost (₹)',
                        ),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(value ?? '');
                        return amount == null || !amount.isFinite || amount < 0
                            ? AppTranslations.translate(
                                'Enter a valid non-negative amount',
                              )
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notes,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Instructions / notes',
                        ),
                      ),
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
              child: const AppText('Save plan'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted && assetId != null) {
      final selected = assets.where((asset) => asset.id == assetId).first;
      final assetData = selected.data();
      final payload = <String, dynamic>{
        'assetId': selected.id,
        'assetName': assetData['name'] as String? ?? 'Asset',
        'assetTag': assetData['assetTag'] as String? ?? '',
        'taskName': task.text.trim(),
        'frequency': frequency,
        'nextDueDate': due.text.trim(),
        'vendorName': vendor.text.trim(),
        'estimatedCost': double.parse(cost.text.trim()),
        'notes': notes.text.trim(),
        'status': data['status'] as String? ?? 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      try {
        if (doc == null) {
          payload['createdBy'] = _uid;
          payload['createdAt'] = FieldValue.serverTimestamp();
          payload['lastCompletedDate'] = '';
          await _plans.add(payload);
          _message('Preventive maintenance plan created.');
        } else {
          await doc.reference.update(payload);
          _message('Maintenance plan updated.');
        }
      } on FirebaseException catch (error) {
        _message('Unable to save plan: ${error.message ?? error.code}');
      }
    }
    task.dispose();
    due.dispose();
    vendor.dispose();
    cost.dispose();
    notes.dispose();
  }

  Future<void> _showCompletionForm(
    QueryDocumentSnapshot<Map<String, dynamic>> plan,
  ) async {
    final data = plan.data();
    final serviceDate = TextEditingController(text: _dateKey(DateTime.now()));
    final vendor = TextEditingController(
      text: data['vendorName'] as String? ?? '',
    );
    final description = TextEditingController(
      text: data['taskName'] as String? ?? 'Preventive maintenance',
    );
    final cost = TextEditingController(text: '${data['estimatedCost'] ?? 0}');
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Record completed service'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  'Asset: ${data['assetName'] ?? 'Asset'}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: serviceDate,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate(
                      'Service date (YYYY-MM-DD)',
                    ),
                  ),
                  validator: (value) => _parseDate(value) == null
                      ? AppTranslations.translate('Enter date as YYYY-MM-DD')
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: vendor,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Vendor / technician'),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: description,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Work performed *'),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? AppTranslations.translate('Describe the work')
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: cost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate(
                      'Actual service cost (₹)',
                    ),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value ?? '');
                    return amount == null || amount < 0
                        ? AppTranslations.translate('Enter a valid amount')
                        : null;
                  },
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
          ElevatedButton(
            onPressed: () {
              if (key.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const AppText('Save completion'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      final completed = _parseDate(serviceDate.text.trim())!;
      final nextDue = _dateKey(
        _addFrequency(completed, data['frequency'] as String? ?? 'monthly'),
      );
      final amount = double.parse(cost.text.trim());
      final assetRef = _colony.doc(data['assetId'] as String);
      final planLog = plan.reference.collection('completionLogs').doc();
      final assetLog = assetRef.collection('serviceLogs').doc();
      try {
        final batch = FirebaseFirestore.instance.batch();
        batch.set(planLog, {
          'planId': plan.id,
          'assetId': data['assetId'],
          'assetName': data['assetName'] ?? 'Asset',
          'taskName': data['taskName'] ?? 'Preventive maintenance',
          'serviceDate': serviceDate.text.trim(),
          'vendorName': vendor.text.trim(),
          'description': description.text.trim(),
          'cost': amount,
          'nextDueDate': nextDue,
          'performedBy': _uid,
          'performedByName': widget.adminName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(assetLog, {
          'serviceDate': serviceDate.text.trim(),
          'vendorName': vendor.text.trim(),
          'description': description.text.trim(),
          'cost': amount,
          'nextServiceDate': nextDue,
          'createdBy': _uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(plan.reference, {
          'lastCompletedDate': serviceDate.text.trim(),
          'nextDueDate': nextDue,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
        _message('Service completion saved. Next due: $nextDue');
      } on FirebaseException catch (error) {
        _message('Unable to save completion: ${error.message ?? error.code}');
      }
    }
    serviceDate.dispose();
    vendor.dispose();
    description.dispose();
    cost.dispose();
  }

  Future<void> _showPlanHistory(
    QueryDocumentSnapshot<Map<String, dynamic>> plan,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(
          'Completion history · ${plan.data()['taskName'] ?? 'Plan'}',
        ),
        content: SizedBox(
          width: 460,
          height: 390,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: plan.reference.collection('completionLogs').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: AppText('Unable to load completion history.'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs.toList() ?? [];
              docs.sort(
                (a, b) => (b.data()['serviceDate'] as String? ?? '').compareTo(
                  a.data()['serviceDate'] as String? ?? '',
                ),
              );
              if (docs.isEmpty) {
                return _empty(
                  'No completed services',
                  'Recorded completions will appear here.',
                  Icons.history_rounded,
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, index) {
                  final data = docs[index].data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: AppText(
                      data['description'] as String? ?? 'Service',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: AppText(
                      '${data['serviceDate'] ?? ''} · ${data['vendorName'] ?? 'No vendor'}',
                    ),
                    trailing: AppText(_money(data['cost'])),
                  );
                },
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

  Future<void> _setPlanStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> plan,
    String status,
  ) async {
    try {
      await plan.reference.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(
        status == 'active'
            ? 'Maintenance plan resumed.'
            : 'Maintenance plan paused.',
      );
    } on FirebaseException catch (error) {
      _message('Unable to update plan: ${error.message ?? error.code}');
    }
  }

  Future<void> _showContractForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assets;
    try {
      assets = await _loadAssets(includeRetired: doc != null);
    } on FirebaseException catch (error) {
      _message('Unable to load assets: ${error.message ?? error.code}');
      return;
    }
    if (!mounted) return;
    if (assets.isEmpty) {
      _message('Add a colony asset before registering an AMC contract.');
      return;
    }
    final data = doc?.data() ?? <String, dynamic>{};
    String? assetId = data['assetId'] as String? ?? assets.first.id;
    String status = data['status'] as String? ?? 'active';
    final number = TextEditingController(
      text: data['contractNumber'] as String? ?? '',
    );
    final vendor = TextEditingController(
      text: data['vendorName'] as String? ?? '',
    );
    final phone = TextEditingController(
      text: data['vendorPhone'] as String? ?? '',
    );
    final start = TextEditingController(
      text: data['startDate'] as String? ?? '',
    );
    final end = TextEditingController(text: data['endDate'] as String? ?? '');
    final amount = TextEditingController(text: '${data['annualCost'] ?? 0}');
    final coverage = TextEditingController(
      text: data['coverage'] as String? ?? '',
    );
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: AppText(
            doc == null ? 'Register AMC contract' : 'Edit AMC contract',
          ),
          content: SizedBox(
            width: 470,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: assetId,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Linked asset'),
                      ),
                      items: assets
                          .map(
                            (asset) => DropdownMenuItem(
                              value: asset.id,
                              child: AppText(
                                '${asset.data()['name'] ?? 'Asset'} · ${asset.data()['assetTag'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => assetId = value),
                      validator: (value) => value == null
                          ? AppTranslations.translate('Select an asset')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: number,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Contract number / reference *',
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? AppTranslations.translate(
                              'Enter a contract reference',
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: vendor,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Vendor / service provider *',
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? AppTranslations.translate('Enter a vendor name')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Vendor phone / contact',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: start,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Contract start date (YYYY-MM-DD)',
                        ),
                      ),
                      validator: (value) => _parseDate(value) == null
                          ? AppTranslations.translate(
                              'Enter a valid start date',
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: end,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Contract end date (YYYY-MM-DD)',
                        ),
                      ),
                      validator: (value) {
                        final a = _parseDate(start.text);
                        final b = _parseDate(value);
                        return b == null || a == null || !b.isAfter(a)
                            ? AppTranslations.translate(
                                'End date must be after start date',
                              )
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Annual contract cost (₹)',
                        ),
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value ?? '');
                        return parsed == null || !parsed.isFinite || parsed < 0
                            ? AppTranslations.translate(
                                'Enter a valid non-negative amount',
                              )
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: coverage,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Coverage / exclusions / service terms',
                        ),
                      ),
                    ),
                    if (doc != null)
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Contract status',
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'active',
                            child: AppText('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: AppText('Cancelled'),
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
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (key.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const AppText('Save contract'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted && assetId != null) {
      final selected = assets.where((asset) => asset.id == assetId).first;
      final assetData = selected.data();
      final payload = <String, dynamic>{
        'assetId': selected.id,
        'assetName': assetData['name'] as String? ?? 'Asset',
        'assetTag': assetData['assetTag'] as String? ?? '',
        'contractNumber': number.text.trim(),
        'vendorName': vendor.text.trim(),
        'vendorPhone': phone.text.trim(),
        'startDate': start.text.trim(),
        'endDate': end.text.trim(),
        'annualCost': double.parse(amount.text.trim()),
        'coverage': coverage.text.trim(),
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      try {
        if (doc == null) {
          payload['createdBy'] = _uid;
          payload['createdAt'] = FieldValue.serverTimestamp();
          await _contracts.add(payload);
          _message('AMC contract registered.');
        } else {
          await doc.reference.update(payload);
          _message('AMC contract updated.');
        }
      } on FirebaseException catch (error) {
        _message('Unable to save contract: ${error.message ?? error.code}');
      }
    }
    number.dispose();
    vendor.dispose();
    phone.dispose();
    start.dispose();
    end.dispose();
    amount.dispose();
    coverage.dispose();
  }

  Future<void> _setContractStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> contract,
    String status,
  ) async {
    try {
      await contract.reference.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(
        status == 'active' ? 'Contract reactivated.' : 'Contract cancelled.',
      );
    } on FirebaseException catch (error) {
      _message('Unable to update contract: ${error.message ?? error.code}');
    }
  }
}
// PREVENTIVE_MAINTENANCE_AMC_SCREEN_END
