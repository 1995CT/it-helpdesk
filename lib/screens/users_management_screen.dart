import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});
  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<Map<String, dynamic>> _resetRequests = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .order('username');
      final requests = await Supabase.instance.client
          .from('pin_reset_requests')
          .select('*')
          .eq('status', 'pending')
          .order('requested_at', ascending: false);
      if (mounted) setState(() {
        _allUsers = List<Map<String, dynamic>>.from(response);
        _filteredUsers = _allUsers;
        _resetRequests = List<Map<String, dynamic>>.from(requests);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = _allUsers
          .where((u) => u['username'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _approveReset(Map<String, dynamic> request) async {
    try {
      await Supabase.instance.client
          .from('pin_reset_requests')
          .update({'status': 'approved', 'resolved_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', request['id']);
      _fetchUsers();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("✅ ${request['username']} reset approved! They can now set a new PIN."),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }


  String _getOnlineStatus(Map<String, dynamic> user) {
    final lastSeen = user['last_seen'];
    final isOnline = user['is_online'] == true;
    if (isOnline) return 'online';
    if (lastSeen == null) return 'never';
    final diff = DateTime.now().difference(DateTime.parse(lastSeen));
    if (diff.inMinutes < 5) return 'recent';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _getOnlineColor(Map<String, dynamic> user) {
    final status = _getOnlineStatus(user);
    if (status == 'online') return Colors.greenAccent;
    if (status == 'recent') return Colors.yellowAccent;
    if (status == 'never') return Colors.white24;
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = _allUsers.where((u) => u['is_online'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Row(children: [
          const Text("Engineer Management", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (_resetRequests.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(12)),
              child: Text("${_resetRequests.length}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ]),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchUsers, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8))),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filterUsers,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search engineers...",
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : RefreshIndicator(
              onRefresh: _fetchUsers,
              color: const Color(0xFF38BDF8),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 8),

                  // Stats Row
                  Row(children: [
                    _buildStatChip(Icons.people_rounded, "${_allUsers.length} Total", const Color(0xFF38BDF8)),
                    const SizedBox(width: 10),
                    _buildStatChip(Icons.circle, "$onlineCount Online", Colors.greenAccent),
                    const SizedBox(width: 10),
                    _buildStatChip(Icons.engineering_rounded, "${_allUsers.where((u) => u['role'] == 'engineer').length} Engineers", Colors.white54),
                  ]),
                  const SizedBox(height: 16),

                  // PIN Reset Requests
                  if (_resetRequests.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.lock_reset_rounded, color: Colors.orangeAccent, size: 18),
                            const SizedBox(width: 8),
                            Text("PIN Reset Requests (${_resetRequests.length})",
                                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 12),
                          ..._resetRequests.map((req) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              const Icon(Icons.person_rounded, color: Colors.white54, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(req['username'].toString().toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text(req['requested_at'].toString().substring(0, 16).replaceAll('T', ' '),
                                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ])),
                              ElevatedButton(
                                onPressed: () => _approveReset(req),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orangeAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text("Approve", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ]),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // User List
                  ..._filteredUsers.map((user) {
                    final status = _getOnlineStatus(user);
                    final statusColor = _getOnlineColor(user);
                    final isOnline = status == 'online';
                    final role = (user['role'] ?? 'engineer').toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: isOnline ? Border.all(color: Colors.greenAccent.withOpacity(0.3)) : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Stack(children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF38BDF8).withOpacity(0.15),
                            child: Text(user['username'][0].toUpperCase(),
                                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                          ),
                          Positioned(bottom: 0, right: 0,
                            child: Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: statusColor, shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF1E293B), width: 2),
                              ),
                            )),
                        ]),
                        title: Row(children: [
                          Text(user['username'].toString().toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          if (role == 'admin')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                              child: const Text("ADMIN", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ]),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.circle, size: 8, color: statusColor),
                            const SizedBox(width: 4),
                            Text(isOnline ? "Online" : status == 'never' ? "Never logged in" : "Last seen: $status",
                                style: TextStyle(color: statusColor, fontSize: 12)),
                          ]),
                          const SizedBox(height: 2),
                          Text("PIN: ****  •  Role: ${role.toUpperCase()}",
                              style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ]),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber),
                          color: const Color(0xFF1E293B),
                          onSelected: (newRole) async {
                            await Supabase.instance.client
                                .from('profiles').update({'role': newRole}).eq('id', user['id']);
                            _fetchUsers();
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Role updated to $newRole"), backgroundColor: Colors.green));
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'admin', child: Text("Make Admin", style: TextStyle(color: Colors.white))),
                            const PopupMenuItem(value: 'engineer', child: Text("Make Engineer", style: TextStyle(color: Colors.white))),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
