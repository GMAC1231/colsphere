import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/session_manager.dart';
import 'add_product_page.dart';
import 'login_screen.dart';

class GhalaManagement extends StatefulWidget {
  const GhalaManagement({super.key});

  @override
  State<GhalaManagement> createState() => _GhalaManagementState();
}

class _GhalaManagementState extends State<GhalaManagement> {
  // --- CORE ENGINE VARIABLES ---
  List<Map<String, dynamic>> _liveInventory = [];
  List<Map<String, dynamic>> _incomingOrdersLog = [];
  bool _isLoading = true;
  bool _isAdminVerified = false;

  // 🎛️ SYSTEM NAVIGATION SEGMENTS
  // 0 = Inventory, 1 = Orders, 2 = Passes, 3 = Feedback
  int _activeControlTab = 0;
  double _totalCalculatedRevenue = 0.0;
  int _activeRentedCount = 0;

  // --- HOOK DATA ARRAYS ---
  List<Map<String, dynamic>> _systemPassesRegistry = [];
  List<Map<String, dynamic>> _userFeedbackInbox = [];

  // 📂 INTERACTIVE TOGGLE STATE FOR MINI-REPORTS
  final Set<dynamic> _expandedTicketIds = <dynamic>{};

  // 🔐 PASSPORT VALIDATION CONTROLLERS
  final Map<String, TextEditingController> _passVerificationInputs = {};
  bool _isPassProcessing = false;
  bool _isFeedbackLoading = false;

  @override
  void initState() {
    super.initState();
    _executeSecurityClearanceCheck();
  }

