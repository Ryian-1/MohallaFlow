import 'package:cloud_firestore/cloud_firestore.dart' hide Type;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mohalla_flow/app.dart';
import 'package:mohalla_flow/firebase_options.dart';
import 'package:mohalla_flow/screens/admin_dashboard_screen.dart';
import 'package:mohalla_flow/screens/cleanliness_screen.dart';
import 'package:mohalla_flow/screens/resident_dashboard_screen.dart';
import 'package:mohalla_flow/screens/worker_dashboard_screen.dart';
import 'package:mohalla_flow/screens/notification_center_screen.dart';
import 'package:mohalla_flow/widgets/notification_bell.dart';

const String projectId = 'demo-mohallaflow';
const String colonyId = 'four_role_application_integration';
const String colonyName = 'MohallaFlow Integration Colony';
const String password = 'MohallaFlow-Integration-2026!';
const String householdId = 'household-four-role';
const String residentId = 'resident-four-role';
const String workerId = 'worker-four-role';
const String firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

enum RoleCase { admin, resident, cleanlinessManager, worker }

class RoleScenario {
  const RoleScenario({
    required this.email,
    required this.role,
    required this.dashboardType,
  });

  final String email;
  final RoleCase role;
  final Type dashboardType;
}

const List<RoleScenario> scenarios = [
  RoleScenario(
    email: 'mf-four-role-admin@example.test',
    role: RoleCase.admin,
    dashboardType: AdminDashboardScreen,
  ),
  RoleScenario(
    email: 'mf-four-role-resident@example.test',
    role: RoleCase.resident,
    dashboardType: ResidentDashboardScreen,
  ),
  RoleScenario(
    email: 'mf-four-role-manager@example.test',
    role: RoleCase.cleanlinessManager,
    dashboardType: CleanlinessScreen,
  ),
  RoleScenario(
    email: 'mf-four-role-worker@example.test',
    role: RoleCase.worker,
    dashboardType: WorkerDashboardScreen,
  ),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Authenticated sessions resolve all four roles and open their real dashboards',
    (tester) async {
      final base = DefaultFirebaseOptions.currentPlatform;

      // The iOS runner may already have a native default Firebase app
      // configured from GoogleService-Info.plist. Delete only that app
      // before creating the isolated demo-project default app.
      final existingDefaultApps = Firebase.apps
          .where((existing) => existing.name == defaultFirebaseAppName)
          .toList(growable: false);

      for (final existing in existingDefaultApps) {
        await existing.delete();
      }

      final app = await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: base.apiKey,
          appId: base.appId,
          messagingSenderId: base.messagingSenderId,
          projectId: projectId,
          authDomain: base.authDomain,
          storageBucket: base.storageBucket,
        ),
      );

      expect(
        app.options.projectId,
        projectId,
        reason: 'This test must never connect to the production project.',
      );

      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      await auth.useAuthEmulator(firebaseEmulatorHost, 9099);

      firestore.useFirestoreEmulator(firebaseEmulatorHost, 8080);
      firestore.settings = const Settings(persistenceEnabled: false);

      await auth.signOut();

      for (final scenario in scenarios) {
        await tester.pumpWidget(const SizedBox.shrink());
        await auth.signOut();

        final credential = await auth.signInWithEmailAndPassword(
          email: scenario.email,
          password: password,
        );

        final user = credential.user;
        expect(user, isNotNull);

        final uid = user!.uid;

        final profile = await firestore.collection('users').doc(uid).get();
        expect(profile.exists, isTrue);

        final membership = await firestore
            .doc('colonies/$colonyId/members/$uid')
            .get();

        expect(membership.exists, isTrue);
        expect(membership.data()?['status'], 'active');

        await _verifyRoleData(
          firestore: firestore,
          uid: uid,
          role: scenario.role,
        );

        // Boot the actual app shell. The existing authenticated session is
        // restored by LoginScreen and routed through ColonyDashboardRouter.
        await tester.pumpWidget(const MohallaFlowApp());
        await tester.pump(const Duration(seconds: 3));

        final dashboard = find.byType(scenario.dashboardType);

        await _waitForDashboard(
          tester: tester,
          dashboard: dashboard,
          role: scenario.role,
        );

        // Allow dashboard Firestore streams to receive their initial data.
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();

        final renderingErrors = <Object>[];
        Object? renderingError;
        while ((renderingError = tester.takeException()) != null) {
          renderingErrors.add(renderingError!);
        }

        expect(
          renderingErrors,
          isEmpty,
          reason:
              'Rendering/layout error for ${scenario.role}: '
              '${renderingErrors.join('\n')}',
        );

        expect(dashboard, findsOneWidget);
        expect(find.text(colonyName), findsWidgets);
        expect(
          find.textContaining('Unable to load'),
          findsNothing,
          reason: 'A dashboard data stream failed for ${scenario.role}.',
        );

        // Unmount before signing out so every role's stream subscriptions are
        // disposed before the next authenticated session is created.
        await tester.pumpWidget(const SizedBox.shrink());
        await auth.signOut();
      }

      // Verify worker notification fan-out is presented as one logical event.
      await _exerciseWorkerNotificationDeduplication(
        tester: tester,
        auth: auth,
        firestore: firestore,
      );

      // Stage 6 real resident-to-resolution UI journey. This deliberately
      // uses each role's authenticated app session and visible UI controls.
      await _exerciseResidentToResolutionJourney(
        tester: tester,
        auth: auth,
        firestore: firestore,
      );

      // Stage 7: resident payment submission, Admin verification,
      // and resident-visible verified payment history.
      await _exerciseMaintenancePaymentJourney(
        tester: tester,
        auth: auth,
        firestore: firestore,
      );

      expect(auth.currentUser, isNull);
    },
  );
}

