// COLONY_BUDGET_EXPENSE_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Admin-only colony outflow ledger and monthly category budgets.
/// Resident maintenance collections remain in Maintenance Dues.
class ColonyBudgetExpenseScreen extends StatefulWidget {
  const ColonyBudgetExpenseScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<ColonyBudgetExpenseScreen> createState() =>
      _ColonyBudgetExpenseScreenState();
}

class _ColonyBudgetExpenseScreenState extends State<ColonyBudgetExpenseScreen> {
  CollectionReference<Map<String, dynamic>> get _expenses => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('colonyExpenses');

  CollectionReference<Map<String, dynamic>> get _budgets => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('colonyBudgets');

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const Map<String, String> _categories = {
    'utilities': 'Utilities',
    'water': 'Water',
    'security': 'Security',
    'housekeeping': 'Housekeeping',
    'repairs': 'Repairs',
    'landscaping': 'Landscaping',
    'staff': 'Staff',
    'insurance': 'Insurance',
    'administration': 'Administration',
    'other': 'Other',
  };

  static const Map<String, String> _paymentMethods = {
    'upi': 'UPI',
    'bank_transfer': 'Bank transfer',
    'cash': 'Cash',
    'cheque': 'Cheque',
    'card': 'Card',
    'other': 'Other',
  };

  String _monthKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';

  String _dateLabel(Object? value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (date == null) return 'Date not set';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return key;
    return '${months[month - 1]} ${parts[0]}';
  }

  String _money(Object? value) =>
      '₹${(value is num ? value.toDouble() : 0).toStringAsFixed(2)}';