  @override
  void dispose() {
    _passVerificationInputs.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _logoutAdmin() async {
    await Supabase.instance.client.auth.signOut();
    SessionManager().destroyActiveSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _executeSecurityClearanceCheck() {
    final session = SessionManager();
    if (session.isLoggedIn && session.isGhalaAdmin) {
      setState(() {
        _isAdminVerified = true;      });
      _syncAllCommandCenterData();
    } else {
      setState(() {
        _isLoading = false;
        _isAdminVerified = false;
      });
    }
  }

  // --- MASTER SYSTEM REFRESH RECOVERY SEQUENCE ---
  Future<void> _syncAllCommandCenterData() async {
    if (!_isAdminVerified) return;

    // Start loading state once
    setState(() => _isLoading = true);

    try {
      // 🚀 SPEED OPTIMIZATION: Fires all 4 requests simultaneously instead of one-by-one
      await Future.wait([
        _fetchCurrentInventoryMetrics(),
        _fetchGlobalOrdersSystem(),
        _fetchSystemPassesData(),
        _fetchFeedbackMessagesInbox(),
      ]);
    } catch (e) {
      print("❌ PARALLEL SYNC BLOCK FAILURE: $e");
    } finally {
      // Safely kill loading spinner even if a network request acts up
      setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // 📡 CORE BACKEND CONNECTION PIPELINES
  // =========================================================================
  Future<void> _fetchCurrentInventoryMetrics() async {
    try {
      final data = await Supabase.instance.client
          .from('products')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _liveInventory = (data as List).map<Map<String, dynamic>>((item) {
          final verifiedId = item['product_id'] ?? item['id'] ?? 0;
          return {
            'db_id': verifiedId,
            'name': (item['name'] ?? 'UNKNOWN PIECE').toString().toUpperCase(),
            'id': "ARCH-$verifiedId",
            'status': (item['status'] ?? 'AVAILABLE').toString().toUpperCase(),
            'mode': (item['mode'] ?? 'RENT').toString().toUpperCase(),
            'price_omr': (item['price_omr'] ?? '0.000').toString(),
            'condition': (item['condition'] ?? 'BRAND NEW').toString().toUpperCase(),
            'description': item['description'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print("❌ GHALA SUPABASE INVENTORY FAULT: $e");
    }
  }


  Future<void> _fetchGlobalOrdersSystem() async {
    try {
      final rawLogData = await Supabase.instance.client
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> parsedGlobalOrders = [];
      double revenueAccumulator = 0.0;
      int activeRentalsCounter = 0;

      for (var item in rawLogData as List) {
        String explicitMode = 'RENT';
        if (item['order_type'] != null) {
          explicitMode = item['order_type'].toString().toUpperCase();
        } else if (item['mode'] != null) {
          explicitMode = item['mode'].toString().toUpperCase();
        }

        String rawNameString = (item['product_name'] ?? item['name'] ?? 'ARCHIVE PIECE').toString().trim().toUpperCase();
        String rawPriceString = (item['price_omr'] ?? '').toString().trim().toUpperCase();

        List<String> separateNames = rawNameString.contains(',') ? rawNameString.split(',') : [rawNameString];

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

          String cleanDigitsOnly = displayPrice.replaceAll(RegExp(r'[^0-9.]'), '');
          double parsedPrice = double.tryParse(cleanDigitsOnly) ?? 0.0;
          revenueAccumulator += parsedPrice;

          if (displayStatus == 'ACTIVE' || displayStatus == 'READY TO COLLECT' || displayStatus == 'NOT COLLECTED YET') {
            activeRentalsCounter++;
          }

          parsedGlobalOrders.add({
            'id': item['id'],
            'order_id': item['order_id'] ?? 'CLO-PASS',
            'product_name': cleanName,
            'dates': extractedDates,
            'order_type': explicitMode,
            'status': displayStatus,
            'price_omr': displayPrice,
            'pickup_code': item['pickup_code'] ?? 'CPS-${(1000 + (item['id'] ?? 1) * 3).toString()}',
            'rental_start': item['rental_start'] ?? '---',
            'rental_end': item['rental_end'] ?? '---',
            'user_id': item['user_id']?.toString() ?? 'GUEST',
          });
        }
      }

      setState(() {
        _incomingOrdersLog = parsedGlobalOrders;
        _totalCalculatedRevenue = revenueAccumulator;
        _activeRentedCount = activeRentalsCounter;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ GHALA ADMIN SUPABASE ORDERS EXCEPTION: $e");
      setState(() {
        _incomingOrdersLog = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSystemPassesData() async {
    try {
      final rawManifestList = await Supabase.instance.client
          .from('orders')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _systemPassesRegistry = (rawManifestList as List).map<Map<String, dynamic>>((pass) {
          String currentOrderId = (pass['order_id'] ?? 'UNKNOWN').toString();
          if (!_passVerificationInputs.containsKey(currentOrderId)) {
            _passVerificationInputs[currentOrderId] = TextEditingController();
          }
          return {
            'order_id': currentOrderId,
            'product_name': (pass['product_name'] ?? 'MANIFEST UNKNOWN').toString().toUpperCase(),
            'pickup_code': (pass['pickup_code'] ?? '000-000').toString(),
            'total_amount': (pass['total_amount'] ?? pass['price_omr'] ?? '0.000 OMR').toString(),
            'user_id': (pass['user_id'] ?? 'CLIENT-USER').toString()
          };
        }).toList();
      });
    } catch (e) {
      print("❌ GHALA ENGINE SUPABASE PASS RECEPTION ERROR: $e");
    }
  }

  Future<void> _fetchFeedbackMessagesInbox() async {
    setState(() => _isFeedbackLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('feedback')
          .select()
          .order('timestamp', ascending: false);

      setState(() {
        _userFeedbackInbox = (data as List).map<Map<String, dynamic>>((f) => {
          'id': f['id'],
          'user_id': f['user_id'] ?? 'GUEST',
          'type': f['type'] ?? 'HELP TICKET',
          'message': f['message'] ?? '',
          'client_name': f['client_name'] ?? f['name'] ?? f['username'] ?? 'N/A',
          'client_gmail': f['client_gmail'] ?? f['gmail'] ?? f['email'] ?? 'N/A',
          'timestamp': f['timestamp'] ?? ''
        }).toList();
      });
    } catch (e) {
      print("❌ SUPABASE FEEDBACK STREAM DISCONNECTED: $e");
    } finally {
      setState(() => _isFeedbackLoading = false);
    }
  }

  Future<void> _modifyProductState(Map<String, dynamic> rawItem) async {
    final dynamic dbId = rawItem['db_id'];

    final TextEditingController editNameController = TextEditingController(text: rawItem['name']);
    final TextEditingController editPriceController = TextEditingController(text: rawItem['price_omr']);

    // 🛡️ CRASH GUARD 1: Safely handle null descriptions for old items
    final TextEditingController editDescController = TextEditingController(
        text: (rawItem['description'] == null) ? "" : rawItem['description'].toString()
    );

    // 🛡️ CRASH GUARD 2: Safely parse and sanitize selection drop-downs from older database records
    String selectedStatus = (rawItem['status'] == null || rawItem['status'].toString().isEmpty) ? 'AVAILABLE' : rawItem['status'].toString().toUpperCase();
    String selectedMode = (rawItem['mode'] == null || rawItem['mode'].toString().isEmpty) ? 'RENT' : rawItem['mode'].toString().toUpperCase();
    String selectedCondition = (rawItem['condition'] == null || rawItem['condition'].toString().isEmpty) ? 'BRAND NEW' : rawItem['condition'].toString().toUpperCase();

    // 🛡️ CRASH GUARD 3: Fallback safety validation to prevent Flutter Dropdown value matching crash
    if (selectedStatus != 'AVAILABLE' && selectedStatus != 'OUT ON HIRE' && selectedStatus != 'MAINTENANCE' && selectedStatus != 'RESERVED') {
      selectedStatus = 'AVAILABLE';
    }
    if (selectedMode != 'RENT' && selectedMode != 'BUY' && selectedMode != 'BOTH') {
      selectedMode = 'RENT';
    }
    if (selectedCondition != 'BRAND NEW' && selectedCondition != 'EXCELLENT' && selectedCondition != 'GOOD CONDITION') {
      selectedCondition = 'BRAND NEW';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(30, 40, 30, MediaQuery.of(context).viewInsets.bottom + 30),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("MODIFY ARCHIVE METADATA", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2, color: Colors.black)),
                    const Divider(height: 30, color: Colors.black, thickness: 2),

                    const Text("PRODUCT DESIGNATION NAME", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black, letterSpacing: 1)),
                    TextField(
                      controller: editNameController,
                      cursorColor: Colors.black,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black, letterSpacing: 0.5),
                      decoration: const InputDecoration(
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 3)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 25),

                    const Text("VALUATION (OMR)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black, letterSpacing: 1)),
                    TextField(
                      controller: editPriceController,
                      cursorColor: Colors.black,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black, letterSpacing: 0.5),
                      decoration: const InputDecoration(
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 3)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 25),

                    const Text("DESCRIPTIVE METADATA SPECIFICATIONS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black, letterSpacing: 1)),
                    TextField(
                      controller: editDescController,
                      cursorColor: Colors.black,
                      maxLines: 2,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black, height: 1.4),
                      decoration: const InputDecoration(
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 3)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 30),

                    const Text("OPERATIONAL AVAILABILITY STATUS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black, letterSpacing: 1)),
                    DropdownButton<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      underline: Container(height: 1.5, color: Colors.black),
                      items: <String>['AVAILABLE', 'OUT ON HIRE', 'MAINTENANCE', 'RESERVED'].map((String val) {
                        return DropdownMenuItem<String>(value: val, child: Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black, letterSpacing: 0.5)));
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedStatus = val!),
                    ),
                    const SizedBox(height: 25),

                    const Text("COMMERCIAL SYSTEM MODE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black, letterSpacing: 1)),
                    DropdownButton<String>(
                      value: selectedMode,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      underline: Container(height: 1.5, color: Colors.black),
                      items: <String>['RENT', 'BUY', 'BOTH'].map((String val) {
                        return DropdownMenuItem<String>(value: val, child: Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black, letterSpacing: 0.5)));
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedMode = val!),
                    ),
                    const SizedBox(height: 25),

                    const Text("ASSET CONDITION GRADE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.black, letterSpacing: 1)),
                    DropdownButton<String>(
                      value: selectedCondition,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      underline: Container(height: 1.5, color: Colors.black),
                      items: <String>['BRAND NEW', 'EXCELLENT', 'GOOD CONDITION'].map((String val) {
                        return DropdownMenuItem<String>(value: val, child: Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black, letterSpacing: 0.5)));
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedCondition = val!),
                    ),
                    const SizedBox(height: 45),

                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        setState(() => _isLoading = true);

                        String finalPrice = editPriceController.text.trim();
                        if (!finalPrice.contains('OMR') && finalPrice.isNotEmpty) {
                          finalPrice = "$finalPrice OMR";
                        }

                        try {
                          await Supabase.instance.client
                              .from('products')
                              .update({
                                "name": editNameController.text.trim().toUpperCase(),
                                "price_omr": finalPrice,
                                "status": selectedStatus,
                                "mode": selectedMode,
                                "condition": selectedCondition,
                                "description": editDescController.text.trim()
                              })
                              .eq('product_id', dbId);
                          _syncAllCommandCenterData();
                        } catch (e) {
                          print("❌ UPDATE CALL EXCEPTION: $e");
                          setState(() => _isLoading = false);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        color: Colors.black,
                        child: const Center(child: Text("APPLY STATE OVERRIDES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2))),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeAssetPurge(dynamic dbId, String assetName) async {
    // Safety clearance fallback loop
    if (dbId == null || dbId.toString() == 'null' || dbId.toString() == '0') {
      print("❌ SYSTEM EXCEPTION: Deletion aborted. Resolved database ID key is null/corrupted.");
      return;
    }

    bool confirmPurge = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text("CRITICAL ASSET DELETION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black)),
        content: Text("ARE YOU SURE YOU WANT TO PURGE $assetName FROM LIVE SYSTEM?", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, height: 1.4, color: Colors.black)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11))
          ),
          TextButton(
              onPressed: () { confirmPurge = true; Navigator.pop(context); },
              child: const Text("PURGE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11))
          ),
        ],
      ),
    );

    if (!confirmPurge) return;
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('products')
          .delete()
          .eq('product_id', dbId);
      print("✅ SUPABASE PURGE VALIDATED. Synchronizing matrices...");
      _syncAllCommandCenterData();
    } catch (e) {
      print("❌ TRANSMISSION CHANNEL EXECUTION BREAKDOWN: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeOrderTermination(dynamic orderId) async {
    bool confirmTermination = false;

    // 1. Show warning confirmation dialog before destructive action
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
            "CRITICAL ORDER TERMINATION",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.black)
        ),
        content: Text(
            "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE TRACE OF SYSTEM ORDER ID #$orderId FROM THE LIVE REVENUE LOGS?",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))
          ),
          TextButton(
              onPressed: () {
                confirmTermination = true;
                Navigator.pop(context);
              },
              child: const Text("TERMINATE & PURGE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))
          ),
        ],
      ),
    );

    if (!confirmTermination) return;

    // 2. Execute Backend Pipeline Communication
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('orders')
          .delete()
          .eq('id', orderId);

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: Colors.black,
              content: Text("ORDER SUCCESSFULLY REMOVED FROM LOGS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white))
          )
      );
      _syncAllCommandCenterData();
    } catch (e) {
      print("❌ CRITICAL TRANS-LOG TERMINATION EXCEPTION: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text("ERROR: $e", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white))
          )
      );
      _syncAllCommandCenterData();
    }
  }

  Future<void> _executeFeedbackClearance(dynamic feedbackId) async {
    bool confirmClearance = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text("CLOSE ACTIVE SUPPORT TICKET", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.black)),
        content: const Text("MARK THIS ASSISTANCE LOG AS FULLY RESOLVED AND PURGE RECORD?", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
          TextButton(onPressed: () { confirmClearance = true; Navigator.pop(context); }, child: const Text("RESOLVE & PURGE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
        ],
      ),
    );
    if (!confirmClearance) return;
    setState(() => _isFeedbackLoading = true);
    try {
      await Supabase.instance.client
          .from('feedback')
          .delete()
          .eq('id', feedbackId);
      _fetchFeedbackMessagesInbox();
    } catch (e) {
      print("❌ CRITICAL SUPPORT CLEARANCE EXCEPTION: $e");
    } finally {
      setState(() => _isFeedbackLoading = false);
    }
  }

  // =========================================================================
  // 🎨 USER INTERFACE MASTER BUILDER
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    if (!_isAdminVerified && !_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text("ACCESS DENIED • SECURITY TERMINAL LOCK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2))),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.logout, color: Colors.black), onPressed: _logoutAdmin),
        title: const Text('GHALA COMMAND CENTER', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 3)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _syncAllCommandCenterData,
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Row(                      children: [
                      _buildMetricTile('TOTAL ASSETS', _isLoading ? '...' : _liveInventory.length.toString(), Icons.inventory_2_outlined),
                      const SizedBox(width: 15),
                      _buildMetricTile('TOTAL REVENUE', _isLoading ? '...' : '${_totalCalculatedRevenue.toStringAsFixed(3)} OMR', Icons.payments_outlined),
                    ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _buildMetricTile('OUT ON HIRE', _isLoading ? '...' : _activeRentedCount.toString().padLeft(2, '0'), Icons.shopping_bag_outlined),
                        const SizedBox(width: 15),
                        _buildMetricTile('TOTAL FEEDBACK', _isLoading ? '...' : _userFeedbackInbox.length.toString().padLeft(2, '0'), Icons.rate_review_outlined),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildSegmentTab("INVENTORY", 0),
                          _buildSegmentTab("ORDERS Log", 1),
                          _buildSegmentTab("PASS ENGINE", 2),
                          _buildSegmentTab("FEEDBACKS", 3),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    if (_activeControlTab == 0) ...[_buildInventoryTabSection()],
                    if (_activeControlTab == 1) ...[_buildOrdersTabSection()],
                    if (_activeControlTab == 2) ...[_buildPassEngineTabSection()],
                    if (_activeControlTab == 3) ...[_buildFeedbackTabSection()],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentTab(String label, int index) {    bool isActive = _activeControlTab == index;
  return GestureDetector(
    onTap: () => setState(() => _activeControlTab = index),
    child: Container(
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: isActive ? 3.0 : 1.0)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 9,
          letterSpacing: 1.2,
          color: isActive ? Colors.black : Colors.black38,
        ),
      ),
    ),
  );
  }

  Widget _buildMetricTile(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryTabSection() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1.5));
    if (_liveInventory.isEmpty) return const Center(child: Text("NO PIECES REGISTERED IN ENGINE", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)));

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _liveInventory.length,
          separatorBuilder: (context, index) => const Divider(color: Colors.black, thickness: 1.5, height: 30),
          itemBuilder: (context, index) {
            final item = _liveInventory[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            item['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.2)
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "${item['id']} • MODE: ${item['mode']} • VALUE: ${item['price_omr']}",
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Text(
                            item['status'],
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 0.5)
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black),
                          onPressed: () => _modifyProductState(item)
                      ),
                      IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.black),
                          onPressed: () => _executeAssetPurge(item['db_id'], item['name'])
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductPage()));
            _syncAllCommandCenterData();
          },
          child: _buildSystemAction('ADD NEW ARCHIVE PIECE', Icons.add_box_outlined),
        ),
      ],
    );
  }

  Widget _buildOrdersTabSection() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1.5));

    if (_incomingOrdersLog.isEmpty) return const Center(child: Text("NO TRANSACTION HISTORY CAPTURED", style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _incomingOrdersLog.length,
      separatorBuilder: (context, index) => const Divider(color: Color(0xFFEAEAEA), thickness: 1.5, height: 30),
      itemBuilder: (context, index) {
        final order = _incomingOrdersLog[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Price and Status Indicator Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order['price_omr'] ?? '0.000 OMR',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black),
                ),
                Row(
                  children: [
                    Icon(Icons.circle, size: 5, color: order['status'] == 'READY TO COLLECT' || order['status'] == 'COLLECTED' ? const Color(0xFF00AA66) : Colors.black),
                    const SizedBox(width: 5),
                    Text(
                      order['status'] ?? 'READY TO COLLECT',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          color: order['status'] == 'READY TO COLLECT' || order['status'] == 'COLLECTED' ? const Color(0xFF00AA66) : Colors.black,
                          letterSpacing: 0.5
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Product Name with Optional Bracketed Dates
            RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                text: order['product_name'] ?? 'ARCHIVE PIECE',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black, height: 1.4, letterSpacing: 0.2),
                children: [
                  if (order['dates'] != null && order['dates'].toString().isNotEmpty)
                    TextSpan(
                      text: " ${order['dates']}",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black54),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Row 3: Meta Context Row (Client Reference, Mode, Hub Code & Purge Trigger)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CLIENT REF: USER-${order['user_id'] ?? 'GUEST'}",
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black38),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "MODE: ${order['order_type'] ?? 'RENT'} • HUB CODE: ${order['pickup_code'] ?? '000-000'}",
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black45),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.black, size: 18),
                  onPressed: () => _executeOrderTermination(order['id']),
                )
              ],
            )
          ],
        );
      },
    );
  }

  Widget _buildPassEngineTabSection() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1.5));
    if (_systemPassesRegistry.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 50),
          child: Text("NO PENDING VALIDATION PASSES LOADED FROM BACKEND", style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _systemPassesRegistry.length,
      separatorBuilder: (context, index) => const Divider(color: Color(0xFFF5F5F5), thickness: 1.5, height: 35),
      itemBuilder: (context, index) {
        final pass = _systemPassesRegistry[index];
        final String currentOrderId = pass['order_id'];
        final String genuineSecureCode = pass['pickup_code'].toString().trim();
        final TextEditingController textController = _passVerificationInputs[currentOrderId]!;

        return Container(
          padding: const EdgeInsets.all(20),
          color: const Color(0xFFFAFAFA),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("PASS NO: $currentOrderId", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5, color: Colors.black)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black,
                    child: const Text("PENDING HANDOVER", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Text(pass['product_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
              const SizedBox(height: 4),
              Text("ASSIGNED TO IDENTITY REF: USER-${pass['user_id']}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38)),
              const Divider(height: 25, color: Colors.black12),
              const Text("ENTER CLIENT SECURE UNLOCK PASSCODE:", style: TextStyle(color: Colors.black54, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      keyboardType: TextInputType.text,
                      cursorColor: Colors.black,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 4),
                      decoration: const InputDecoration(
                        hintText: "000-000",
                        hintStyle: TextStyle(color: Colors.black26, letterSpacing: 4),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.5)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () async {
                      String cleanUserInput = textController.text.toString().trim();
                      if (cleanUserInput == genuineSecureCode) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(backgroundColor: Colors.black, content: Text("PASS AUTHENTICATED • CODE IS CORRECT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)))
                        );
                        setState(() => _isLoading = true);
                        try {
                          await Supabase.instance.client
                              .from('orders')
                              .update({"status": "COLLECTED"})
                              .eq('order_id', currentOrderId);
                          _syncAllCommandCenterData();
                        } catch (e) {
                          print("❌ AUTHENTICATION SUBMISSION FAULT: $e");
                          setState(() => _isLoading = false);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(backgroundColor: Colors.redAccent, content: Text("SECURITY ERROR: INCORRECT PASSCODE ENTERED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)))
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      color: Colors.black,
                      child: const Text("VERIFY PASS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1)),
                    ),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedbackTabSection() {
    if (_isFeedbackLoading) return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1.5)));
    if (_userFeedbackInbox.isEmpty) return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 50), child: Text("NO CUSTOMER ISSUES LOGGED IN INBOX", style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold))));
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userFeedbackInbox.length,
      separatorBuilder: (context, index) => const Divider(color: Color(0xFFF5F5F5), thickness: 1.5, height: 25),
      itemBuilder: (context, index) {
        final ticket = _userFeedbackInbox[index];
        final dynamic ticketId = ticket['id'];
        final bool isExpanded = _expandedTicketIds.contains(ticketId);
        String ticketType = (ticket['type'] ?? 'HELP TICKET').toString().toUpperCase();

        return Container(
          color: const Color(0xFFFAFAFA),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedTicketIds.remove(ticketId);
                    } else {
                      _expandedTicketIds.add(ticketId);
                    }
                  });                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_down_sharp : Icons.keyboard_arrow_right_sharp,
                            color: Colors.black,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: Colors.black12,
                            child: Text(
                                ticketType,
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 0.5)
                            ),
                          ),
                        ],
                      ),
                      Text(
                          (ticket['timestamp'] ?? '').toString().split('T').first,
                          style: const TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Colors.black12, height: 10),
                      const SizedBox(height: 5),
                      const Text(
                          "SUBMITTED ACCOUNT REPORT METADATA:",
                          style: TextStyle(color: Colors.black38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                      ),
                      const SizedBox(height: 6),
                      Text(
                          "CLIENT NAME: ${ticket['client_name']}".toUpperCase(),
                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                      ),
                      const SizedBox(height: 3),
                      Text(
                          "GMAIL ADDRESS: ${ticket['client_gmail']}".toUpperCase(),
                          style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                      ),
                      const SizedBox(height: 4),
                      Text(
                          "PROFILE SYSTEM ID: ${ticket['user_id']}".toUpperCase(),
                          style: const TextStyle(color: Colors.black45, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                      ),
                      const Divider(color: Colors.black12, height: 20),
                      const Text(
                          "INBOX CRITIQUE MESSAGE:",
                          style: TextStyle(color: Colors.black38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                      ),
                      const SizedBox(height: 6),
                      Text(
                          ticket['message'] ?? '',
                          style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold, height: 1.4)
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () => _executeFeedbackClearance(ticketId),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black, width: 1.2)
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.check_circle_outline_sharp, color: Colors.black, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                      "RESOLVED",
                                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 1)
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemAction(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.5)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
          Icon(icon, size: 18, color: Colors.black),
        ],
      ),
    );
  }
}


