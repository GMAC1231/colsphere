import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedMode = 'RENT';
  String _selectedCondition = 'BRAND NEW';
  bool _isPublishing = false;

  Future<void> _publishProductToDatabase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isPublishing = true);

    String finalPrice = _priceController.text.trim();
    if (!finalPrice.toUpperCase().contains('OMR')) {
      finalPrice = "$finalPrice OMR";
    }

    final Map<String, dynamic> productData = {
      'name': _nameController.text.trim().toUpperCase(),
      'price_omr': finalPrice,
      'mode': _selectedMode,
      'condition': _selectedCondition.toUpperCase(),
      'status': 'AVAILABLE',
      'image_url': _imageUrlController.text.trim(),
      'description': _descriptionController.text.trim(),
    };

    try {
      await Supabase.instance.client.from('products').insert(productData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ASSET SAVED TO SUPABASE SUCCESSFULLY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.white)),
            backgroundColor: Colors.black,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('SUPABASE ERROR: $e', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.white)),
              backgroundColor: Colors.black
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  InputDecoration _buildPremiumInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 1.5),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 3.0),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 1.5),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 3.0),
      ),
      errorStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('PUBLISH NEW ASSET', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PRODUCT NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black)),
              const SizedBox(height: 5),
              TextFormField(
                controller: _nameController,
                cursorColor: Colors.black,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black, letterSpacing: 0.5),
                decoration: _buildPremiumInputDecoration('E.G., PRADA RE-NYLON JACKET'),
                validator: (val) => val!.isEmpty ? 'FIELD REQUIRED' : null,
              ),
              const SizedBox(height: 35),

              const Text('PRICE VALUE (OMR)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black)),
              const SizedBox(height: 5),
              TextFormField(
                controller: _priceController,
                cursorColor: Colors.black,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black, letterSpacing: 0.5),
                decoration: _buildPremiumInputDecoration('E.G., 12.500'),
                validator: (val) => val!.isEmpty ? 'FIELD REQUIRED' : null,
              ),
              const SizedBox(height: 35),

              const Text('IMAGE FILE URL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black)),
              const SizedBox(height: 5),
              TextFormField(
                controller: _imageUrlController,
                cursorColor: Colors.black,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.2),
                decoration: _buildPremiumInputDecoration('PASTE DIRECT ASSET IMAGE NAME HERE'),
                validator: (val) => val!.isEmpty ? 'FIELD REQUIRED' : null,
              ),
              const SizedBox(height: 35),

              const Text('PRODUCT DESCRIPTIVE METADATA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black)),
              const SizedBox(height: 5),
              TextFormField(
                controller: _descriptionController,
                cursorColor: Colors.black,
                maxLines: 3,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black, height: 1.5, letterSpacing: 0.2),
                decoration: _buildPremiumInputDecoration('ENTER FABRIC SPECIFICATIONS, MEASUREMENTS, AND FIT DETAILS...'),
                validator: (val) => val!.isEmpty ? 'FIELD REQUIRED' : null,
              ),
              const SizedBox(height: 40),

              const Text('TRANSACTION SELECTION MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('RENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.black)),
                      value: 'RENT', groupValue: _selectedMode, activeColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _selectedMode = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('BUY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.black)),
                      value: 'BUY', groupValue: _selectedMode, activeColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _selectedMode = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              const Text('ASSET CONDITION GRADE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('NEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.black)),
                      value: 'BRAND NEW', groupValue: _selectedCondition, activeColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _selectedCondition = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('EXCELLENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.black)),
                      value: 'EXCELLENT', groupValue: _selectedCondition, activeColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _selectedCondition = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('GOOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.black)),
                      value: 'GOOD CONDITION', groupValue: _selectedCondition, activeColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _selectedCondition = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),

              GestureDetector(
                onTap: _isPublishing ? null : _publishProductToDatabase,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Center(
                    child: _isPublishing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('PUBLISH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


