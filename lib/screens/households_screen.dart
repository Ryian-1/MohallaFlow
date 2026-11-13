import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class HouseholdsScreen extends StatefulWidget {
  const HouseholdsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
  });

  final String colonyId;
  final String colonyName;

  @override
  State<HouseholdsScreen> createState() => _HouseholdsScreenState();
}

class _HouseholdsScreenState extends State<HouseholdsScreen> {
  CollectionReference<Map<String, dynamic>> get _householdsCollection =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('households');

  Future<void> _openHouseholdForm({
    DocumentSnapshot<Map<String, dynamic>>? existingHousehold,
  }) async {
    final existingData = existingHousehold?.data() ?? {};

    final formKey = GlobalKey<FormState>();

    final blockController = TextEditingController(
      text: existingData['blockId'] as String? ?? '',
    );

    final houseController = TextEditingController(
      text: existingData['houseNumber'] as String? ?? '',
    );

    final headController = TextEditingController(
      text: existingData['householdHeadName'] as String? ?? '',
    );

    final phoneController = TextEditingController(
      text: existingData['primaryPhone'] as String? ?? '',
    );

    String occupancyStatus =
        existingData['occupancyStatus'] as String? ?? 'occupied';

    bool saving = false;
    bool saved = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> saveHousehold() async {
              if (saving || !formKey.currentState!.validate()) {
                return;
              }

              final String? uid = FirebaseAuth.instance.currentUser?.uid;

              if (uid == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: AppText('Please sign in again.')),
                );
                return;
              }

              setDialogState(() {
                saving = true;
              });

              final Map<String, dynamic> fields = {
                'blockId': blockController.text.trim(),
                'houseNumber': houseController.text.trim(),
                'householdHeadName': headController.text.trim(),
                'primaryPhone': phoneController.text.trim(),
                'occupancyStatus': occupancyStatus,
                'updatedAt': FieldValue.serverTimestamp(),
              };

              try {
                if (existingHousehold == null) {
                  await _householdsCollection.add({
                    ...fields,
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': uid,
                  });
                } else {
                  await existingHousehold.reference.update(fields);
                }

                saved = true;

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();
              } on FirebaseException catch (error) {
                debugPrint(
                  'Household save failed: ${error.code} ${error.message}',
                );

                setDialogState(() {
                  saving = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: AppText(
                      'Unable to save household: ${error.message ?? error.code}',
                    ),
                  ),
                );
              } catch (error) {
                debugPrint('Household save error: $error');

                setDialogState(() {
                  saving = false;
                });

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: AppText('Unable to save household.')),
                );
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.white,
              title: AppText(
                existingHousehold == null
                    ? 'Register household'
                    : 'Edit household',
                style: const TextStyle(
                  color: AppTheme.navyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInput(
                          controller: blockController,
                          label: 'Block / Tower',
                          hint: 'Example: A',
                        ),
                        const SizedBox(height: 15),
                        _buildInput(
                          controller: houseController,
                          label: 'House / Flat number',
                          hint: 'Example: 101',
                        ),
                        const SizedBox(height: 15),
                        _buildInput(
                          controller: headController,
                          label: 'Primary household contact',
                          hint: 'Enter full name',
                        ),
                        const SizedBox(height: 15),
                        _buildInput(
                          controller: phoneController,
                          label: 'Shared household contact number',
                          hint: 'Optional',
                          requiredField: false,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          initialValue: occupancyStatus,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Occupancy status',
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'occupied',
                              child: AppText('Occupied'),
                            ),
                            DropdownMenuItem(
                              value: 'vacant',
                              child: AppText('Vacant'),
                            ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      occupancyStatus = value;
                                    });
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
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const AppText(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textGrey),
                  ),
                ),
                ElevatedButton(
                  onPressed: saving ? null : saveHousehold,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : AppText(existingHousehold == null ? 'Save' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    blockController.dispose();
    houseController.dispose();
    headController.dispose();
    phoneController.dispose();

    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            existingHousehold == null
                ? 'Household registered successfully.'
                : 'Household updated successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool requiredField = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: AppTranslations.translate(label),
        hintText: AppTranslations.translate(hint),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';

        if (requiredField && text.isEmpty) {
          return AppTranslations.translate('Please enter $label');
        }

        return null;
      },
    );
  }

  Widget _buildHouseholdCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final String blockId = data['blockId'] as String? ?? '';
    final String houseNumber = data['houseNumber'] as String? ?? '';
    final String headName =
        data['householdHeadName'] as String? ?? 'Not provided';
    final String phone = data['primaryPhone'] as String? ?? '';
    final String status = data['occupancyStatus'] as String? ?? 'occupied';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        leading: Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            color: AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.home_work_outlined,
            color: AppTheme.secondaryNavy,
          ),
        ),
        title: AppText(
          'Block $blockId · House $houseNumber',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                headName,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
              if (phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: AppText(
                    phone,
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: AppText(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.secondaryNavy,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: AppTranslations.translate('Edit household'),
          onPressed: () => _openHouseholdForm(existingHousehold: document),
          icon: const Icon(Icons.edit_outlined, color: AppTheme.secondaryNavy),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.navyBlue,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Household Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            AppText(
              widget.colonyName,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openHouseholdForm(),
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_home_work_outlined),
        label: const AppText(
          'Add household',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _householdsCollection
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppText(
                  'Unable to load households.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textGrey, height: 1.6),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.navyBlue),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderGrey),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.home_work_outlined,
                        color: AppTheme.secondaryNavy,
                        size: 30,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppText(
                              'Registered households',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textGrey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            AppText(
                              '${documents.length}',
                              style: const TextStyle(
                                fontSize: 27,
                                color: AppTheme.navyBlue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const AppText(
                  'Household directory',
                  style: TextStyle(
                    fontSize: 19,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: documents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.home_work_outlined,
                                color: AppTheme.textGrey,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              const AppText(
                                'No households registered yet',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const AppText(
                                'Start by adding your first household.',
                                style: TextStyle(
                                  color: AppTheme.textGrey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => _openHouseholdForm(),
                                icon: const Icon(Icons.add),
                                label: const AppText('Add first household'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: documents.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildHouseholdCard(documents[index]);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
