import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/colony_dashboard_router.dart';
import '../services/user_access_service.dart';
import '../theme/app_theme.dart';
import 'app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class ColonySwitchAction extends StatefulWidget {
  const ColonySwitchAction({
    super.key,
    required this.currentColonyId,
    required this.currentColonyName,
    required this.currentRole,
  });

  final String currentColonyId;
  final String currentColonyName;
  final UserRole currentRole;

  @override
  State<ColonySwitchAction> createState() => _ColonySwitchActionState();
}

class _ColonySwitchActionState extends State<ColonySwitchAction> {
  bool _isLoading = false;

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<ColonyMembership?> _showColonyList(
    List<ColonyMembership> memberships,
  ) {
    return showModalBottomSheet<ColonyMembership>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderGrey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const AppText(
                    'Switch colony',
                    style: TextStyle(
                      color: AppTheme.navyBlue,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const AppText(
                    'Choose an active colony to continue.',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(sheetContext).size.height * 0.60,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: memberships.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final membership = memberships[index];
                        final bool isCurrent =
                            membership.colonyId == widget.currentColonyId;

                        return Material(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: () {
                              Navigator.of(sheetContext).pop(membership);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: isCurrent
                                      ? AppTheme.navyBlue
                                      : AppTheme.borderGrey,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    height: 44,
                                    width: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.lightGrey,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.apartment_rounded,
                                      color: AppTheme.navyBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppText(
                                          membership.colonyName,
                                          style: const TextStyle(
                                            color: AppTheme.textDark,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        AppText(
                                          membership.role.displayName,
                                          style: const TextStyle(
                                            color: AppTheme.textGrey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCurrent)
                                    const AppText(
                                      'Current',
                                      style: TextStyle(
                                        color: AppTheme.secondaryNavy,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: AppTheme.textGrey,
                                      size: 15,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSwitcher() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Re-read and validate every membership before showing the list.
      final access = await UserAccessService().loadCurrentUserAccess();

      if (!mounted) return;

      if (!access.canAccessColony || access.memberships.isEmpty) {
        _showMessage(
          access.errorMessage ?? 'No active colony membership is available.',
        );
        return;
      }

      // A single membership does not need a selection dialog.
      if (access.memberships.length == 1) {
        final membership = access.memberships.single;

        if (membership.colonyId == widget.currentColonyId &&
            membership.role == widget.currentRole) {
          _showMessage('You currently have access to one active colony.');
          return;
        }

        ColonyDashboardRouter.open(
          context: context,
          membership: membership,
          profileData: access.profileData,
        );
        return;
      }

      final selected = await _showColonyList(access.memberships);

      if (!mounted || selected == null) return;

      if (selected.colonyId == widget.currentColonyId &&
          selected.role == widget.currentRole) {
        return;
      }

      ColonyDashboardRouter.open(
        context: context,
        membership: selected,
        profileData: access.profileData,
      );
    } catch (error, stackTrace) {
      debugPrint('Colony switching error: $error');
      debugPrintStack(stackTrace: stackTrace);

      _showMessage('Unable to load your colonies. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return IconButton(
      tooltip: AppTranslations.translate('Switch colony'),
      onPressed: _isLoading ? null : _openSwitcher,
      icon: _isLoading
          ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.swap_horiz_rounded, color: AppTheme.navyBlue),
    );
  }
}
