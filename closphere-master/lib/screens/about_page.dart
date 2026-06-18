import 'package:flutter/material.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _ceoName = "OMAR ABDIGANI ALI";
  String _companyDivision = "CLOSPHERE GLOBAL";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSystemMetadata();
  }

  Future<void> _fetchSystemMetadata() async {
    // No backend needed. Static company metadata is used here.
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
            'ABOUT CLOSPHERE',
            style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'THE VISION',
                style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)
            ),
            const SizedBox(height: 15),

            const Text(
              'CLOSPHERE IS A HIGH-END ARCHIVAL RENTAL PLATFORM DESIGNED TO EXTEND THE LIFECYCLE OF ICONIC GARMENTS.\n\nWE BELIEVE IN CIRCULAR FASHION—WHERE LUXURY IS ACCESSIBLE, AND STYLE IS SUSTAINABLE. BY CURATING THE WORLD\'S RAREST PIECES, WE ENABLE A NEW GENERATION OF ARCHIVISTS TO WEAR HISTORY WITHOUT THE FOOTPRINT.',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.8,
                  color: Colors.black,
                  letterSpacing: 0.5
              ),
            ),

            const SizedBox(height: 40),
            const Divider(color: Colors.black, thickness: 1.5),
            const SizedBox(height: 25),

            const Text(
                'FOUNDER & CEO',
                style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)
            ),
            const SizedBox(height: 10),

            Text(
                _ceoName.toUpperCase(),
                style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)
            ),

            const SizedBox(height: 4),
            Text(
                _companyDivision.toUpperCase(),
                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)
            ),
          ],
        ),
      ),
    );
  }
}



