import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/session_manager.dart'; // Links active state data
import 'collection_pass.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _userName = "LOADING PROFILE...";
  String _userEmail = "...";
  bool _isLoading = true;
  bool _isLoggedIn = false;
  List<dynamic> _orderHistory = [];

  @override
  void initState() {
    super.initState();
    _loadProfileAndOrders();
  }

  Future<void> _loadProfileAndOrders() async {
    setState(() => _isLoading = true);
    try {
      final session = SessionManager();
      final user = Supabase.instance.client.auth.currentUser;

      if (session.isLoggedIn && user != null) {
        setState(() {
          _userName = session.name ?? 'CLOSPHERE MEMBER';
          _userEmail = session.email ?? 'No email associated';
          _isLoggedIn = true;
        });

        final rawData = await Supabase.instance.client
            .from('orders')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        setState(() {
          _orderHistory = (rawData as List).map((order) {
            return {
              'order_id': (order['order_id'] ?? order['id'] ?? 'CLO-000000').toString(),
              'product_name': (order['product_name'] ?? order['name'] ?? 'UNNAMED PIECE').toString(),
              'pickup_code': (order['pickup_code'] ?? order['code'] ?? '000-000').toString(),
            };
          }).toList();
        });
      } else {
        setState(() {
          _userName = "GUEST USER";
          _userEmail = "PLEASE LOG IN TO VIEW DETAILS";
          _isLoggedIn = false;
          _orderHistory = [];
        });
      }
    } catch (e) {
      print("⚠️ SUPABASE SESSION ERROR: $e");
      setState(() {
        _userName = "CONNECTION ERROR";
        _userEmail = "UNABLE TO REACH SUPABASE";
        _isLoggedIn = false;
        _orderHistory = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- MODAL DIALOG POPUPS FOR FIXED PLATFORM PARAMETERS ---

  void _showPermanentPaymentMethod() {
    _showMinimalBottomSheet(
      title: 'PERMANENT PAYMENT METHOD',
      content: 'ALL TRANSACTIONS WITHIN THE CLOSPHERE ARCHIVE OPERATE EXCLUSIVELY ON A "CASH ON COLLECTION" OR PHYSICAL "GHALA ACCOUNT CARD" PROTOCOL.\n\nYOUR PIECES ARE SECURED ONLINE AND BILLED UPON INSPECTION AT FULFILLMENT.',
    );
  }

  void _showWarehouseLocation() {
    _showMinimalBottomSheet(
      title: 'COLLECTION WAREHOUSE',
      content: 'LOCATION: GHALA INDUSTRIAL AREA, MUSCAT, OMAN\n\nHOUSE/COMPLEX: CLOSPHERE ARCHIVE HUBS (BLDG 42/B)\n\nHOURS: 10:00 AM - 9:00 PM (SATURDAY - THURSDAY)\n\nPLEASE PRESENT YOUR PASSCODE AT THE SECURE ENTRANCE TERMINAL.',
    );
  }

  void _showTermsAndPickupPolicy() {
    _showMinimalBottomSheet(
      title: 'TERMS & PICK-UP POLICY',
      content: '1. ALL CODES REMAIN VALID FOR EXCLUSIVELY 72 HOURS FROM ISSUANCE BEFORE SELF-CANCELING.\n\n2. EXAMINE PRODUCT CONDITIONS THOROUGHLY BEFORE SECURING THE SIGN-OFF CONTEXT WITH THE GHALA MANAGER.\n\n3. ALL RENTALS OR PURCHASES ARE FINALIZED UPON PAYMENT GATEWAY VERIFICATION.',
    );
  }

  void _showMinimalBottomSheet({required String title, required String content}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.zero)),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: Colors.black, thickness: 1.5),
              ),
              const SizedBox(height: 5),
              Text(
                content,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.8, color: Colors.black, letterSpacing: 0.5),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: Colors.black,
                  child: const Center(
                    child: Text(
                      'ACKNOWLEDGE',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                  ),
                ),
              ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
            'MY PROFILE',
            style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : RefreshIndicator(
        color: Colors.black,
        onRefresh: _loadProfileAndOrders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.black,
                      child: Icon(Icons.person_outline, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _userName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.black),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userEmail.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                'ARCHIVED INVOICE PASSES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: Colors.black, thickness: 1),
              ),

              _orderHistory.isEmpty
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    _isLoggedIn ? "NO ORDERS PLACED YET" : "LOG IN TO VIEW YOUR PASS HISTORY",
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 0.5),
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _orderHistory.length,
                itemBuilder: (context, index) {
                  final order = _orderHistory[index];
                  String orderId = order['order_id'];
                  String products = order['product_name'];
                  String pickupCode = order['pickup_code'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Colors.black, width: 0.5),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                      title: Text(
                        orderId,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5, color: Colors.black),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          products.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            pickupCode,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'VIEW PASS',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black),
                          ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CollectionPass(
                              productName: products,
                              orderId: orderId,
                              totalAmount: "REVIEW AT GHALA",
                            ),
                          ),
                        );
                        _loadProfileAndOrders();
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 25),

              // --- CONFIGURATION TILES CONNECTED TO SHEETS ---
              _buildProfileTile('PERMANENT PAYMENT METHODS', Icons.credit_card, _showPermanentPaymentMethod),
              _buildProfileTile('COLLECTION WAREHOUSE ADDRESS', Icons.location_on_outlined, _showWarehouseLocation),
              _buildProfileTile('TERMS & PICK-UP POLICIES', Icons.gavel_outlined, _showTermsAndPickupPolicy),
              _buildProfileTile('PRIVACY SYSTEM POLICY', Icons.shield_outlined, () {
                _showMinimalBottomSheet(
                    title: 'PRIVACY SYSTEM POLICY',
                    content: 'YOUR PERSONAL DATA PROFILE MATRIX IS FULLY ENCRYPTED LOCALLY AND USED SOLELY FOR SECURING INVOICE PASS GENERATIONS ACROSS INTERNAL GHALA ARCHIVE NETWORKS.'
                );
              }),

              const SizedBox(height: 35),
              const Center(
                child: Text('APP VERSION 1.0.0 (STABLE)', style: TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTile(String title, IconData icon, VoidCallback action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 0.5)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Colors.black, size: 18),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5, color: Colors.black)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 10),
        onTap: action,
      ),
    );
  }
}
