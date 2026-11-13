import 'households_screen.dart';
import 'residents_screen.dart';
import 'resident_self_service_screen.dart';
import 'complaints_screen.dart';
import 'cleanliness_screen.dart';
import 'maintenance_screen.dart';
import 'maintenance_sla_screen.dart';
import 'water_supply_screen.dart';
import 'document_repository_screen.dart';
import 'rwa_governance_screen.dart';
import 'rwa_committee_permissions_screen.dart';
import 'water_operations_screen.dart';
import 'visitor_management_screen.dart';
import 'gate_operations_screen.dart';
import 'community_events_polls_screen.dart';
import 'community_hub_screen.dart';
import 'amenity_bookings_screen.dart';
import 'colony_asset_inventory_screen.dart';
import 'preventive_maintenance_screen.dart';
import 'move_in_out_screen.dart';
import 'tenant_lease_management_screen.dart';
import 'security_incidents_screen.dart';
import 'emergency_preparedness_screen.dart';
import 'emergency_response_screen.dart';
import 'maintenance_dues_screen.dart';
import 'recurring_maintenance_billing_screen.dart';
import 'procurement_management_screen.dart';
import 'staff_payroll_screen.dart';
import 'staff_leave_management_screen.dart';
import 'colony_budget_expense_screen.dart';
import 'rwa_accounting_screen.dart';
import 'announcements_screen.dart';
import '../widgets/notification_bell.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/push_notification_service.dart';

