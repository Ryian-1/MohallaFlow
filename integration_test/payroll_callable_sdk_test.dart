import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mohalla_flow/firebase_options.dart';

const projectId = 'demo-mohallaflow';
const colonyId = 'payroll_flutter_sdk_integration';

const adminEmail = 'payroll-flutter-admin@example.test';
const workerEmail = 'payroll-flutter-worker@example.test';
const password = 'MohallaFlow-Emulator-2026!';

Future<void> expectCallableCode(
  Future<dynamic> Function() action,
  String expectedCode,
) async {
  try {
    await action();
    fail('Expected callable error: $expectedCode');
  } on FirebaseFunctionsException catch (error) {
    expect(
      error.code,
      expectedCode,
      reason: 'Unexpected callable error: ${error.message}',
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Flutter Firebase SDK enforces authoritative payroll approval', (
    tester,
  ) async {
    final base = DefaultFirebaseOptions.currentPlatform;

    final options = FirebaseOptions(
      apiKey: base.apiKey,
      appId: base.appId,
      messagingSenderId: base.messagingSenderId,
      projectId: projectId,
      authDomain: base.authDomain,
      storageBucket: base.storageBucket,
    );

    final app = await Firebase.initializeApp(
      name: 'payroll-sdk-integration',
      options: options,
    );

    expect(
      app.options.projectId,
      projectId,
      reason: 'Integration test must use demo-mohallaflow, not production.',
    );

    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);
    final functions = FirebaseFunctions.instanceFor(
      app: app,
      region: 'asia-south1',
    );

    // iOS Simulator / local runs use loopback. Android Emulator CI passes
    // FIREBASE_EMULATOR_HOST=10.0.2.2 to reach the host runner.
    const emulatorHost = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    );

    await auth.useAuthEmulator(emulatorHost, 9099);

    firestore.useFirestoreEmulator(emulatorHost, 8080);
    firestore.settings = const Settings(persistenceEnabled: false);

    functions.useFunctionsEmulator(emulatorHost, 5001);

    final callable = functions.httpsCallable('approveColonyPayrollRun');

    final adminRequest = <String, dynamic>{
      'colonyId': colonyId,
      'runId': '2026-11',
    };

    final workerRequest = <String, dynamic>{
      'colonyId': colonyId,
      'runId': '2026-12',
    };

    await auth.signOut();

    await expectCallableCode(
      () => callable.call(adminRequest),
      'unauthenticated',
    );

    final workerCredential = await auth.signInWithEmailAndPassword(
      email: workerEmail,
      password: password,
    );

    expect(workerCredential.user, isNotNull);

    await expectCallableCode(
      () => callable.call(workerRequest),
      'permission-denied',
    );

    await auth.signOut();

    final adminCredential = await auth.signInWithEmailAndPassword(
      email: adminEmail,
      password: password,
    );

    expect(adminCredential.user, isNotNull);

    final approval = await callable.call(adminRequest);
    final result = Map<String, dynamic>.from(approval.data as Map);

    expect(result['status'], 'approved');
    expect(result['staffCount'], 1);
    expect(result['grossTotal'], 33400);
    expect(result['deductionTotal'], 1500);
    expect(result['netTotal'], 31900);

    final runRef = firestore.doc(
      'colonies/$colonyId/colonyPayrollRuns/2026-11',
    );

    final run = (await runRef.get()).data()!;

    expect(run['status'], 'approved');
    expect(run['approvedBy'], adminCredential.user!.uid);
    expect(run['approvedByName'], 'Flutter SDK Integration Admin');
    expect(run['grossTotal'], 33400);
    expect(run['deductionTotal'], 1500);
    expect(run['netTotal'], 31900);
    expect(run['balanceTotal'], 31900);

    final entryRef = runRef.collection('entries').doc('staff-2026-11');

    final entry = (await entryRef.get()).data()!;

    expect(entry['status'], 'approved');
    expect(entry['basePay'], 28000);
    expect(entry['overtimePay'], 400);
    expect(entry['grossPay'], 33400);
    expect(entry['totalDeductions'], 1500);
    expect(entry['netPay'], 31900);
    expect(entry['balance'], 31900);

    final workerRun = await firestore
        .doc('colonies/$colonyId/colonyPayrollRuns/2026-12')
        .get();

    expect(workerRun.data()!['status'], 'draft');

    await expectCallableCode(
      () => callable.call(adminRequest),
      'failed-precondition',
    );

    await auth.signOut();
  });
}
