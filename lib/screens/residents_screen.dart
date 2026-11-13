import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';
import '../services/resident_registration_activation_service.dart';

class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
  });

  final String colonyId;
  final String colonyName;

  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  CollectionReference<Map<String, dynamic>> get _residentsCollection =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('residents');

  CollectionReference<Map<String, dynamic>> get _householdsCollection =>
      FirebaseFirestore.instance
          .collection('colonies')
          .doc(widget.colonyId)
          .collection('households');

  CollectionReference<Map<String, dynamic>>
  get _residentLoginRegistrationsCollection => FirebaseFirestore.instance
      .collection('colonies')
      .doc(widget.colonyId)
      .collection('residentLoginRegistrations');

  static const List<String> _relationships = [
    'Owner',
    'Spouse',
    'Child',
    'Parent',
    'Tenant',
    'Other',
  ];

  Future<void> _openResidentForm({
    DocumentSnapshot<Map<String, dynamic>>? existingResident,
  }) async {
    final data = existingResident?.data() ?? <String, dynamic>{};
    final existingLoginSnapshot = existingResident == null
        ? null
        : await _residentLoginRegistrationsCollection
              .doc(existingResident.id)
              .get();
    // The household registration read may finish after this screen closes.
    if (!mounted) {
      return;
    }

    final loginData = existingLoginSnapshot?.data() ?? <String, dynamic>{};

    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(
      text: data['fullName'] as String? ?? '',
    );

    final phoneController = TextEditingController(
      text: data['phoneNumber'] as String? ?? '',
    );

    final loginPhoneController = TextEditingController(
      text: loginData['phoneNumber'] as String? ?? '',
    );
    final linkedUid = (loginData['linkedUid'] as String? ?? '').trim();
    final bool loginPhoneLocked =
        linkedUid.isNotEmpty || loginData['status'] == 'linked';
    bool enableResidentLogin =
        loginPhoneLocked || loginPhoneController.text.trim().isNotEmpty;

    final emailController = TextEditingController(
      text: data['email'] as String? ?? '',
    );

    String? selectedHouseholdId = data['householdId'] as String?;

    String relationship = data['relationshipToHead'] as String? ?? 'Owner';

    String residentStatus = data['residentStatus'] as String? ?? 'active';

    String? formError;
    bool saving = false;
    bool saved = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _householdsCollection.snapshots(),
              builder: (context, householdSnapshot) {
                if (householdSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const AlertDialog(
                    content: SizedBox(
                      height: 90,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.navyBlue,
                        ),
                      ),
                    ),
                  );
                }

                if (householdSnapshot.hasError) {
                  return AlertDialog(
                    title: const AppText('Unable to load households'),
                    content: AppText('${householdSnapshot.error}'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const AppText('Close'),
                      ),
                    ],
                  );
                }

                final households = householdSnapshot.data?.docs ?? [];

                if (households.isEmpty) {
                  return AlertDialog(
                    title: const AppText(
                      'No households available',
                      style: TextStyle(
                        color: AppTheme.navyBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    content: const AppText(
                      'Please register a household before adding '
                      'a resident.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const AppText('Close'),
                      ),
                    ],
                  );
                }

                final bool householdExists = households.any(
                  (household) => household.id == selectedHouseholdId,
                );

                final String? dropdownHouseholdId = householdExists
                    ? selectedHouseholdId
                    : null;
                Map<String, dynamic> selectedHouseholdDisplayData = {};
                for (final household in households) {
                  if (household.id == dropdownHouseholdId) {
                    selectedHouseholdDisplayData = household.data();
                    break;
                  }
                }
                final sharedHouseholdPhone =
                    selectedHouseholdDisplayData['primaryPhone']
                        ?.toString()
                        .trim() ??
                    '';
                if (phoneController.text.trim().isEmpty &&
                    sharedHouseholdPhone.isNotEmpty) {
                  phoneController.text = sharedHouseholdPhone;
                }

                Future<void> saveResident() async {
                  if (saving || !formKey.currentState!.validate()) {
                    return;
                  }

                  final String? uid = FirebaseAuth.instance.currentUser?.uid;

                  if (uid == null) {
                    setDialogState(() {
                      formError = 'Please sign in again.';
                    });
                    return;
                  }

                  QueryDocumentSnapshot<Map<String, dynamic>>?
                  selectedHousehold;

                  for (final household in households) {
                    if (household.id == selectedHouseholdId) {
                      selectedHousehold = household;
                      break;
                    }
                  }

                  if (selectedHousehold == null) {
                    setDialogState(() {
                      formError = 'Please select a valid household.';
                    });
                    return;
                  }

                  final householdData = selectedHousehold.data();
                  final loginDigits = enableResidentLogin
                      ? ResidentRegistrationActivationService.normalizeIndianMobileNumber(
                          loginPhoneController.text,
                        )
                      : null;
                  final existingLoginPhone =
                      (loginData['phoneNumber'] as String? ?? '').trim();
                  final oldLoginE164 =
                      (loginData['phoneNumberE164'] as String? ?? '').trim();

                  if (loginPhoneLocked &&
                      existingResident != null &&
                      selectedHousehold.id !=
                          (data['householdId'] as String? ?? '')) {
                    setDialogState(() {
                      formError = AppTranslations.translate(
                        'A linked resident cannot be reassigned directly. Use the Move-in / Move-out workflow.',
                      );
                    });
                    return;
                  }

                  if (loginPhoneLocked &&
                      residentStatus !=
                          (data['residentStatus'] as String? ?? 'active')) {
                    setDialogState(() {
                      formError = AppTranslations.translate(
                        'An app-enabled resident status must be changed through the Move-in / Move-out workflow.',
                      );
                    });
                    return;
                  }

                  if (loginPhoneLocked &&
                      (!enableResidentLogin ||
                          (loginDigits != null &&
                              '+91$loginDigits' != oldLoginE164))) {
                    setDialogState(() {
                      formError = AppTranslations.translate(
                        'A verified login number is locked. Use the secure number-change process to update it.',
                      );
                    });
                    return;
                  }

                  if (enableResidentLogin && loginDigits == null) {
                    setDialogState(() {
                      formError = AppTranslations.translate(
                        'Enter a valid 10-digit Indian mobile number.',
                      );
                    });
                    return;
                  }

                  if (enableResidentLogin && residentStatus != 'active') {
                    setDialogState(() {
                      formError = AppTranslations.translate(
                        'Only active residents can have app login enabled.',
                      );
                    });
                    return;
                  }

                  var householdContactDigits =
                      (householdData['primaryPhone']?.toString() ?? '')
                          .replaceAll(RegExp(r'[^0-9]'), '');
                  if (householdContactDigits.length == 12 &&
                      householdContactDigits.startsWith('91')) {
                    householdContactDigits = householdContactDigits.substring(
                      2,
                    );
                  }
                  if (enableResidentLogin &&
                      householdContactDigits.isNotEmpty &&
                      householdContactDigits == loginDigits) {
                    setDialogState(() {
                      formError = AppTranslations.translate(
                        'Personal login number cannot be the shared household contact number.',
                      );
                    });
                    return;
                  }

                  if (enableResidentLogin) {
                    setDialogState(() {
                      saving = true;
                      formError = null;
                    });
                    try {
                      final e164 = '+91$loginDigits';
                      final duplicateSnapshot =
                          await _residentLoginRegistrationsCollection
                              .where('phoneNumberE164', isEqualTo: e164)
                              .get();
                      final duplicateExists = duplicateSnapshot.docs.any(
                        (document) => document.id != existingResident?.id,
                      );
                      if (duplicateExists) {
                        setDialogState(() {
                          saving = false;
                          formError = AppTranslations.translate(
                            'This number is already assigned to another resident in this colony.',
                          );
                        });
                        return;
                      }
                    } on FirebaseException catch (error) {
                      debugPrint(
                        'Resident login-number duplicate check failed: ${error.code} ${error.message}',
                      );
                      setDialogState(() {
                        saving = false;
                        formError = AppTranslations.translate(
                          'Unable to verify the personal login number. Please try again.',
                        );
                      });
                      return;
                    }
                  }

                  setDialogState(() {
                    saving = true;
                    formError = null;
                  });

                  final Map<String, dynamic> residentData = {
                    'fullName': nameController.text.trim(),
                    'phoneNumber': phoneController.text.trim(),
                    'email': emailController.text.trim(),
                    'householdId': selectedHousehold.id,
                    'blockId': householdData['blockId'] as String? ?? '',
                    'houseNumber':
                        householdData['houseNumber'] as String? ?? '',
                    'relationshipToHead': relationship,
                    'residentStatus': residentStatus,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  try {
                    final residentReference =
                        existingResident?.reference ??
                        _residentsCollection.doc();
                    final loginRegistrationReference =
                        _residentLoginRegistrationsCollection.doc(
                          residentReference.id,
                        );
                    final loginRegistrationData = <String, dynamic>{
                      'residentId': residentReference.id,
                      'phoneNumber': loginPhoneLocked
                          ? existingLoginPhone
                          : (enableResidentLogin ? loginDigits! : ''),
                      'phoneNumberE164': loginPhoneLocked
                          ? oldLoginE164
                          : (enableResidentLogin ? '+91$loginDigits' : ''),
                      'status': loginPhoneLocked
                          ? 'linked'
                          : (enableResidentLogin ? 'pending' : 'not_enabled'),
                      'updatedAt': FieldValue.serverTimestamp(),
                    };
                    if (existingLoginSnapshot?.exists != true) {
                      loginRegistrationData['createdAt'] =
                          FieldValue.serverTimestamp();
                      loginRegistrationData['createdBy'] = uid;
                    }

                    final batch = FirebaseFirestore.instance.batch();
                    if (existingResident == null) {
                      batch.set(residentReference, {
                        ...residentData,
                        'createdAt': FieldValue.serverTimestamp(),
                        'createdBy': uid,
                      });
                    } else {
                      batch.update(residentReference, residentData);
                    }
                    // Admin-only private registration record. Merge preserves
                    // the server-owned UID, verified timestamp and phone claim.
                    batch.set(
                      loginRegistrationReference,
                      loginRegistrationData,
                      SetOptions(merge: true),
                    );
                    await batch.commit();

                    saved = true;

                    if (!dialogContext.mounted) return;

                    Navigator.of(dialogContext).pop();
                  } on FirebaseException catch (error) {
                    debugPrint(
                      'Resident save error: ${error.code} ${error.message}',
                    );

                    setDialogState(() {
                      saving = false;
                      formError =
                          'Unable to save resident: '
                          '${error.message ?? error.code}';
                    });
                  } catch (error) {
                    debugPrint('Resident save error: $error');

                    setDialogState(() {
                      saving = false;
                      formError = 'Unable to save resident. Please try again.';
                    });
                  }
                }

                return AlertDialog(
                  backgroundColor: AppTheme.white,
                  title: AppText(
                    existingResident == null
                        ? 'Register resident'
                        : 'Edit resident',
                    style: const TextStyle(
                      color: AppTheme.navyBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  content: SizedBox(
                    width: 430,
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInput(
                              controller: nameController,
                              label: 'Resident full name',
                              hint: 'Enter full name',
                            ),
                            const SizedBox(height: 15),
                            _buildInput(
                              controller: phoneController,
                              label: 'Resident contact number (may be shared)',
                              hint: 'May be the shared household contact; not used for sign-in',
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (value) {
                                final phone = value?.trim() ?? '';

                                if (!RegExp(r'^[6-9][0-9]{9}$')
                                    .hasMatch(phone)) {
                                  return AppTranslations.translate(
                                    'Enter a valid 10-digit Indian mobile number.',
                                  );
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            if (dropdownHouseholdId != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGrey,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.borderGrey,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.home_outlined,
                                      size: 17,
                                      color: AppTheme.secondaryNavy,
                                    ),
                                    const SizedBox(width: 8),
                                    const AppText(
                                      'Shared household contact',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textGrey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const AppText(': '),
                                    Expanded(
                                      child: sharedHouseholdPhone.isEmpty
                                          ? const AppText('Not set')
                                          : AppText(sharedHouseholdPhone),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 15),
                            _buildInput(
                              controller: emailController,
                              label: 'Email address',
                              hint: 'Optional',
                              requiredField: false,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: enableResidentLogin,
                              onChanged: saving || loginPhoneLocked
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        enableResidentLogin = value ?? false;
                                        if (!enableResidentLogin) {
                                          loginPhoneController.clear();
                                        }
                                      });
                                    },
                              title: const AppText(
                                'Enable individual app login',
                                style: TextStyle(
                                  color: AppTheme.textDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const AppText(
                                'Each resident must use their own verified mobile number. The shared household contact number cannot be used for sign-in.',
                                style: TextStyle(
                                  color: AppTheme.textGrey,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            if (enableResidentLogin) ...[
                              TextFormField(
                                controller: loginPhoneController,
                                enabled: !saving && !loginPhoneLocked,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                decoration: InputDecoration(
                                  labelText: AppTranslations.translate(
                                    'Personal login mobile number',
                                  ),
                                  hintText: AppTranslations.translate(
                                    '10-digit personal number',
                                  ),
                                  helperText: AppTranslations.translate(
                                    "Enter the resident's own 10-digit number",
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (!enableResidentLogin) return null;
                                  if (ResidentRegistrationActivationService.normalizeIndianMobileNumber(
                                        value ?? '',
                                      ) ==
                                      null) {
                                    return AppTranslations.translate(
                                      'Enter a valid 10-digit Indian mobile number.',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              if (loginPhoneLocked)
                                const Padding(
                                  padding: EdgeInsets.only(top: 7),
                                  child: AppText(
                                    'A verified login number is locked. Use the secure number-change process to update it.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textGrey,
                                    ),
                                  ),
                                ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(left: 12, bottom: 4),
                                child: AppText(
                                  'Leave blank if this family member will not sign in to the app.',
                                  style: TextStyle(
                                    color: AppTheme.textGrey,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 15),
                            DropdownButtonFormField<String>(
                              initialValue: dropdownHouseholdId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: AppTranslations.translate(
                                  'Select household',
                                ),
                                border: OutlineInputBorder(),
                              ),
                              items: households.map((household) {
                                final h = household.data();
                                final block = h['blockId'] ?? '';
                                final house = h['houseNumber'] ?? '';

                                return DropdownMenuItem<String>(
                                  value: household.id,
                                  child: AppText(
                                    'Block $block · House $house',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: saving
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        selectedHouseholdId = value;
                                        if (phoneController.text
                                                .trim()
                                                .isEmpty &&
                                            value != null) {
                                          final selected = households
                                              .firstWhere(
                                                (item) => item.id == value,
                                              );
                                          phoneController.text =
                                              selected
                                                  .data()['primaryPhone']
                                                  ?.toString() ??
                                              '';
                                        }
                                      });
                                    },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppTranslations.translate(
                                    'Please select a household',
                                  );
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            DropdownButtonFormField<String>(
                              initialValue: relationship,
                              decoration: InputDecoration(
                                labelText: AppTranslations.translate(
                                  'Relationship to household head',
                                ),
                                border: OutlineInputBorder(),
                              ),
                              items: _relationships.map((item) {
                                return DropdownMenuItem(
                                  value: item,
                                  child: AppText(item),
                                );
                              }).toList(),
                              onChanged: saving
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setDialogState(() {
                                          relationship = value;
                                        });
                                      }
                                    },
                            ),
                            const SizedBox(height: 15),
                            DropdownButtonFormField<String>(
                              initialValue: residentStatus,
                              decoration: InputDecoration(
                                labelText: AppTranslations.translate(
                                  'Resident status',
                                ),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'active',
                                  child: AppText('Active'),
                                ),
                                DropdownMenuItem(
                                  value: 'inactive',
                                  child: AppText('Inactive'),
                                ),
                              ],
                              onChanged: saving
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setDialogState(() {
                                          residentStatus = value;
                                        });
                                      }
                                    },
                            ),
                            if (formError != null) ...[
                              const SizedBox(height: 14),
                              AppText(
                                formError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
                      child: const AppText('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: saving ? null : saveResident,
                      child: saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : AppText(
                              existingResident == null
                                  ? 'Save resident'
                                  : 'Update resident',
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    loginPhoneController.dispose();
    emailController.dispose();

    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            existingResident == null
                ? 'Resident registered successfully.'
                : 'Resident updated successfully.',
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
    String? Function(String?)? validator,
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
      validator:
          validator ??
          (value) {
            if (requiredField && (value == null || value.trim().isEmpty)) {
              return AppTranslations.translate('Please enter $label');
            }
            return null;
          },
    );
  }

  Widget _buildResidentCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final String name = data['fullName'] as String? ?? 'Unnamed resident';

    final String phone = data['phoneNumber'] as String? ?? '';

    final String block = data['blockId'] as String? ?? '';

    final String house = data['houseNumber'] as String? ?? '';

    final String relationship = data['relationshipToHead'] as String? ?? '';

    final String status = data['residentStatus'] as String? ?? 'active';
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        leading: Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            color: AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: AppTheme.secondaryNavy,
          ),
        ),
        title: AppText(
          name,
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Block $block · House $house',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
              const SizedBox(height: 3),
              AppText(
                '$phone · $relationship',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
              const SizedBox(height: 5),
              AppText(
                status.toUpperCase(),
                style: TextStyle(
                  color: status == 'active'
                      ? AppTheme.secondaryNavy
                      : AppTheme.textGrey,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: AppTranslations.translate('Edit resident'),
          onPressed: () => _openResidentForm(existingResident: document),
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
              'Resident Management',
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
        onPressed: () => _openResidentForm(),
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const AppText(
          'Add resident',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _residentsCollection
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppText(
                  'Unable to load residents.\n${snapshot.error}',
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

          final int activeCount = documents.where((doc) {
            return doc.data()['residentStatus'] == 'active';
          }).length;

          final int inactiveCount = documents.length - activeCount;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppTheme.borderGrey),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildCount('Total residents', documents.length),
                      ),
                      Container(
                        width: 1,
                        height: 43,
                        color: AppTheme.borderGrey,
                      ),
                      Expanded(child: _buildCount('Active', activeCount)),
                      Container(
                        width: 1,
                        height: 43,
                        color: AppTheme.borderGrey,
                      ),
                      Expanded(child: _buildCount('Inactive', inactiveCount)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const AppText(
                  'Resident directory',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 19,
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
                                Icons.people_outline_rounded,
                                size: 48,
                                color: AppTheme.textGrey,
                              ),
                              const SizedBox(height: 12),
                              const AppText(
                                'No residents registered yet',
                                style: TextStyle(
                                  color: AppTheme.textDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const AppText(
                                'Add residents and link them to households.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textGrey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => _openResidentForm(),
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const AppText('Add first resident'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: documents.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildResidentCard(documents[index]);
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

  Widget _buildCount(String label, int count) {
    return Column(
      children: [
        AppText(
          '$count',
          style: const TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        AppText(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
        ),
      ],
    );
  }
}