  double _number(Object? value) => value is num ? value.toDouble() : 0;

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(value), behavior: SnackBarBehavior.floating),
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

  Widget _metric(
    String label,
    String value,
    IconData icon, {
    String? subtitle,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.borderGrey),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.secondaryNavy, size: 21),
        const SizedBox(height: 12),
        AppText(
          value,
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        AppText(
          label,
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          AppText(
            subtitle,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
          ),
        ],
      ],
    ),
  );

  Widget _tag(String value, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.lightGrey,
      borderRadius: BorderRadius.circular(18),
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
                'Colony Budget & Expenses',
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
              tooltip: AppTranslations.translate('Add financial record'),
              onSelected: (value) {
                if (value == 'expense') _showExpenseForm();
                if (value == 'budget') _showBudgetForm();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'expense',
                  child: AppText('Record expense'),
                ),
                PopupMenuItem(
                  value: 'budget',
                  child: AppText('Set monthly budget'),
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
                icon: Icon(Icons.account_balance_wallet_outlined),
                text: AppTranslations.translate('Overview'),
              ),
              Tab(
                icon: Icon(Icons.receipt_long_outlined),
                text: AppTranslations.translate('Expenses'),
              ),
              Tab(
                icon: Icon(Icons.pie_chart_outline_rounded),
                text: AppTranslations.translate('Budgets'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [_overviewTab(), _expensesTab(), _budgetsTab()],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.navyBlue,
          foregroundColor: AppTheme.white,
          onPressed: _showExpenseForm,
          icon: const Icon(Icons.add),
          label: const AppText('Expense'),
        ),
      ),
    );
  }

  Widget _overviewTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _expenses.snapshots(),
    builder: (context, expenseSnapshot) {
      if (expenseSnapshot.hasError) {
        return _empty(
          'Unable to load expense records',
          'Check your connection and deployed Firestore rules.',
          Icons.error_outline_rounded,
        );
      }
      if (expenseSnapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyBlue),
        );
      }
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _budgets.snapshots(),
        builder: (context, budgetSnapshot) {
          if (budgetSnapshot.hasError) {
            return _empty(
              'Unable to load budgets',
              'Check Firestore access.',
              Icons.error_outline_rounded,
            );
          }
          if (budgetSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.navyBlue),
            );
          }
          final month = _monthKey(DateTime.now());
          final expenses =
              expenseSnapshot.data?.docs.map((d) => d.data()).toList() ?? [];
          final budgets =
              budgetSnapshot.data?.docs.map((d) => d.data()).toList() ?? [];
          final monthExpenses = expenses
              .where((e) => e['monthKey'] == month)
              .toList();
          final paid = monthExpenses.fold<double>(
            0,
            (accumulator, e) => accumulator + _number(e['amountPaid']),
          );
          final committed = monthExpenses.fold<double>(
            0,
            (accumulator, e) => accumulator + _number(e['amount']),
          );
          final monthBudgets = budgets
              .where((b) => b['monthKey'] == month)
              .toList();
          final budgetTotal = monthBudgets.fold<double>(
            0,
            (accumulator, b) => accumulator + _number(b['budgetAmount']),
          );
          final remaining = budgetTotal - paid;
          final outstanding = monthExpenses.fold<double>(
            0,
            (accumulator, e) =>
                accumulator + (_number(e['amount']) - _number(e['amountPaid'])),
          );
          final categorySpend = <String, double>{};
          for (final expense in monthExpenses) {
            final category = expense['category'] as String? ?? 'other';
            categorySpend[category] =
                (categorySpend[category] ?? 0) + _number(expense['amountPaid']);
          }
          final sorted = categorySpend.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
            children: [
              AppText(
                _monthLabel(month),
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const AppText(
                'Outgoing colony expenditure only. Resident maintenance collections remain in Maintenance Dues.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final int responsiveColumnCount = 2;
                  final double horizontalGap = (10).toDouble();
                  final double itemWidth =
                      (constraints.maxWidth -
                          horizontalGap * (responsiveColumnCount - 1)) /
                      responsiveColumnCount;
                  return Wrap(
                    spacing: horizontalGap,
                    runSpacing: 10,
                    children:
                        ([
                              _metric(
                                'Paid this month',
                                _money(paid),
                                Icons.payments_outlined,
                              ),
                              _metric(
                                'Monthly budget',
                                _money(budgetTotal),
                                Icons.account_balance_outlined,
                                subtitle:
                                    '${monthBudgets.length} categories configured',
                              ),
                              _metric(
                                'Budget remaining',
                                _money(remaining),
                                Icons.savings_outlined,
                                subtitle: budgetTotal == 0
                                    ? 'Set budgets to track limits'
                                    : remaining < 0
                                    ? 'Over budget'
                                    : 'Against paid expenses',
                              ),
                              _metric(
                                'Unpaid / outstanding',
                                _money(outstanding),
                                Icons.pending_actions_outlined,
                                subtitle:
                                    'Of ${_money(committed)} recorded expenses',
                              ),
                            ])
                            .map<Widget>(
                              (child) =>
                                  SizedBox(width: itemWidth, child: child),
                            )
                            .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: 22),
              const AppText(
                'Paid spend by category',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              if (sorted.isEmpty)
                _empty(
                  'No expenses this month',
                  'Record an outgoing colony expense to see the breakdown.',
                  Icons.receipt_long_outlined,
                )
              else
                ...sorted.map(
                  (entry) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      border: Border.all(color: AppTheme.borderGrey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppText(
                            _categories[entry.key] ?? entry.key,
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        AppText(
                          _money(entry.value),
                          style: const TextStyle(
                            color: AppTheme.navyBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showBudgetForm,
                icon: const Icon(Icons.add_chart_outlined),
                label: const AppText('Set or update a category budget'),
              ),
            ],
          );
        },
      );
    },
  );

  Widget _expensesTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _expenses.orderBy('expenseDate', descending: true).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _empty(
          'Unable to load expenses',
          'Check your connection and deployed Firestore rules.',
          Icons.error_outline_rounded,
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyBlue),
        );
      }
      final records = snapshot.data?.docs ?? [];
      if (records.isEmpty) {
        return _empty(
          'No expenses recorded yet',
          'Record payments made for utilities, water, security, repairs and other colony operations.',
          Icons.receipt_long_outlined,
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
        itemCount: records.length,
        itemBuilder: (context, index) {
          final doc = records[index];
          final data = doc.data();
          final amount = _number(data['amount']);
          final amountPaid = _number(data['amountPaid']);
          final status = data['paymentStatus'] as String? ?? 'unpaid';
          final category = data['category'] as String? ?? 'other';
          return Card(
            color: AppTheme.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.borderGrey),
            ),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              data['title'] as String? ?? 'Expense',
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AppText(
                              '${_categories[category] ?? category} · ${_dateLabel(data['expenseDate'])}',
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
                          if (value == 'payment') {
                            _updatePaidAmount(doc.id, data);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'payment',
                            child: AppText('Update payment progress'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      AppText(
                        _money(amount),
                        style: const TextStyle(
                          color: AppTheme.navyBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      _tag(status.replaceAll('_', ' ').toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    'Paid ${_money(amountPaid)} · Balance ${_money(amount - amountPaid)}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                  if ((data['payeeName'] as String? ?? '').isNotEmpty ||
                      (data['vendorName'] as String? ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: AppText(
                        [data['payeeName'], data['vendorName']]
                            .whereType<String>()
                            .where((v) => v.trim().isNotEmpty)
                            .join(' · '),
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if ((data['reference'] as String? ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: AppText(
                        'Reference: ${data['reference']}',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 10,
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

  Widget _budgetsTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _budgets.snapshots(),
    builder: (context, budgetSnapshot) {
      if (budgetSnapshot.hasError) {
        return _empty(
          'Unable to load budgets',
          'Check your connection and deployed Firestore rules.',
          Icons.error_outline_rounded,
        );
      }
      if (budgetSnapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyBlue),
        );
      }
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _expenses.snapshots(),
        builder: (context, expenseSnapshot) {
          if (expenseSnapshot.hasError) {
            return _empty(
              'Unable to load expense records',
              'Budget actuals are unavailable until this read succeeds: ${expenseSnapshot.error}',
              Icons.cloud_off_outlined,
            );
          }
          if (expenseSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.navyBlue),
            );
          }
          final budgets = budgetSnapshot.data?.docs.toList() ?? [];
          budgets.sort(
            (a, b) => (b.data()['monthKey'] as String? ?? '').compareTo(
              a.data()['monthKey'] as String? ?? '',
            ),
          );
          if (budgets.isEmpty) {
            return _empty(
              'No monthly budgets yet',
              'Set category budgets to compare paid expenses against planned limits.',
              Icons.pie_chart_outline_rounded,
            );
          }
          final expenses =
              expenseSnapshot.data?.docs.map((d) => d.data()).toList() ?? [];
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final doc = budgets[index];
              final data = doc.data();
              final month = data['monthKey'] as String? ?? '';
              final category = data['category'] as String? ?? 'other';
              final budget = _number(data['budgetAmount']);
              final spent = expenses
                  .where(
                    (e) => e['monthKey'] == month && e['category'] == category,
                  )
                  .fold<double>(
                    0,
                    (accumulator, e) => accumulator + _number(e['amountPaid']),
                  );
              final ratio = budget <= 0
                  ? 0.0
                  : (spent / budget).clamp(0.0, 1.0);
              return Card(
                color: AppTheme.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 9),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  _categories[category] ?? category,
                                  style: const TextStyle(
                                    color: AppTheme.textDark,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                AppText(
                                  _monthLabel(month),
                                  style: const TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppText(
                            _money(budget),
                            style: const TextStyle(
                              color: AppTheme.navyBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: AppTheme.lightGrey,
                          color: AppTheme.secondaryNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              'Paid ${_money(spent)}',
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          AppText(
                            spent > budget
                                ? 'Over by ${_money(spent - budget)}'
                                : 'Remaining ${_money(budget - spent)}',
                            style: TextStyle(
                              color: spent > budget
                                  ? const Color(0xFF9B2C2C)
                                  : AppTheme.textGrey,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
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
      );
    },
  );

  Future<void> _showExpenseForm() async {
    final title = TextEditingController();
    final amount = TextEditingController();
    final amountPaid = TextEditingController(text: '0');
    final payee = TextEditingController();
    final vendor = TextEditingController();
    final asset = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    String category = 'utilities';
    String method = 'upi';
    DateTime expenseDate = DateTime.now();
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Record colony expense'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Expense title *'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Category'),
                    ),
                    items: _categories.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: AppText(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => category = v);
                    },
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Total amount (₹) *',
                      ),
                    ),
                  ),
                  TextField(
                    controller: amountPaid,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Amount paid (₹)'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Payment method'),
                    ),
                    items: _paymentMethods.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: AppText(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => method = v);
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: expenseDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => expenseDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: AppText(
                        'Expense date: ${_dateLabel(expenseDate)}',
                      ),
                    ),
                  ),
                  TextField(
                    controller: payee,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Paid to / payee'),
                    ),
                  ),
                  TextField(
                    controller: vendor,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Vendor name (optional)',
                      ),
                    ),
                  ),
                  TextField(
                    controller: asset,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Related asset (optional)',
                      ),
                    ),
                  ),
                  TextField(
                    controller: reference,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Invoice / transaction reference',
                      ),
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLength: 1200,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Notes'),
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
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final parsedAmount = double.tryParse(amount.text.trim());
                      final parsedPaid = double.tryParse(
                        amountPaid.text.trim().isEmpty
                            ? '0'
                            : amountPaid.text.trim(),
                      );
                      if (title.text.trim().length < 2 ||
                          parsedAmount == null ||
                          parsedAmount <= 0 ||
                          parsedPaid == null ||
                          parsedPaid < 0 ||
                          parsedPaid > parsedAmount ||
                          notes.text.trim().length > 1200) {
                        _message(
                          'Enter a title, valid total amount and paid amount not exceeding the total.',
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      final status = parsedPaid == 0
                          ? 'unpaid'
                          : parsedPaid == parsedAmount
                          ? 'paid'
                          : 'partially_paid';
                      try {
                        await _expenses.add({
                          'title': title.text.trim(),
                          'category': category,
                          'amount': parsedAmount,
                          'amountPaid': parsedPaid,
                          'paymentStatus': status,
                          'paymentMethod': method,
                          'expenseDate': Timestamp.fromDate(
                            DateTime(
                              expenseDate.year,
                              expenseDate.month,
                              expenseDate.day,
                            ),
                          ),
                          'monthKey': _monthKey(expenseDate),
                          'payeeName': payee.text.trim(),
                          'vendorName': vendor.text.trim(),
                          'assetName': asset.text.trim(),
                          'reference': reference.text.trim(),
                          'notes': notes.text.trim(),
                          'createdBy': _uid,
                          'createdByName': widget.adminName,
                          'createdAt': FieldValue.serverTimestamp(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        _message('Expense recorded.');
                      } catch (error) {
                        setDialogState(() => saving = false);
                        _message('Could not save expense: $error');
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppText('Save expense'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    amount.dispose();
    amountPaid.dispose();
    payee.dispose();
    vendor.dispose();
    asset.dispose();
    reference.dispose();
    notes.dispose();
  }

  Future<void> _showBudgetForm() async {
    final amount = TextEditingController();
    final notes = TextEditingController();
    String category = 'utilities';
    DateTime monthDate = DateTime.now();
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Set monthly category budget'),
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
                    items: _categories.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: AppText(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => category = v);
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: monthDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => monthDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: AppText(
                        'Budget month: ${_monthLabel(_monthKey(monthDate))}',
                      ),
                    ),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Budget amount (₹) *',
                      ),
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Notes'),
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
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final parsed = double.tryParse(amount.text.trim());
                      if (parsed == null ||
                          parsed <= 0 ||
                          notes.text.trim().length > 500) {
                        _message('Enter a valid budget amount.');
                        return;
                      }
                      setDialogState(() => saving = true);
                      final month = _monthKey(monthDate);
                      final key = '${month}_$category';
                      final ref = _budgets.doc(key);
                      try {
                        final existing = await ref.get();
                        if (existing.exists) {
                          await ref.update({
                            'budgetAmount': parsed,
                            'notes': notes.text.trim(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                        } else {
                          await ref.set({
                            'monthKey': month,
                            'category': category,
                            'budgetAmount': parsed,
                            'notes': notes.text.trim(),
                            'createdBy': _uid,
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        _message('Monthly budget saved.');
                      } catch (error) {
                        setDialogState(() => saving = false);
                        _message('Could not save budget: $error');
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppText('Save budget'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    notes.dispose();
  }

  Future<void> _updatePaidAmount(String id, Map<String, dynamic> data) async {
    final controller = TextEditingController(
      text: _number(data['amountPaid']).toStringAsFixed(2),
    );
    final total = _number(data['amount']);
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Update payment progress'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: AppTranslations.translate('Total paid (₹)'),
            helperText: AppTranslations.translate('Maximum: ${_money(total)}'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < 0 || value > total) {
                _message(
                  'Paid amount must be between zero and the total expense.',
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const AppText('Update'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final status = result == 0
        ? 'unpaid'
        : result == total
        ? 'paid'
        : 'partially_paid';
    try {
      await _expenses.doc(id).update({
        'amountPaid': result,
        'paymentStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Payment progress updated.');
    } catch (error) {
      _message('Could not update payment: $error');
    }
  }
}
// COLONY_BUDGET_EXPENSE_SCREEN_END
