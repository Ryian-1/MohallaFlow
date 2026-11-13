import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

import '../services/notification_service.dart';
import '../widgets/app_text.dart';
import '../widgets/app_selectable_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class MaintenanceDuesScreen extends StatefulWidget {
  const MaintenanceDuesScreen({
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
  State<MaintenanceDuesScreen> createState() => _MaintenanceDuesScreenState();
}

class _MaintenanceDuesScreenState extends State<MaintenanceDuesScreen> {
  int _adminTab = 0;
  String _filter = 'all';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _bills => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('maintenanceBills');

  CollectionReference<Map<String, dynamic>> get _payments => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('maintenancePayments');

  CollectionReference<Map<String, dynamic>> get _households => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('households');

  DocumentReference<Map<String, dynamic>> get _resident => FirebaseFirestore
      .instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('residents')
      .doc(widget.residentId);

  num _number(dynamic value) => value is num ? value : 0;

  String _money(num value) => '₹${value.toStringAsFixed(2)}';

  String _date(dynamic value) {
    if (value is! Timestamp) return 'Not available';

    final date = value.toDate().toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _status(Map<String, dynamic> data) {
    final total = _number(data['totalAmount']);
    final paid = _number(data['amountPaid']);

    if (total > 0 && paid >= total) return 'Paid';

    final dueDate = data['dueDate'];
    if (dueDate is Timestamp && dueDate.toDate().isBefore(DateTime.now())) {
      return 'Overdue';
    }

    if (paid > 0) return 'Partially paid';

    return 'Unpaid';
  }

  String _paymentMethod(String method) {
    switch (method) {
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
        return 'Bank transfer';
      case 'cash':
        return 'Cash';
      default:
        return method;
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  // =====================================================
  // CREATE HOUSEHOLD BILL
  // =====================================================

  Future<void> _createBill() async {
    final uid = _uid;
    if (uid == null) {
      _message('Please sign in again.');
      return;
    }

    try {
      final householdSnapshot = await _households
          .where('occupancyStatus', isEqualTo: 'occupied')
          .get();

      if (!mounted) return;

      final households = householdSnapshot.docs;

      if (households.isEmpty) {
        _message('No occupied households are available.');
        return;
      }

      final periodController = TextEditingController();
      final titleController = TextEditingController(
        text: 'Monthly maintenance',
      );
      final amountController = TextEditingController();
      final descriptionController = TextEditingController();
      final upiController = TextEditingController();
      final instructionsController = TextEditingController();

      String? selectedHouseholdId;
      DateTime dueDate = DateTime.now().add(const Duration(days: 7));

      try {
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                Future<void> pickDate() async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: dueDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );

                  if (picked != null && dialogContext.mounted) {
                    setDialogState(() {
                      dueDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        23,
                        59,
                      );
                    });
                  }
                }

                return AlertDialog(
                  title: const AppText(
                    'Create maintenance bill',
                    style: TextStyle(
                      color: AppTheme.navyBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  content: SizedBox(
                    width: 430,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedHouseholdId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Household *',
                              ),
                            ),
                            items: households.map((household) {
                              final data = household.data();
                              final block = data['blockId'] as String? ?? '';
                              final house =
                                  data['houseNumber'] as String? ?? '';
                              final head =
                                  data['householdHeadName'] as String? ?? '';

                              return DropdownMenuItem(
                                value: household.id,
                                child: AppText(
                                  '$block - $house · $head',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() => selectedHouseholdId = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: periodController,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Billing period *',
                              ),
                              hintText: AppTranslations.translate(
                                'November 2026',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Bill title *',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Total amount (₹) *',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descriptionController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Description',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: pickDate,
                              icon: const Icon(Icons.calendar_month),
                              label: AppText(
                                'Due date: ${_date(Timestamp.fromDate(dueDate))}',
                              ),
                            ),
                          ),
                          const Divider(height: 26),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: AppText(
                              'Payment instructions',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navyBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: upiController,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate('UPI ID'),
                              hintText: AppTranslations.translate(
                                'society@bank',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: instructionsController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: AppTranslations.translate(
                                'Additional instructions',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const AppText('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navyBlue,
                      ),
                      onPressed: () {
                        final amount = num.tryParse(
                          amountController.text.trim(),
                        );

                        if (selectedHouseholdId == null) {
                          _message('Select a household.');
                        } else if (periodController.text.trim().isEmpty) {
                          _message('Enter the billing period.');
                        } else if (titleController.text.trim().isEmpty) {
                          _message('Enter the bill title.');
                        } else if (amount == null || amount <= 0) {
                          _message('Enter a valid amount.');
                        } else {
                          Navigator.of(dialogContext).pop(true);
                        }
                      },
                      child: const AppText('Create bill'),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (confirmed != true || !mounted) return;

        final householdId = selectedHouseholdId;
        if (householdId == null) return;

        final household = households.firstWhere(
          (item) => item.id == householdId,
        );
        final householdData = household.data();

        final amount = num.parse(amountController.text.trim());

        final billRef = _bills.doc();
        final batch = FirebaseFirestore.instance.batch();
        batch.set(billRef, {
          'householdId': householdId,
          'blockId': householdData['blockId'] as String? ?? '',
          'houseNumber': householdData['houseNumber'] as String? ?? '',
          'householdHeadName':
              householdData['householdHeadName'] as String? ?? '',
          'billingPeriod': periodController.text.trim(),
          'title': titleController.text.trim(),
          'description': descriptionController.text.trim(),
          'totalAmount': amount,
          'amountPaid': 0,
          'status': 'unpaid',
          'dueDate': Timestamp.fromDate(dueDate),
          'upiId': upiController.text.trim(),
          'paymentInstructions': instructionsController.text.trim(),
          'createdBy': uid,
          'createdByName': widget.adminName ?? 'Admin',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        NotificationService.addBillIssued(
          batch: batch,
          colonyId: widget.colonyId,
          billId: billRef.id,
          createdBy: uid,
        );
        await batch.commit();

        _message('Maintenance bill created successfully.');
      } finally {
        periodController.dispose();
        titleController.dispose();
        amountController.dispose();
        descriptionController.dispose();
        upiController.dispose();
        instructionsController.dispose();
      }
    } on FirebaseException catch (error) {
      _message('Unable to create bill: ${error.message ?? error.code}');
    } catch (error) {
      _message('Unable to create bill: $error');
    }
  }

  // =====================================================
  // RECORD ADMIN PAYMENT
  // =====================================================

  Future<void> _recordPayment(
    QueryDocumentSnapshot<Map<String, dynamic>> bill,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    final data = bill.data();
    final total = _number(data['totalAmount']);
    final paid = _number(data['amountPaid']);
    final balance = total - paid;

    if (balance <= 0) {
      _message('This bill is already fully paid.');
      return;
    }

    final amountController = TextEditingController(
      text: balance.toStringAsFixed(2),
    );
    final referenceController = TextEditingController();

    String method = 'cash';

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const AppText('Record verified payment'),
                content: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText('Outstanding: ${_money(balance)}'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Amount received (₹)',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: method,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Payment method',
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'cash',
                            child: AppText('Cash'),
                          ),
                          DropdownMenuItem(value: 'upi', child: AppText('UPI')),
                          DropdownMenuItem(
                            value: 'bank_transfer',
                            child: AppText('Bank transfer'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => method = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: referenceController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Transaction / receipt reference',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const AppText('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final amount = num.tryParse(amountController.text.trim());

                      if (amount == null || amount <= 0 || amount > balance) {
                        _message('Enter a valid amount within the balance.');
                        return;
                      }

                      Navigator.of(dialogContext).pop(true);
                    },
                    child: const AppText('Confirm payment'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true || !mounted) return;

      final amount = num.parse(amountController.text.trim());
      final paymentRef = _payments.doc();
      final billRef = _bills.doc(bill.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(billRef);

        if (!snapshot.exists) {
          throw StateError('Bill not found.');
        }

        final current = snapshot.data()!;
        final currentTotal = _number(current['totalAmount']);
        final currentPaid = _number(current['amountPaid']);
        final outstanding = currentTotal - currentPaid;

        if (amount > outstanding || amount <= 0) {
          throw StateError('The payment exceeds the current balance.');
        }

        final newPaid = currentPaid + amount;

        transaction.update(billRef, {
          'amountPaid': newPaid,
          'status': newPaid >= currentTotal ? 'paid' : 'partially_paid',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(paymentRef, {
          'billId': bill.id,
          'householdId': current['householdId'],
          'residentId': null,
          'residentName': current['householdHeadName'] ?? 'Household',
          'submittedBy': uid,
          'submittedByName': widget.adminName ?? 'Admin',
          'submittedByRole': 'admin',
          'paymentMethod': method,
          'amount': amount,
          'transactionReference': referenceController.text.trim(),
          'notes': '',
          'status': 'verified',
          'createdBy': uid,
          'createdByRole': 'admin',
          'createdByName': widget.adminName ?? 'Admin',
          'verifiedBy': uid,
          'verifiedByName': widget.adminName ?? 'Admin',
          'verifiedAt': FieldValue.serverTimestamp(),
          'rejectionReason': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _message('Payment recorded successfully.');
    } on FirebaseException catch (error) {
      _message('Unable to record payment: ${error.message ?? error.code}');
    } catch (error) {
      _message('Unable to record payment: $error');
    } finally {
      amountController.dispose();
      referenceController.dispose();
    }
  }

  // =====================================================
  // RESIDENT PAYMENT SUBMISSION
  // =====================================================

  Future<void> _submitPayment(
    QueryDocumentSnapshot<Map<String, dynamic>> bill,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    final data = bill.data();
    final balance = _number(data['totalAmount']) - _number(data['amountPaid']);

    if (balance <= 0) {
      _message('This bill is already paid.');
      return;
    }

    final amountController = TextEditingController(
      text: balance.toStringAsFixed(2),
    );
    final referenceController = TextEditingController();

    String method = 'upi';

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const AppText('Submit payment details'),
                content: SizedBox(
                  width: 390,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText('Outstanding: ${_money(balance)}'),
                        if ((data['upiId'] as String? ?? '').isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            color: AppTheme.lightGrey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText(
                                  'UPI ID',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 5),
                                AppSelectableText(data['upiId'] as String),
                                if ((data['paymentInstructions'] as String? ??
                                        '')
                                    .isNotEmpty)
                                  AppText(
                                    data['paymentInstructions'] as String,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Amount paid (₹)',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: method,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Payment method',
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'upi',
                              child: AppText('UPI'),
                            ),
                            DropdownMenuItem(
                              value: 'bank_transfer',
                              child: AppText('Bank transfer'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => method = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: referenceController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Transaction reference / UTR *',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const AppText(
                          'Payment remains pending until the Admin verifies '
                          'the transfer. Complete the transfer before '
                          'submitting its reference.',
                          style: TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const AppText('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final amount = num.tryParse(amountController.text.trim());

                      if (amount == null || amount <= 0 || amount > balance) {
                        _message('Enter a valid amount within the balance.');
                        return;
                      }

                      if (referenceController.text.trim().isEmpty) {
                        _message('Enter your transaction reference.');
                        return;
                      }

                      Navigator.of(dialogContext).pop(true);
                    },
                    child: const AppText('Submit for verification'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true || !mounted) return;

      final residentSnapshot = await _resident.get();

      if (!mounted) return;

      if (!residentSnapshot.exists) {
        _message('Resident profile not found.');
        return;
      }

      final residentData = residentSnapshot.data()!;

      if (residentData['residentStatus'] != 'active' ||
          residentData['householdId'] != data['householdId']) {
        _message('Your resident profile is not linked to this household.');
        return;
      }

      final paymentRef = _payments.doc();
      final batch = FirebaseFirestore.instance.batch();
      batch.set(paymentRef, {
        'billId': bill.id,
        'householdId': data['householdId'],
        'residentId': widget.residentId,
        'residentName': widget.residentName ?? '',
        'submittedBy': uid,
        'submittedByName': widget.residentName ?? '',
        'submittedByRole': 'resident',
        'paymentMethod': method,
        'amount': num.parse(amountController.text.trim()),
        'transactionReference': referenceController.text.trim(),
        'notes': '',
        'status': 'pending',
        'createdBy': uid,
        'createdByRole': 'resident',
        'createdByName': widget.residentName ?? '',
        'verifiedBy': null,
        'verifiedByName': null,
        'verifiedAt': null,
        'rejectionReason': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      NotificationService.addPaymentSubmitted(
        batch: batch,
        colonyId: widget.colonyId,
        paymentId: paymentRef.id,
        residentName: widget.residentName ?? 'A resident',
        createdBy: uid,
      );
      await batch.commit();

      _message('Payment submitted for Admin verification.');
    } on FirebaseException catch (error) {
      _message('Unable to submit payment: ${error.message ?? error.code}');
    } catch (error) {
      _message('Unable to submit payment: $error');
    } finally {
      amountController.dispose();
      referenceController.dispose();
    }
  }

  // =====================================================
  // REVIEW PAYMENT
  // =====================================================

  Future<void> _reviewPayment(
    QueryDocumentSnapshot<Map<String, dynamic>> payment, {
    required bool approve,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final reasonController = TextEditingController();

    try {
      if (!approve) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const AppText('Reject payment'),
            content: TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppTranslations.translate('Reason for rejection'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const AppText('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (reasonController.text.trim().isEmpty) {
                    _message('Enter a rejection reason.');
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const AppText('Reject'),
              ),
            ],
          ),
        );

        if (confirmed != true || !mounted) return;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final paymentSnapshot = await transaction.get(payment.reference);

        if (!paymentSnapshot.exists ||
            paymentSnapshot.data()!['status'] != 'pending') {
          throw StateError('Payment is missing or already reviewed.');
        }

        final paymentData = paymentSnapshot.data()!;

        if (!approve) {
          transaction.update(payment.reference, {
            'status': 'rejected',
            'verifiedBy': uid,
            'verifiedByName': widget.adminName ?? 'Admin',
            'verifiedAt': FieldValue.serverTimestamp(),
            'rejectionReason': reasonController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          NotificationService.addPaymentReviewedToTransaction(
            transaction: transaction,
            colonyId: widget.colonyId,
            paymentId: payment.id,
            residentUid: paymentData['submittedBy'] as String? ?? '',
            approved: false,
            createdBy: uid,
          );
          return;
        }

        final billId = paymentData['billId'] as String?;
        if (billId == null || billId.isEmpty) {
          throw StateError('Linked bill not found.');
        }

        final billRef = _bills.doc(billId);
        final billSnapshot = await transaction.get(billRef);

        if (!billSnapshot.exists) {
          throw StateError('Linked bill not found.');
        }

        final billData = billSnapshot.data()!;
        final total = _number(billData['totalAmount']);
        final paid = _number(billData['amountPaid']);
        final amount = _number(paymentData['amount']);
        final balance = total - paid;

        if (amount <= 0 || amount > balance) {
          throw StateError('Payment exceeds the current bill balance.');
        }

        final newPaid = paid + amount;

        transaction.update(billRef, {
          'amountPaid': newPaid,
          'status': newPaid >= total ? 'paid' : 'partially_paid',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(payment.reference, {
          'status': 'verified',
          'verifiedBy': uid,
          'verifiedByName': widget.adminName ?? 'Admin',
          'verifiedAt': FieldValue.serverTimestamp(),
          'rejectionReason': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        NotificationService.addPaymentReviewedToTransaction(
          transaction: transaction,
          colonyId: widget.colonyId,
          paymentId: payment.id,
          residentUid: paymentData['submittedBy'] as String? ?? '',
          approved: true,
          createdBy: uid,
        );
      });

      _message(approve ? 'Payment verified.' : 'Payment rejected.');
    } on FirebaseException catch (error) {
      _message('Unable to review payment: ${error.message ?? error.code}');
    } catch (error) {
      _message('Unable to review payment: $error');
    } finally {
      reasonController.dispose();
    }
  }

  // =====================================================
  // BILL CARD
  // =====================================================

  // V2 UPI INTENT: opens an installed UPI app with the current bill balance.
  Future<void> _launchUpiPayment(
    Map<String, dynamic> billData,
    num outstanding,
  ) async {
    final upiId = (billData['upiId'] as String? ?? '').trim();
    final at = upiId.indexOf('@');

    if (upiId.isEmpty ||
        at <= 0 ||
        at == upiId.length - 1 ||
        at != upiId.lastIndexOf('@') ||
        upiId.contains(RegExp(r'\s'))) {
      _message('The Colony Admin has not configured a valid UPI ID.');
      return;
    }

    if (outstanding <= 0) {
      _message('This bill has no outstanding balance.');
      return;
    }

    final period = (billData['billingPeriod'] as String? ?? '').trim();
    final block = (billData['blockId'] as String? ?? '').trim();
    final house = (billData['houseNumber'] as String? ?? '').trim();
    final reference = [
      'MohallaFlow',
      period,
      if (block.isNotEmpty || house.isNotEmpty) '$block-$house',
    ].where((value) => value.isNotEmpty).join(' ');

    final paymentUri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': widget.colonyName,
        'am': outstanding.toStringAsFixed(2),
        'cu': 'INR',
        'tn': reference.length > 80 ? reference.substring(0, 80) : reference,
      },
    );

    try {
      final launched = await launchUrl(
        paymentUri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) return;

      await Clipboard.setData(ClipboardData(text: paymentUri.toString()));
      _message(
        'No UPI app opened. The payment link has been copied; paste it into '
        'your UPI app.',
      );
    } catch (error) {
      try {
        await Clipboard.setData(ClipboardData(text: paymentUri.toString()));
        _message(
          'Could not open a UPI app. The payment link was copied instead.',
        );
      } catch (_) {
        _message('Unable to open or copy the UPI payment link: $error');
      }
    }
  }

  Widget _billCard(
    QueryDocumentSnapshot<Map<String, dynamic>> bill, {
    required bool admin,
  }) {
    final data = bill.data();
    final total = _number(data['totalAmount']);
    final paid = _number(data['amountPaid']);
    final balance = (total - paid).clamp(0, total);
    final status = _status(data);

    final color = status == 'Paid'
        ? const Color(0xFF26734D)
        : status == 'Overdue'
        ? const Color(0xFFB54747)
        : status == 'Partially paid'
        ? const Color(0xFF996515)
        : AppTheme.secondaryNavy;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
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
                  data['title'] as String? ?? 'Maintenance bill',
                  style: const TextStyle(
                    color: AppTheme.navyBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              AppText(
                status,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          AppText(
            data['billingPeriod'] as String? ?? '',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
          if (admin) ...[
            const SizedBox(height: 9),
            AppText(
              '${data['householdHeadName'] ?? ''} · '
              'Block ${data['blockId'] ?? ''} · '
              'House ${data['houseNumber'] ?? ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _amount('Total', total)),
              Expanded(child: _amount('Paid', paid)),
              Expanded(child: _amount('Balance', balance)),
            ],
          ),
          const SizedBox(height: 13),
          AppText(
            'Due date: ${_date(data['dueDate'])}',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
          if ((data['description'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppText(
                data['description'] as String,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
            ),
          if (admin && balance > 0) ...[
            const Divider(height: 22),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _recordPayment(bill),
                icon: const Icon(Icons.add_card_outlined),
                label: const AppText('Record payment'),
              ),
            ),
          ],
          if (!admin && balance > 0) ...[
            if ((data['upiId'] as String? ?? '').isNotEmpty) ...[
              const Divider(height: 22),
              const AppText(
                'UPI payment details',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              AppSelectableText(data['upiId'] as String),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _launchUpiPayment(data, balance),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: AppText('Pay ${_money(balance)} using UPI app'),
                ),
              ),
              if ((data['paymentInstructions'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: AppText(
                    data['paymentInstructions'] as String,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _submitPayment(bill),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                ),
                icon: const Icon(Icons.payments_outlined),
                label: const AppText('Submit payment details'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _amount(String label, num value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
        ),
        const SizedBox(height: 4),
        AppText(
          _money(value),
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // ADMIN BILLS
  // =====================================================

  Widget _adminBills() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _bills.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: AppText('Unable to load bills: ${snapshot.error}'),
          );
        }

        final records = snapshot.data?.docs ?? [];

        final visible = records.where((bill) {
          final status = _status(bill.data());

          if (_filter == 'paid') return status == 'Paid';
          if (_filter == 'unpaid') return status != 'Paid';

          return true;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 7),
              child: Wrap(
                spacing: 8,
                children: [
                  _filterChip('All', 'all'),
                  _filterChip('Outstanding', 'unpaid'),
                  _filterChip('Paid', 'paid'),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? _empty(
                      'No maintenance bills',
                      'Create a bill for an occupied household.',
                      Icons.receipt_long_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 11),
                      itemBuilder: (context, index) =>
                          _billCard(visible[index], admin: true),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;

    return ChoiceChip(
      label: AppText(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppTheme.navyBlue,
      backgroundColor: AppTheme.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.navyBlue,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // =====================================================
  // ADMIN PAYMENT SUBMISSIONS
  // =====================================================

  Widget _adminPayments() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _payments.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: AppText('Unable to load payments: ${snapshot.error}'),
          );
        }

        final records = snapshot.data?.docs ?? [];

        if (records.isEmpty) {
          return _empty(
            'No payment submissions',
            'Resident payment submissions will appear here.',
            Icons.payments_outlined,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final payment = records[index];
            final data = payment.data();
            final status = data['status'] as String? ?? 'pending';
            final pending = status == 'pending';

            return Container(
              padding: const EdgeInsets.all(15),
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
                          data['residentName'] as String? ?? 'Payment',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navyBlue,
                          ),
                        ),
                      ),
                      AppText(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: status == 'verified'
                              ? const Color(0xFF26734D)
                              : status == 'rejected'
                              ? const Color(0xFFB54747)
                              : const Color(0xFF996515),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  AppText(
                    _money(_number(data['amount'])),
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    '${_paymentMethod(data['paymentMethod'] as String? ?? '')}'
                    ' · ${_date(data['createdAt'])}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                  if ((data['transactionReference'] as String? ?? '')
                      .isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: AppSelectableText(
                        'Reference: ${data['transactionReference']}',
                        translate: true,
                      ),
                    ),
                  if (status == 'rejected' &&
                      (data['rejectionReason'] as String? ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: AppText(
                        'Reason: ${data['rejectionReason']}',
                        style: const TextStyle(
                          color: Color(0xFFB54747),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if (pending) ...[
                    const Divider(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              _reviewPayment(payment, approve: false),
                          child: const AppText(
                            'Reject',
                            style: TextStyle(color: Color(0xFFB54747)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.navyBlue,
                          ),
                          onPressed: () =>
                              _reviewPayment(payment, approve: true),
                          child: const AppText('Verify payment'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =====================================================
  // RESIDENT BILLS
  // =====================================================

  Widget _residentBills() {
    if (widget.residentId == null || widget.residentId!.isEmpty) {
      return _empty(
        'Resident account not linked',
        'Contact your Colony Admin.',
        Icons.person_off_outlined,
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _resident.get(),
      builder: (context, residentSnapshot) {
        if (residentSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }

        if (residentSnapshot.hasError) {
          return Center(
            child: AppText('Unable to load profile: ${residentSnapshot.error}'),
          );
        }

        if (!residentSnapshot.hasData || !residentSnapshot.data!.exists) {
          return _empty(
            'Resident profile not found',
            'Contact your Colony Admin.',
            Icons.person_off_outlined,
          );
        }

        final residentData = residentSnapshot.data!.data()!;

        if (residentData['residentStatus'] != 'active') {
          return _empty(
            'Resident account inactive',
            'Contact your Colony Admin.',
            Icons.lock_outline,
          );
        }

        final householdId = residentData['householdId'] as String? ?? '';

        if (householdId.isEmpty) {
          return _empty(
            'No household linked',
            'Your resident profile needs a household assignment.',
            Icons.home_outlined,
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _bills
              .where('householdId', isEqualTo: householdId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.navyBlue),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AppText('Unable to load bills: ${snapshot.error}'),
                ),
              );
            }

            final records = snapshot.data?.docs.toList() ?? [];

            records.sort((a, b) {
              final aDate = a.data()['createdAt'];
              final bDate = b.data()['createdAt'];

              final aTime = aDate is Timestamp
                  ? aDate.millisecondsSinceEpoch
                  : 0;
              final bTime = bDate is Timestamp
                  ? bDate.millisecondsSinceEpoch
                  : 0;

              return bTime.compareTo(aTime);
            });

            // Use a named accumulator to avoid the Dart lint:
            // avoid_types_as_parameter_names.
            final outstanding = records.fold<num>(0, (runningTotal, bill) {
              final data = bill.data();
              final balance =
                  _number(data['totalAmount']) - _number(data['amountPaid']);

              return runningTotal + (balance > 0 ? balance : 0);
            });

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.navyBlue,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'HOUSEHOLD OUTSTANDING',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        _money(outstanding),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AppText(
                        '${residentData['blockId'] ?? ''} · '
                        '${residentData['houseNumber'] ?? ''}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const AppText(
                  'Household maintenance bills',
                  style: TextStyle(
                    color: AppTheme.navyBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  _empty(
                    'No maintenance bills',
                    'Your Admin has not issued a bill for this household.',
                    Icons.receipt_long_outlined,
                  )
                else
                  ...records.map(
                    (bill) => Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: _billCard(bill, admin: false),
                    ),
                  ),
                const SizedBox(height: 18),
                const AppText(
                  'My payment history',
                  style: TextStyle(
                    color: AppTheme.navyBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 10),
                _residentPayments(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _residentPayments() {
    final uid = _uid;
    if (uid == null) return const AppText('Please sign in again.');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _payments.where('submittedBy', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.navyBlue),
          );
        }

        if (snapshot.hasError) {
          return AppText('Unable to load history: ${snapshot.error}');
        }

        final records = snapshot.data?.docs ?? [];

        if (records.isEmpty) {
          return const AppText(
            'No payment submissions yet.',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
          );
        }

        return Column(
          children: records.map((record) {
            final data = record.data();
            final status = data['status'] as String? ?? 'pending';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppTheme.white,
                border: Border.all(color: AppTheme.borderGrey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppText(
                          _money(_number(data['amount'])),
                          style: const TextStyle(
                            color: AppTheme.navyBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      AppText(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: status == 'verified'
                              ? const Color(0xFF26734D)
                              : status == 'rejected'
                              ? const Color(0xFFB54747)
                              : const Color(0xFF996515),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  AppText(
                    '${_paymentMethod(data['paymentMethod'] as String? ?? '')}'
                    ' · ${_date(data['createdAt'])}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                  if ((data['rejectionReason'] as String? ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: AppText(
                        'Admin note: ${data['rejectionReason']}',
                        style: const TextStyle(
                          color: Color(0xFFB54747),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =====================================================
  // EMPTY STATE
  // =====================================================

  Widget _empty(String title, String description, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 43, color: AppTheme.secondaryNavy),
            const SizedBox(height: 12),
            AppText(
              title,
              textAlign: TextAlign.center,
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
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // MAIN BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              widget.isAdmin ? 'Maintenance Dues' : 'My Maintenance Bills',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            AppText(
              widget.colonyName,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
            ),
          ],
        ),
      ),
      body: widget.isAdmin
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 7),
                  child: Row(
                    children: [
                      Expanded(child: _tabChip('Bills', 0)),
                      const SizedBox(width: 9),
                      Expanded(child: _tabChip('Payment submissions', 1)),
                    ],
                  ),
                ),
                Expanded(
                  child: _adminTab == 0 ? _adminBills() : _adminPayments(),
                ),
              ],
            )
          : _residentBills(),
      floatingActionButton: widget.isAdmin && _adminTab == 0
          ? FloatingActionButton.extended(
              onPressed: _createBill,
              backgroundColor: AppTheme.navyBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_card_outlined),
              label: const AppText('Create bill'),
            )
          : null,
    );
  }

  Widget _tabChip(String label, int index) {
    final selected = _adminTab == index;

    return InkWell(
      onTap: () => setState(() => _adminTab = index),
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.navyBlue : AppTheme.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? AppTheme.navyBlue : AppTheme.borderGrey,
          ),
        ),
        child: AppText(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.navyBlue,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
