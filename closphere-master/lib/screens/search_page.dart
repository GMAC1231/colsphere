import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product_detail.dart';
import '../core/supabase_config.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allArchive = [];
  List<Map<String, dynamic>> _filteredArchive = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSearchData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSearchData() async {
    try {
      final downloadedData = await Supabase.instance.client
          .from('products')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _allArchive = (downloadedData as List).map((item) => {
          'product_id': item['product_id'],
          'name': item['name'] ?? 'UNNAMED PIECE',
          'price_omr': item['price_omr'] ?? '0.000 OMR',
          'price': item['price_omr'] ?? '0.000 OMR',
          'mode': item['mode'].toString().toUpperCase() == 'RENT' ? 'RENT' : 'BUY',
          'status': item['status'] ?? 'AVAILABLE',
          'condition': item['condition'] ?? 'EXCELLENT',
          'description': item['description'] ?? '',
          'image_url': SupabaseConfig.imageUrl((item['image_url'] ?? '').toString()),
        }).toList();
        _filteredArchive = List.from(_allArchive);
        _isLoading = false;
      });
    } catch (e) {
      print("❌ SEARCH SUPABASE FAULT: $e");
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toUpperCase();
    setState(() {
      if (query.isEmpty) {
        _filteredArchive = List.from(_allArchive);
      } else {
        _filteredArchive = _allArchive.where((product) {
          final name = product['name'].toString().toUpperCase();
          final condition = product['condition'].toString().toUpperCase();
          final status = product['status'].toString().toUpperCase();
          return name.contains(query) || condition.contains(query) || status.contains(query);
        }).toList();
      }
    });
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
          'EXPLORE ARCHIVE',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- LIVE KEYWORD INPUT BLOCK ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _searchController,
              cursorColor: Colors.black,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
              decoration: InputDecoration(
                hintText: 'SEARCH BY BRAND, TYPE, OR TAG',
                hintStyle: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // --- ARCHIVE RESULT BOXES ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : _filteredArchive.isEmpty
                ? const Center(child: Text("NO ASSETS FOUND MATCHING PARAMETERS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)))
                : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.60,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: _filteredArchive.length,
              itemBuilder: (context, index) {
                final item = _filteredArchive[index];
                String imageUrl = item['image_url'] ?? '';
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProductDetail(product: item)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          color: const Color(0xFFF9F9F9),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, err, stack) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.black, size: 30)),
                          )
                              : const Center(child: Icon(Icons.photo_outlined, color: Colors.black, size: 30)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item['name'].toString().toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5, color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['price'],
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        color: Colors.black,
                        child: Text(
                          item['mode'],
                          style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

