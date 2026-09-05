import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bus_ticket_system/services/auth_service.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/database/user_model.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String phone;
  final String cnic;
  final String gender;
  final String? previewOtp;
  final String? verificationId; // Firebase Phone Verification ID

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.cnic,
    required this.gender,
    this.previewOtp,
    this.verificationId,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isVerifying = false;
  int _timerSeconds = 60;
  Timer? _timer;
  late String? _activeVerificationId;

  @override
  void initState() {
    super.initState();
    _activeVerificationId = widget.verificationId;
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _timerSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _controllers.map((c) => c.text.trim()).join();

  Future<void> _verifyOtp() async {
    final otp = _enteredOtp;
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter complete 6-digit OTP"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      if (_activeVerificationId != null && _activeVerificationId!.isNotEmpty) {
        // 1. Verify Real SIM SMS OTP & Create Firebase Account
        await AuthService.instance.verifySimOtpAndCreateAccount(
          verificationId: _activeVerificationId!,
          smsCode: otp,
          email: widget.email,
          password: widget.password,
          firstName: widget.firstName,
          lastName: widget.lastName,
          phone: widget.phone,
          cnic: widget.cnic,
          gender: widget.gender,
        );
      } else {
        // Fallback OTP verification
        await AuthService.instance.verifyOtpAndCreateFirebaseAccount(
          email: widget.email,
          enteredOtp: otp,
          password: widget.password,
          firstName: widget.firstName,
          lastName: widget.lastName,
          phone: widget.phone,
          cnic: widget.cnic,
          gender: widget.gender,
        );
      }

      // 2. Offline SQLite Sync
      UserModel user = UserModel(
        firstName: widget.firstName,
        lastName: widget.lastName,
        email: widget.email.toLowerCase(),
        phone: widget.phone,
        cnic: widget.cnic,
        gender: widget.gender,
        password: widget.password,
      );
      await DBHelper.instance.registerUser(user);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account Verified & Created with Firebase!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/welcome_login',
        (route) => false,
        arguments: {'userEmail': widget.email},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_timerSeconds > 0) return;
    try {
      if (_activeVerificationId != null) {
        // Resend real SIM SMS OTP via Firebase
        await AuthService.instance.sendSimPhoneOtp(
          phoneNumber: widget.phone,
          onCodeSent: (newVerId) {
            setState(() {
              _activeVerificationId = newVerId;
            });
            _startCountdown();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("New 6-digit SMS OTP sent to your phone!"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          onVerificationFailed: (err) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err), backgroundColor: Colors.red),
              );
            }
          },
          onAutoVerified: (cred) {
            // Auto verified
          },
        );
      } else {
        await AuthService.instance.send6DigitEmailOtp(widget.email);
        _startCountdown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("New 6-digit OTP sent!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF018A30),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "OTP Verification",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                _activeVerificationId != null ? Icons.sms_outlined : Icons.mark_email_read_outlined,
                size: 80,
                color: const Color(0xFF018A30),
              ),
              const SizedBox(height: 20),
              Text(
                _activeVerificationId != null ? "Verify Phone (SIM SMS)" : "Verify Your Email",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3C72),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _activeVerificationId != null
                    ? "We have sent a 6-digit SMS OTP to your phone:\n${widget.phone}"
                    : "We have sent a 6-digit verification code to:\n${widget.email}",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 35),

              // 6 OTP DIGIT BOXES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    height: 55,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF018A30),
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF018A30),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (index == 5 && value.isNotEmpty) {
                          _verifyOtp();
                        }
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 35),

              // VERIFY BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF018A30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _isVerifying ? null : _verifyOtp,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "Verify & Create Account",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              // RESEND OTP SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  GestureDetector(
                    onTap: _timerSeconds == 0 ? _resendOtp : null,
                    child: Text(
                      _timerSeconds > 0
                          ? "Resend in ${_timerSeconds}s"
                          : "Resend Code",
                      style: TextStyle(
                        color: _timerSeconds == 0
                            ? const Color(0xFF018A30)
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