import '../theme/app_theme.dart';
import '../models/user_role.dart';
import 'splash_screen.dart';
import 'housekeeping_screen.dart';
import 'reports_screen.dart';
import 'advanced_analytics_screen.dart';
import '../widgets/colony_switch_action.dart';
import '../widgets/app_text.dart';
import '../widgets/brand_logo.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';
import '../widgets/app_language_toggle.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isSigningOut = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _residentsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _complaintsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>
  _cleanlinessTasksStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _maintenanceJobsStream;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PushNotificationService.initializeForMember(
          context: context,
          colonyId: widget.colonyId,
        );
      }
    });

    final colony = FirebaseFirestore.instance
        .collection('colonies')
        .doc(widget.colonyId);

    _residentsStream = colony.collection('residents').snapshots();
    _complaintsStream = colony.collection('complaints').snapshots();
    _cleanlinessTasksStream = colony.collection('cleanlinessTasks').snapshots();
    _maintenanceJobsStream = colony.collection('maintenanceJobs').snapshots();
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await PushNotificationService.unregisterCurrentDevice();

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSigningOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Unable to sign out. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      debugPrint('Admin sign-out error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const BrandLogo(width: 150, height: 34),
        actions: [
          const AppLanguageToggle(),
          ColonySwitchAction(
            currentColonyId: widget.colonyId,
            currentColonyName: widget.colonyName,
            currentRole: UserRole.admin,
          ),
          NotificationBell(
            colonyId: widget.colonyId,
            colonyName: widget.colonyName,
            roleKey: 'admin',
          ),
          IconButton(
            tooltip: AppTranslations.translate('Sign out'),
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded, color: AppTheme.navyBlue),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 28),
                      _buildSectionHeading(
                        'Colony overview',
                        'Your colony at a glance',
                      ),
                      const SizedBox(height: 15),
                      _buildOverviewGrid(constraints.maxWidth),
                      const SizedBox(height: 30),
                      _buildSectionHeading(
                        'Management modules',
                        'Manage your colony operations',
                      ),
                      const SizedBox(height: 15),
                      _buildModuleGrid(constraints.maxWidth),
                      const SizedBox(height: 24),
                      _buildAccessInformation(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: AppTheme.pageBorderRadius,
        boxShadow: AppTheme.quietCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const AppText(
              'ADMINISTRATOR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppText(
            'Welcome, ${widget.adminName}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            widget.colonyName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          AppText(
            'Manage your community from one place.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          title,
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        AppText(
          subtitle,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildOverviewGrid(double availableWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int responsiveColumnCount = availableWidth >= 850 ? 4 : 2;
        final double horizontalGap = (13).toDouble();
        final double itemWidth =
            (constraints.maxWidth -
                horizontalGap * (responsiveColumnCount - 1)) /
            responsiveColumnCount;
        return Wrap(
          spacing: horizontalGap,
          runSpacing: 13,
          children:
              ([
                    _OverviewMetricCard(
                      title: 'Residents',
                      icon: Icons.people_alt_outlined,
                      stream: _residentsStream,
                      valueBuilder: (records) => records
                          .where((r) {
                            return r['residentStatus']
                                    ?.toString()
                                    .toLowerCase() ==
                                'active';
                          })
                          .length
                          .toString(),
                      subtitleBuilder: (records) {
                        final active = records.where((r) {
                          return r['residentStatus']
                                  ?.toString()
                                  .toLowerCase() ==
                              'active';
                        }).length;
                        return '$active active · ${records.length} registered';
                      },
                    ),
                    _OverviewMetricCard(
                      title: 'Open complaints',
                      icon: Icons.report_problem_outlined,
                      stream: _complaintsStream,
                      valueBuilder: (records) => records
                          .where((r) {
                            final status = r['status']
                                ?.toString()
                                .toLowerCase();
                            return const {
                              'submitted',
                              'acknowledged',
                              'in_progress',
                            }.contains(status);
                          })
                          .length
                          .toString(),
                      subtitleBuilder: (records) {
                        final submitted = records.where((r) {
                          return r['status'] == 'submitted';
                        }).length;
                        final addressing = records.where((r) {
                          return r['status'] == 'acknowledged' ||
                              r['status'] == 'in_progress';
                        }).length;
                        return '$submitted awaiting · $addressing being addressed';
                      },
                    ),
                    _OverviewMetricCard(
                      title: 'Cleanliness tasks',
                      icon: Icons.cleaning_services_outlined,
                      stream: _cleanlinessTasksStream,
                      valueBuilder: (records) => records
                          .where((r) {
                            return r['status'] == 'assigned' ||
                                r['status'] == 'in_progress';
                          })
                          .length
                          .toString(),
                      subtitleBuilder: (records) {
                        final assigned = records.where((r) {
                          return r['status'] == 'assigned';
                        }).length;
                        final progress = records.where((r) {
                          return r['status'] == 'in_progress';
                        }).length;
                        return '$assigned assigned · $progress in progress';
                      },
                    ),
                    _OverviewMetricCard(
                      title: 'Maintenance',
                      icon: Icons.home_repair_service_outlined,
                      stream: _maintenanceJobsStream,
                      valueBuilder: (records) => records
                          .where((r) {
                            final status = r['status']
                                ?.toString()
                                .toLowerCase();
                            return const {
                              'open',
                              'assigned',
                              'in_progress',
                            }.contains(status);
                          })
                          .length
                          .toString(),
                      subtitleBuilder: (records) {
                        final open = records.where((r) {
                          return r['status'] == 'open';
                        }).length;
                        final assigned = records.where((r) {
                          return r['status'] == 'assigned';
                        }).length;
                        final progress = records.where((r) {
                          return r['status'] == 'in_progress';
                        }).length;
                        return '$open open · $assigned assigned · $progress in progress';
                      },
                    ),
                  ])
                  .map<Widget>(
                    (child) => SizedBox(width: itemWidth, child: child),
                  )
                  .toList(growable: false),
        );
      },
    );
  }

  Widget _buildModuleGrid(double availableWidth) {
    final int columns = availableWidth >= 850 ? 3 : 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final int responsiveColumnCount = columns;
        final double horizontalGap = (13).toDouble();
        final double itemWidth =
            (constraints.maxWidth -
                horizontalGap * (responsiveColumnCount - 1)) /
            responsiveColumnCount;
        return Wrap(
          spacing: horizontalGap,
          runSpacing: 13,
          children:
              ([
                    _ModuleCard(
                      title: 'Households',
                      description: 'Register and manage colony homes',
                      icon: Icons.home_work_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HouseholdsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Residents',
                      description: 'Register and manage colony residents',
                      icon: Icons.people_outline_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ResidentsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Resident Self-Service',
                      description: 'Profile corrections, household member requests and official letters',
                      icon: Icons.manage_accounts_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ResidentSelfServiceScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Complaints',
                      description: 'Register and track complaints',
                      icon: Icons.assignment_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ComplaintsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Workers & Cleanliness',
                      description: 'Worker profiles, task assignments and operational tracking',
                      icon: Icons.people_alt_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CleanlinessScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                              currentRole: UserRole.admin,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Maintenance',
                      description:
                          'Repair jobs, vendors and maintenance requests',
                      icon: Icons.handyman_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MaintenanceScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Maintenance SLA',
                      description: 'Response targets, resolution deadlines, pauses, escalations and vendor scorecards',
                      icon: Icons.timer_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MaintenanceSlaScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Announcements',
                      description: 'Publish and manage colony notices',
                      icon: Icons.campaign_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AnnouncementsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Water Supply',
                      description:
                          'Tanker deliveries, suppliers and water records',
                      icon: Icons.water_drop_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WaterSupplyScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Water Operations',
                      description: 'Storage, meters, consumption, quality and distribution',
                      icon: Icons.water_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WaterOperationsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Committee Delegated Permissions',
                      description: 'Link committee appointments to resident logins and assign time-limited operational access',
                      icon: Icons.admin_panel_settings_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RwaCommitteePermissionsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'RWA Governance & Compliance',
                      description: 'Committee, meetings, resolutions, action register and compliance',
                      icon: Icons.account_balance_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RwaGovernanceScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Gate Operations',
                      description: 'Gate register, domestic help, service visits, deliveries and shift handovers',
                      icon: Icons.security_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GateOperationsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Document Repository',
                      description: 'Secure files, version history, resident submissions and access policies',
                      icon: Icons.folder_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DocumentRepositoryScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Visitor Management',
                      description:
                          'Visitor register, walk-ins and check-in/check-out',
                      icon: Icons.directions_walk_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => VisitorManagementScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Security & Lost and Found',
                      description: 'Review safety incidents and lost/found property claims',
                      icon: Icons.shield_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SecurityIncidentsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              currentUserName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Emergency Preparedness',
                      description: 'Emergency contacts, assembly points, readiness checks, command log and drills',
                      icon: Icons.health_and_safety_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EmergencyPreparednessScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              currentUserName: widget.adminName,
                              isAdmin: true,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Emergency Response Control',
                      description: 'Live resident SOS alerts, responder assignment, status timeline and resolution records',
                      icon: Icons.sos,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EmergencyResponseScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              mode: EmergencyResponseMode.admin,
                              currentUserName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Advanced Operational Analytics',
                      description: 'Executive, finance, maintenance, workforce, water, security and governance intelligence',
                      icon: Icons.query_stats_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AdvancedAnalyticsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Reports & Analytics',
                      description: 'Colony operations, collections and activity summaries',
                      icon: Icons.analytics_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReportsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Housekeeping',
                      description: 'Resident requests, worker assignments and job tracking',
                      icon: Icons.cleaning_services_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HousekeepingScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              mode: HousekeepingMode.admin,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Resident Directory & Community Hub',
                      description: 'Opt-in resident directory, colony discussions, replies, reports and Admin moderation',
                      icon: Icons.groups_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CommunityHubScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              currentUserName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Events & Polls',
                      description:
                          'Publish community events and collect resident votes',
                      icon: Icons.poll_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CommunityEventsPollsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Facility Bookings',
                      description: 'Manage community facilities and resident reservations',
                      icon: Icons.event_available_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AmenityBookingsScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Assets & Inventory',
                      description: 'Track colony equipment, service history and stock levels',
                      icon: Icons.inventory_2_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ColonyAssetInventoryScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Preventive Maintenance & AMC',
                      description: 'Schedule recurring asset servicing and track AMC contracts',
                      icon: Icons.event_repeat_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PreventiveMaintenanceScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Move-In & Move-Out',
                      description: 'Review resident move-outs and schedule incoming households',
                      icon: Icons.local_shipping_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MoveInOutScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Tenant & Lease Management',
                      description: 'Track tenancy terms, lease dates, deposits and expiries',
                      icon: Icons.key_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TenantLeaseManagementScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Colony Budget & Expenses',
                      description: 'Track operating expenses and monthly category budgets',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ColonyBudgetExpenseScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Staff Leave Management',
                      description: 'Review staff leave requests and approve paid or unpaid leave',
                      icon: Icons.event_available_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StaffLeaveManagementScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Staff & Payroll',
                      description: 'Manage staff profiles, salary cycles, payouts and payroll reports',
                      icon: Icons.payments_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StaffPayrollScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Procurement & Purchasing',
                      description: 'Requisitions, supplier quotes, purchase orders, receipts and payments',
                      icon: Icons.shopping_cart_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProcurementManagementScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'RWA Accounting & Reconciliation',
                      description: 'Double-entry ledger, source imports, bank matching, trial balance and period closing',
                      icon: Icons.account_balance_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RwaAccountingScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Recurring Billing & Arrears',
                      description: 'Monthly billing plans, resumable bill runs, late fees, arrears ageing and audit history',
                      icon: Icons.request_quote_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RecurringMaintenanceBillingScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                    _ModuleCard(
                      title: 'Maintenance Dues',
                      description: 'Household bills, payment submissions and collections',
                      icon: Icons.receipt_long_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MaintenanceDuesScreen(
                              colonyId: widget.colonyId,
                              colonyName: widget.colonyName,
                              isAdmin: true,
                              adminName: widget.adminName,
                            ),
                          ),
                        );
                      },
                    ),
                  ])
                  .map<Widget>(
                    (child) => SizedBox(width: itemWidth, child: child),
                  )
                  .toList(growable: false),
        );
      },
    );
  }

  // ==========================================
  // ADMIN ACCESS INFORMATION
  // ==========================================

  Widget _buildAccessInformation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppTheme.secondaryNavy,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Administrator access verified',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                AppText(
                  'Colony ID: ${widget.colonyId}',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                const AppText(
                  'Your account is connected to this colony. '
                  'Use the management modules above to oversee colony operations.',
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// OVERVIEW CARD
// ==========================================

typedef _MetricTextBuilder = String Function(
  List<Map<String, dynamic>> records,
);

class _OverviewMetricCard extends StatelessWidget {
  const _OverviewMetricCard({
    required this.title,
    required this.icon,
    required this.stream,
    required this.valueBuilder,
    required this.subtitleBuilder,
  });

  final String title;
  final IconData icon;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final _MetricTextBuilder valueBuilder;
  final _MetricTextBuilder subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _OverviewCard(
            title: title,
            value: '—',
            subtitle: 'Unable to load records',
            icon: icon,
          );
        }

        if (!snapshot.hasData) {
          return _OverviewCard(
            title: title,
            value: '…',
            subtitle: 'Loading live data',
            icon: icon,
          );
        }

        final records = snapshot.data!.docs
            .map((doc) => doc.data())
            .toList(growable: false);

        return _OverviewCard(
          title: title,
          value: valueBuilder(records),
          subtitle: subtitleBuilder(records),
          icon: icon,
        );
      },
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(color: AppTheme.borderGrey),
        boxShadow: AppTheme.quietCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppTheme.secondaryNavy, size: 25),
              const SizedBox(width: 8),
              Flexible(
                child: AppText(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.navyBlue,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              AppText(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// REUSABLE DASHBOARD MODULE CARD
// ==========================================

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.cardBorderRadius,
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: AppTheme.cardBorderRadius,
          border: Border.all(color: AppTheme.borderGrey),
          boxShadow: AppTheme.quietCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.secondaryNavy, size: 24),
                const Spacer(),
                if (onTap == null)
                  const AppText(
                    'COMING NEXT',
                    style: TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.secondaryNavy,
                    size: 17,
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                AppText(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
