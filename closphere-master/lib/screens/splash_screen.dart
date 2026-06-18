import 'package:flutter/material.dart';
import 'dart:async';
import '../core/style_guide.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _logoOpacity = 0.0;
  double _sloganOpacity = 0.0;
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _runProfessionalSequence();
  }

  void _runProfessionalSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _logoOpacity = 1.0);

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _sloganOpacity = 1.0);

    _startLoadingBar();

    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  void _startLoadingBar() {
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_loadingProgress >= 1.0) {
        timer.cancel();
      } else if (mounted) {
        setState(() => _loadingProgress += 0.05);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosphereColors.black, // Now White
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  opacity: _logoOpacity,
                  duration: const Duration(milliseconds: 600),
                  child: const Text('CLOSPHERE', style: ClosphereText.logoStyle),
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: _sloganOpacity,
                  duration: const Duration(milliseconds: 600),
                  child: const Text('PIECES YOU CAN\'T HAVE. YET.', style: ClosphereText.sloganStyle),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 50,
            left: 50,
            right: 50,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _loadingProgress,
                  backgroundColor: Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                  minHeight: 1.5,
                ),
                const SizedBox(height: 10),
                const Text('INITIALIZING SYSTEM',
                    style: TextStyle(color: Colors.black26, fontSize: 8, letterSpacing: 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


