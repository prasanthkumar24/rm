import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import '../models/user_model.dart';
class OtpVerificationScreen extends StatefulWidget {
  final String mobileNumber;

  const OtpVerificationScreen({Key? key, required this.mobileNumber}) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _authService = AuthService();
  bool _isLoading = false;
  String? _error;
  
  // Timer related
  Timer? _timer;
  int _start = 300;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    setState(() {
      _start = 300;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _timer?.cancel();
          _canResend = true;
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  String _formatRemaining() {
    final minutes = (_start ~/ 60).toString().padLeft(2, '0');
    final seconds = (_start % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _handleResendOtp() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authService.sendOtp(widget.mobileNumber);
      if (mounted) {
        startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otpCode = _controllers.map((c) => c.text).join();
    if (otpCode.length != 6) {
      setState(() => _error = 'PLEASE ENTER A VALID 6-DIGIT OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _authService.verifyOtp(widget.mobileNumber, otpCode);
      
      if (mounted) {
        if (response['status'] == 'success') {
          // 1. Set the mobile authenticated flag permanently
          await _authService.setMobileAuthenticated();

          // 2. Save video server credentials so we can retry login if server is down
          final String jellyfinUsername = response['jellyfin_user_name'] ?? 'Appuser';
          final String jellyfinPassword = response['jellyfin_password'] ?? 'Smiles123\$';
          await _authService.saveVideoCredentials(jellyfinUsername, jellyfinPassword);

          // 3. Attempt to log in to the video server, but don't block navigation
          bool isServerAvailable = true;
          User? user;
          try {
            user = await _authService.login(
              'https://rmvideo.in',
              jellyfinUsername,
              jellyfinPassword,
            );
          } catch (e) {
            debugPrint('Video server login failed during OTP verification: $e');
            isServerAvailable = false;
            // Create a dummy user object to allow navigation to home screen
            user = await _authService.getSession(); // Get cached user if available
            if (user == null) {
              // If no cached user, create a temporary one to pass to home screen
              user = User(id: '', name: '', accessToken: '', serverUrl: 'https://rmvideo.in');
            }
          }
          
          // 4. Always navigate to home screen
          if (mounted && user != null) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  user: user!,
                  initialServerAvailable: isServerAvailable,
                ),
              ),
              (route) => false,
            );
          }
        } else {
          setState(() => _error = response['message'] ?? 'INVALID OTP. PLEASE TRY AGAIN.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 45,
      height: 55,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: RawKeyboardListener(
        focusNode: FocusNode(), // Dummy focus node for listener
        onKey: (event) {
          if (event is RawKeyDownEvent && 
              event.logicalKey == LogicalKeyboardKey.backspace && 
              _controllers[index].text.isEmpty && 
              index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: const Color(0xFF0E323E),
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF3B6DCC), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            }
            if (otpCodeFull) {
               _handleVerifyOtp();
            }
          },
        ),
      ),
    );
  }

  bool get otpCodeFull => _controllers.every((c) => c.text.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF002B38),
              Color(0xFF00151C),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.play_circle_fill, size: 80, color: Color(0xFF3B6DCC));
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                Text(
                  'Verify OTP',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to\n${widget.mobileNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF6B8CA0),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // OTP Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) => _buildOtpBox(index)),
                ),
                const SizedBox(height: 24),

                // Timer & Resend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _canResend ? "Didn't receive code? " : "Resend code in ",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF6B8CA0),
                      ),
                    ),
                    if (!_canResend)
                      Text(
                        _formatRemaining(),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3B6DCC),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _handleResendOtp,
                        child: Text(
                          'Resend OTP',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3B6DCC),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B6DCC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Verify & Login',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