Future<void> _exerciseResidentToResolutionJourney({
  required WidgetTester tester,
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
}) async {
  final colony = firestore.collection('colonies').doc(colonyId);
  final uniqueSuffix = DateTime.now().microsecondsSinceEpoch;
  final complaintTitle = 'Stage 6 UI lifecycle $uniqueSuffix';
  const complaintDescription =
      'Integration test: remove accumulated litter from the shared corridor.';
  // 1. Resident creates a new cleanliness complaint through the real form.
  await _signInAndOpenRoleDashboard(
    tester: tester,
    auth: auth,
    role: RoleCase.resident,
  );
  final residentUid = auth.currentUser!.uid;

  final submitComplaintAction = find.byTooltip('Submit complaint');
  expect(submitComplaintAction, findsOneWidget);
  await tester.tap(submitComplaintAction);
  await _waitForCondition(
    tester,
    () => find.text('Submit a complaint').evaluate().isNotEmpty,
    'Resident complaint form did not open.',
  );

  final residentFields = find.byType(TextField);
  expect(
    residentFields,
    findsNWidgets(3),
    reason: 'Resident complaint form should expose title, location and description.',
  );
  await tester.enterText(residentFields.at(0), complaintTitle);
  await tester.enterText(
    residentFields.at(1),
    'Block A, near the shared corridor',
  );
  await tester.enterText(residentFields.at(2), complaintDescription);

  final categoryDropdown = find.byType(DropdownButtonFormField<String>).first;
  await tester.ensureVisible(categoryDropdown);
  await tester.tap(categoryDropdown);
  await tester.pumpAndSettle();
  final cleanlinessCategory = find.text('Garbage collection');
  expect(cleanlinessCategory, findsWidgets);
  await tester.tap(cleanlinessCategory.last);
  await tester.pump();

  final residentSubmitButton = find.widgetWithText(
    ElevatedButton,
    'Submit complaint',
  );
  expect(residentSubmitButton, findsOneWidget);
  await tester.tap(residentSubmitButton);
  await _waitForCondition(
    tester,
    () => find.text('Submit a complaint').evaluate().isEmpty,
    'Resident complaint form did not close after submitting.',
  );

  final residentComplaints = await colony
      .collection('complaints')
      .where('submittedBy', isEqualTo: residentUid)
      .get();
  final createdComplaints = residentComplaints.docs.where((document) {
    return document.data()['title'] == complaintTitle;
  }).toList();
  expect(
    createdComplaints,
    hasLength(1),
    reason: 'Resident UI submission must persist exactly one complaint.',
  );
  final complaint = createdComplaints.single;
  final complaintData = complaint.data();
  expect(complaintData['complaintType'], 'cleanliness');
  expect(complaintData['status'], 'submitted');
  expect(complaintData['submittedBy'], residentUid);

  await _endRoleSession(tester, auth);

  // 2. Cleanliness Manager receives that exact complaint and assigns a task.
  await _signInAndOpenRoleDashboard(
    tester: tester,
    auth: auth,
    role: RoleCase.cleanlinessManager,
  );

  final incomingComplaintsButton = find.widgetWithText(
    OutlinedButton,
    'Incoming complaints',
  );
  expect(incomingComplaintsButton, findsOneWidget);
  await tester.tap(incomingComplaintsButton);
  await _waitForCondition(
    tester,
    () => find.text('Incoming cleanliness complaints').evaluate().isNotEmpty,
    'Cleanliness Manager incoming-complaints dialog did not open.',
  );
  await _waitForCondition(
    tester,
    () => find.text(complaintTitle).evaluate().isNotEmpty,
    'The newly submitted resident complaint did not reach the manager UI.',
  );

  final incomingComplaintCard = find
      .ancestor(of: find.text(complaintTitle), matching: find.byType(Column))
      .first;
  final createCleaningTaskButton = find.descendant(
    of: incomingComplaintCard,
    matching: find.widgetWithText(ElevatedButton, 'Create cleaning task'),
  );
  expect(
    createCleaningTaskButton,
    findsOneWidget,
    reason: 'Task creation must be initiated from this resident complaint, not another incoming complaint.',
  );
  await tester.tap(createCleaningTaskButton);
  await _waitForCondition(
    tester,
    () => find.text('Create and assign task').evaluate().isNotEmpty,
    'Manager task-assignment form did not open.',
  );

  final managerFields = find.byType(TextFormField);
  expect(
    managerFields,
    findsNWidgets(3),
    reason: 'Task form should expose title, location and description.',
  );
  expect(
    tester.widget<TextFormField>(managerFields.at(0)).controller?.text,
    complaintTitle,
    reason: 'Task title should carry forward from the originating complaint.',
  );
  expect(
    tester.widget<TextFormField>(managerFields.at(2)).controller?.text,
    complaintDescription,
    reason:
        'Task description should carry forward from the originating complaint.',
  );

  // The fixture has exactly one active worker. The form defaults to that worker.
  final managerSaveButtons = find.byType(ElevatedButton);
  expect(managerSaveButtons, findsWidgets);
  await tester.tap(managerSaveButtons.last);
  await _waitForCondition(
    tester,
    () => find.text('Create and assign task').evaluate().isEmpty,
    'Manager assignment form did not close after saving.',
  );

  final linkedTasks = await colony
      .collection('cleanlinessTasks')
      .where('sourceComplaintId', isEqualTo: complaint.id)
      .get();
  expect(
    linkedTasks.docs,
    hasLength(1),
    reason:
        'Manager action must create one task linked to the exact complaint.',
  );
  final task = linkedTasks.docs.single;
  final taskData = task.data();
  expect(taskData['status'], 'assigned');
  expect(taskData['assignedWorkerId'], workerId);
  expect(taskData['sourceComplaintId'], complaint.id);

  final acknowledgedComplaint = await complaint.reference.get();
  expect(acknowledgedComplaint.data()?['status'], 'acknowledged');

  // The manager can change operational task status but must not manually
  // complete a complaint-linked task. The assigned Worker owns the atomic
  // completion path that also resolves the resident's complaint.
  final managerTaskCard = find.byKey(
    ValueKey<String>('cleanliness-task-${task.id}'),
  );
  expect(managerTaskCard, findsOneWidget);
  final managerStatusMenu = find.descendant(
    of: managerTaskCard,
    matching: find.byTooltip('Update task status'),
  );
  expect(managerStatusMenu, findsOneWidget);
  expect(
    find.text(
      'The assigned worker completes this task to resolve the resident complaint.',
    ),
    findsOneWidget,
  );
  await tester.tap(managerStatusMenu);
  await tester.pumpAndSettle();
  expect(
    find.widgetWithText(PopupMenuItem<String>, 'Completed'),
    findsNothing,
    reason:
        'Manager must not have a manual completion action for a linked task.',
  );
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();

  final managerTaskSnapshot = await task.reference.get();
  expect(
    managerTaskSnapshot.data()?['status'],
    'assigned',
    reason: 'Opening the manager task menu must not mutate task state.',
  );

  await _endRoleSession(tester, auth);

  // 3. Assigned Worker starts and completes the task through the task card.
  await _signInAndOpenRoleDashboard(
    tester: tester,
    auth: auth,
    role: RoleCase.worker,
  );
  final taskTitleFinder = find.text(complaintTitle);
  await _waitForCondition(
    tester,
    () => taskTitleFinder.evaluate().isNotEmpty,
    'The assigned worker did not receive the newly assigned task.',
  );
  await tester.ensureVisible(taskTitleFinder);

  final taskCard = find.byKey(ValueKey<String>('worker-task-${task.id}'));
  expect(taskCard, findsOneWidget);
  final startTaskButton = find.descendant(
    of: taskCard,
    matching: find.widgetWithText(ElevatedButton, 'Start task'),
  );
  expect(startTaskButton, findsOneWidget);
  // Scroll the worker task list itself. ensureVisible() alone did not
  // move the nested task viewport on the iPhone simulator in the first run.
  final workerTaskScrollable = find
      .ancestor(of: startTaskButton, matching: find.byType(Scrollable))
      .first;
  await tester.dragUntilVisible(
    startTaskButton,
    workerTaskScrollable,
    const Offset(0, -280),
  );
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(startTaskButton);

  final markCompletedButton = find.descendant(
    of: taskCard,
    matching: find.widgetWithText(ElevatedButton, 'Mark as completed'),
  );
  await _waitForCondition(
    tester,
    () => markCompletedButton.evaluate().isNotEmpty,
    'Starting the task did not expose the completion action.',
  );

  // Clear transient task feedback before interacting with the next action.
  final workerMessenger = ScaffoldMessenger.of(tester.element(taskCard));
  workerMessenger.clearSnackBars();
  await tester.pumpAndSettle();

  expect(
    find.byType(SnackBar),
    findsNothing,
    reason: 'Transient task feedback must not obstruct task completion.',
  );

  final completionTaskScrollable = find
      .ancestor(of: markCompletedButton, matching: find.byType(Scrollable))
      .first;
  await tester.dragUntilVisible(
    markCompletedButton,
    completionTaskScrollable,
    const Offset(0, -280),
  );
  await tester.pump(const Duration(milliseconds: 250));
  await tester.ensureVisible(markCompletedButton);
  await tester.pumpAndSettle();
  await tester.tap(markCompletedButton);

  final completionConfirmation = find.descendant(
    of: taskCard,
    matching: find.text('Task completed successfully'),
  );
  await _waitForCondition(
    tester,
    () => completionConfirmation.evaluate().isNotEmpty,
    'Worker completion did not update the visible task card.',
  );

  final completedTask = await task.reference.get();
  expect(completedTask.data()?['status'], 'completed');
  expect(completedTask.data()?['completedAt'], isNotNull);

  await _endRoleSession(tester, auth);

  // 4. Resident returns to the Complaints tab and sees the resolved status.
  await _signInAndOpenRoleDashboard(
    tester: tester,
    auth: auth,
    role: RoleCase.resident,
  );
  final complaintsNavigationItem = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('Complaints'),
  );
  expect(complaintsNavigationItem, findsOneWidget);
  await tester.tap(complaintsNavigationItem);
  await _waitForCondition(
    tester,
    () => find.text(complaintTitle).evaluate().isNotEmpty,
    'Resident complaints list did not display the submitted complaint.',
  );

  final resolvedTextVisible =
      find.textContaining('RESOLVED').evaluate().isNotEmpty ||
      find.textContaining('Resolved').evaluate().isNotEmpty ||
      find.textContaining('resolved').evaluate().isNotEmpty;
  expect(
    resolvedTextVisible,
    isTrue,
    reason: 'Resident UI must visibly show the complaint as resolved.',
  );

  final resolvedComplaint = await complaint.reference.get();
  final resolvedData = resolvedComplaint.data() ?? <String, dynamic>{};
  expect(resolvedData['status'], 'resolved');
  expect(resolvedData['resolutionTaskId'], task.id);
  expect(resolvedData['resolvedAt'], isNotNull);
  expect(resolvedData['submittedBy'], residentUid);

  final renderingError = tester.takeException();
  expect(
    renderingError,
    isNull,
    reason: 'The real four-role complaint lifecycle produced a UI exception.',
  );

  await _endRoleSession(tester, auth);
}

