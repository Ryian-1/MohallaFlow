import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text.dart';
import '../l10n/app_locale_controller.dart';

class ColonySelectionScreen extends StatelessWidget {
  const ColonySelectionScreen({super.key, required this.memberships});

  final List<ColonyMembership> memberships;

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Unable to sign out. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return PopScope<Object?>(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const AppText('MohallaFlow'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const AppText('Sign out'),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      size: 29,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 22),
                  AppText(
                    'Choose your colony',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 9),
                  AppText(
                    'Your account has access to '
                    '${memberships.length} colonies. '
                    'Select one to continue to your dashboard.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.separated(
                      itemCount: memberships.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ColonyMembership membership = memberships[index];

                        final String colonyName =
                            membership.colonyName.trim().isEmpty
                            ? 'Your colony'
                            : membership.colonyName.trim();

                        return Card(
                          elevation: 0,
                          color: AppTheme.white,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppTheme.borderGrey),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop(membership);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.lightGrey,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.apartment_rounded,
                                      color: AppTheme.navyBlue,
                                      size: 25,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppText(
                                          colonyName,
                                          style: const TextStyle(
                                            color: AppTheme.textDark,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 9),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.lightGrey,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: AppText(
                                            membership.role.displayName,
                                            style: const TextStyle(
                                              color: AppTheme.secondaryNavy,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 17,
                                    color: AppTheme.textGrey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: AppText(
                      'Your access is determined by your registered '
                      'colony membership.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppTheme.textGrey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
