import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database.dart';
import 'create_ticket_screen.dart';
import 'analytics_screen.dart';
import 'login_screen.dart';
import 'users_management_screen.dart';
import '../main.dart';
import 'onedrive_settings_screen.dart';
import 'ticket_detail_screen.dart';
import 'category_management_screen.dart';
import 'data_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      }
    }
  }

  void _openCreateTicket() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTicketScreen()),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const DashboardView(),
      const AnalyticsScreen(),
    ];

    final int pageIndex = _currentIndex == 0 ? 0 : 1;
    final int navIndex = _currentIndex == 0 ? 0 : 2;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(child: pages[pageIndex]),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: Colors.white38,
        currentIndex: navIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) {
            _openCreateTicket();
          } else {
            setState(() {
              _currentIndex = index == 0 ? 0 : 1;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              backgroundColor: Color(0xFF38BDF8),
              child: Icon(Icons.add, color: Colors.black),
            ),
            label: 'New Ticket',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
        ],
      ),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;
  String _searchQuery = "";
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    final tickets = await _db.getTickets();
    if (mounted) {
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTickets = _tickets.where((t) {
      final query = _searchQuery.toLowerCase();
      return t['problem'].toString().toLowerCase().contains(query) ||
             t['category'].toString().toLowerCase().contains(query) ||
             t['user_name'].toString().toLowerCase().contains(query);
    }).toList();

    final pendingTickets = filteredTickets.where((t) => t['status'] != 'Done').toList();
    final historyTickets = filteredTickets.where((t) => t['status'] == 'Done').toList();
    
    final displayTickets = _showHistory ? historyTickets : pendingTickets;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("IT Helpdesk", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text("${pendingTickets.length} pending", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Admin Settings Menu
                  FutureBuilder(
                    future: SharedPreferences.getInstance().then((p) => p.getString('saved_role')),
                    builder: (context, snapshot) {
                      final role = snapshot.data?.toString().toLowerCase() ?? '';
                      if (role == 'admin') {
                        return PopupMenuButton<String>(
                          icon: const Icon(Icons.settings_rounded, color: Colors.greenAccent, size: 24),
                          color: const Color(0xFF1E293B),
                          onSelected: (val) {
                            if (val == 'categories') Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagementScreen()));
                            if (val == 'onedrive') Navigator.push(context, MaterialPageRoute(builder: (_) => const OneDriveSettingsScreen()));
                            if (val == 'users') Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersManagementScreen()));
                            if (val == 'data') Navigator.push(context, MaterialPageRoute(builder: (_) => const DataManagementScreen()));
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'categories', child: Row(children: [
                              Icon(Icons.category_rounded, color: Colors.amberAccent, size: 20),
                              SizedBox(width: 10),
                              Text("Categories", style: TextStyle(color: Colors.white)),
                            ])),
                            const PopupMenuItem(value: 'onedrive', child: Row(children: [
                              Icon(Icons.cloud_rounded, color: Color(0xFF0078D4), size: 20),
                              SizedBox(width: 10),
                              Text("OneDrive", style: TextStyle(color: Colors.white)),
                            ])),
                            const PopupMenuItem(value: 'users', child: Row(children: [
                              Icon(Icons.manage_accounts_rounded, color: Colors.greenAccent, size: 20),
                              SizedBox(width: 10),
                              Text("Users", style: TextStyle(color: Colors.white)),
                            ])),
                            const PopupMenuItem(value: 'data', child: Row(children: [
                              Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                              SizedBox(width: 10),
                              Text("Data Management", style: TextStyle(color: Colors.white)),
                            ])),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  IconButton(
                    onPressed: _fetchTickets,
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8), size: 24),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('saved_username');
                      await prefs.remove('saved_pin');
                      await prefs.remove('saved_password');
                      await prefs.remove('saved_role');
                      final uid = Supabase.instance.client.auth.currentUser?.id;
                      if (uid != null) {
                        await Supabase.instance.client.from('profiles')
                            .update({'is_online': false, 'last_seen': DateTime.now().toUtc().toIso8601String()})
                            .eq('id', uid);
                      }
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),
          
          // Toggle Buttons
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showHistory = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_showHistory ? const Color(0xFF38BDF8) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text("Pending", style: TextStyle(color: !_showHistory ? Colors.black : Colors.white54, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showHistory = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _showHistory ? const Color(0xFF38BDF8) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text("History", style: TextStyle(color: _showHistory ? Colors.black : Colors.white54, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15)),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(hintText: "Search issues...", border: InputBorder.none, icon: Icon(Icons.search, color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : displayTickets.isEmpty 
                  ? Center(child: Text(_showHistory ? "No closed tickets yet." : "No pending tickets! 🎉", style: const TextStyle(color: Colors.white38, fontSize: 16)))
                  : ListView.builder(
                    itemCount: displayTickets.length,
                    itemBuilder: (context, index) {
                      final ticket = displayTickets[index];
                      return GestureDetector(
                        onTap: () async {
                          final shouldRefresh = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)),
                          );
                          if (shouldRefresh == true) {
                            _fetchTickets();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(18)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFF38BDF8).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text(ticket['category'], style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                  Text(DateFormat('dd MMM').format(DateTime.parse(ticket['created_at'])), style: const TextStyle(color: Colors.white24, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(ticket['problem'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              if ((ticket['caller_name'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(children: [
                                    const Icon(Icons.person_pin_rounded, size: 14, color: Color(0xFF38BDF8)),
                                    const SizedBox(width: 4),
                                    Text(ticket['caller_name'], style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                                  ]),
                                ),
                              Row(children: [
                                const Icon(Icons.engineering_rounded, size: 14, color: Colors.white38),
                                const SizedBox(width: 4),
                                Text("IT: ${ticket['user_name']}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                              ]),
                            ],
                          ),
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
