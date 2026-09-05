import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _busController;
  late Animation<double> _busSlide;
  late Animation<double> _busFloat;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();

    // 1. Entrance slide animation
    _busController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _busSlide = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(parent: _busController, curve: Curves.easeOutCubic),
    );

    // 2. Continuous floating animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _busFloat = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _busController.forward();
  }

  @override
  void dispose() {
    _busController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ================= TOP POP-OUT HERO CARD =================
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Vibrant Gradient Background Card
                      Container(
                        width: double.infinity,
                        height: size.height * 0.44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1E3C72), // Deep Royal Navy
                              Color(0xFF2A5298), // Rich Cobalt
                              Color(0xFF388AF6), // Vibrant Dodger Blue
                              Color(0xFF00D2FF), // Glowing Cyan
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF388AF6).withOpacity(0.35),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Ambient decorative stars & moon icon
                            Positioned(
                              top: 25,
                              left: 25,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.nightlight_round,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),

                            // Small twinkling stars
                            Positioned(
                              top: 40,
                              left: 80,
                              child: Icon(Icons.star, color: Colors.white.withOpacity(0.8), size: 10),
                            ),
                            Positioned(
                              top: 20,
                              right: 70,
                              child: Icon(Icons.star, color: Colors.white.withOpacity(0.6), size: 14),
                            ),
                            Positioned(
                              top: 60,
                              right: 40,
                              child: Icon(Icons.star, color: Colors.white.withOpacity(0.7), size: 8),
                            ),

                            // Glowing speed winds swirl
                            Positioned(
                              bottom: 30,
                              left: 20,
                              right: 20,
                              child: Container(
                                height: 35,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.0),
                                      Colors.white.withOpacity(0.25),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3D Pop-Out Overlapping Bus
                      Positioned(
                        bottom: -30,
                        left: 10,
                        right: -15, // Overlaps the edge for 3D depth
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_busController, _floatController]),
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                _busSlide.value + _busFloat.value,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.35),
                                      blurRadius: 28,
                                      spreadRadius: -4,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  "assets/images/bus_welcome.png",
                                  height: size.height * 0.28,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 45),

                  // ================= TEXT SECTION =================
                  Column(
                    children: [
                      const Text(
                        "Your Journey Made",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B), // Dark Slate
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Smart & Memorable",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF388AF6), // Vibrant Blue Accent
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "Book luxury bus tickets, track live buses, and manage your cargo seamlessly with Junaid Movers.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // ================= ACTION BUTTONS =================
                  Column(
                    children: [
                      // Gradient Glow "Get Started" Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF388AF6), // Dodger Blue
                              Color(0xFF00B4DB), // Electric Cyan
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF388AF6).withOpacity(0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, "/signup");
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Get Started",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Secondary Sign In Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, "/login");
                            },
                            child: const Text(
                              "Sign In",
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF388AF6),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
