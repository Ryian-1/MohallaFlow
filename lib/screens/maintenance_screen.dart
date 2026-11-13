import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../widgets/notification_bell.dart';
import '../widgets/app_text.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({
    super.key,
    required this.colonyId,
    required this.colonyName,
    required this.adminName,
  });

  final String colonyId;
  final String colonyName;
  final String adminName;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  static const List<String> _jobCategories = [
    'Lift',
    'Plumbing',
    'Electrical',
    'Electricity',
    'Generator',
    'Water Supply',
    'Water supply',
    'Civil Work',
    'Security System',
    'Security',
    'Common area',
    'Other',
  ];

  static const List<String> _vendorCategories = [
    'Lift',
    'Plumbing',
    'Electrical',
    'Generator',
    'Water Supply',
    'Civil Work',
    'Security System',
    'Other',
  ];

  static const List<String> _priorities = ['low', 'normal', 'high', 'urgent'];

  static const List<String> _jobStatuses = [
    'open',
    'assigned',
    'in_progress',
    'completed',
    'cancelled',
  ];

  late final CollectionReference<Map<String, dynamic>> _jobs;
  late final CollectionReference<Map<String, dynamic>> _vendors;
  late final CollectionReference<Map<String, dynamic>> _complaints;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _jobsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _vendorsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _complaintsStream;

  @override
  void initState() {
    super.initState();

    final colony = FirebaseFirestore.instance
        .collection('colonies')
        .doc(widget.colonyId);

    _jobs = colony.collection('maintenanceJobs');
    _vendors = colony.collection('maintenanceVendors');
    _complaints = colony.collection('complaints');

    _jobsStream = _jobs.snapshots();
    _vendorsStream = _vendors.snapshots();
    _complaintsStream = _complaints.snapshots();
  }

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
                'Maintenance Management',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              AppText(
                widget.colonyName,
                style: const TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            NotificationBell(
              colonyId: widget.colonyId,
              colonyName: widget.colonyName,
              roleKey: 'admin',
            ),
            IconButton(
              tooltip: AppTranslations.translate('Create maintenance job'),
              onPressed: () => _showCreateJobDialog(),
              icon: const Icon(Icons.add_task_rounded),
            ),
            IconButton(
              tooltip: AppTranslations.translate('Register vendor'),
              onPressed: _showVendorDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: AppTheme.navyBlue,
            unselectedLabelColor: AppTheme.textGrey,
            indicatorColor: AppTheme.navyBlue,
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: Icon(Icons.dashboard_outlined),
                text: AppTranslations.translate('Overview'),
              ),
              Tab(
                icon: Icon(Icons.handyman_outlined),
                text: AppTranslations.translate('Repair jobs'),
              ),
              Tab(
                icon: Icon(Icons.business_outlined),
                text: AppTranslations.translate('Vendors'),
              ),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _jobsStream,
          builder: (context, jobSnapshot) {
            if (jobSnapshot.hasError) {
              return _buildStreamError(
                'Maintenance jobs could not be loaded.',
                jobSnapshot.error,
              );
            }

            if (!jobSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final jobs = _sortByCreatedAt(jobSnapshot.data!.docs);

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _vendorsStream,
              builder: (context, vendorSnapshot) {
                if (vendorSnapshot.hasError) {
                  return _buildStreamError(
                    'Maintenance vendors could not be loaded.',
                    vendorSnapshot.error,
                  );
                }

                if (!vendorSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final vendors = vendorSnapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aName =
                        a.data()['vendorName']?.toString().toLowerCase() ?? '';
                    final bName =
                        b.data()['vendorName']?.toString().toLowerCase() ?? '';
                    return aName.compareTo(bName);
                  });

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _complaintsStream,
                  builder: (context, complaintSnapshot) {
                    if (complaintSnapshot.hasError) {
                      return _buildStreamError(
                        'Maintenance requests could not be loaded.',
                        complaintSnapshot.error,
                      );
                    }

                    if (!complaintSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final maintenanceComplaints =
                        complaintSnapshot.data!.docs.where((doc) {
                          return doc.data()['complaintType'] == 'maintenance';
                        }).toList()..sort((a, b) {
                          return _timestampValue(
                            b.data()['createdAt'],
                          ).compareTo(_timestampValue(a.data()['createdAt']));
                        });

                    return TabBarView(
                      children: [
                        _buildOverviewTab(jobs, vendors, maintenanceComplaints),
                        _buildJobsTab(jobs, vendors),
                        _buildVendorsTab(vendors),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateJobDialog(),
          backgroundColor: AppTheme.navyBlue,
          foregroundColor: AppTheme.white,
          icon: const Icon(Icons.add_rounded),
          label: const AppText('New repair job'),
        ),
      ),
    );
  }

  // ==========================================
  // OVERVIEW
  // ==========================================

  Widget _buildOverviewTab(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> vendors,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> complaints,
  ) {
    final open = jobs.where((doc) => doc.data()['status'] == 'open').length;
    final assigned = jobs
        .where((doc) => doc.data()['status'] == 'assigned')
        .length;
    final inProgress = jobs
        .where((doc) => doc.data()['status'] == 'in_progress')
        .length;
    final completed = jobs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;
    final activeVendors = vendors
        .where((doc) => doc.data()['status'] == 'active')
        .length;
    final incoming = complaints
        .where((doc) => doc.data()['status'] == 'submitted')
        .toList(growable: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntroCard(),
              const SizedBox(height: 20),
              _sectionHeading(
                'Maintenance overview',
                'Live status of repair work across your colony',
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metricCard(
                    'Open jobs',
                    open.toString(),
                    Icons.assignment_outlined,
                    const Color(0xFF54708F),
                  ),
                  _metricCard(
                    'Assigned',
                    assigned.toString(),
                    Icons.assignment_ind_outlined,
                    const Color(0xFF8A6A2C),
                  ),
                  _metricCard(
                    'In progress',
                    inProgress.toString(),
                    Icons.engineering_outlined,
                    const Color(0xFF326B9B),
                  ),
                  _metricCard(
                    'Completed',
                    completed.toString(),
                    Icons.task_alt_rounded,
                    const Color(0xFF36765A),
                  ),
                  _metricCard(
                    'Active vendors',
                    activeVendors.toString(),
                    Icons.business_outlined,
                    AppTheme.secondaryNavy,
                  ),
                  _metricCard(
                    'New requests',
                    incoming.length.toString(),
                    Icons.notification_important_outlined,
                    const Color(0xFF9A5A34),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: _sectionHeading(
                      'Incoming maintenance requests',
                      'Convert resident complaints into tracked repair jobs',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCreateJobDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const AppText('Create job'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (incoming.isEmpty)
                _emptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No new maintenance requests',
                  message: AppTranslations.translate(
                    'New resident maintenance complaints will appear here.',
                  ),
                )
              else
                ...incoming.take(5).map(_complaintCard),
              const SizedBox(height: 25),
              _sectionHeading(
                'Recent repair jobs',
                'The latest maintenance work registered for this colony',
              ),
              const SizedBox(height: 12),
              if (jobs.isEmpty)
                _emptyState(
                  icon: Icons.handyman_outlined,
                  title: 'No repair jobs registered',
                  message: AppTranslations.translate(
                    'Create a repair job or convert an incoming request to get started.',
                  ),
                )
              else
                ...jobs.take(4).map((job) => _jobCard(job, vendors)),
              const SizedBox(height: 85),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.navyBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'MAINTENANCE OPERATIONS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 11),
                AppText(
                  'Keep ${widget.colonyName} running smoothly.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const AppText(
                  'Track repairs, coordinate service vendors and close maintenance requests.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.home_repair_service_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color accent) {
    return SizedBox(
      width: 165,
      child: Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: accent, size: 22),
                AppText(
                  value,
                  style: const TextStyle(
                    color: AppTheme.navyBlue,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            AppText(
              label,
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // REPAIR JOBS
  // ==========================================

  Widget _buildJobsTab(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> vendors,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _sectionHeading(
                      'Repair job register',
                      '${jobs.length} job${jobs.length == 1 ? '' : 's'} recorded for this colony',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showCreateJobDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const AppText('New job'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (jobs.isEmpty)
                _emptyState(
                  icon: Icons.handyman_outlined,
                  title: 'No maintenance jobs yet',
                  message: AppTranslations.translate(
                    'Create a job manually or convert a resident maintenance complaint.',
                  ),
                )
              else
                ...jobs.map((job) => _jobCard(job, vendors)),
              const SizedBox(height: 85),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jobCard(
    QueryDocumentSnapshot<Map<String, dynamic>> job,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> vendors,
  ) {
    final data = job.data();
    final title = data['title']?.toString() ?? 'Maintenance job';
    final category = data['category']?.toString() ?? 'Other';
    final location = data['location']?.toString() ?? 'Location not specified';
    final description = data['description']?.toString() ?? '';
    final priority = data['priority']?.toString() ?? 'normal';
    final status = data['status']?.toString() ?? 'open';
    final vendorName = data['vendorName']?.toString();
    final createdAt = _dateLabel(data['createdAt']);
    final actualCost = data['actualCost'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.handyman_outlined,
                  color: AppTheme.secondaryNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      '$category · $location',
                      style: const TextStyle(
                        color: AppTheme.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: AppTranslations.translate('Manage maintenance job'),
                onSelected: (value) {
                  if (value == 'manage') {
                    _showManageJobDialog(job, vendors);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'manage',
                    child: AppText('Manage job'),
                  ),
                ],
              ),
            ],
          ),
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            AppText(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusBadge(status),
              _priorityBadge(priority),
              _infoPill(
                Icons.business_outlined,
                vendorName == null || vendorName.trim().isEmpty
                    ? 'Vendor not assigned'
                    : vendorName,
              ),
              _infoPill(Icons.schedule_rounded, createdAt),
              if (actualCost is num && actualCost > 0)
                _infoPill(
                  Icons.currency_rupee_rounded,
                  _moneyLabel(actualCost),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _showManageJobDialog(job, vendors),
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const AppText('Manage job'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showManageJobDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> job,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> vendors,
  ) async {
    final data = job.data();
    final notesController = TextEditingController(
      text: data['resolutionNotes']?.toString() ?? '',
    );
    final costController = TextEditingController(
      text: data['actualCost'] is num
          ? (data['actualCost'] as num).toString()
          : '',
    );

    final activeVendors = vendors
        .where((doc) => doc.data()['status'] == 'active')
        .toList(growable: false);
    final currentVendorId = data['vendorId']?.toString();
    final currentVendorName = data['vendorName']?.toString() ?? '';
    final currentVendorPhone = data['vendorPhone']?.toString() ?? '';

    String selectedVendorId = currentVendorId ?? '';
    String selectedStatus = _jobStatuses.contains(data['status'])
        ? data['status'] as String
        : 'open';
    bool saving = false;
    String? formError;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentVendorIsInList =
                currentVendorId != null &&
                activeVendors.any((vendor) => vendor.id == currentVendorId);

            return AlertDialog(
              title: const AppText('Manage repair job'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText(
                        data['title']?.toString() ?? 'Maintenance job',
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: selectedVendorId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Assigned vendor',
                          ),
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: AppText('No vendor assigned'),
                          ),
                          if (currentVendorId != null && !currentVendorIsInList)
                            DropdownMenuItem<String>(
                              value: currentVendorId,
                              child: AppText(
                                currentVendorName.isEmpty
                                    ? 'Current vendor (inactive or unavailable)'
                                    : '$currentVendorName (inactive or unavailable)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ...activeVendors.map((vendor) {
                            final vendorData = vendor.data();
                            return DropdownMenuItem<String>(
                              value: vendor.id,
                              child: AppText(
                                vendorData['vendorName']?.toString() ??
                                    'Unnamed vendor',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedVendorId = value ?? '';
                                });
                              },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate('Job status'),
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: _jobStatuses.map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: AppText(_statusLabel(status)),
                          );
                        }).toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedStatus = value;
                                });
                              },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: notesController,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Resolution notes',
                          ),
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: costController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Actual cost (₹)',
                          ),
                          hintText: AppTranslations.translate(
                            'Leave blank if not yet known',
                          ),
                          prefixIcon: Icon(Icons.currency_rupee_rounded),
                        ),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        _formError(formError!),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const AppText('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final costText = costController.text.trim();
                          final parsedCost = costText.isEmpty
                              ? null
                              : num.tryParse(costText);

                          if (costText.isNotEmpty &&
                              (parsedCost == null ||
                                  !parsedCost.isFinite ||
                                  parsedCost < 0)) {
                            setDialogState(() {
                              formError = 'Enter a valid non-negative cost.';
                            });
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            formError = null;
                          });

                          try {
                            String? vendorName;
                            String? vendorPhone;

                            final assignedVendorId = selectedVendorId.isEmpty
                                ? null
                                : selectedVendorId;

                            if (assignedVendorId == null) {
                              vendorName = null;
                              vendorPhone = null;
                            } else if (assignedVendorId == currentVendorId) {
                              vendorName = currentVendorName;
                              vendorPhone = currentVendorPhone;
                            } else {
                              QueryDocumentSnapshot<Map<String, dynamic>>?
                              selectedVendor;
                              for (final vendor in activeVendors) {
                                if (vendor.id == selectedVendorId) {
                                  selectedVendor = vendor;
                                  break;
                                }
                              }

                              if (selectedVendor == null) {
                                setDialogState(() {
                                  saving = false;
                                  formError = 'Select an active vendor or remove the current assignment.';
                                });
                                return;
                              }

                              final vendorData = selectedVendor.data();
                              vendorName =
                                  vendorData['vendorName']?.toString() ?? '';
                              vendorPhone =
                                  vendorData['phoneNumber']?.toString() ?? '';
                            }

                            final batch = FirebaseFirestore.instance.batch();
                            batch.update(job.reference, {
                              'vendorId': assignedVendorId,
                              'vendorName': vendorName,
                              'vendorPhone': vendorPhone,
                              'status': selectedStatus,
                              'resolutionNotes': notesController.text.trim(),
                              'actualCost': parsedCost,
                              'updatedAt': FieldValue.serverTimestamp(),
                              'completedAt': selectedStatus == 'completed'
                                  ? FieldValue.serverTimestamp()
                                  : null,
                            });

                            final previousStatus =
                                data['status']?.toString() ?? 'open';
                            final linkedComplaintId =
                                data['sourceComplaintId']?.toString() ?? '';
                            if (selectedStatus != previousStatus &&
                                linkedComplaintId.isNotEmpty) {
                              final linkedComplaint = await _complaints
                                  .doc(linkedComplaintId)
                                  .get();
                              final residentUserId =
                                  linkedComplaint
                                      .data()?['submittedBy']
                                      ?.toString() ??
                                  '';
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;
                              if (currentUser != null &&
                                  residentUserId.isNotEmpty) {
                                NotificationService.addMaintenanceJobUpdated(
                                  batch: batch,
                                  colonyId: widget.colonyId,
                                  jobId: job.id,
                                  jobTitle:
                                      data['title']?.toString() ??
                                      'Maintenance job',
                                  newStatus: selectedStatus,
                                  recipientUserId: residentUserId,
                                  createdBy: currentUser.uid,
                                );
                              }
                            }

                            await batch.commit();

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop(true);
                          } on FirebaseException catch (error) {
                            debugPrint(
                              'Maintenance job update failed: ${error.code} ${error.message}',
                            );
                            setDialogState(() {
                              saving = false;
                              formError = _firebaseErrorMessage(error);
                            });
                          } catch (error) {
                            debugPrint('Maintenance job update error: $error');
                            setDialogState(() {
                              saving = false;
                              formError =
                                  'Unable to update this maintenance job.';
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppText('Save changes'),
                ),
              ],
            );
          },
        );
      },
    );

    notesController.dispose();
    costController.dispose();

    if (result == true) {
      _showMessage('Maintenance job updated successfully.');
    }
  }

  // ==========================================
  // VENDORS
  // ==========================================

  Widget _buildVendorsTab(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> vendors,
  ) {
    final activeCount = vendors
        .where((doc) => doc.data()['status'] == 'active')
        .length;
    final inactiveCount = vendors.length - activeCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _sectionHeading(
                      'Maintenance vendor directory',
                      '$activeCount active · $inactiveCount inactive · ${vendors.length} total',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showVendorDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const AppText('Add vendor'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (vendors.isEmpty)
                _emptyState(
                  icon: Icons.business_outlined,
                  title: 'No vendors registered',
                  message: AppTranslations.translate(
                    'Register trusted service providers to assign them to repair jobs.',
                  ),
                )
              else
                ...vendors.map(_vendorCard),
              const SizedBox(height: 85),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vendorCard(QueryDocumentSnapshot<Map<String, dynamic>> vendor) {
    final data = vendor.data();
    final name = data['vendorName']?.toString() ?? 'Unnamed vendor';
    final contact = data['contactPerson']?.toString() ?? '';
    final phone = data['phoneNumber']?.toString() ?? '';
    final email = data['email']?.toString() ?? '';
    final category = data['serviceCategory']?.toString() ?? 'Other';
    final status = data['status']?.toString() ?? 'inactive';
    final active = status == 'active';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: AppTheme.secondaryNavy,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  name,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                AppText(
                  '$category services',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (contact.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _vendorDetail(Icons.person_outline_rounded, contact),
                ],
                if (phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _vendorDetail(Icons.phone_outlined, phone),
                ],
                if (email.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _vendorDetail(Icons.email_outlined, email),
                ],
                const SizedBox(height: 9),
                _statusBadge(status),
              ],
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: AppTranslations.translate('Vendor actions'),
            onSelected: (value) {
              if (value == 'toggle') {
                _toggleVendorStatus(vendor, active ? 'inactive' : 'active');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'toggle',
                child: AppText(
                  active ? 'Deactivate vendor' : 'Activate vendor',
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _showVendorDialog() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    String selectedCategory = _vendorCategories.first;
    bool saving = false;
    String? formError;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const AppText('Register maintenance vendor'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        maxLength: 150,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Vendor / company name *',
                          ),
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contactController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Contact person',
                          ),
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Phone number *',
                          ),
                          prefixIcon: Icon(Icons.phone_outlined),
                          hintText: AppTranslations.translate(
                            '7–20 characters',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate('Email address'),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: AppTranslations.translate(
                            'Service category *',
                          ),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: _vendorCategories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: AppText(category),
                          );
                        }).toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedCategory = value;
                                });
                              },
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        _formError(formError!),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const AppText('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final contact = contactController.text.trim();
                          final phone = phoneController.text.trim();
                          final email = emailController.text.trim();

                          if (name.isEmpty || name.length > 150) {
                            setDialogState(() {
                              formError = 'Enter a vendor name of up to 150 characters.';
                            });
                            return;
                          }

                          if (phone.length < 7 || phone.length > 20) {
                            setDialogState(() {
                              formError =
                                  'Phone number must contain 7–20 characters.';
                            });
                            return;
                          }

                          if (email.isNotEmpty &&
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)) {
                            setDialogState(() {
                              formError = 'Enter a valid email address.';
                            });
                            return;
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            setDialogState(() {
                              formError = 'Your session has expired. Please sign in again.';
                            });
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            formError = null;
                          });

                          try {
                            await _vendors.add({
                              'vendorName': name,
                              'contactPerson': contact,
                              'phoneNumber': phone,
                              'email': email,
                              'serviceCategory': selectedCategory,
                              'status': 'active',
                              'createdBy': user.uid,
                              'createdByName': widget.adminName,
                              'createdAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop(true);
                          } on FirebaseException catch (error) {
                            debugPrint(
                              'Maintenance vendor creation failed: ${error.code} ${error.message}',
                            );
                            setDialogState(() {
                              saving = false;
                              formError = _firebaseErrorMessage(error);
                            });
                          } catch (error) {
                            debugPrint(
                              'Maintenance vendor creation error: $error',
                            );
                            setDialogState(() {
                              saving = false;
                              formError = 'Unable to register this vendor.';
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppText('Register vendor'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    contactController.dispose();
    phoneController.dispose();
    emailController.dispose();

    if (result == true) {
      _showMessage('Maintenance vendor registered successfully.');
    }
  }

  Future<void> _toggleVendorStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> vendor,
    String newStatus,
  ) async {
    try {
      await vendor.reference.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showMessage(
        newStatus == 'active'
            ? 'Vendor activated successfully.'
            : 'Vendor deactivated successfully.',
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Maintenance vendor status update failed: ${error.code} ${error.message}',
      );
      _showMessage('Unable to update vendor: ${_firebaseErrorMessage(error)}');
    } catch (error) {
      debugPrint('Maintenance vendor status update error: $error');
      _showMessage('Unable to update vendor status.');
    }
  }

  // ==========================================
  // CREATE JOB / CONVERT COMPLAINT
  // ==========================================

  Future<void> _showCreateJobDialog({
    DocumentSnapshot<Map<String, dynamic>>? complaint,
  }) async {
    final complaintData = complaint?.data() ?? const <String, dynamic>{};
    final fromComplaint = complaint != null;

    final titleController = TextEditingController(
      text: complaintData['title']?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: complaintData['location']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: complaintData['description']?.toString() ?? '',
    );

    String selectedCategory =
        _jobCategories.contains(complaintData['category']?.toString())
        ? complaintData['category'] as String
        : _jobCategories.first;
    String selectedPriority =
        _priorities.contains(complaintData['priority']?.toString())
        ? complaintData['priority'] as String
        : 'normal';

    bool saving = false;
    String? formError;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: AppText(
                fromComplaint
                    ? 'Convert request to repair job'
                    : 'Create repair job',
              ),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (fromComplaint) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF0F7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const AppText(
                              'The complaint details are kept unchanged so the job remains linked to the original resident request.',
                              style: TextStyle(
                                color: AppTheme.secondaryNavy,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: titleController,
                          readOnly: fromComplaint,
                          maxLength: 120,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Job title *'),
                            prefixIcon: Icon(Icons.title_rounded),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty || text.length > 120) {
                              return AppTranslations.translate(
                                'Enter a title of up to 120 characters.',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Category *'),
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: _jobCategories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: AppText(category),
                            );
                          }).toList(),
                          onChanged: fromComplaint || saving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    selectedCategory = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: locationController,
                          readOnly: fromComplaint,
                          maxLength: 160,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate(
                              'Location / area *',
                            ),
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty || text.length > 160) {
                              return AppTranslations.translate(
                                'Enter a location of up to 160 characters.',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedPriority,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Priority *'),
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                          items: _priorities.map((priority) {
                            return DropdownMenuItem<String>(
                              value: priority,
                              child: AppText(_priorityLabel(priority)),
                            );
                          }).toList(),
                          onChanged: fromComplaint || saving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    selectedPriority = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descriptionController,
                          readOnly: fromComplaint,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 2000,
                          decoration: InputDecoration(
                            labelText: AppTranslations.translate('Description'),
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                          validator: (value) {
                            if ((value?.length ?? 0) > 2000) {
                              return AppTranslations.translate(
                                'Description cannot exceed 2,000 characters.',
                              );
                            }
                            return null;
                          },
                        ),
                        if (formError != null) ...[
                          const SizedBox(height: 12),
                          _formError(formError!),
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
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const AppText('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            setDialogState(() {
                              formError = 'Your session has expired. Please sign in again.';
                            });
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            formError = null;
                          });

                          try {
                            final batch = FirebaseFirestore.instance.batch();
                            final jobReference = _jobs.doc();

                            final jobData = <String, dynamic>{
                              'title': titleController.text.trim(),
                              'category': selectedCategory,
                              'location': locationController.text.trim(),
                              'description': descriptionController.text.trim(),
                              'priority': selectedPriority,
                              'status': 'open',
                              'vendorId': null,
                              'vendorName': null,
                              'vendorPhone': null,
                              'resolutionNotes': '',
                              'actualCost': null,
                              'createdBy': user.uid,
                              'createdByName': widget.adminName,
                              'createdAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                              'completedAt': null,
                              if (complaint != null)
                                'sourceComplaintId': complaint.id,
                            };

                            batch.set(jobReference, jobData);

                            if (complaint != null) {
                              batch.update(complaint.reference, {
                                'status': 'acknowledged',
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              final complaintData =
                                  complaint.data() ?? <String, dynamic>{};
                              final recipientUserId =
                                  complaintData['submittedBy']?.toString() ??
                                  '';
                              if (recipientUserId.isNotEmpty) {
                                NotificationService.addComplaintStatusChanged(
                                  batch: batch,
                                  colonyId: widget.colonyId,
                                  complaintId: complaint.id,
                                  complaintTitle:
                                      complaintData['title']?.toString() ??
                                      'Your complaint',
                                  newStatus: 'acknowledged',
                                  recipientUserId: recipientUserId,
                                  createdBy: user.uid,
                                );
                              }
                            }

                            await batch.commit();

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop(true);
                          } on FirebaseException catch (error) {
                            debugPrint(
                              'Maintenance job creation failed: ${error.code} ${error.message}',
                            );
                            setDialogState(() {
                              saving = false;
                              formError = _firebaseErrorMessage(error);
                            });
                          } catch (error) {
                            debugPrint(
                              'Maintenance job creation error: $error',
                            );
                            setDialogState(() {
                              saving = false;
                              formError =
                                  'Unable to create this maintenance job.';
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : AppText(
                          fromComplaint ? 'Convert to job' : 'Create job',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();

    if (result == true) {
      _showMessage(
        fromComplaint
            ? 'Maintenance request converted to a repair job.'
            : 'Maintenance job created successfully.',
      );
    }
  }

  Widget _complaintCard(QueryDocumentSnapshot<Map<String, dynamic>> complaint) {
    final data = complaint.data();
    final title = data['title']?.toString() ?? 'Maintenance request';
    final category = data['category']?.toString() ?? 'Other';
    final location = data['location']?.toString() ?? 'Location not specified';
    final description = data['description']?.toString() ?? '';
    final priority = data['priority']?.toString() ?? 'normal';
    final status = data['status']?.toString() ?? 'submitted';
    final reporter = data['reportedByName']?.toString() ?? '';
    final createdAt = _dateLabel(data['createdAt']);
    final canConvert = status == 'submitted';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
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
                  title,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 6),
          AppText(
            '$category · $location',
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            AppText(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _priorityBadge(priority),
              if (reporter.trim().isNotEmpty)
                _infoPill(Icons.person_outline_rounded, reporter),
              _infoPill(Icons.schedule_rounded, createdAt),
            ],
          ),
          const SizedBox(height: 11),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: canConvert
                  ? () => _showCreateJobDialog(complaint: complaint)
                  : null,
              icon: const Icon(Icons.construction_rounded, size: 17),
              label: AppText(
                canConvert ? 'Convert to repair job' : 'Already acknowledged',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED UI
  // ==========================================

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
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
        const SizedBox(height: 5),
        AppText(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textGrey,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color background;
    Color foreground;

    switch (status) {
      case 'completed':
        background = const Color(0xFFE6F3EC);
        foreground = const Color(0xFF28734D);
        break;
      case 'in_progress':
        background = const Color(0xFFE7F0FA);
        foreground = const Color(0xFF2D6595);
        break;
      case 'assigned':
        background = const Color(0xFFFFF3DB);
        foreground = const Color(0xFF946719);
        break;
      case 'cancelled':
        background = const Color(0xFFFCEAEA);
        foreground = const Color(0xFF9B4141);
        break;
      case 'acknowledged':
        background = const Color(0xFFEAF0F7);
        foreground = AppTheme.secondaryNavy;
        break;
      default:
        background = const Color(0xFFF0F2F5);
        foreground = AppTheme.textGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: AppText(
        _statusLabel(status).toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.45,
        ),
      ),
    );
  }

  Widget _priorityBadge(String priority) {
    final Color foreground = switch (priority) {
      'urgent' => const Color(0xFFB23B3B),
      'high' => const Color(0xFF9B5A27),
      'low' => const Color(0xFF54705E),
      _ => AppTheme.secondaryNavy,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: AppText(
        'PRIORITY: ${_priorityLabel(priority).toUpperCase()}',
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textGrey),
          const SizedBox(width: 5),
          AppText(
            text,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vendorDetail(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textGrey),
        const SizedBox(width: 7),
        Expanded(
          child: AppText(
            value,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.secondaryNavy, size: 34),
          const SizedBox(height: 12),
          AppText(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          AppText(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEAEA),
        borderRadius: BorderRadius.circular(9),
      ),
      child: AppText(
        message,
        style: const TextStyle(
          color: Color(0xFF9B4141),
          fontSize: 11,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildStreamError(String title, Object? error) {
    debugPrint('$title $error');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppTheme.textGrey,
              size: 38,
            ),
            const SizedBox(height: 12),
            AppText(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const AppText(
              'Check your connection and administrator access, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DATA / FEEDBACK HELPERS
  // ==========================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortByCreatedAt(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final result = documents.toList();
    result.sort((a, b) {
      return _timestampValue(b.data()['createdAt'])
          .compareTo(_timestampValue(a.data()['createdAt']));
    });
    return result;
  }

  int _timestampValue(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  String _dateLabel(Object? value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate().toLocal();
    if (value is DateTime) date = value.toLocal();
    if (date == null) return 'Date pending';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} · $hour:$minute';
  }

  String _moneyLabel(num amount) {
    final rounded = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '₹$rounded';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'submitted':
        return 'Submitted';
      case 'acknowledged':
        return 'Acknowledged';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  String _priorityLabel(String priority) {
    if (priority.isEmpty) return 'Normal';
    return '${priority[0].toUpperCase()}${priority.substring(1)}';
  }

  String _firebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore denied this action. Confirm your admin access and the maintenance security rules.';
      case 'unavailable':
        return 'The service is temporarily unavailable. Check your connection and retry.';
      case 'unauthenticated':
        return 'Your session has expired. Please sign in again.';
      default:
        return error.message ?? 'Firebase error: ${error.code}';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
