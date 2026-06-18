import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/session_manager.dart';
import 'login_screen.dart';
import 'product_detail.dart';
import 'shopping_bag.dart';
import 'search_page.dart';
import 'ghala_management.dart';
import 'rental_history.dart';
import 'profile_page.dart';
import 'about_page.dart';
import 'feedback_page.dart';
import '../core/supabase_config.dart';

class DiscoveryFeed extends StatefulWidget {
  const DiscoveryFeed({super.key});

  @override
  State<DiscoveryFeed> createState() => _DiscoveryFeedState();
}

class _DiscoveryFeedState extends State<DiscoveryFeed> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<String> _filters = ['ALL', 'BUY', 'RENT'];
  int _selectedFilter = 0;

  bool _isLoading = true;
  String _networkDebugMessage = "";
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _fetchLiveArchiveData();
  }

  Future<void> _fetchLiveArchiveData() async {
    setState(() {
      _isLoading = true;
      _networkDebugMessage = "";
    });

    try {
      final downloadedList = await Supabase.instance.client
          .from('products')
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 12));

      setState(() {
        _products = (downloadedList as List).map<Map<String, dynamic>>((item) {
          final rawImageName = (item['image_url'] ?? '').toString().trim();
          final finalNetworkUrl = SupabaseConfig.imageUrl(rawImageName);

          return {
            'product_id': item['product_id'],
            'name': (item['name'] ?? 'UNNAMED PIECE').toString().toUpperCase().trim(),
            'price_omr': (item['price_omr'] ?? '0.000 OMR').toString().trim(),
            'mode': (item['mode'] ?? 'BUY').toString().toUpperCase().trim(),
            'condition': (item['condition'] ?? 'EXCELLENT').toString().toUpperCase().trim(),
            'status': (item['status'] ?? 'AVAILABLE').toString().toUpperCase().trim(),
            'description': (item['description'] ?? '').toString().trim(),
            'image_url': finalNetworkUrl,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("❌ SUPABASE PRODUCTS TRACE: $e");
      setState(() {
        _networkDebugMessage = "SUPABASE CONNECTION ERROR\n👉 Check Supabase URL, anon key, RLS policy, and internet.\n👉 Details: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayedProducts = _products.where((p) {
      if (_selectedFilter == 0) return true;
      return p['mode'].toString() == _filters[_selectedFilter];
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildAppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.black), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        title: const Text('CLOSPHERE', style: TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -2)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _fetchLiveArchiveData),
          IconButton(icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ShoppingBag()))),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(color: Colors.black12, height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : _networkDebugMessage.isNotEmpty
                ? _buildErrorDiagnosticsPanel()
                : displayedProducts.isEmpty
                ? const Center(child: Text("NO ITEMS RETRIEVED FROM ARCHIVE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))
                : ListView.builder(
              padding: const EdgeInsets.only(top: 20),
              itemCount: displayedProducts.length,
              itemBuilder: (context, index) => _buildProductCard(displayedProducts[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedFilter == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = index),
            child: Padding(
              padding: const EdgeInsets.only(right: 35, top: 15),
              child: Text(
                  _filters[index],
                  style: TextStyle(
                      color: isSelected ? Colors.black : Colors.black54,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      letterSpacing: 1.5
                  )
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    String imageUrl = product['image_url'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetail(product: product))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(2)),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image_outlined, color: Colors.black, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            "FALLBACK: ${imageUrl.split('/').last}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                    : const Center(child: Icon(Icons.image_outlined, color: Colors.black, size: 40)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                      product['name'],
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black, letterSpacing: -0.3),
                      overflow: TextOverflow.ellipsis
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                    product['price_omr'],
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black)
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                "${product['mode']} | ${product['status']} | ${product['condition']}",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDiagnosticsPanel() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.router_outlined, size: 44, color: Colors.redAccent),
            const SizedBox(height: 14),
            const Text("NETWORK CONNECTION FAILURE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Text(
              _networkDebugMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.4, fontFamily: 'Courier'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: _fetchLiveArchiveData,
              child: const Text("RETRY CONNECTION", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.only(left: 10, right: 10, top: 40),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Clean Logo Header Section
            Container(
              height: 100,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'CLOSPHERE',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1.5,
                ),
              ),
            ),

            // Unified App Page List
            ListTile(
              horizontalTitleGap: 10,
              leading: const Icon(Icons.person_outline, color: Colors.black, size: 22),
              title: const Text('MY PROFILE', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
              },
            ),
            ListTile(
              horizontalTitleGap: 10,
              leading: const Icon(Icons.grid_view_outlined, color: Colors.black, size: 22),
              title: const Text('DISCOVERY FEED', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              horizontalTitleGap: 10,
              leading: const Icon(Icons.search, color: Colors.black, size: 22),
              title: const Text('SEARCH ARCHIVE', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage()));
              },
            ),

            // Secure Admin Entry: Only renders if your active identity matches
            if (SessionManager().isGhalaAdmin)
              ListTile(
                horizontalTitleGap: 10,
                leading: const Icon(Icons.analytics_outlined, color: Colors.black, size: 22),
                title: const Text('GHALA COMMAND', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const GhalaManagement()));
                },
              ),

            ListTile(
              horizontalTitleGap: 10,
              leading: const Icon(Icons.history, color: Colors.black, size: 22),
              title: const Text('RENTAL HISTORY', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const RentalHistory()));
              },
            ),
            ListTile(
              horizontalTitleGap: 10,
              leading: const Icon(Icons.info_outline, color: Colors.black, size: 22),
              title: const Text('ABOUT CLOSPHERE', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
              },
            ),
            ListTile(
              horizontalTitleGap: 10,
              leading: const Icon(Icons.chat_bubble_outline, color: Colors.black, size: 22),
              title: const Text('SEND FEEDBACK', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const FeedbackPage()));
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Divider(color: Colors.black12, height: 1),
            ),

            ListTile(
              horizontalTitleGap: 10,
              leading: const Icon(Icons.logout, color: Colors.black, size: 22),
              title: const Text('SIGN OUT', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              onTap: () {
                Navigator.pop(context);
                Supabase.instance.client.auth.signOut();
                SessionManager().destroyActiveSession();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

