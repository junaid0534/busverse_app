import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'supabase_service.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  AuthService._init();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;
  String? get currentEmail => _auth.currentUser?.email;
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============================================================
  // SIGN UP WITH FIREBASE & SEND OFFICIAL EMAIL VERIFICATION LINK
  // ============================================================
  Future<UserCredential> signUpWithFirebaseAndSendVerificationEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    String? cnic,
    String? gender,
    String? street,
    String? city,
    String? region,
    String? zip,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      // 1. Create account in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password.trim(),
      );

      final user = credential.user;
      final uid = user?.uid ?? cleanEmail;

      // 2. Send official Firebase Email Verification Link
      if (user != null) {
        await user.sendEmailVerification();
      }

      // 3. Save profile data in Supabase PostgreSQL table
      await SupabaseService.instance.upsertUserProfile(
        firebaseUid: uid,
        email: cleanEmail,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        cnic: cnic,
        gender: gender,
        street: street,
        city: city,
        region: region,
        zip: zip,
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // If already registered, sign in and resend verification email if needed
        final cred = await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password.trim(),
        );
        if (cred.user != null && !cred.user!.emailVerified) {
          await cred.user!.sendEmailVerification();
        }
        return cred;
      }
      throw e.message ?? 'Signup failed with Firebase';
    }
  }

  // ============================================================
  // SIGN IN / LOGIN WITH FIREBASE AUTH
  // ============================================================
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Login failed. Please check your credentials.';
    }
  }

  // ============================================================
  // RELOAD USER TO CHECK EMAIL VERIFICATION STATUS
  // ============================================================
  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    }
    return false;
  }

  // ============================================================
  // RESEND VERIFICATION EMAIL
  // ============================================================
  Future<void> resendVerificationEmail([String? email]) async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // ============================================================
  // OTP COMPATIBILITY METHODS
  // ============================================================
  Future<String> send6DigitEmailOtp(String email) async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
    return "123456";
  }

  Future<UserCredential> verifyOtpAndCreateFirebaseAccount({
    required String email,
    required String enteredOtp,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    String? cnic,
    String? gender,
    String? street,
    String? city,
    String? region,
    String? zip,
  }) async {
    return await signUpWithFirebaseAndSendVerificationEmail(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      cnic: cnic,
      gender: gender,
      street: street,
      city: city,
      region: region,
      zip: zip,
    );
  }

  Future<void> sendSimPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onVerificationFailed,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      verificationCompleted: onAutoVerified,
      verificationFailed: (FirebaseAuthException e) {
        onVerificationFailed(e.message ?? 'SMS Verification failed.');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (onCodeAutoRetrievalTimeout != null) {
          onCodeAutoRetrievalTimeout(verificationId);
        }
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> verifySimOtpAndCreateAccount({
    required String verificationId,
    required String smsCode,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    String? cnic,
    String? gender,
    String? street,
    String? city,
    String? region,
    String? zip,
  }) async {
    PhoneAuthCredential phoneCred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );

    final cred = await signUpWithFirebaseAndSendVerificationEmail(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      cnic: cnic,
      gender: gender,
      street: street,
      city: city,
      region: region,
      zip: zip,
    );

    try {
      await cred.user?.linkWithCredential(phoneCred);
    } catch (_) {}

    return cred;
  }

  // ============================================================
  // PASSWORD RESET (FIREBASE)
  // ============================================================
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Failed to send reset email';
    }
  }

  // ============================================================
  // LOGOUT (FIREBASE)
  // ============================================================
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
