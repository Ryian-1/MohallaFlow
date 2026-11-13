// MOHALLAFLOW_RWA_ACCOUNTING_SCREEN_BEGIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

/// Admin-only double-entry accounting, source import, bank reconciliation and period control.
/// Existing operational collections remain the source of truth for bills, verified receipts and expenses.
class RwaAccountingScreen extends StatefulWidget {
  const RwaAccountingScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });
  final String colonyId;
  final String colonyName;
  final String adminName;
  @override
  State<RwaAccountingScreen> createState() => _RwaAccountingScreenState();
}

class _RwaAccountingScreenState extends State<RwaAccountingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final CollectionReference<Map<String, dynamic>> _accounts;
  late final CollectionReference<Map<String, dynamic>> _settings;
  late final CollectionReference<Map<String, dynamic>> _journals;
  late final CollectionReference<Map<String, dynamic>> _imports;
  late final CollectionReference<Map<String, dynamic>> _statements;
  late final CollectionReference<Map<String, dynamic>> _journalMatches;
  late final CollectionReference<Map<String, dynamic>> _reconciliations;
  late final CollectionReference<Map<String, dynamic>> _periods;
  late final CollectionReference<Map<String, dynamic>> _audit;
  late final CollectionReference<Map<String, dynamic>> _bills;
  late final CollectionReference<Map<String, dynamic>> _payments;
  late final CollectionReference<Map<String, dynamic>> _expenses;
  late final CollectionReference<Map<String, dynamic>> _supplierInvoices;
  late final CollectionReference<Map<String, dynamic>> _supplierPayments;
  bool _busy = false;
  String _selectedPeriod = _monthKey(DateTime.now());
  String? _selectedBankAccount;
  Map<String, String> _paymentAccountMapping = {
    'upi': '1000',
    'bank_transfer': '1000',
    'card': '1000',
    'cash': '1010',
    'cheque': '1020',
    'other': '1000',
  };

  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  static DateTime _asDate(Object? value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : DateTime.now();
  static double _n(Object? value) => value is num ? value.toDouble() : 0.0;
  static String _money(Object? value) => '₹${_n(value).toStringAsFixed(2)}';
  static const Map<String, String> _typeLabels = {
    'asset': 'Asset',
    'liability': 'Liability',
    'equity': 'Equity',
    'income': 'Income',
    'expense': 'Expense',
  };
  static const Map<String, String> _methodLabels = {
    'upi': 'UPI',
    'bank_transfer': 'Bank transfer',
    'cash': 'Cash',
    'cheque': 'Cheque',
    'card': 'Card',
    'other': 'Other',
  };
  static const Map<String, String> _expenseAccount = {
    'utilities': '5100',
    'water': '5200',
    'security': '5300',
    'housekeeping': '5400',
    'repairs': '5500',
    'landscaping': '5600',
    'staff': '5700',
    'insurance': '5800',
    'administration': '5900',
    'other': '5990',
  };

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    final colony = FirebaseFirestore.instance
        .collection('colonies')
        .doc(widget.colonyId);
    _accounts = colony.collection('accountingAccounts');
    _settings = colony.collection('accountingSettings');
    _journals = colony.collection('accountingJournals');
    _imports = colony.collection('accountingImports');
    _statements = colony.collection('accountingBankStatements');
    _journalMatches = colony.collection('accountingJournalMatches');
    _reconciliations = colony.collection('accountingReconciliations');
    _periods = colony.collection('accountingPeriods');
    _audit = colony.collection('accountingAuditEvents');
    _bills = colony.collection('maintenanceBills');
    _payments = colony.collection('maintenancePayments');
    _expenses = colony.collection('colonyExpenses');
    _supplierInvoices = colony.collection('supplierInvoices');
    _supplierPayments = colony.collection('supplierPayments');
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedAccounts());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _seedAccounts() async {
    final defaults = <String, Map<String, dynamic>>{
      '1000': {
        'code': '1000',
        'name': 'Operating Bank',
        'type': 'asset',
        'subtype': 'bank',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '1010': {
        'code': '1010',
        'name': 'Cash on Hand',
        'type': 'asset',
        'subtype': 'cash',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '1020': {
        'code': '1020',
        'name': 'Undeposited Cheques',
        'type': 'asset',
        'subtype': 'clearing',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '1100': {
        'code': '1100',
        'name': 'Maintenance Receivables',
        'type': 'asset',
        'subtype': 'receivable',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '1300': {
        'code': '1300',
        'name': 'Inventory on Hand',
        'type': 'asset',
        'subtype': 'inventory',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '2000': {
        'code': '2000',
        'name': 'Supplier Payables (control)',
        'type': 'liability',
        'subtype': 'payable',
        'normalBalance': 'credit',
        'isSystem': true,
      },
      '3000': {
        'code': '3000',
        'name': 'Opening Balance Equity',
        'type': 'equity',
        'subtype': 'opening_equity',
        'normalBalance': 'credit',
        'isSystem': true,
      },
      '4000': {
        'code': '4000',
        'name': 'Maintenance Dues Income',
        'type': 'income',
        'subtype': 'operating_income',
        'normalBalance': 'credit',
        'isSystem': true,
      },
      '4100': {
        'code': '4100',
        'name': 'Other Colony Income',
        'type': 'income',
        'subtype': 'other_income',
        'normalBalance': 'credit',
        'isSystem': true,
      },
      '5100': {
        'code': '5100',
        'name': 'Utilities Expense',
        'type': 'expense',
        'subtype': 'utilities',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '5200': {
        'code': '5200',
        'name': 'Water Expense',
        'type': 'expense',
        'subtype': 'water',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '5300': {
        'code': '5300',
        'name': 'Security Expense',
        'type': 'expense',
        'subtype': 'security',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '5400': {
        'code': '5400',
        'name': 'Housekeeping Expense',
        'type': 'expense',
        'subtype': 'housekeeping',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '5500': {
        'code': '5500',
        'name': 'Repairs Expense',
        'type': 'expense',
        'subtype': 'repairs',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '5600': {
        'code': '5600',
        'name': 'Landscaping Expense',
        'type': 'expense',
        'subtype': 'landscaping',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '5700': {
        'code': '5700',
        'name': 'Staff & Payroll Expense',
        'type': 'expense',
        'subtype': 'staff',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '5800': {
        'code': '5800',
        'name': 'Insurance Expense',
        'type': 'expense',
        'subtype': 'insurance',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '5900': {
        'code': '5900',
        'name': 'Administration Expense',
        'type': 'expense',
        'subtype': 'administration',
        'normalBalance': 'debit',
        'isSystem': true,
      },
      '5990': {
        'code': '5990',
        'name': 'Other Operating Expense',
        'type': 'expense',
        'subtype': 'other',
        'normalBalance': 'debit',
        'isSystem': true,
      },
    };
    try {
      final refs = defaults.keys.map((key) => _accounts.doc(key)).toList();
      final snapshots = await Future.wait(refs.map((ref) => ref.get()));
      final batch = FirebaseFirestore.instance.batch();
      var writes = 0;
      for (var i = 0; i < snapshots.length; i++) {
        if (snapshots[i].exists) continue;
        final key = defaults.keys.elementAt(i);
        batch.set(refs[i], {
          ...defaults[key]!,
          'isActive': true,
          'createdBy': _uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        writes++;
      }
      if (writes > 0) await batch.commit();
    } catch (e) {
      debugPrint('Accounting account seed skipped: $e');
    }
  }

  Future<void> _auditEvent(
    String action,
    String entityType,
    String entityId,
    String summary,
  ) async {
    await _audit.add({
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'summary': summary.length > 1000 ? summary.substring(0, 1000) : summary,
      'performedBy': _uid,
      'performedByName': widget.adminName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _periodFor(DateTime d) => _monthKey(d);
  Future<void> _assertOpenPeriod(Transaction tx, String period) async {
    final snap = await tx.get(_periods.doc(period));
    if (snap.exists && snap.data()?['status'] == 'closed') {
      throw StateError(
        'Accounting period $period is closed. Use an adjustment in an open period.',
      );
    }
  }

  String _cashAccountFor(String? method, [Map<String, String>? mapping]) {
    final raw = (method ?? 'other').trim().toLowerCase();
    final key = raw.replaceAll(' ', '_').replaceAll('-', '_');
    return (mapping ?? _paymentAccountMapping)[key] ?? '1000';
  }

  Future<void> _syncOperationalSources() async {
    if (_busy) return;
    setState(() => _busy = true);
    var created = 0;
    var flagged = 0;
    var skipped = 0;
    try {
      final mappingSnapshot = await _settings.doc('paymentMappings').get();
      final paymentMapping = Map<String, String>.from(
        mappingSnapshot.data()?['paymentMappings'] ?? _paymentAccountMapping,
      );
      final billSnap = await _bills.get();
      for (final doc in billSnap.docs) {
        final d = doc.data();
        final amount = _n(d['totalAmount']);
        if (amount <= 0) {
          skipped++;
          continue;
        }
        final markerId = 'bill_${doc.id}';
        final marker = _imports.doc(markerId);
        final journal = _journals.doc();
        final date = _asDate(d['createdAt']);
        final period = _periodFor(date);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final existing = await tx.get(marker);
          if (existing.exists) {
            if ((_n(existing.data()?['sourceAmount']) - amount).abs() > 0.005 &&
                existing.data()?['needsReview'] != true) {
              tx.update(marker, {
                'needsReview': true,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
            return;
          }
          await _assertOpenPeriod(tx, period);
          tx.set(
            journal,
            _journalData(
              date: date,
              period: period,
              memo: 'Maintenance bill ${doc.id} · ${d['houseNumber'] ?? ''}',
              sourceType: 'maintenance_bill',
              sourceId: doc.id,
              debitAccount: '1100',
              creditAccount: '4000',
              amount: amount,
            ),
          );
          tx.set(marker, {
            'sourceType': 'maintenance_bill',
            'sourceId': doc.id,
            'sourceAmount': amount,
            'importedAmount': amount,
            'journalIds': [journal.id],
            'needsReview': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
        final after = await marker.get();
        if (after.exists &&
            (after.data()?['journalIds'] as List? ?? []).contains(journal.id)) {
          created++;
        }
      }

      final paymentSnap = await _payments
          .where('status', isEqualTo: 'verified')
          .get();
      for (final doc in paymentSnap.docs) {
        final d = doc.data();
        final amount = _n(d['amount']);
        if (amount <= 0) {
          skipped++;
          continue;
        }
        final marker = _imports.doc('receipt_${doc.id}');
        final journal = _journals.doc();
        final date = _asDate(d['verifiedAt'] ?? d['createdAt']);
        final period = _periodFor(date);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final existing = await tx.get(marker);
          if (existing.exists) return;
          await _assertOpenPeriod(tx, period);
          tx.set(
            journal,
            _journalData(
              date: date,
              period: period,
              memo: 'Verified maintenance receipt ${doc.id}',
              sourceType: 'maintenance_receipt',
              sourceId: doc.id,
              debitAccount: _cashAccountFor(
                d['paymentMethod'] as String?,
                paymentMapping,
              ),
              creditAccount: '1100',
              amount: amount,
              reference: (d['transactionReference'] ?? '').toString(),
            ),
          );
          tx.set(marker, {
            'sourceType': 'maintenance_receipt',
            'sourceId': doc.id,
            'sourceAmount': amount,
            'importedAmount': amount,
            'journalIds': [journal.id],
            'needsReview': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
        final after = await marker.get();
        if (after.exists &&
            (after.data()?['journalIds'] as List? ?? []).contains(journal.id)) {
          created++;
        }
      }

      // Verified procurement invoices accrue a payable once. Inventory-linked
      // PO lines debit Inventory on Hand; non-inventory lines debit the mapped expense.
      final invoiceSnap = await _supplierInvoices
          .where('verificationStatus', isEqualTo: 'verified')
          .get();
      for (final doc in invoiceSnap.docs) {
        final d = doc.data();
        final total = _n(d['total']);
        if (total <= 0) {
          skipped++;
          continue;
        }
        final marker = _imports.doc('supplier_invoice_${doc.id}');
        final journal = _journals.doc();
        final date = _asDate(d['invoiceDate']);
        final period = _periodFor(date);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final existing = await tx.get(marker);
          if (existing.exists) {
            if ((_n(existing.data()?['sourceAmount']) - total).abs() > 0.005 &&
                existing.data()?['needsReview'] != true) {
              tx.update(marker, {
                'needsReview': true,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
            return;
          }
          await _assertOpenPeriod(tx, period);
          final rawItems = (d['items'] as List? ?? []);
          var inventoryBase = 0.0;
          var nonInventoryBase = 0.0;
          for (final raw in rawItems) {
            if (raw is! Map) continue;
            final lineTotal = _n(raw['lineTotal']);
            final itemId = (raw['inventoryItemId'] ?? '').toString().trim();
            if (itemId.isNotEmpty) {
              inventoryBase += lineTotal;
            } else {
              nonInventoryBase += lineTotal;
            }
          }
          final base = inventoryBase + nonInventoryBase;
          final inventoryAmount = base > 0 ? total * inventoryBase / base : 0.0;
          final expenseAmount = total - inventoryAmount;
          final lines = <Map<String, dynamic>>[];
          if (inventoryAmount > 0.005) {
            lines.add({
              'accountId': '1300',
              'debit': inventoryAmount,
              'credit': 0.0,
            });
          }
          if (expenseAmount > 0.005) {
            lines.add({
              'accountId':
                  _expenseAccount[(d['expenseCategory'] ?? 'other')
                      .toString()] ??
                  '5990',
              'debit': expenseAmount,
              'credit': 0.0,
            });
          }
          lines.add({'accountId': '2000', 'debit': 0.0, 'credit': total});
          tx.set(
            journal,
            _multiLineJournalData(
              date: date,
              period: period,
              memo:
                  'Verified supplier invoice ${d['supplierInvoiceNumber'] ?? doc.id}',
              sourceType: 'supplier_invoice',
              sourceId: doc.id,
              lines: lines,
              total: total,
              reference: (d['supplierInvoiceNumber'] ?? '').toString(),
            ),
          );
          tx.set(marker, {
            'sourceType': 'supplier_invoice',
            'sourceId': doc.id,
            'sourceAmount': total,
            'importedAmount': total,
            'journalIds': [journal.id],
            'needsReview': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
        final after = await marker.get();
        if (after.exists &&
            (after.data()?['journalIds'] as List? ?? []).contains(journal.id)) {
          created++;
        }
      }

      // Supplier payments reduce Accounts Payable. Their matching PROC-* expense
      // records are deliberately excluded from the generic expense import below.
      final supplierPaymentSnap = await _supplierPayments.get();
      for (final doc in supplierPaymentSnap.docs) {
        final d = doc.data();
        final amount = _n(d['amount']);
        if (amount <= 0) {
          skipped++;
          continue;
        }
        final marker = _imports.doc('supplier_payment_${doc.id}');
        final journal = _journals.doc();
        final date = _asDate(d['paymentDate'] ?? d['createdAt']);
        final period = _periodFor(date);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final existing = await tx.get(marker);
          if (existing.exists) return;
          await _assertOpenPeriod(tx, period);
          tx.set(
            journal,
            _journalData(
              date: date,
              period: period,
              memo: 'Supplier payment ${d['invoiceNumber'] ?? doc.id}',
              sourceType: 'supplier_payment',
              sourceId: doc.id,
              debitAccount: '2000',
              creditAccount: _cashAccountFor(
                d['paymentMethod'] as String?,
                paymentMapping,
              ),
              amount: amount,
              reference: (d['transactionReference'] ?? '').toString(),
            ),
          );
          tx.set(marker, {
            'sourceType': 'supplier_payment',
            'sourceId': doc.id,
            'sourceAmount': amount,
            'importedAmount': amount,
            'journalIds': [journal.id],
            'needsReview': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
        final after = await marker.get();
        if (after.exists &&
            (after.data()?['journalIds'] as List? ?? []).contains(journal.id)) {
          created++;
        }
      }

      final expenseSnap = await _expenses.get();
      for (final doc in expenseSnap.docs) {
        final d = doc.data();
        final paid = _n(d['amountPaid']);
        final expenseReference = (d['reference'] ?? '').toString();
        if (expenseReference.startsWith('PROC-')) {
          skipped++;
          continue;
        }
        if (paid <= 0) {
          skipped++;
          continue;
        }
        final marker = _imports.doc('expense_${doc.id}');
        final journal = _journals.doc();
        final sourceDate = _asDate(d['expenseDate']);
        var thisCreated = false;
        var thisFlagged = false;
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final existing = await tx.get(marker);
          final imported = _n(existing.data()?['importedAmount']);
          if (paid + 0.005 < imported) {
            if (existing.exists && existing.data()?['needsReview'] != true) {
              tx.update(marker, {
                'needsReview': true,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              thisFlagged = true;
            }
            return;
          }
          final delta = paid - imported;
          if (delta <= 0.005) return;
          // First import uses the source expense date; subsequent paid-balance
          // increases are dated when discovered because the source has no payment-level history.
          final postDate = existing.exists ? DateTime.now() : sourceDate;
          final period = _periodFor(postDate);
          await _assertOpenPeriod(tx, period);
          final cat = (d['category'] ?? 'other').toString();
          tx.set(
            journal,
            _journalData(
              date: postDate,
              period: period,
              memo: 'Paid expense ${doc.id} · ${d['title'] ?? ''}',
              sourceType: 'colony_expense',
              sourceId: doc.id,
              debitAccount: _expenseAccount[cat] ?? '5990',
              creditAccount: _cashAccountFor(
                d['paymentMethod'] as String?,
                paymentMapping,
              ),
              amount: delta,
              reference: (d['reference'] ?? '').toString(),
            ),
          );
          final ids = List<String>.from(existing.data()?['journalIds'] ?? [])
            ..add(journal.id);
          tx.set(marker, {
            'sourceType': 'colony_expense',
            'sourceId': doc.id,
            'sourceAmount': paid,
            'importedAmount': paid,
            'journalIds': ids,
            'needsReview': existing.data()?['needsReview'] == true,
            'createdAt':
                existing.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          thisCreated = true;
        });
        if (thisCreated) created++;
        if (thisFlagged) flagged++;
      }
      await _auditEvent(
        'source_sync',
        'accounting_import',
        'batch',
        'Created $created journal entries; $flagged sources need review; $skipped zero-value entries skipped.',
      );
      _msg(
        'Source sync complete: $created journal entries created, $flagged source changes flagged for review.',
      );
    } catch (e) {
      _msg('Source sync stopped: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _journalData({
    required DateTime date,
    required String period,
    required String memo,
    required String sourceType,
    required String sourceId,
    required String debitAccount,
    required String creditAccount,
    required double amount,
    String reference = '',
  }) => {
    'journalDate': Timestamp.fromDate(
      DateTime(date.year, date.month, date.day),
    ),
    'periodKey': period,
    'memo': memo.length > 250 ? memo.substring(0, 250) : memo,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'reference': reference.length > 100
        ? reference.substring(0, 100)
        : reference,
    'lines': [
      {'accountId': debitAccount, 'debit': amount, 'credit': 0.0},
      {'accountId': creditAccount, 'debit': 0.0, 'credit': amount},
    ],
    'totalDebit': amount,
    'totalCredit': amount,
    'status': 'posted',
    'createdBy': _uid,
    'createdByName': widget.adminName,
    'createdAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> _multiLineJournalData({
    required DateTime date,
    required String period,
    required String memo,
    required String sourceType,
    required String sourceId,
    required List<Map<String, dynamic>> lines,
    required double total,
    String reference = '',
  }) => {
    'journalDate': Timestamp.fromDate(
      DateTime(date.year, date.month, date.day),
    ),
    'periodKey': period,
    'memo': memo.length > 250 ? memo.substring(0, 250) : memo,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'reference': reference.length > 100
        ? reference.substring(0, 100)
        : reference,
    'lines': lines,
    'totalDebit': total,
    'totalCredit': total,
    'status': 'posted',
    'createdBy': _uid,
    'createdByName': widget.adminName,
    'createdAt': FieldValue.serverTimestamp(),
  };

  Future<void> _createAccount() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final bankName = TextEditingController();
    final last4 = TextEditingController();
    String type = 'expense';
    String subtype = 'custom';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Add chart-of-accounts entry'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: code,
                    maxLength: 12,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Account code'),
                    ),
                  ),
                  TextField(
                    controller: name,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Account name'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Account type'),
                    ),
                    items: _typeLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: AppText(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setD(() {
                      type = v ?? type;
                      subtype = type == 'asset' ? 'bank' : 'custom';
                    }),
                  ),
                  if (type == 'asset')
                    DropdownButtonFormField<String>(
                      initialValue: subtype,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Asset account purpose',
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'bank',
                          child: AppText('Bank account'),
                        ),
                        DropdownMenuItem(
                          value: 'cash',
                          child: AppText('Cash account'),
                        ),
                        DropdownMenuItem(
                          value: 'clearing',
                          child: AppText('Cheque / clearing account'),
                        ),
                        DropdownMenuItem(
                          value: 'receivable',
                          child: AppText('Receivable account'),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: AppText('Other asset'),
                        ),
                      ],
                      onChanged: (v) => setD(() => subtype = v ?? subtype),
                    ),
                  if (type == 'asset' && subtype == 'bank') ...[
                    TextField(
                      controller: bankName,
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Bank name'),
                      ),
                    ),
                    TextField(
                      controller: last4,
                      maxLength: 4,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate(
                          'Account last 4 digits only',
                        ),
                      ),
                    ),
                    const AppText(
                      'Do not enter full bank account numbers, passwords or credentials.',
                      style: TextStyle(fontSize: 10, color: AppTheme.textGrey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Save account'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final c = code.text.trim();
      final n = name.text.trim();
      if (c.isEmpty ||
          n.length < 2 ||
          c.length > 12 ||
          (subtype == 'bank' &&
              last4.text.trim().isNotEmpty &&
              !RegExp(r'^\d{4}$').hasMatch(last4.text.trim()))) {
        _msg(
          'Enter a valid account code/name and, when supplied, exactly four trailing digits.',
        );
      } else {
        try {
          await FirebaseFirestore.instance.runTransaction((tx) async {
            final ref = _accounts.doc(c);
            final existing = await tx.get(ref);
            if (existing.exists) {
              throw StateError('That account code already exists.');
            }
            tx.set(ref, {
              'code': c,
              'name': n,
              'type': type,
              'subtype': subtype,
              'normalBalance': type == 'asset' || type == 'expense'
                  ? 'debit'
                  : 'credit',
              'bankName': bankName.text.trim(),
              'accountLast4': last4.text.trim(),
              'isSystem': false,
              'isActive': true,
              'createdBy': _uid,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          });
          await _auditEvent(
            'account_created',
            'account',
            c,
            'Created account $c · $n',
          );
          _msg('Account created.');
        } catch (e) {
          _msg('Could not create account: $e');
        }
      }
    }
    code.dispose();
    name.dispose();
    bankName.dispose();
    last4.dispose();
  }

  Future<void> _setOpeningBalance(
    String id,
    Map<String, dynamic> account,
  ) async {
    if (account['type'] != 'asset' && account['type'] != 'liability') {
      _msg(
        'Opening balances are currently enabled for asset and liability accounts.',
      );
      return;
    }
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText('Set opening balance · ${account['name']}'),
        content: TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: AppTranslations.translate('Opening balance (₹)'),
            helperText: AppTranslations.translate(
              'Positive balance. This can only be recorded once.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Post opening balance'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final v = double.tryParse(amount.text.trim());
      if (v == null || v <= 0 || v > 100000000000) {
        _msg('Enter a valid opening balance.');
      } else {
        final marker = _imports.doc('opening_$id');
        final journal = _journals.doc();
        final now = DateTime.now();
        final debit = account['type'] == 'asset' ? id : '3000';
        final credit = account['type'] == 'asset' ? '3000' : id;
        try {
          await FirebaseFirestore.instance.runTransaction((tx) async {
            final m = await tx.get(marker);
            if (m.exists) {
              throw StateError(
                'An opening balance is already recorded for this account.',
              );
            }
            await _assertOpenPeriod(tx, _periodFor(now));
            tx.set(
              journal,
              _journalData(
                date: now,
                period: _periodFor(now),
                memo: 'Opening balance · ${account['name']}',
                sourceType: 'opening_balance',
                sourceId: id,
                debitAccount: debit,
                creditAccount: credit,
                amount: v,
              ),
            );
            tx.set(marker, {
              'sourceType': 'opening_balance',
              'sourceId': id,
              'sourceAmount': v,
              'importedAmount': v,
              'journalIds': [journal.id],
              'needsReview': false,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          });
          await _auditEvent(
            'opening_balance_posted',
            'account',
            id,
            'Opening balance ${_money(v)} posted to ${account['name']}',
          );
          _msg('Opening balance posted.');
        } catch (e) {
          _msg('Could not post opening balance: $e');
        }
      }
    }
    amount.dispose();
  }

  Future<void> _manualJournal() async {
    final memo = TextEditingController();
    final amount = TextEditingController();
    final refText = TextEditingController();
    final accountSnap = await _accounts
        .where('isActive', isEqualTo: true)
        .get();
    if (!mounted) {
      memo.dispose();
      amount.dispose();
      refText.dispose();
      return;
    }
    final opts = accountSnap.docs;
    if (opts.length < 2) {
      _msg('At least two active accounts are required.');
      memo.dispose();
      amount.dispose();
      refText.dispose();
      return;
    }
    final debitDefault = opts
        .firstWhere(
          (d) => d.data()['type'] == 'expense',
          orElse: () => opts.first,
        )
        .id;
    final creditDefault = opts
        .firstWhere((d) => d.data()['type'] == 'asset', orElse: () => opts.last)
        .id;
    String debit = debitDefault;
    String credit = creditDefault == debitDefault
        ? opts.firstWhere((d) => d.id != debitDefault).id
        : creditDefault;
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Create balanced journal entry'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: memo,
                    maxLength: 250,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Narration / purpose',
                      ),
                    ),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Amount (₹)'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: debit,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Debit account'),
                    ),
                    items: opts
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: AppText('${e.id} · ${e.data()['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setD(() => debit = v ?? debit),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: credit,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Credit account'),
                    ),
                    items: opts
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: AppText('${e.id} · ${e.data()['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setD(() => credit = v ?? credit),
                  ),
                  TextField(
                    controller: refText,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate(
                        'Reference (optional)',
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setD(() => date = d);
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: AppText(
                        'Date: ${date.day}/${date.month}/${date.year}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Post journal'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final value = double.tryParse(amount.text.trim());
      if (memo.text.trim().length < 3 ||
          value == null ||
          value <= 0 ||
          value > 100000000000 ||
          debit == credit) {
        _msg('Enter narration, positive amount and two different accounts.');
      } else {
        final journal = _journals.doc();
        final d = DateTime(date.year, date.month, date.day);
        final period = _periodFor(d);
        try {
          await FirebaseFirestore.instance.runTransaction((tx) async {
            await _assertOpenPeriod(tx, period);
            tx.set(
              journal,
              _journalData(
                date: d,
                period: period,
                memo: memo.text.trim(),
                sourceType: 'manual',
                sourceId: journal.id,
                debitAccount: debit,
                creditAccount: credit,
                amount: value,
                reference: refText.text.trim(),
              ),
            );
          });
          await _auditEvent(
            'manual_journal_posted',
            'journal',
            journal.id,
            'Posted balanced manual journal ${_money(value)} · ${memo.text.trim()}',
          );
          _msg('Balanced journal posted.');
        } catch (e) {
          _msg('Journal not posted: $e');
        }
      }
    }
    memo.dispose();
    amount.dispose();
    refText.dispose();
  }

  Future<void> _addStatementLine() async {
    final accounts = await _accounts.where('isActive', isEqualTo: true).get();
    if (!mounted) return;
    final bank = accounts.docs
        .where(
          (d) => ['bank', 'cash', 'clearing'].contains(d.data()['subtype']),
        )
        .toList();
    if (bank.isEmpty) {
      _msg('No active bank/cash accounts found.');
      return;
    }
    String account = bank.first.id, flow = 'in';
    final amount = TextEditingController(),
        description = TextEditingController(),
        reference = TextEditingController();
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Add bank statement line'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: account,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Bank / cash account'),
                  ),
                  items: bank
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: AppText('${e.id} · ${e.data()['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setD(() => account = v ?? account),
                ),
                DropdownButtonFormField<String>(
                  initialValue: flow,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Statement direction'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'in',
                      child: AppText(
                        'Money received / credit on bank statement',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'out',
                      child: AppText('Money paid / debit on bank statement'),
                    ),
                  ],
                  onChanged: (v) => setD(() => flow = v ?? flow),
                ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Amount (₹)'),
                  ),
                ),
                TextField(
                  controller: description,
                  maxLength: 180,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Description'),
                  ),
                ),
                TextField(
                  controller: reference,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: AppTranslations.translate('Bank reference'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setD(() => date = d);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: AppText(
                      'Date: ${date.day}/${date.month}/${date.year}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Save line'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final v = double.tryParse(amount.text.trim());
      if (v == null || v <= 0 || description.text.trim().length < 2) {
        _msg('Enter a valid amount and description.');
      } else {
        try {
          final d = DateTime(date.year, date.month, date.day);
          final ref = _statements.doc();
          await ref.set({
            'accountId': account,
            'flow': flow,
            'amount': v,
            'description': description.text.trim(),
            'bankReference': reference.text.trim(),
            'transactionDate': Timestamp.fromDate(d),
            'monthKey': _periodFor(d),
            'status': 'unmatched',
            'createdBy': _uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          await _auditEvent(
            'statement_line_added',
            'bank_statement',
            ref.id,
            'Added ${flow == 'in' ? 'inflow' : 'outflow'} statement line ${_money(v)}',
          );
          _msg('Statement line added.');
        } catch (e) {
          _msg('Could not save statement line: $e');
        }
      }
    }
    amount.dispose();
    description.dispose();
    reference.dispose();
  }

  Future<void> _matchStatement(
    QueryDocumentSnapshot<Map<String, dynamic>> statement,
  ) async {
    final s = statement.data();
    if (s['status'] == 'matched') {
      _msg('This statement line is already matched.');
      return;
    }
    final from = DateTime(
      _asDate(s['transactionDate']).year,
      _asDate(s['transactionDate']).month,
      _asDate(s['transactionDate']).day,
    ).subtract(const Duration(days: 5));
    final to = DateTime(
      _asDate(s['transactionDate']).year,
      _asDate(s['transactionDate']).month,
      _asDate(s['transactionDate']).day,
    ).add(const Duration(days: 6));
    late final List<QueryDocumentSnapshot<Map<String, dynamic>>> candidates;
    try {
      final journals = await _journals
          .where(
            'journalDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from),
          )
          .where('journalDate', isLessThan: Timestamp.fromDate(to))
          .get();
      candidates = journals.docs.where((j) {
        final lines = (j.data()['lines'] as List? ?? []);
        return lines.any(
          (l) =>
              l is Map &&
              l['accountId'] == s['accountId'] &&
              (((s['flow'] == 'in') ? _n(l['debit']) : _n(l['credit'])) -
                          _n(s['amount']))
                      .abs() <
                  0.01,
        );
      }).toList();
      final alreadyMatched = <String>{};
      for (final candidate in candidates) {
        final match = await _journalMatches.doc(candidate.id).get();
        if (match.exists) alreadyMatched.add(candidate.id);
      }
      candidates.removeWhere(
        (candidate) => alreadyMatched.contains(candidate.id),
      );
    } catch (error) {
      _msg('Could not load journals for matching: $error');
      return;
    }
    if (candidates.isEmpty) {
      _msg(
        'No unmatched exact amount/account journal was found within five days.',
      );
      return;
    }
    if (!mounted) return;
    String selected = candidates.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Match statement line'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            items: candidates
                .map(
                  (j) => DropdownMenuItem(
                    value: j.id,
                    child: AppText(
                      '${j.data()['journalDate'] is Timestamp ? _date(j.data()['journalDate']) : ''} · ${j.data()['memo']} · ${_money(j.data()['totalDebit'])}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setD(() => selected = v ?? selected),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Match'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final fresh = await tx.get(statement.reference);
          final journal = await tx.get(_journals.doc(selected));
          final match = await tx.get(_journalMatches.doc(selected));
          if (!fresh.exists ||
              fresh.data()?['status'] == 'matched' ||
              !journal.exists ||
              match.exists) {
            throw StateError(
              'Statement line or journal was already matched. Refresh.',
            );
          }
          tx.update(statement.reference, {
            'status': 'matched',
            'matchedJournalId': selected,
            'matchedBy': _uid,
            'matchedAt': FieldValue.serverTimestamp(),
          });
          tx.set(_journalMatches.doc(selected), {
            'journalId': selected,
            'statementId': statement.id,
            'accountId': s['accountId'],
            'periodKey': s['monthKey'],
            'matchedBy': _uid,
            'matchedAt': FieldValue.serverTimestamp(),
          });
        });
        await _auditEvent(
          'statement_line_matched',
          'bank_statement',
          statement.id,
          'Matched to journal $selected',
        );
        _msg('Statement line matched.');
      } catch (e) {
        _msg('Unable to match statement line: $e');
      }
    }
  }

  String _date(Object? value) {
    final d = _asDate(value);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  double _balanceFor(
    String accountId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> journals,
  ) {
    double v = 0;
    for (final j in journals) {
      for (final raw in (j.data()['lines'] as List? ?? [])) {
        if (raw is Map && raw['accountId'] == accountId) {
          v += _n(raw['debit']) - _n(raw['credit']);
        }
      }
    }
    return v;
  }

  Future<void> _finalizeReconciliation(String accountId) async {
    final closing = TextEditingController();
    late final int unmatched;
    late final double bookBalance;
    try {
      final statement = await _statements
          .where('accountId', isEqualTo: accountId)
          .where('monthKey', isEqualTo: _selectedPeriod)
          .get();
      unmatched = statement.docs
          .where((d) => d.data()['status'] != 'matched')
          .length;
      final nextMonth = DateTime(
        int.parse(_selectedPeriod.substring(0, 4)),
        int.parse(_selectedPeriod.substring(5, 7)) + 1,
        1,
      );
      final bookJournals = await _journals
          .where('journalDate', isLessThan: Timestamp.fromDate(nextMonth))
          .get();
      bookBalance = _balanceFor(accountId, bookJournals.docs);
    } catch (error) {
      closing.dispose();
      _msg('Could not load reconciliation data: $error');
      return;
    }
    if (!mounted) {
      closing.dispose();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText('Reconcile $accountId · $_selectedPeriod'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText('Book balance through period end: ${_money(bookBalance)}'),
            AppText('Unmatched statement lines: $unmatched'),
            const SizedBox(height: 8),
            TextField(
              controller: closing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: AppTranslations.translate(
                  'Closing balance as per bank statement (₹)',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Save reconciliation'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final bankClosing = double.tryParse(closing.text.trim());
      if (bankClosing == null ||
          bankClosing < 0 ||
          bankClosing > 100000000000) {
        _msg('Enter a valid bank statement closing balance.');
      } else {
        final difference = bankClosing - bookBalance;
        final reconciliationId = '${accountId}_$_selectedPeriod';
        try {
          await _reconciliations.doc(reconciliationId).set({
            'accountId': accountId,
            'periodKey': _selectedPeriod,
            'statementClosingBalance': bankClosing,
            'bookClosingBalance': bookBalance,
            'difference': difference,
            'unmatchedStatementLines': unmatched,
            'status': unmatched == 0 && difference.abs() < 0.01
                ? 'reconciled'
                : 'needs_review',
            'reconciledBy': _uid,
            'reconciledByName': widget.adminName,
            'reconciledAt': FieldValue.serverTimestamp(),
          });
          await _auditEvent(
            'bank_reconciliation_saved',
            'bank_reconciliation',
            reconciliationId,
            'Saved reconciliation. Difference ${_money(difference)}; unmatched lines $unmatched.',
          );
          _msg(
            unmatched == 0 && difference.abs() < 0.01
                ? 'Bank account reconciled.'
                : 'Reconciliation saved for review. Resolve the difference before period close.',
          );
        } catch (e) {
          _msg('Could not save reconciliation: $e');
        }
      }
    }
    closing.dispose();
  }

  Future<void> _closePeriod() async {
    late final QuerySnapshot<Map<String, dynamic>> journals;
    late final int unbalanced;
    late final int unmatched;
    late final int unreconciled;
    try {
      final existing = await _periods.doc(_selectedPeriod).get();
      if (existing.exists) {
        _msg('This accounting period is already closed.');
        return;
      }
      journals = await _journals
          .where('periodKey', isEqualTo: _selectedPeriod)
          .get();
      unbalanced = journals.docs
          .where(
            (d) =>
                (_n(d.data()['totalDebit']) - _n(d.data()['totalCredit']))
                    .abs() >
                0.005,
          )
          .length;
      final statement = await _statements
          .where('monthKey', isEqualTo: _selectedPeriod)
          .get();
      unmatched = statement.docs
          .where((d) => d.data()['status'] != 'matched')
          .length;
      final affectedAccounts = statement.docs
          .map((d) => d.data()['accountId'] as String? ?? '')
          .where((v) => v.isNotEmpty)
          .toSet();
      var unresolvedCount = 0;
      for (final accountId in affectedAccounts) {
        final rec = await _reconciliations
            .doc('${accountId}_$_selectedPeriod')
            .get();
        if (!rec.exists || rec.data()?['status'] != 'reconciled') {
          unresolvedCount++;
        }
      }
      unreconciled = unresolvedCount;
    } catch (error) {
      _msg('Could not validate the accounting period: $error');
      return;
    }
    if (unbalanced > 0 || unmatched > 0 || unreconciled > 0) {
      _msg(
        'Cannot close: $unbalanced unbalanced journals, $unmatched unmatched statement lines and $unreconciled unreconciled bank accounts remain.',
      );
      return;
    }
    final totalDebit = journals.docs.fold<double>(
      0,
      (s, d) => s + _n(d.data()['totalDebit']),
    );
    final totalCredit = journals.docs.fold<double>(
      0,
      (s, d) => s + _n(d.data()['totalCredit']),
    );
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText('Close $_selectedPeriod?'),
        content: AppText(
          'This permanently locks new accounting journals in $_selectedPeriod. ${journals.docs.length} journals · Debits ${_money(totalDebit)} · Credits ${_money(totalCredit)}. Corrections must be posted in an open period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Close period'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        final ref = _periods.doc(_selectedPeriod);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final current = await tx.get(ref);
          if (current.exists) {
            throw StateError('Period was closed by another session.');
          }
          tx.set(ref, {
            'periodKey': _selectedPeriod,
            'status': 'closed',
            'journalCount': journals.docs.length,
            'totalDebit': totalDebit,
            'totalCredit': totalCredit,
            'closedBy': _uid,
            'closedByName': widget.adminName,
            'closedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        await _auditEvent(
          'period_closed',
          'accounting_period',
          _selectedPeriod,
          'Closed period $_selectedPeriod',
        );
        _msg('Accounting period closed and locked.');
      } catch (e) {
        _msg('Could not close period: $e');
      }
    }
  }

  Widget _metric(String title, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppTheme.borderGrey),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.secondaryNavy, size: 21),
        const SizedBox(height: 8),
        AppText(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.navyBlue,
          ),
        ),
        AppText(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textGrey,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
  Widget _empty(String title, String detail, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppTheme.textGrey),
          const SizedBox(height: 8),
          AppText(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          AppText(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navyBlue,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'RWA Accounting & Reconciliation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            AppText(
              widget.colonyName,
              style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _syncOperationalSources,
            tooltip: AppTranslations.translate('Sync existing source records'),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppTheme.navyBlue,
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: AppTheme.navyBlue,
          tabs: [
            Tab(text: AppTranslations.translate('Overview')),
            Tab(text: AppTranslations.translate('Accounts')),
            Tab(text: AppTranslations.translate('Ledger')),
            Tab(text: AppTranslations.translate('Reconciliation')),
            Tab(text: AppTranslations.translate('Period Close')),
            Tab(text: AppTranslations.translate('Reports')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _overview(),
          _accountsTab(),
          _ledgerTab(),
          _reconciliationTab(),
          _periodTab(),
          _reportsTab(),
        ],
      ),
    );
  }

  Widget _overview() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _journals.snapshots(),
    builder: (context, s) {
      if (s.hasError) {
        return _empty(
          'Unable to load accounting',
          'Check Firestore rules.',
          Icons.error_outline,
        );
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final docs = s.data!.docs;
      final dr = docs.fold<double>(0, (a, d) => a + _n(d.data()['totalDebit']));
      final cr = docs.fold<double>(
        0,
        (a, d) => a + _n(d.data()['totalCredit']),
      );
      final unbalanced = docs
          .where(
            (d) =>
                (_n(d.data()['totalDebit']) - _n(d.data()['totalCredit']))
                    .abs() >
                .005,
          )
          .length;
      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          AppText(
            'Accounting control centre',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(height: 5),
          const AppText(
            'Double-entry books generated from verified colony source records. Operational bills, payments and expenses remain authoritative.',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final int responsiveColumnCount = 2;
              final double horizontalGap = (9).toDouble();
              final double itemWidth =
                  (constraints.maxWidth -
                      horizontalGap * (responsiveColumnCount - 1)) /
                  responsiveColumnCount;
              return Wrap(
                spacing: horizontalGap,
                runSpacing: 9,
                children:
                    ([
                          _metric(
                            'Posted journals',
                            '${docs.length}',
                            Icons.menu_book_outlined,
                          ),
                          _metric('Total debits', _money(dr), Icons.south_west),
                          _metric(
                            'Total credits',
                            _money(cr),
                            Icons.north_east,
                          ),
                          _metric(
                            'Unbalanced journals',
                            '$unbalanced',
                            Icons.account_balance_outlined,
                          ),
                        ])
                        .map<Widget>(
                          (child) => SizedBox(width: itemWidth, child: child),
                        )
                        .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _syncOperationalSources,
            icon: const Icon(Icons.sync),
            label: const AppText(
              'Import verified bills, receipts & paid expenses',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _manualJournal,
            icon: const Icon(Icons.add),
            label: const AppText('Create manual journal entry'),
          ),
          const SizedBox(height: 12),
          _note(
            'Accounting import rules',
            'Maintenance bills create receivables and dues income; verified receipts reduce receivables. Verified supplier invoices create payables, inventory-linked lines debit Inventory on Hand, and payments reduce payables. Payroll and ordinary paid expenses are imported from colonyExpenses. Supplier PROC-* expense mirrors are excluded because supplierPayments are posted against payables, preventing duplicate posting.',
          ),
          _note(
            'Source corrections',
            'If an already imported bill or verified supplier invoice changes, or a paid expense is reduced after import, the source is flagged for review. Posted accounting history is never silently rewritten.',
          ),
          _note(
            'Accounting basis and scope',
            'This is an internal management ledger, not an audited statutory accounting or tax product. Maintenance bills are accrued as receivables/income; verified supplier invoices are accrued to payables and inventory-linked invoice lines are allocated to Inventory on Hand; payroll and ordinary expenses are posted when paid. GST, TDS, PF, ESI, depreciation, inventory COGS and statutory filings are not calculated.',
          ),
        ],
      );
    },
  );

  Future<void> _configurePaymentMapping() async {
    final accountSnap = await _accounts
        .where('isActive', isEqualTo: true)
        .get();
    final options = accountSnap.docs
        .where(
          (d) => ['bank', 'cash', 'clearing'].contains(d.data()['subtype']),
        )
        .toList();
    if (options.isEmpty) {
      _msg('Create at least one active bank, cash or clearing account first.');
      return;
    }
    final stored = await _settings.doc('paymentMappings').get();
    final current = Map<String, String>.from(
      stored.data()?['paymentMappings'] ?? _paymentAccountMapping,
    );
    final methods = ['upi', 'bank_transfer', 'card', 'cash', 'cheque', 'other'];
    final chosen = Map<String, String>.from(current);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const AppText('Map payment methods to accounts'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppText(
                    'Select where each source payment method is posted in the books.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textGrey),
                  ),
                  ...methods.map(
                    (method) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: DropdownButtonFormField<String>(
                        initialValue: options.any((o) => o.id == chosen[method])
                            ? chosen[method]
                            : options.first.id,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            _methodLabels[method] ?? method,
                          ),
                        ),
                        items: options
                            .map(
                              (o) => DropdownMenuItem(
                                value: o.id,
                                child: AppText('${o.id} · ${o.data()['name']}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setD(() => chosen[method] = v ?? options.first.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Save mappings'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await _settings.doc('paymentMappings').set({
          'paymentMappings': chosen,
          'updatedBy': _uid,
          'updatedByName': widget.adminName,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt':
              stored.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() => _paymentAccountMapping = chosen);
        await _auditEvent(
          'payment_account_mapping_updated',
          'accounting_settings',
          'paymentMappings',
          'Updated source payment account mappings.',
        );
        _msg('Payment account mappings saved.');
      } catch (e) {
        _msg('Could not save payment mappings: $e');
      }
    }
  }

  Widget _accountsTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _accounts.orderBy('code').snapshots(),
    builder: (context, s) {
      if (s.hasError) {
        return _empty(
          'Unable to load accounts',
          'Check Firestore rules.',
          Icons.error_outline,
        );
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Chart of accounts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyBlue,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _configurePaymentMapping,
                icon: const Icon(Icons.tune, size: 16),
                label: const AppText('Payment map'),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: _createAccount,
                icon: const Icon(Icons.add, size: 16),
                label: const AppText('Add'),
              ),
            ],
          ),
          const AppText(
            'System accounts are seeded automatically. Custom accounts and additional bank/cash accounts can be added; map payment methods to the correct cash or bank ledger account.',
            style: TextStyle(fontSize: 10, color: AppTheme.textGrey),
          ),
          ...s.data!.docs.map((d) {
            final a = d.data();
            return Card(
              color: AppTheme.white,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.lightGrey,
                  child: AppText(
                    d.id,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                ),
                title: AppText(
                  a['name'] ?? d.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                subtitle: AppText(
                  '${_typeLabels[a['type']] ?? a['type']} · ${a['subtype'] ?? 'custom'}',
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: TextButton(
                  onPressed: () => _setOpeningBalance(d.id, a),
                  child: const AppText('Opening balance'),
                ),
              ),
            );
          }),
        ],
      );
    },
  );

  Widget _ledgerTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _journals
        .orderBy('journalDate', descending: true)
        .limit(250)
        .snapshots(),
    builder: (context, s) {
      if (s.hasError) {
        return _empty(
          'Unable to load ledger',
          'Check Firestore rules.',
          Icons.error_outline,
        );
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'General ledger',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.navyBlue,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _manualJournal,
                icon: const Icon(Icons.add, size: 16),
                label: const AppText('Journal'),
              ),
            ],
          ),
          ...s.data!.docs.map((d) {
            final j = d.data();
            final lines = (j['lines'] as List? ?? []);
            return Card(
              color: AppTheme.white,
              child: ExpansionTile(
                title: AppText(
                  j['memo'] ?? 'Journal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                subtitle: AppText(
                  '${_date(j['journalDate'])} · ${j['periodKey']} · ${j['sourceType']}',
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: AppText(
                  _money(j['totalDebit']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navyBlue,
                  ),
                ),
                children: lines.map((l) {
                  final m = Map<String, dynamic>.from(l as Map);
                  return ListTile(
                    dense: true,
                    title: AppText(
                      'Account ${m['accountId']}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: AppText(
                      'Dr ${_money(m['debit'])} · Cr ${_money(m['credit'])}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      );
    },
  );

  Widget
  _reconciliationTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _accounts.where('isActive', isEqualTo: true).snapshots(),
    builder: (context, as) {
      if (as.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText(
                'Unable to load bank and cash accounts.',
                style: TextStyle(color: AppTheme.textGrey),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: AppText(as.error.toString()),
              ),
              TextButton(
                onPressed: () {
                  if (mounted) setState(() {});
                },
                child: const AppText('Retry'),
              ),
            ],
          ),
        );
      }
      if (as.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      final bank = as.data!.docs
          .where(
            (d) => ['bank', 'cash', 'clearing'].contains(d.data()['subtype']),
          )
          .toList();
      if (bank.isEmpty) {
        return _empty(
          'No active bank or cash accounts',
          'Create an active bank, cash or clearing account before reconciliation.',
          Icons.account_balance_outlined,
        );
      }
      final selected =
          _selectedBankAccount ?? (bank.isNotEmpty ? bank.first.id : null);
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Statement reconciliation',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.navyBlue,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addStatementLine,
                icon: const Icon(Icons.add, size: 16),
                label: const AppText('Add line'),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: InputDecoration(
              labelText: AppTranslations.translate('Bank / cash account'),
            ),
            items: bank
                .map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: AppText('${d.id} · ${d.data()['name']}'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedBankAccount = v),
          ),
          DropdownButtonFormField<String>(
            initialValue: _selectedPeriod,
            decoration: InputDecoration(
              labelText: AppTranslations.translate('Statement month'),
            ),
            items: List.generate(24, (i) {
              final d = DateTime(
                DateTime.now().year,
                DateTime.now().month - i,
                1,
              );
              final k = _monthKey(d);
              return DropdownMenuItem(value: k, child: AppText(k));
            }),
            onChanged: (v) {
              if (v != null) setState(() => _selectedPeriod = v);
            },
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _statements.snapshots(),
            builder: (context, ss) {
              if (ss.hasError) {
                return Column(
                  children: [
                    const AppText(
                      'Unable to load bank statement lines.',
                      style: TextStyle(color: AppTheme.textGrey),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: AppText(ss.error.toString()),
                    ),
                    TextButton(
                      onPressed: () {
                        if (mounted) setState(() {});
                      },
                      child: const AppText('Retry'),
                    ),
                  ],
                );
              }
              if (ss.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final lines =
                  ss.data!.docs
                      .where(
                        (d) =>
                            d.data()['accountId'] == selected &&
                            d.data()['monthKey'] == _selectedPeriod,
                      )
                      .toList()
                    ..sort(
                      (a, b) =>
                          _asDate(b.data()['transactionDate'])
                              .compareTo(_asDate(a.data()['transactionDate'])),
                    );
              final unmatched = lines
                  .where((d) => d.data()['status'] != 'matched')
                  .length;
              return Column(
                children: [
                  _metric(
                    'Unmatched statement lines',
                    '$unmatched',
                    Icons.compare_arrows,
                  ),
                  FilledButton.icon(
                    onPressed: selected == null
                        ? null
                        : () => _finalizeReconciliation(selected),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const AppText('Finalize account reconciliation'),
                  ),
                  ...lines.map((d) {
                    final x = d.data();
                    return Card(
                      color: AppTheme.white,
                      child: ListTile(
                        title: AppText(
                          x['description'] ?? 'Statement line',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: AppText(
                          '${_date(x['transactionDate'])} · ${x['flow']} · ${x['bankReference'] ?? ''}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: x['status'] == 'matched'
                            ? const Icon(
                                Icons.check_circle_outline,
                                color: AppTheme.secondaryNavy,
                              )
                            : TextButton(
                                onPressed: () => _matchStatement(d),
                                child: const AppText('Match'),
                              ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      );
    },
  );

  Widget _periodTab() => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      AppText(
        'Financial period control',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.navyBlue,
        ),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _selectedPeriod,
        decoration: InputDecoration(
          labelText: AppTranslations.translate('Accounting month'),
        ),
        items: List.generate(24, (i) {
          final d = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
          final k = _monthKey(d);
          return DropdownMenuItem(value: k, child: AppText(k));
        }),
        onChanged: (v) {
          if (v != null) setState(() => _selectedPeriod = v);
        },
      ),
      const SizedBox(height: 12),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _periods.doc(_selectedPeriod).snapshots(),
        builder: (context, s) {
          if (s.hasError) {
            return Card(
              color: AppTheme.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'Unable to verify accounting period status.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    AppText('${s.error}'),
                    TextButton(
                      onPressed: () => setState(() {}),
                      child: const AppText('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (s.connectionState == ConnectionState.waiting && !s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final closed = s.data?.exists == true;
          return Card(
            color: AppTheme.white,
            child: ListTile(
              leading: Icon(
                closed ? Icons.lock : Icons.lock_open,
                color: AppTheme.navyBlue,
              ),
              title: AppText(
                closed ? 'Period closed' : 'Period open',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: AppText(
                closed
                    ? 'Closed by ${s.data?.data()?['closedByName'] ?? 'Admin'}'
                    : 'Posting and reconciliation are allowed.',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _closePeriod,
        icon: const Icon(Icons.lock_outline),
        label: const AppText('Validate and close period'),
      ),
      const SizedBox(height: 8),
      _note(
        'Before closing',
        'All posted journals must balance. Every statement line entered for the month must be matched. Closing permanently prevents new journals in that month; corrections must be posted in an open period.',
      ),
    ],
  );

  Widget _reportStreamError(String title, Object error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 38,
            color: AppTheme.textGrey,
          ),
          const SizedBox(height: 10),
          AppText(title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          AppText('$error', textAlign: TextAlign.center),
          TextButton(
            onPressed: () => setState(() {}),
            child: const AppText('Retry'),
          ),
        ],
      ),
    ),
  );

  Widget _reportsTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _accounts.orderBy('code').snapshots(),
    builder: (context, as) {
      if (as.hasError) {
        return _reportStreamError(
          'Unable to load accounting accounts',
          as.error!,
        );
      }
      if (!as.hasData) return const Center(child: CircularProgressIndicator());
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _journals.snapshots(),
        builder: (context, js) {
          if (js.hasError) {
            return _reportStreamError(
              'Unable to load accounting journals',
              js.error!,
            );
          }
          if (!js.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = js.data!.docs;
          final accounts = as.data!.docs;
          double sumType(String type) {
            double total = 0;
            for (final a in accounts.where((d) => d.data()['type'] == type)) {
              final balance = _balanceFor(a.id, docs);
              final normal = a.data()['normalBalance'] ?? 'debit';
              total += normal == 'debit' ? balance : -balance;
            }
            return total;
          }

          final assets = sumType('asset'),
              liabilities = sumType('liability'),
              equity = sumType('equity'),
              income = sumType('income'),
              expense = sumType('expense');
          final rows = <String>[
            'TRIAL BALANCE',
            'Assets ${_money(assets)}',
            'Liabilities ${_money(liabilities)}',
            'Equity ${_money(equity)}',
            'Income ${_money(income)}',
            'Expenses ${_money(expense)}',
            'Surplus / (deficit) ${_money(income - expense)}',
            'Balance check ${(assets - (liabilities + equity + income - expense)).abs() < 0.05 ? 'Balanced' : 'Review required'}',
          ];
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              AppText(
                'Financial statements',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navyBlue,
                ),
              ),
              const SizedBox(height: 8),
              ...rows.map(
                (r) => Card(
                  color: AppTheme.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AppText(
                      r,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: rows.join('\n')))
                        .then((_) => _msg('Financial summary copied.')),
                icon: const Icon(Icons.copy),
                label: const AppText('Copy financial summary'),
              ),
            ],
          );
        },
      );
    },
  );

  Widget _note(String title, String text) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.white,
      border: Border.all(color: AppTheme.borderGrey),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.navyBlue,
          ),
        ),
        const SizedBox(height: 4),
        AppText(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textGrey,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}
// MOHALLAFLOW_RWA_ACCOUNTING_SCREEN_END
