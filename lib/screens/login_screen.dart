import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colony_selection_screen.dart';

import '../theme/app_theme.dart';
import '../models/user_role.dart';
import '../services/user_access_service.dart';
import '../services/colony_dashboard_router.dart';
import '../widgets/app_text.dart';
import '../widgets/brand_logo.dart';
import '../l10n/app_translations.dart';
import '../l10n/app_locale_controller.dart';

import 'package:cloud_functions/cloud_functions.dart';

import '../services/resident_registration_activation_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _phoneFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _otpFormKey = GlobalKey<FormState>();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _otpController = TextEditingController();

  ConfirmationResult? _confirmationResult;
  String? _verificationId;
  int? _resendToken;

  User? _user;

  bool _isLoading = false;
  bool _isCodeSent = false;
  bool _firebaseReady = true;

  String? _errorMessage;
  String? _infoMessage;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  String get _fullPhoneNumber => '+91${_phoneController.text.trim()}';

  @override
  void initState() {
    super.initState();

    // This also allows the screen to render in widget tests
    // where Firebase has not been initialized.
    try {
      final User? existingUser = FirebaseAuth.instance.currentUser;
      _user = existingUser;

      if (existingUser != null) {
        _isLoading = true;
        _infoMessage = 'Restoring your secure session...';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleAuthenticatedUser(existingUser);
        });
      }
    } catch (error) {
      _firebaseReady = false;
      debugPrint('Firebase is not initialized: $error');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // SEND OTP
  // --------------------------------------------------

  Future<void> _sendOtp({bool resend = false}) async {
    if (!_firebaseReady) {
      setState(() {
        _errorMessage =
            'Firebase is not initialized. Please restart the application.';
      });
      return;
    }

    if (_phoneFormKey.currentState?.validate() != true) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      if (kIsWeb) {
        // WEB: Firebase uses reCAPTCHA automatically.

        final ConfirmationResult result = await _auth.signInWithPhoneNumber(
          _fullPhoneNumber,
        );

        if (!mounted) return;

        setState(() {
          _confirmationResult = result;
          _isCodeSent = true;
          _isLoading = false;
          _infoMessage =
              'Complete the security verification if prompted, '
              'then enter your verification code.';
        });
      } else {
        // ANDROID AND IOS: Native phone verification.

        await _auth.verifyPhoneNumber(
          phoneNumber: _fullPhoneNumber,
          timeout: const Duration(seconds: 60),
          forceResendingToken: resend ? _resendToken : null,

          verificationCompleted: (PhoneAuthCredential credential) async {
            await _signInWithCredential(credential);
          },

          verificationFailed: (FirebaseAuthException error) {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
              _errorMessage = _friendlyErrorMessage(error);
            });
          },

          codeSent: (String verificationId, int? resendToken) {
            if (!mounted) return;

            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isCodeSent = true;
              _isLoading = false;
              _errorMessage = null;
              _infoMessage = 'Verification code sent to $_fullPhoneNumber.';
            });
          },

          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to request verification. Please try again.';
      });

      debugPrint('OTP request error: $error');
    }
  }

  // --------------------------------------------------
  // VERIFY OTP
  // --------------------------------------------------

  Future<void> _verifyOtp() async {
    if (!_firebaseReady) {
      setState(() {
        _errorMessage = 'Firebase is not initialized.';
      });
      return;
    }

    if (_otpFormKey.currentState?.validate() != true) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final String code = _otpController.text.trim();

      if (kIsWeb) {
        // WEB: Confirm the Firebase phone session.

        final ConfirmationResult? confirmation = _confirmationResult;

        if (confirmation == null) {
          throw FirebaseAuthException(
            code: 'session-expired',
            message: AppTranslations.translate(
              'Please request a new verification code.',
            ),
          );
        }

        final UserCredential result = await confirmation.confirm(code);

        await _handleSuccessfulSignIn(result);
      } else {
        // ANDROID AND IOS: Create a phone credential.

        final String? verificationId = _verificationId;

        if (verificationId == null) {
          throw FirebaseAuthException(
            code: 'session-expired',
            message: AppTranslations.translate(
              'Please request a new verification code.',
            ),
          );
        }

        final PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        );

        final UserCredential result = await _auth.signInWithCredential(
          credential,
        );

        await _handleSuccessfulSignIn(result);
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Verification failed. Please check the code and try again.';
      });

      debugPrint('OTP verification error: $error');
    }
  }

  // --------------------------------------------------
  // AUTOMATIC NATIVE VERIFICATION
  // --------------------------------------------------

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      await _handleSuccessfulSignIn(result);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Automatic verification could not be completed.';
      });

      debugPrint('Automatic verification error: $error');
    }
  }

  // --------------------------------------------------
  // AUTHENTICATION SUCCESS
  // ------------------  // --------------------------------------------------
  // AUTHENTICATION SUCCESS AND ROLE-BASED ROUTING
  // --------------------------------------------------

  // --------------------------------------------------
  // AUTHENTICATION SUCCESS AND ROLE-BASED ROUTING
  // --------------------------------------------------

  Future<void> _handleSuccessfulSignIn(UserCredential result) {
    return _handleAuthenticatedUser(result.user);
  }

  // --------------------------------------------------
  // AUTHENTICATED USER ACCESS AND ROLE ROUTING
  // --------------------------------------------------

  Future<void> _handleAuthenticatedUser(User? authenticatedUser) async {
    if (!mounted) return;

    if (authenticatedUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to identify your authenticated account.';
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _user = authenticatedUser;
      _isLoading = true;
      _isCodeSent = false;
      _verificationId = null;
      _confirmationResult = null;
      _errorMessage = null;
      _infoMessage = 'Checking your colony access...';
      _otpController.clear();
    });

    try {
      // Reuse the same membership verification for:
      // 1. New OTP sign-ins.
      // 2. Automatically restored Firebase sessions.

      final accessService = UserAccessService();
      UserAccessResult access = await accessService.loadCurrentUserAccess();

      // A newly OTP-verified resident can claim only an Admin-created record
      // matching Firebase Auth's verified phone token claim.
      if (access.status == UserAccessStatus.userProfileMissing) {
        try {
          await ResidentRegistrationActivationService()
              .claimCurrentPhoneRegistration();
          access = await accessService.loadCurrentUserAccess();
        } on FirebaseFunctionsException catch (error) {
          if (!mounted) return;
          setState(() {
            _user = authenticatedUser;
            _isLoading = false;
            _errorMessage = _residentRegistrationErrorMessage(error);
            _infoMessage = null;
          });
          return;
        } on StateError catch (error) {
          if (!mounted) return;
          setState(() {
            _user = authenticatedUser;
            _isLoading = false;
            _errorMessage = error.message.toString();
            _infoMessage = null;
          });
          return;
        }
      }

      if (!mounted) return;

      debugPrint('ACCESS STATUS: ${access.status}');
      debugPrint('MEMBERSHIP COUNT: ${access.memberships.length}');

      if (!access.canAccessColony || access.memberships.isEmpty) {
        String message;

        switch (access.status) {
          case UserAccessStatus.unauthenticated:
            message = 'Your sign-in session could not be verified.';
            break;

          case UserAccessStatus.userProfileMissing:
            message =
                'Your phone is verified, but your MohallaFlow profile '
                'has not been registered.';
            break;

          case UserAccessStatus.noActiveMembership:
            message =
                'Your phone is verified, but you do not have an active '
                'colony membership.';
            break;

          case UserAccessStatus.multipleMemberships:
            message = 'No active colony membership could be selected.';
            break;

          case UserAccessStatus.unavailable:
            message =
                access.errorMessage ??
                'Firestore access is currently unavailable.';
            break;

          case UserAccessStatus.authorized:
            message = 'Unable to resolve your colony access.';
            break;
        }

        setState(() {
          _user = authenticatedUser;
          _isLoading = false;
          _errorMessage = message;
          _infoMessage = null;
        });

        return;
      }

      // Resolve the colony membership.

      late final ColonyMembership membership;

      if (access.memberships.length == 1) {
        membership = access.memberships.single;
      } else {
        final ColonyMembership? selectedMembership = await Navigator.of(context)
            .push<ColonyMembership>(
              MaterialPageRoute<ColonyMembership>(
                builder: (_) =>
                    ColonySelectionScreen(memberships: access.memberships),
              ),
            );

        if (!mounted) return;

        if (selectedMembership == null) {
          // ColonySelectionScreen signs out before returning null.
          final User? currentUser = FirebaseAuth.instance.currentUser;

          setState(() {
            _user = currentUser;
            _isLoading = false;
            _isCodeSent = false;
            _verificationId = null;
            _confirmationResult = null;
            _resendToken = null;
            _errorMessage = null;
            _infoMessage = null;
          });

          return;
        }

        membership = selectedMembership;
      }

      debugPrint('VERIFIED ROLE: ${membership.role.firestoreValue}');
      debugPrint('VERIFIED COLONY: ${membership.colonyName}');

      // Check required role-specific account links before routing.

      String? linkageError;

      switch (membership.role) {
        case UserRole.worker:
          if (membership.workerId == null ||
              membership.workerId!.trim().isEmpty) {
            linkageError =
                'Your Worker account is not linked to a registered '
                'cleanliness worker. Please contact your Colony Admin.';
          }
          break;

        case UserRole.resident:
          if (membership.residentId == null ||
              membership.residentId!.trim().isEmpty) {
            linkageError =
                'Your account is not linked to a registered resident '
                'profile. Please contact your Colony Admin.';
          }
          break;

        case UserRole.admin:
        case UserRole.cleanlinessManager:
          break;
      }

      if (linkageError != null) {
        setState(() {
          _user = authenticatedUser;
          _isLoading = false;
          _errorMessage = linkageError;
          _infoMessage = null;
        });
        return;
      }

      // Clear the loading state before transferring navigation.

      setState(() {
        _user = authenticatedUser;
        _isLoading = false;
        _errorMessage = null;
        _infoMessage = null;
      });

      // One central router now handles every role.
      // Colony switching already uses this same router.

      ColonyDashboardRouter.open(
        context: context,
        membership: membership,
        profileData: access.profileData,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;

      debugPrint('Colony access verification error: $error');
      debugPrintStack(stackTrace: stackTrace);

      setState(() {
        _user = FirebaseAuth.instance.currentUser;
        _isLoading = false;
        _errorMessage = 'Unable to verify colony access. Please try again.';
        _infoMessage = null;
      });
    }
  }

  // --------------------------------------------------
  // RESEND OTP
  // --------------------------------------------------

  Future<void> _resendOtp() async {
    _otpController.clear();
    await _sendOtp(resend: true);
  }

  // --------------------------------------------------
  // CHANGE PHONE NUMBER
  // --------------------------------------------------

  void _changePhoneNumber() {
    setState(() {
      _isCodeSent = false;
      _verificationId = null;
      _confirmationResult = null;
      _resendToken = null;
      _errorMessage = null;
      _infoMessage = null;
      _otpController.clear();
    });
  }

  // --------------------------------------------------
  // SIGN OUT
  // --------------------------------------------------

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _auth.signOut();

      if (!mounted) return;

      setState(() {
        _user = null;
        _isLoading = false;
        _isCodeSent = false;
        _verificationId = null;
        _confirmationResult = null;
        _resendToken = null;
        _otpController.clear();
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    }
  }

  // --------------------------------------------------
  // RESIDENT REGISTRATION LINKING ERRORS
  // --------------------------------------------------

  String _residentRegistrationErrorMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'failed-precondition':
        return 'Your verified phone is not registered for individual resident login. Ask your Colony Admin to add your personal login number.';
      case 'already-exists':
        return 'This phone number is already linked to another MohallaFlow account. Contact your Colony Admin.';
      case 'not-found':
        return 'The resident account-linking service or matching registration could not be found. Contact your Colony Admin.';
      case 'permission-denied':
        return 'Your existing colony membership is inactive. Contact your Colony Admin.';
      case 'resource-exhausted':
        return 'This resident number is assigned to multiple resident records in the same colony. Ask your Colony Admin to resolve the duplicate.';
      case 'unauthenticated':
        return 'Please verify your mobile number again before linking your resident account.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'The resident account-linking service is not deployed yet. Please contact your Colony Admin.';
      default:
        return 'Resident account linking could not be completed. Please contact your Colony Admin.';
    }
  }

  // --------------------------------------------------
  // FIREBASE ERROR MESSAGES
  // --------------------------------------------------

  String _friendlyErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid mobile number.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'quota-exceeded':
        return 'The SMS quota has been exceeded.';

      case 'operation-not-allowed':
        return 'Phone authentication is not enabled in Firebase.';

      case 'invalid-verification-code':
        return 'Incorrect verification code. Please try again.';

      case 'session-expired':
      case 'code-expired':
        return 'Your verification session has expired. Request a new code.';

      case 'captcha-check-failed':
        return 'Security verification failed. Please try again.';

      case 'network-request-failed':
        return 'Network error. Check your internet connection.';

      case 'unauthorized-domain':
        return 'This website domain is not authorised in Firebase.';

      case 'app-not-authorized':
        return 'This application is not authorised for Firebase authentication.';

      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  // --------------------------------------------------
  // MAIN SCREEN
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.watch(context);
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 60,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBrandHeader(),
                        const SizedBox(height: 34),
                        _buildLoginCard(),
                        const SizedBox(height: 24),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --------------------------------------------------
  // BRAND HEADER
  // --------------------------------------------------

  Widget _buildBrandHeader() {
    return Column(
      children: [
        const BrandLogo(width: 310, height: 69),
        const SizedBox(height: 6),
        const AppText(
          'YOUR COLONY. BETTER CONNECTED.',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppTheme.textGrey,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // LOGIN CARD
  // --------------------------------------------------

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(27),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderGrey),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navyBlue.withValues(alpha: 0.05),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _user != null
          ? _buildAuthenticatedContent()
          : _isCodeSent
          ? _buildOtpContent()
          : _buildPhoneContent(),
    );
  }

  // --------------------------------------------------
  // PHONE NUMBER SCREEN
  // --------------------------------------------------

  Widget _buildPhoneContent() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Welcome back',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 9),
          const AppText(
            'Sign in to access your colony services, '
            'complaints and important updates.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 29),
          const AppText(
            'Mobile number',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            decoration: InputDecoration(
              hintText: AppTranslations.translate('Enter your mobile number'),
              counterText: '',
              prefixIcon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  child: AppText(
                    '+91',
                    style: TextStyle(
                      color: AppTheme.navyBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              prefixIconConstraints: BoxConstraints(
                minWidth: 62,
                minHeight: 56,
              ),
              suffixIcon: Icon(
                Icons.phone_iphone_rounded,
                color: AppTheme.textGrey,
                size: 20,
              ),
            ),
            validator: (value) {
              final phone = value?.trim() ?? '';

              if (phone.isEmpty) {
                return AppTranslations.translate(
                  'Please enter your mobile number',
                );
              }

              if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
                return AppTranslations.translate(
                  'Please enter a valid 10-digit Indian mobile number',
                );
              }

              return null;
            },
          ),
          const SizedBox(height: 25),
          _buildPrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _sendOtp(),
          ),
          _buildStatusMessage(),
          const SizedBox(height: 23),
          const Row(
            children: [
              Expanded(child: Divider(color: AppTheme.borderGrey)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: AppText(
                  'SECURE COLONY ACCESS',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textGrey,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppTheme.borderGrey)),
            ],
          ),
          const SizedBox(height: 20),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 19,
                color: AppTheme.secondaryNavy,
              ),
              SizedBox(width: 10),
              Expanded(
                child: AppText(
                  'Access is available to authorised '
                  'colony residents and management staff.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppTheme.textGrey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // OTP VERIFICATION SCREEN
  // --------------------------------------------------

  Widget _buildOtpContent() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: _isLoading ? null : _changePhoneNumber,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.navyBlue,
            ),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          const SizedBox(height: 12),
          const AppText(
            'Verify your number',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          const AppText(
            'Enter the six-digit verification code for:',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            _fullPhoneNumber,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.navyBlue,
            ),
          ),
          const SizedBox(height: 28),
          const AppText(
            'Verification code',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: AppTheme.navyBlue,
            ),
            decoration: InputDecoration(
              hintText: AppTranslations.translate('------'),
              counterText: '',
            ),
            validator: (value) {
              final code = value?.trim() ?? '';

              if (code.isEmpty) {
                return AppTranslations.translate(
                  'Please enter the verification code',
                );
              }

              if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
                return AppTranslations.translate(
                  'Please enter a valid six-digit code',
                );
              }

              return null;
            },
          ),
          const SizedBox(height: 25),
          _buildPrimaryButton(
            label: 'Verify & Continue',
            icon: Icons.verified_rounded,
            onPressed: _verifyOtp,
          ),
          _buildStatusMessage(),
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : _resendOtp,
              child: const AppText(
                'Resend verification code',
                style: TextStyle(
                  color: AppTheme.navyBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : _changePhoneNumber,
              child: const AppText(
                'Change mobile number',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // AUTHENTICATED SCREEN
  // --------------------------------------------------

  Widget _buildAuthenticatedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF23804A),
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Center(
          child: AppText(
            'Phone number verified',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: AppText(
            _user?.phoneNumber ?? _fullPhoneNumber,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.navyBlue,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppTheme.lightGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const AppText(
            'Your phone number has been authenticated. '
            'Your colony membership and user role must still '
            'be checked before dashboard access is granted.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppTheme.textGrey,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const AppText(
              'Sign out',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
        _buildStatusMessage(),
      ],
    );
  }

  // --------------------------------------------------
  // REUSABLE PRIMARY BUTTON
  // --------------------------------------------------

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppText(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(icon, size: 19),
                ],
              ),
      ),
    );
  }

  // --------------------------------------------------
  // ERROR AND INFORMATION MESSAGES
  // --------------------------------------------------

  Widget _buildStatusMessage() {
    if (_errorMessage == null && _infoMessage == null) {
      return const SizedBox.shrink();
    }

    final bool isError = _errorMessage != null;
    final String message = _errorMessage ?? _infoMessage!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEEEE) : const Color(0xFFEFF4FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: isError ? Colors.red.shade700 : AppTheme.secondaryNavy,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: AppText(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isError ? Colors.red.shade800 : AppTheme.secondaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // FOOTER
  // --------------------------------------------------

  Widget _buildFooter() {
    return const Column(
      children: [
        AppText(
          'New to your colony app?',
          style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
        ),
        SizedBox(height: 5),
        AppText(
          'Contact your colony administrator for access.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.navyBlue,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 20),
        AppText(
          'MOHALLAFLOW  •  COMMUNITY MANAGEMENT',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1,
            color: AppTheme.textGrey,
          ),
        ),
      ],
    );
  }
}
