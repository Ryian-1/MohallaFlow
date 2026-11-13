import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Claims only an Admin-created resident registration matching the verified
/// Firebase Phone Auth number. No resident ID or phone is supplied by the client.
class ResidentRegistrationActivationService {
  ResidentRegistrationActivationService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1'),
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  static String? normalizeIndianMobileNumber(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(digits)) return null;
    return digits;
  }

  static String? toIndianE164(String input) {
    final digits = normalizeIndianMobileNumber(input);
    return digits == null ? null : '+91$digits';
  }

  Future<Map<String, dynamic>> claimCurrentPhoneRegistration() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('A verified Firebase sign-in is required.');
    }
    final verifiedPhone = user.phoneNumber;
    if (verifiedPhone == null || toIndianE164(verifiedPhone) == null) {
      throw StateError(
        'The signed-in account has no verified Indian mobile number.',
      );
    }

    final callable = _functions.httpsCallable(
      'claimResidentRegistration',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call<dynamic>();
    if (result.data is Map) {
      return Map<String, dynamic>.from(result.data as Map);
    }
    return <String, dynamic>{};
  }
}
