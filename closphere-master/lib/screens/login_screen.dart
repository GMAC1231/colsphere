import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/style_guide.dart';
import '../core/session_manager.dart';
import 'discovery_feed.dart';
import 'ghala_management.dart'; // Imported to allow immediate administrative routing splits

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Enum to handle clear toggling states within our entry workspace view
  int viewMode = 0; // 0 = Login, 1 = Register, 2 = Reset Password
  bool _isLoading = false;

  // Input Controllers to capture text variables
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _oldPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _oldPasswordController.dispose();
    super.dispose();
  }

  // --- PASSWORD UPDATE UTILITY PIPELINE ---
  Future<void> handlePasswordChange() async {
    final email = _emailController.text.trim();
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _passwordController.text.trim();

    if (email.isEmpty || oldPassword.isEmpty || newPassword.isEmpty) {
      _showFeedbackSnackBar("Please completely fill out the change request form.");
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signInWithPassword(email: email, password: oldPassword);
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      await supabase.auth.signOut();

      SessionManager().destroyActiveSession();
      _showFeedbackSnackBar("🎉 Password updated successfully. Sign in with your new keys.");
      setState(() {
        viewMode = 0;
        _oldPasswordController.clear();
        _passwordController.clear();
      });
    } on AuthException catch (e) {
      _showFeedbackSnackBar(e.message);
    } catch (e) {
      _showFeedbackSnackBar("Supabase password update failed: $e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // --- THE CORE SUPABASE AUTH PIPELINE ---
  Future<void> handleAuthentication() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (viewMode == 1 && name.isEmpty)) {
      _showFeedbackSnackBar("Please completely fill out the form requirements.");
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final supabase = Supabase.instance.client;
      User? user;

      if (viewMode == 0) {
        final authResponse = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        user = authResponse.user;
      } else {
        final authResponse = await supabase.auth.signUp(
          email: email,
          password: password,
        );
        user = authResponse.user;

        if (user != null) {
          await supabase.from('profiles').upsert({
            'id': user.id,
            'name': name,
            'email': email,
            'role': email.toLowerCase() == 'omar@closphere.com' ? 'admin' : 'user',
          });
        }
      }

      if (user == null) {
        _showFeedbackSnackBar("Authentication failed. Check email confirmation settings.");
        return;
      }

      final profileRows = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .limit(1);

      Map<String, dynamic> profile;
      if (profileRows is List && profileRows.isNotEmpty) {
        profile = Map<String, dynamic>.from(profileRows.first);
      } else {
        profile = {
          'id': user.id,
          'name': name.isNotEmpty ? name : 'CLOSPHERE MEMBER',
          'email': email,
          'role': email.toLowerCase() == 'omar@closphere.com' ? 'admin' : 'user',
        };
        await supabase.from('profiles').upsert(profile);
      }

      SessionManager().saveSession({
        'id': user.id,
        'name': profile['name'] ?? 'CLOSPHERE MEMBER',
        'email': profile['email'] ?? email,
        'role': profile['role'] ?? 'user',
        'isGhalaAdmin': (profile['role'] ?? '').toString().toLowerCase() == 'admin',
      });

      _showFeedbackSnackBar(viewMode == 0 ? "Welcome back to Closphere!" : "🎉 Account Registered Successfully!");

      if (mounted) {
        if (SessionManager().isGhalaAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GhalaManagement()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DiscoveryFeed()),
          );
        }
      }
    } on AuthException catch (e) {
      _showFeedbackSnackBar(e.message);
    } catch (e) {
      _showFeedbackSnackBar("Supabase authentication failed: $e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _showFeedbackSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 80),

              // --- LOGO & MOTTO ---
              const Text('CLOSPHERE', style: ClosphereText.logoStyle),
              const SizedBox(height: 10),
              const Text('PIECES YOU CAN\'T HAVE. YET.', style: ClosphereText.sloganStyle),

              const SizedBox(height: 80),

              // --- HEADER ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  viewMode == 0 ? 'LOG IN' : (viewMode == 1 ? 'CREATE ACCOUNT' : 'RESET SECURITY KEYS'),
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // --- INPUTS GRID COMPOSER ---
              if (viewMode == 1) ...[
                _buildModernTextField(
                    label: 'FULL NAME',
                    hint: 'John Doe',
                    prefixIcon: Icons.person_outline,
                    controller: _nameController
                ),
                const SizedBox(height: 25),
              ],

              _buildModernTextField(
                  label: 'EMAIL',
                  hint: 'name@identity.com',
                  prefixIcon: Icons.alternate_email,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress
              ),
              const SizedBox(height: 25),

              if (viewMode == 2) ...[
                _buildModernTextField(
                    label: 'CURRENT PASSWORD',
                    hint: '••••••••',
                    isObscure: true,
                    prefixIcon: Icons.lock_open_outlined,
                    controller: _oldPasswordController
                ),
                const SizedBox(height: 25),
              ],

              _buildModernTextField(
                  label: viewMode == 2 ? 'NEW CHOSEN PASSWORD' : 'PASSWORD',
                  hint: '••••••••',
                  isObscure: true,
                  prefixIcon: Icons.lock_outline,
                  controller: _passwordController
              ),

              const SizedBox(height: 40),

              // --- MAIN ACTION BUTTON ---
              GestureDetector(
                onTap: _isLoading
                    ? null
                    : (viewMode == 2 ? handlePasswordChange : handleAuthentication),
                child: _buildModernButton(
                    text: viewMode == 0 ? 'CONTINUE' : (viewMode == 1 ? 'JOIN THE SYSTEM' : 'UPDATE PASSWORD KEYS'),
                    color: Colors.black,
                    textColor: Colors.white,
                    showLoading: _isLoading
                ),
              ),

              const SizedBox(height: 20),

              // --- VIEW STATE LINK TOGGLES LIST ---
              Column(
                children: [
                  if (viewMode != 0)
                    TextButton(
                      onPressed: _isLoading ? null : () => setState(() => viewMode = 0),
                      child: const Text("RETURN TO ACCOUNT SIGN IN",
                        style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                    ),
                  if (viewMode != 1)
                    TextButton(
                      onPressed: _isLoading ? null : () => setState(() => viewMode = 1),
                      child: const Text("NEW TO CLOSPHERE? JOIN SYSTEM",
                        style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                    ),
                  if (viewMode != 2)
                    TextButton(
                      onPressed: _isLoading ? null : () => setState(() => viewMode = 2),
                      child: const Text("FORGOT OR WANT TO CHANGE PASSWORD?",
                        style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 40),

              // --- TERMS & PRIVACY ---
              const Opacity(
                opacity: 0.4,
                child: Text(
                  'By entering, you are agreeing to our\nTerms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black, fontSize: 9, height: 1.4, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required TextEditingController controller,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black45, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
        TextField(
          controller: controller,
          obscureText: isObscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.black, fontSize: 15),
          cursorColor: Colors.black,
          decoration: InputDecoration(
            prefixIcon: Icon(prefixIcon, color: Colors.black26, size: 16),
            prefixIconConstraints: const BoxConstraints(minWidth: 30),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black12, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildModernButton({
    required String text,
    required Color color,
    required Color textColor,
    bool showLoading = false
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: showLoading
          ? const Center(child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          : Center(
        child: Text(
          text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2),
        ),
      ),
    );
  }
}


