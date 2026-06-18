import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/session_manager.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _feedbackController = TextEditingController();
  bool _isSending = false;

  String _selectedTicketType = 'GENERAL FEEDBACK';
  final List<String> _ticketCategories = ['GENERAL FEEDBACK', 'HELP', 'URGENT ASSISTANCE'];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  bool get _isGeneralFeedback => _selectedTicketType == 'GENERAL FEEDBACK';

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PLEASE ENTER A VALID MESSAGE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.black),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('feedback').insert({
        'user_id': user?.id,
        'type': _selectedTicketType,
        'message': text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 SEND SUCCESSFULLY.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.black),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ SUPABASE FAULT: $e', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.black),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('FEEDBACK AND HELP', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CLOSPHERE SUPPORT SYSTEM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5, color: Colors.black)),
            const SizedBox(height: 30),

            const Text("CLASSIFICATION TYPE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black, letterSpacing: 1)),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              value: _selectedTicketType,
              decoration: const InputDecoration(filled: true, fillColor: Color(0xFFF9F9F9), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12)),
              items: _ticketCategories.map((String type) => DropdownMenuItem<String>(value: type, child: Text(type, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black)))).toList(),
              onChanged: (val) => setState(() => _selectedTicketType = val!),
            ),
            const SizedBox(height: 20),

            if (_isGeneralFeedback) ...[
              const Text("DESCRIPTION OF SERVICE ISSUE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black, letterSpacing: 1)),
              const SizedBox(height: 5),
              TextField(
                controller: _feedbackController,
                maxLines: 6,
                style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(filled: true, fillColor: Color(0xFFF9F9F9), border: InputBorder.none, contentPadding: EdgeInsets.all(15)),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: _isSending ? null : _submitFeedback,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  color: Colors.black,
                  child: Center(child: _isSending ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5)) : const Text('SEND', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2))),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: const Color(0xFFF9F9F9),
                child: const Column(
                  children: [
                    Text("MESSAGE COSTUMER SERVICE ON WHAT'S APP:", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black, letterSpacing: 1)),
                    SizedBox(height: 10),
                    Text("+968 9291 3880", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
                    SizedBox(height: 10),
                    Text("CLOSPHERE THANKS YOU.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black45)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}






