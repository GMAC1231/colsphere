import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class ProductDetail extends StatelessWidget {
  final Map<String, dynamic> product;
  const ProductDetail({super.key, required this.product});

  // 🌐 Supabase direct bag insert handler
  Future<void> _addToBagNetworkCall(BuildContext context, {String? customPrice}) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please login again before adding items.');
      }

      await supabase.from('cart').insert({
        'user_id': user.id,
        'name': product['name'] ?? 'UNNAMED PIECE',
        'price_omr': customPrice ?? (product['price_omr'] ?? '0.000 OMR'),
        'mode': product['mode'] ?? 'BUY',
        'image_url': product['image_url'] ?? '',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.black,
            content: Text(
              '⚡ ADDED "${product['name'].toString().toUpperCase()}" TO YOUR CLOSPHERE BAG!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.black,
            content: Text(
              '❌ SUPABASE CART ERROR: $e',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        );
      }
    }
  }

  // 📅 Interactive Calendar Date Range Picker Logic
  Future<void> _selectRentalDates(BuildContext context) async {
    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      currentDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null && context.mounted) {
      final int totalDays = pickedRange.duration.inDays == 0 ? 1 : pickedRange.duration.inDays;

      // Clean up the price string to safely parse it numerical value
      String rawPriceStr = (product['price_omr'] ?? '0.000').toString().replaceAll('OMR', '').trim();
      double basePrice = double.tryParse(rawPriceStr) ?? 0.0;
      double calculatedPrice = basePrice * totalDays;

      // Format custom string value to display within your Shopping Bag row metadata cleanly
      final String formattedDateLabel =
          "${pickedRange.start.day}/${pickedRange.start.month} - ${pickedRange.end.day}/${pickedRange.end.month}";
      final String finalPricePayload =
          "${calculatedPrice.toStringAsFixed(3)} OMR ($totalDays DAYS | $formattedDateLabel)";

      // Commit directly to backend storage cache state
      await _addToBagNetworkCall(context, customPrice: finalPricePayload);
    }
  }

  // 🏷️ Dynamic Runtime Size Evaluator
  String _determineProductSize(String name, String description) {
    final cleanName = name.toUpperCase();
    final cleanDesc = description.toUpperCase();

    if (cleanName.contains('SUNGLASSES') || cleanDesc.contains('SUNGLASSES') ||
        cleanName.contains('GLASSES') || cleanDesc.contains('GLASSES') ||
        cleanName.contains('BAG') || cleanDesc.contains('BAG') ||
        cleanName.contains('WALLET') || cleanDesc.contains('WALLET') ||
        cleanName.contains('BELT') || cleanDesc.contains('BELT') ||
        cleanName.contains('HAT') || cleanName.contains('CAP')) {
      return 'O/S (ONE SIZE)';
    }

    final int deterministicValue = (name.length + description.length) % 4;
    switch (deterministicValue) {
      case 0: return 'S';
      case 1: return 'M';
      case 2: return 'L';
      case 3:
      default: return 'XL';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isRent = (product['mode'] ?? 'RENT').toString().toUpperCase() == 'RENT';

    String rawImageUrl = product['image_url'] ?? '';
    String finalImageUrl = rawImageUrl;
    if (rawImageUrl.isNotEmpty && !rawImageUrl.startsWith('http')) {
      finalImageUrl = SupabaseConfig.imageUrl(rawImageUrl);
    }

    String productName = (product['name'] ?? 'UNNAMED PIECE').toString().toUpperCase();
    String priceOmr = product['price_omr'] ?? '0.000 OMR';
    String conditionText = (product['condition'] ?? 'EXCELLENT').toString().toUpperCase();
    String descriptionText = product['description'] ?? 'No archival overview provided for this item.';
    String assignedSize = _determineProductSize(productName, descriptionText);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context)
          )
      ),
      body: Column(
        children: [
          Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF9F9F9),
                child: finalImageUrl.isNotEmpty
                    ? Image.network(
                  finalImageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image_outlined, size: 40, color: Colors.black),
                            const SizedBox(height: 8),
                            Text(
                                finalImageUrl.split('/').last,
                                style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)
                            )
                          ],
                        )
                    ),
                  ),
                )
                    : const Center(
                    child: Icon(Icons.photo_outlined, size: 80, color: Colors.black)
                ),
              )
          ),

          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: Colors.black,
                    child: Text(
                        conditionText,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                      productName,
                      style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)
                  ),
                  const SizedBox(height: 4),

                  Text(
                      isRent ? "$priceOmr / DAY" : priceOmr,
                      style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)
                  ),

                  const Divider(height: 25, color: Colors.black, thickness: 1),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ARCHIVE SIZE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(
                            assignedSize,
                            style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),

                          const Text('DESCRIPTION', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          Text(
                            descriptionText,
                            style: const TextStyle(color: Colors.black, fontSize: 12, height: 1.5, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 18),

                          const Text('THE ARCHIVE GUARANTEE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          const Text(
                            'This piece has been authenticated and inspected by the Closphere team. We guarantee the condition matches our archive standards for luxury and durability.',
                            style: TextStyle(color: Colors.black, fontSize: 12, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => isRent ? _selectRentalDates(context) : _addToBagNetworkCall(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(2)),
                            child: Center(
                              child: Text(
                                isRent ? 'SELECT RENTAL DATES' : 'ADD TO BAG',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