Future<void> _exerciseMaintenancePaymentJourney({
  required WidgetTester tester,
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
}) async {
  const transactionReference = 'MF-INT-PAY-20261110-750';

  final colony = firestore.collection('colonies').doc(colonyId);
  final bills = colony.collection('maintenanceBills');
  final payments = colony.collection('maintenancePayments');
  final billReference = bills.doc('four-role-bill');

  // 1. Resident opens the real Maintenance bills screen.
  await _signInAndOpenRoleDashboard(
    tester: tester,
    auth: auth,
    role: RoleCase.resident,
  );

  final residentUid = auth.currentUser!.uid;
  final maintenanceTile = find.text('Maintenance bills');

  await _waitForCondition(
    tester,
    () => maintenanceTile.evaluate().isNotEmpty,
    'Resident dashboard did not expose the Maintenance bills tile.',
  );
  final maintenanceTileScrollable = find
      .ancestor(of: maintenanceTile, matching: find.byType(Scrollable))
      .first;
  await tester.dragUntilVisible(
    maintenanceTile,
    maintenanceTileScrollable,
    const Offset(0, -320),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(maintenanceTile);

  await _waitForCondition(
    tester,
    () => find.text('My Maintenance Bills').evaluate().isNotEmpty,
    'Resident could not open My Maintenance Bills.',
  );

  final billTitle = find.text('Integration maintenance bill');
  await _waitForCondition(
    tester,
    () => billTitle.evaluate().isNotEmpty,
    'Seeded maintenance bill was not displayed to its household resident.',
  );

  final startingBill = await billReference.get();
  expect(startingBill.exists, isTrue);
  expect(startingBill.data()?['totalAmount'], 2500);
  expect(startingBill.data()?['amountPaid'], 500);
  expect(startingBill.data()?['status'], 'partially_paid');

  final submitButton = find.widgetWithText(
    FilledButton,
    'Submit payment details',
  );

  await _waitForCondition(
    tester,
    () => submitButton.evaluate().isNotEmpty,
    'Resident bill did not expose Submit payment details.',
  );
  final submitButtonScrollable = find
      .ancestor(of: submitButton, matching: find.byType(Scrollable))
      .first;
  await tester.dragUntilVisible(
    submitButton,
    submitButtonScrollable,
    const Offset(0, -320),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(submitButton);

  final confirmButton = find.widgetWithText(
    FilledButton,
    'Submit for verification',
  );

  await _waitForCondition(
    tester,
    () => confirmButton.evaluate().isNotEmpty,
    'Payment submission dialog did not open.',
  );

  final amountField = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Amount paid (₹)',
  );
  final referenceField = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Transaction reference / UTR *',
  );

  expect(amountField, findsOneWidget);
  expect(referenceField, findsOneWidget);

  // Submit ₹750 of the ₹2,000 outstanding balance.
  await tester.enterText(amountField, '750');
  await tester.enterText(referenceField, transactionReference);
  await tester.tap(confirmButton);

  await _waitForCondition(
    tester,
    () => find
        .text('Payment submitted for Admin verification.')
        .evaluate()
        .isNotEmpty,
    'Resident did not receive the payment-submission confirmation.',
  );

  // Confirm the real client write.
  final residentPaymentSnapshot = await payments
      .where('submittedBy', isEqualTo: residentUid)
      .get();

  final matchingPayments = residentPaymentSnapshot.docs
      .where(
        (document) =>
            document.data()['transactionReference'] == transactionReference,
      )
      .toList(growable: false);

  expect(
    matchingPayments,
    hasLength(1),
    reason: 'Resident payment submission must create exactly one payment.',
  );

  final payment = matchingPayments.single;
  final paymentData = payment.data();

  expect(paymentData['billId'], 'four-role-bill');
  expect(paymentData['householdId'], householdId);
  expect(paymentData['residentId'], residentId);
  expect(paymentData['submittedBy'], residentUid);
  expect(paymentData['submittedByRole'], 'resident');
  expect(paymentData['paymentMethod'], 'upi');
  expect(paymentData['amount'], 750);
  expect(paymentData['status'], 'pending');
  expect(paymentData['createdAt'], isNotNull);

  // Submission alone must not change the bill balance.
  final billAfterSubmission = await billReference.get();
  expect(billAfterSubmission.data()?['amountPaid'], 500);
  expect(billAfterSubmission.data()?['status'], 'partially_paid');

  await _endRoleSession(tester, auth);

  // 2. Admin opens the real Maintenance Dues review screen.
  await _signInAndOpenRoleDashboard(
    tester: tester,
    auth: auth,
    role: RoleCase.admin,
  );

  final adminUid = auth.currentUser!.uid;
  final maintenanceModule = find.text('Maintenance Dues');

  await _waitForCondition(
    tester,
    () => maintenanceModule.evaluate().isNotEmpty,
    'Admin dashboard did not expose Maintenance Dues.',
  );
  final maintenanceModuleScrollable = find
      .ancestor(of: maintenanceModule, matching: find.byType(Scrollable))
      .first;
  await tester.dragUntilVisible(
    maintenanceModule,
    maintenanceModuleScrollable,
    const Offset(0, -320),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(maintenanceModule);

  final submissionsTab = find.text('Payment submissions');
  await _waitForCondition(
    tester,
    () => submissionsTab.evaluate().isNotEmpty,
    'Admin screen did not expose Payment submissions.',
  );
  await tester.tap(submissionsTab);

  final transactionReferenceText = find.textContaining(transactionReference);
  await _waitForCondition(
    tester,
    () => transactionReferenceText.evaluate().isNotEmpty,
    'Admin payment submissions did not display the resident transaction.',
  );

  final verifyButton = find.widgetWithText(FilledButton, 'Verify payment');
  await _waitForCondition(
    tester,
    () => verifyButton.evaluate().isNotEmpty,
    'Pending payment did not expose Verify payment to Admin.',
  );
  final verifyButtonScrollable = find
      .ancestor(of: verifyButton, matching: find.byType(Scrollable))
      .first;
  await tester.dragUntilVisible(
    verifyButton,
    verifyButtonScrollable,
    const Offset(0, -320),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(verifyButton);

  await _waitForCondition(
    tester,
    () => find.text('Payment verified.').evaluate().isNotEmpty,
    'Admin did not receive the payment-verification confirmation.',
  );

  // Confirm an Admin-role notification was created.
  final adminNotificationSnapshot = await colony
      .collection('notifications')
      .where('recipientKey', isEqualTo: 'role:admin')
      .get();

  expect(
    adminNotificationSnapshot.docs.any(
      (document) => document.data()['eventType'] == 'payment_submitted',
    ),
    isTrue,
    reason: 'Payment submission should notify the Admin role.',
  );

  // Verify payment approval and the corresponding bill update.
  final verifiedPayment = await payment.reference.get();
  final verifiedPaymentData = verifiedPayment.data()!;

  expect(verifiedPaymentData['status'], 'verified');
  expect(verifiedPaymentData['verifiedBy'], adminUid);
  expect(verifiedPaymentData['verifiedAt'], isNotNull);

  final billAfterVerification = await billReference.get();
  final updatedBill = billAfterVerification.data()!;

  expect(updatedBill['amountPaid'], 1250);
  expect(updatedBill['status'], 'partially_paid');
  expect(updatedBill['totalAmount'], 2500);

  await _endRoleSession(tester, auth);

  // 3. Resident returns and sees VERIFIED in payment history.
  await _signInAndOpenRoleDashboard(
    tester: tester,
    auth: auth,
    role: RoleCase.resident,
  );

  final returnMaintenanceTile = find.text('Maintenance bills');
  await _waitForCondition(
    tester,
    () => returnMaintenanceTile.evaluate().isNotEmpty,
    'Resident dashboard did not reload after Admin verification.',
  );
  final returnMaintenanceTileScrollable = find
      .ancestor(of: returnMaintenanceTile, matching: find.byType(Scrollable))
      .first;
  await tester.dragUntilVisible(
    returnMaintenanceTile,
    returnMaintenanceTileScrollable,
    const Offset(0, -320),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(returnMaintenanceTile);

  await _waitForCondition(
    tester,
    () => find.text('My Maintenance Bills').evaluate().isNotEmpty,
    'Resident could not reopen Maintenance Bills after verification.',
  );

  final verifiedStatus = find.text('VERIFIED');
  final pageScrollable = find.byType(Scrollable).last;

  for (
    var attempt = 0;
    attempt < 12 && verifiedStatus.evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(pageScrollable, const Offset(0, -320));
    await tester.pump(const Duration(milliseconds: 300));
  }

  await _waitForCondition(
    tester,
    () => verifiedStatus.evaluate().isNotEmpty,
    'Resident payment history did not display VERIFIED.',
  );
  expect(verifiedStatus, findsOneWidget);

  // Confirm the resident received the payment-verification event.
  final residentNotificationSnapshot = await colony
      .collection('notifications')
      .where('recipientKey', isEqualTo: 'user:$residentUid')
      .get();

  expect(
    residentNotificationSnapshot.docs.any(
      (document) => document.data()['eventType'] == 'payment_verified',
    ),
    isTrue,
    reason: 'Admin verification should notify the submitting resident.',
  );

  final finalRenderingError = tester.takeException();
  expect(
    finalRenderingError,
    isNull,
    reason: 'Maintenance payment lifecycle produced a UI exception.',
  );

  await _endRoleSession(tester, auth);
}

Future<void> _exerciseWorkerNotificationDeduplication({
  required WidgetTester tester,
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
}) async {
  final colony = firestore.collection('colonies').doc(colonyId);
  const notificationTitle = 'Worker assignment fan-out regression';
  const notificationIds = [
    'notification-dedupe-role',
    'notification-dedupe-user',
    'notification-dedupe-worker',
  ];

  await _signInAndOpenRoleDashboard(
    tester: tester,
    auth: auth,
    role: RoleCase.worker,
  );

  final workerUid = auth.currentUser!.uid;

  // Confirm the fixture contains exactly the three audience representations.
  final seededDocuments = await Future.wait(
    notificationIds.map(
      (id) => colony.collection('notifications').doc(id).get(),
    ),
  );

  expect(
    seededDocuments.every((document) => document.exists),
    isTrue,
    reason: 'All three notification copies must be seeded.',
  );

  expect(
    seededDocuments.map((document) => document.data()!['recipientKey']).toSet(),
    {'role:worker', 'user:$workerUid', 'worker:$workerId'},
  );

  final bell = find.byType(NotificationBell);

  await _waitForCondition(
    tester,
    () => bell.evaluate().length == 1,
    'Worker dashboard did not render exactly one notification bell.',
  );

  final unreadBadge = find.descendant(of: bell, matching: find.text('1'));

  await _waitForCondition(
    tester,
    () => unreadBadge.evaluate().length == 1,
    'Three recipient copies should produce one unread notification.',
  );

  expect(unreadBadge, findsOneWidget);

  final bellButton = find.descendant(
    of: bell,
    matching: find.byType(IconButton),
  );

  expect(bellButton, findsOneWidget);
  await tester.tap(bellButton);

  await _waitForCondition(
    tester,
    () => find.byType(NotificationCenterScreen).evaluate().length == 1,
    'Worker could not open the Notification Centre.',
  );

  final notificationCardTitle = find.text(notificationTitle);

  await _waitForCondition(
    tester,
    () => notificationCardTitle.evaluate().length == 1,
    'The three recipient copies were not grouped into one card.',
  );

  expect(notificationCardTitle, findsOneWidget);

  // Opening the single logical notification must mark every underlying
  // recipient-specific document as read.
  await tester.tap(notificationCardTitle);

  await _waitForCondition(
    tester,
    () => find.byType(AlertDialog).evaluate().length == 1,
    'Notification detail dialog did not open.',
  );

  final closeButton = find.widgetWithText(TextButton, 'Close');
  expect(closeButton, findsOneWidget);
  await tester.tap(closeButton);
  await tester.pump();

  final receiptReferences = notificationIds.map(
    (id) => colony
        .collection('members')
        .doc(workerUid)
        .collection('notificationReads')
        .doc(id),
  );

  final receipts = await Future.wait(
    receiptReferences.map((reference) => reference.get()),
  );

  expect(
    receipts.every((receipt) => receipt.exists),
    isTrue,
    reason: 'Opening one card must create read receipts for all three copies.',
  );

  // Return to the dashboard and verify that the unread badge disappears.
  final backButton = find.byType(BackButton);
  await _waitForCondition(
    tester,
    () => backButton.evaluate().isNotEmpty,
    'Notification Centre back button was not available.',
  );

  await tester.tap(backButton);

  await _waitForCondition(
    tester,
    () => find.byType(NotificationCenterScreen).evaluate().isEmpty,
    'Notification Centre did not close.',
  );

  await _waitForCondition(
    tester,
    () =>
        find.descendant(of: bell, matching: find.text('1')).evaluate().isEmpty,
    'Unread badge remained after all three notification copies were read.',
  );

  expect(find.descendant(of: bell, matching: find.text('1')), findsNothing);

  final renderingError = tester.takeException();
  expect(
    renderingError,
    isNull,
    reason: 'Notification deduplication flow produced a UI exception.',
  );

  await _endRoleSession(tester, auth);
}

Future<void> _signInAndOpenRoleDashboard({
  required WidgetTester tester,
  required FirebaseAuth auth,
  required RoleCase role,
}) async {
  final scenario = scenarios.singleWhere((item) => item.role == role);
  await auth.signOut();
  final credential = await auth.signInWithEmailAndPassword(
    email: scenario.email,
    password: password,
  );
  expect(credential.user, isNotNull);
  await tester.pumpWidget(const MohallaFlowApp());
  await _waitForDashboard(
    tester: tester,
    dashboard: find.byType(scenario.dashboardType),
    role: role,
  );
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _endRoleSession(WidgetTester tester, FirebaseAuth auth) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await auth.signOut();
  await tester.pump();
}

Future<void> _waitForCondition(
  WidgetTester tester,
  bool Function() condition,
  String failureReason,
) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail(failureReason);
}

Future<void> _verifyRoleData({
  required FirebaseFirestore firestore,
  required String uid,
  required RoleCase role,
}) async {
  final colony = firestore.collection('colonies').doc(colonyId);

  switch (role) {
    case RoleCase.admin:
      final residents = await colony.collection('residents').get();
      final complaints = await colony.collection('complaints').get();
      final tasks = await colony.collection('cleanlinessTasks').get();
      final jobs = await colony.collection('maintenanceJobs').get();

      expect(residents.docs, isNotEmpty);
      expect(complaints.docs, isNotEmpty);
      expect(tasks.docs, isNotEmpty);
      expect(jobs.docs, isNotEmpty);
      break;

    case RoleCase.resident:
      final resident = await colony
          .collection('residents')
          .doc(residentId)
          .get();

      final notices = await colony
          .collection('announcements')
          .where('status', isEqualTo: 'published')
          .get();

      final complaints = await colony
          .collection('complaints')
          .where('submittedBy', isEqualTo: uid)
          .get();

      final housekeeping = await colony
          .collection('housekeepingRequests')
          .where('requestedBy', isEqualTo: uid)
          .get();

      final bills = await colony
          .collection('maintenanceBills')
          .where('householdId', isEqualTo: householdId)
          .get();

      expect(resident.exists, isTrue);
      expect(notices.docs, isNotEmpty);
      expect(complaints.docs, isNotEmpty);
      expect(housekeeping.docs, isNotEmpty);
      expect(bills.docs, isNotEmpty);
      break;

    case RoleCase.cleanlinessManager:
      final workers = await colony
          .collection('cleanlinessWorkers')
          .orderBy('fullName')
          .get();

      final tasks = await colony
          .collection('cleanlinessTasks')
          .orderBy('createdAt', descending: true)
          .get();

      final complaints = await colony
          .collection('complaints')
          .where('complaintType', isEqualTo: 'cleanliness')
          .get();

      expect(workers.docs, isNotEmpty);
      expect(tasks.docs, isNotEmpty);
      expect(complaints.docs, isNotEmpty);
      break;

    case RoleCase.worker:
      final worker = await colony
          .collection('cleanlinessWorkers')
          .doc(workerId)
          .get();

      final tasks = await colony
          .collection('cleanlinessTasks')
          .where('assignedWorkerId', isEqualTo: workerId)
          .get();

      expect(worker.exists, isTrue);
      expect(tasks.docs, isNotEmpty);
      break;
  }
}

Future<void> _waitForDashboard({
  required WidgetTester tester,
  required Finder dashboard,
  required RoleCase role,
}) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));

    if (dashboard.evaluate().isNotEmpty) {
      return;
    }
  }

  fail(
    'The LoginScreen did not route the authenticated ${role.name} '
    'session to ${dashboard.toString()}.',
  );
}
