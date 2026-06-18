import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/session_manager.dart';

class RentalHistory extends StatefulWidget {
  const RentalHistory({super.key});

  @override
  State<RentalHistory> createState() => _RentalHistoryState();
}

class _RentalHistoryState extends State<RentalHistory> {
  List<Map<String, dynamic>> _rentedProductsLog = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCollectionPassRentals();
  }

  Future<void> _fetchCollectionPassRentals() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _rentedProductsLog = [];
          _isLoading = false;
        });
        return;
      }

      final rawLogData = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> parsedRentals = [];

      for (var item in rawLogData as List) {
        String explicitMode = 'RENT';
        if (item['order_type'] != null) {
          explicitMode = item['order_type'].toString().toUpperCase();
        } else if (item['mode'] != null) {
          explicitMode = item['mode'].toString().toUpperCase();
        }

        String rawNameString = (item['product_name'] ?? item['name'] ?? 'ARCHIVE PIECE').toString().trim().toUpperCase();
        String rawPriceString = (item['price_omr'] ?? '').toString().trim().toUpperCase();

        List<String> separateNames = rawNameString.contains(',')
            ? rawNameString.split(',')
            : [rawNameString];

        for (var individualName in separateNames) {
          String cleanName = individualName.trim().toUpperCase();
          if (cleanName.isEmpty) continue;

          String displayPrice = rawPriceString;
          String extractedDates = "";

          if (rawPriceString.contains('(')) {
            int startIndex = rawPriceString.indexOf('(');
            int endIndex = rawPriceString.indexOf(')');
            if (endIndex > startIndex) {
              extractedDates = rawPriceString.substring(startIndex, endIndex + 1);
              displayPrice = rawPriceString.substring(0, startIndex).trim();
            }
          } else if (cleanName.contains('(')) {
            int startIndex = cleanName.indexOf('(');
            int endIndex = cleanName.indexOf(')');
            if (endIndex > startIndex) {
              extractedDates = cleanName.substring(startIndex, endIndex + 1);
              cleanName = cleanName.substring(0, startIndex).trim();
            }
          }

          if (!displayPrice.contains('OMR') && displayPrice.isNotEmpty) {
            displayPrice = "$displayPrice OMR";
          }

          String displayStatus = (explicitMode == 'BUY') ? 'NOT COLLECTED YET' : 'READY TO COLLECT';
          if (item['status'] != null &&
              item['status'].toString().toUpperCase() != 'PENDING' &&
              item['status'].toString().toUpperCase() != 'ACTIVE') {
            displayStatus = item['status'].toString().toUpperCase();
          }

          parsedRentals.add({
            'id': item['id'],
            'order_id': item['order_id'] ?? 'CLO-PASS',
            'name': cleanName,
            'dates': extractedDates,
            'mode': explicitMode,
            'status': displayStatus,
            'price_omr': displayPrice,
            'pickup_code': item['pickup_code'] ?? 'CPS-${(1000 + (item['id'] ?? 1) * 3).toString()}',
          });
        }
      }

      setState(() {
        _rentedProductsLog = parsedRentals;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ CRITICAL RENTAL HISTORY SUPABASE LOAD ERROR: $e");
      setState(() {
        _rentedProductsLog = [];
        _isLoading = false;
      });
    }
  }

  Color _getStatusThemeColor(String status) {
    if (status == 'READY TO COLLECT' || status == 'COLLECTED') return const Color(0xFF00AA66);
    if (status == 'NOT COLLECTED YET') return const Color(0xFFE6A23C);
    if (status == 'PENDING TO RETURN') return Colors.deepOrangeAccent;
    return Colors.black;
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        String fullNameWithDates = product['name'];
        if (product['dates'].toString().isNotEmpty) {
          fullNameWithDates += " ${product['dates']}";
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product['order_id'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black45)),
              const Divider(height: 25, color: Colors.black, thickness: 1),

              const Text('PRODUCT SPECIFICATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(fullNameWithDates, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black, height: 1.4, letterSpacing: 0.3)),

              const SizedBox(height: 20),
              const Text('TRANSACTION SYSTEM MODE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(product['mode'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.5)),

              const SizedBox(height: 20),
              const Text('VALUATION & SYSTEM ASSESSMENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(product['price_omr'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black)),

              const Divider(height: 40, color: Colors.black, thickness: 1),

              const Text('OPERATIONAL LIVE STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.black54)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: _getStatusThemeColor(product['status']).withOpacity(0.06),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: _getStatusThemeColor(product['status'])),
                    const SizedBox(width: 10),
                    Text(
                      product['status'],
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _getStatusThemeColor(product['status']), letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('FULFILLMENT HUB CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black)),
                  Text(product['pickup_code'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SETTLEMENT MODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black)),
                  const Text('CASH ON COLLECTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black)),
                ],
              ),
              const SizedBox(height: 40),
              SafeArea(
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    color: Colors.black,
                    child: const Center(child: Text('DISMISS SPECIFICATIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2))),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'RENTED & PURCHASED PRODUCTS',
          style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1.5))
          : _rentedProductsLog.isEmpty
          ? const Center(child: Text("NO PRODUCTS RECORDED", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.black38, letterSpacing: 1)))
          : ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        itemCount: _rentedProductsLog.length,
        separatorBuilder: (context, index) => const Divider(height: 25, color: Colors.black12, thickness: 1),
        itemBuilder: (context, index) {
          final item = _rentedProductsLog[index];

          return InkWell(
            onTap: () => _showProductDetails(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['price_omr'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.2)),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 5, color: _getStatusThemeColor(item['status'])),
                          const SizedBox(width: 5),
                          Text(
                            item['status'],
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                color: _getStatusThemeColor(item['status']),
                                letterSpacing: 0.5
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      text: item['name'],
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black, height: 1.4, letterSpacing: 0.2),
                      children: [
                        if (item['dates'].toString().isNotEmpty)
                          TextSpan(
                            text: " ${item['dates']}",
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "MODE: ${item['mode']}",
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.4), letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


