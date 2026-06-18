import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/session_manager.dart';

class CollectionPass extends StatefulWidget {
  final String productName;
  final String orderId;
  final String totalAmount;

  const CollectionPass({
    super.key,
    required this.productName,
    required this.orderId,
    this.totalAmount = "0.000 OMR",
  });

  @override
  State<CollectionPass> createState() => _CollectionPassState();
}

class _CollectionPassState extends State<CollectionPass> {
  bool _isLoading = true;
  String _liveOrderId = "";
  String _pickupCode = "000-000";
  String _liveProductName = "";

  final String _invoiceDate = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

  @override
  void initState() {
    super.initState();
    _liveOrderId = widget.orderId;
    _liveProductName = widget.productName;
    _fetchLiveAuthenticationPass();
  }

  Future<void> _fetchLiveAuthenticationPass() async {
    try {
      final session = SessionManager();
      final user = Supabase.instance.client.auth.currentUser;
      if (!session.isLoggedIn || user == null) {
        _useLocalFallback();
        return;
      }

      final data = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);

      if (data is List && data.isNotEmpty) {
        final pass = Map<String, dynamic>.from(data.first);
        setState(() {
          _liveOrderId = pass['order_id'] ?? widget.orderId;
          _pickupCode = pass['pickup_code'] ?? "420-981";
          _liveProductName = pass['product_name'] ?? widget.productName;
          _isLoading = false;
        });
      } else {
        _useLocalFallback();
      }
    } catch (e) {
      _useLocalFallback();
    }
  }

  void _useLocalFallback() {
    setState(() {
      _pickupCode = "420-981";
      _isLoading = false;
    });
  }

  Widget _buildInvoiceRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 0.5),
            ),
          ),
          Text(
            value.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'OFFICIAL INVOICE PASS',
          style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CLOSPHERE',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.black),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'INVOICE NO: $_liveOrderId',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(1),
                          ),
                          child: const Text(
                            'PENDING GHALA CASH',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: Colors.black, thickness: 2),
              ),
              _buildInvoiceRow('ISSUE DATE', _invoiceDate),
              _buildInvoiceRow('PAYMENT METHOD', 'CASH AT COLLECTION'),
              _buildInvoiceRow('FULFILLMENT', 'SELF PICK-UP ARRANGEMENT'),
              _buildInvoiceRow('AMOUNT DUE', widget.totalAmount, isBold: true),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Divider(color: Colors.black12, thickness: 1),
              ),
              const Text(
                'ARCHIVAL MANIFEST ITEMS',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.black38),
              ),
              const SizedBox(height: 10),
              Text(
                _liveProductName.toUpperCase(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black, height: 1.5),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 25),
                child: Divider(color: Colors.black, thickness: 2),
              ),
              const Center(
                child: Text(
                  'SECURE PICK-UP CODE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _pickupCode,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 6, color: Colors.black),
                ),
              ),
              const SizedBox(height: 40),
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    'PRESENT THIS INVOICE SCREEN TO THE GHALA MANAGER TO PAY AND COLLECT YOUR SELECTIONS.\n\nNOTE: THIS INVOICE AND PASS ARE SAVED PERMANENTLY WITHIN YOUR PROFILE PAGE FOR EASY ACCESS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold, height: 1.6, letterSpacing: 0.5),
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
