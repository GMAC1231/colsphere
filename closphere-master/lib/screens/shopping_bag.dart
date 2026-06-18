import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/session_manager.dart';
import 'collection_pass.dart';
import '../core/supabase_config.dart';

class ShoppingBag extends StatefulWidget {
  const ShoppingBag({super.key});

  @override
  State<ShoppingBag> createState() => _ShoppingBagState();
}

class _ShoppingBagState extends State<ShoppingBag> {
  List<Map<String, dynamic>> _bagItems = [];
  bool _isLoading = true;
  double _subtotal = 0.0;
  final double _serviceFee = 1.500;

  bool _agreedToTerms = false;
  bool _confirmedCashPayment = false;

  @override
  void initState() {
    super.initState();
    _fetchCartItems();
  }

  Future<void> _fetchCartItems() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _bagItems = [];
          _subtotal = 0.0;
          _isLoading = false;
        });
        return;
      }

      final downloadedList = await Supabase.instance.client
          .from('cart')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      double calculatedSubtotal = 0.0;
      setState(() {
        _bagItems = (downloadedList as List).map<Map<String, dynamic>>((item) {
          String rawPriceOmr = (item['price_omr'] ?? '0.000 OMR').toString();
          String cleanPriceStr = rawPriceOmr.contains('(') ? rawPriceOmr.split('(').first : rawPriceOmr;
          cleanPriceStr = cleanPriceStr.replaceAll('OMR', '').trim();

          double itemPrice = double.tryParse(cleanPriceStr) ?? 0.0;
          calculatedSubtotal += itemPrice;

          return {
            'cart_item_id': item['cart_item_id'],
            'name': (item['name'] ?? 'UNNAMED PIECE').toString().toUpperCase(),
            'price_omr': rawPriceOmr.trim(),
            'mode': (item['mode'] ?? 'RENT').toString().toUpperCase(),
            'image_url': (item['image_url'] ?? '').toString().trim(),
          };
        }).toList();

        _subtotal = calculatedSubtotal;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ ERROR FETCHING BAG FROM SUPABASE: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeCheckoutProcess() async {
    if (_bagItems.isEmpty) return;
    if (!_agreedToTerms || !_confirmedCashPayment) return;

    setState(() => _isLoading = true);

    String finalPassName = '';
    String finalOrderId = '';
    double finalTotal = _subtotal + _serviceFee;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No logged in Supabase user found.');

      for (var item in _bagItems) {
        final itemMode = (item['mode'] ?? 'RENT').toString().toUpperCase();
        final orderId = 'CLO-${DateTime.now().millisecondsSinceEpoch}-${item['cart_item_id']}';
        final pickupCode = 'CPS-${(100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString()}';

        await Supabase.instance.client.from('orders').insert({
          'order_id': orderId,
          'user_id': user.id,
          'product_name': item['name'],
          'price_omr': item['price_omr'],
          'pickup_code': pickupCode,
          'status': 'READY TO COLLECT',
          'rental_start': 'SEE NAME',
          'rental_end': 'SEE NAME',
          'order_type': itemMode,
        });

        finalOrderId = orderId;
      }

      if (_bagItems.isNotEmpty) {
        finalPassName = _bagItems.first['name'];
      }

      if (_bagItems.length > 1) {
        finalPassName = "${_bagItems.length} ARCHIVE PIECES";
      }

      await Supabase.instance.client
          .from('cart')
          .delete()
          .eq('user_id', user.id);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CollectionPass(
              productName: finalPassName,
              orderId: finalOrderId,
              totalAmount: '${finalTotal.toStringAsFixed(3)} OMR',
            ),
          ),
        );
      }
    } catch (e) {
      print("❌ SUPABASE TRANSACTION FAILURE: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.black, content: Text('CHECKOUT ERROR: $e', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeItemFromBag(dynamic cartItemId) async {
    try {
      await Supabase.instance.client
          .from('cart')
          .delete()
          .eq('cart_item_id', cartItemId);
      _fetchCartItems();
    } catch (e) {
      print("❌ REMOVE CALL FAILED: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalEstimate = _bagItems.isEmpty ? 0.0 : (_subtotal + _serviceFee);
    bool isCheckoutAllowed = _bagItems.isNotEmpty && _agreedToTerms && _confirmedCashPayment;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'YOUR BAG',
          style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : _bagItems.isEmpty
          ? const Center(child: Text("YOUR CLOSPHERE BAG IS EMPTY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _bagItems.length,
              itemBuilder: (context, index) {
                final item = _bagItems[index];
                String rawImageUrl = item['image_url'] ?? '';
                String finalImageUrl = SupabaseConfig.imageUrl(rawImageUrl);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFFF9F9F9),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 90,
                        color: Colors.white,
                        child: finalImageUrl.isNotEmpty
                            ? Image.network(finalImageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image_outlined, color: Colors.black))
                            : const Icon(Icons.image_outlined, color: Colors.black),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, height: 1.3)),
                            const SizedBox(height: 4),
                            Text(item['price_omr'], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
                            const SizedBox(height: 6),
                            Text("MODE: ${item['mode']}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.black, size: 20),
                        onPressed: () => _removeItemFromBag(item['cart_item_id']),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(25, 15, 25, 25),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black, width: 1))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SUBTOTAL', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                    Text('${_subtotal.toStringAsFixed(3)} OMR', style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ARCHIVE SERVICE FEE', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                    Text('${_serviceFee.toStringAsFixed(3)} OMR', style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
                const Divider(height: 20, color: Colors.black, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ESTIMATED TOTAL', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                    Text('${totalEstimate.toStringAsFixed(3)} OMR', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 15),

                // --- CUSTOM TILES MATCHING THE PROFILE PAGE DESIGN ---
                GestureDetector(
                  onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            activeColor: Colors.black,
                            checkColor: Colors.white,
                            value: _agreedToTerms,
                            onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'I AGREE TO CLOSPHERE TERMS AND PRIVACY HUB REQUIREMENTS',
                            style: TextStyle(color: Colors.black, fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _confirmedCashPayment = !_confirmedCashPayment),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            activeColor: Colors.black,
                            checkColor: Colors.white,
                            value: _confirmedCashPayment,
                            onChanged: (val) => setState(() => _confirmedCashPayment = val ?? false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'I CONFIRM CASH ON COLLECTION SELECTION AT THE WAREHOUSE FULFILLMENT HUBS',
                            style: TextStyle(color: Colors.black, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                GestureDetector(
                  onTap: isCheckoutAllowed ? _executeCheckoutProcess : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    color: isCheckoutAllowed ? Colors.black : Colors.black.withOpacity(0.2),
                    child: const Center(child: Text('PROCEED TO CHECKOUT PASS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}






