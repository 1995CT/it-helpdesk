import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});
  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  final DatabaseService _db = DatabaseService();
  int _totalTickets = 0;
  int _old90Tickets = 0;
  int _old180Tickets = 0;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final total = await _db.getTicketCount();
    final old90 = await _db.getOldTicketCount(90);
    final old180 = await _db.getOldTicketCount(180);
    final users = await _loadUsers();
    if (mounted) setState(() {
      _totalTickets = total;
      _old90Tickets = old90;
      _old180Tickets = old180;
      _users = users;
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id, username, role')
          .order('username');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Future<bool> _confirmAction(String title, String message, {bool isDanger = true}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger ? Colors.redAccent : const Color(0xFF38BDF8),
            ),
            child: Text(isDanger ? "Delete" : "OK",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteOldTickets(int days) async {
    final count = days == 90 ? _old90Tickets : _old180Tickets;
    if (count == 0) {
      _showSnack("No old completed tickets found", Colors.orange);
      return;
    }
    final ok = await _confirmAction(
      "Delete Old Tickets?",
      "$count completed tickets ($days+ days old) permanently delete thase.\n\nAa action undo nahi thai shake!",
    );
    if (!ok) return;

    try {
      final deleted = await _db.deleteOldTickets(days);
      _showSnack("$deleted tickets deleted", Colors.green);
      _loadStats();
    } catch (e) {
      _showSnack("Error: $e", Colors.red);
    }
  }

  Future<void> _deleteAllTickets() async {
    if (_totalTickets == 0) {
      _showSnack("No tickets to delete", Colors.orange);
      return;
    }
    // Double confirm for full wipe
    final ok1 = await _confirmAction(
      "Delete ALL Tickets?",
      "BADHA $_totalTickets tickets permanently delete thase!\n\nAa action undo nahi thai shake!",
    );
    if (!ok1) return;
    final ok2 = await _confirmAction(
      "Are you SURE?",
      "Last warning! $_totalTickets tickets permanently delete thase. Type kari ne confirm karo.",
    );
    if (!ok2) return;

    try {
      final deleted = await _db.deleteAllTickets();
      _showSnack("$deleted tickets deleted — fresh start!", Colors.green);
      _loadStats();
    } catch (e) {
      _showSnack("Error: $e", Colors.red);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (user['id'] == currentUid) {
      _showSnack("Tamaro potano account delete nai thai shake!", Colors.orange);
      return;
    }
    final ok = await _confirmAction(
      "Delete User?",
      "\"${user['username']}\" ane emni badhi tickets permanently delete thase.\n\nAa action undo nahi thai shake!",
    );
    if (!ok) return;

    try {
      await _db.deleteUser(user['id']);
      _showSnack("${user['username']} deleted", Colors.green);
      _loadStats();
    } catch (e) {
      _showSnack("Error: $e", Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Data Management", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF38BDF8)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: const Color(0xFF38BDF8),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox("Total\nTickets", _totalTickets, const Color(0xFF38BDF8)),
                        _buildStatBox("90+ Days\nCompleted", _old90Tickets, Colors.orangeAccent),
                        _buildStatBox("Total\nUsers", _users.length, Colors.greenAccent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section: Ticket Cleanup
                  const Text("Ticket Cleanup", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Completed (Done) tickets delete thase. Pending tickets safe rehse.",
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 12),

                  _buildActionCard(
                    icon: Icons.auto_delete_rounded,
                    iconColor: Colors.orangeAccent,
                    title: "Delete 90+ Days Old",
                    subtitle: "$_old90Tickets completed tickets (3 month thi juna)",
                    onTap: () => _deleteOldTickets(90),
                  ),
                  const SizedBox(height: 8),

                  _buildActionCard(
                    icon: Icons.delete_sweep_rounded,
                    iconColor: Colors.deepOrangeAccent,
                    title: "Delete 180+ Days Old",
                    subtitle: "$_old180Tickets completed tickets (6 month thi juna)",
                    onTap: () => _deleteOldTickets(180),
                  ),
                  const SizedBox(height: 24),

                  // Section: Danger Zone
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.warning_rounded, color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text("Danger Zone", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                        ]),
                        const SizedBox(height: 12),

                        _buildActionCard(
                          icon: Icons.delete_forever_rounded,
                          iconColor: Colors.redAccent,
                          title: "Delete ALL Tickets",
                          subtitle: "Badha $_totalTickets tickets permanently delete (fresh start)",
                          onTap: _deleteAllTickets,
                          isDanger: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section: User Management
                  Text("Delete Users (${_users.length})",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("User delete karva thi emni badhi tickets pan delete thase.",
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 12),

                  ..._users.map((user) {
                    final isCurrentUser = user['id'] == Supabase.instance.client.auth.currentUser?.id;
                    final isAdmin = user['role'] == 'admin';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrentUser ? Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)) : null,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isAdmin
                                ? Colors.amberAccent.withOpacity(0.15)
                                : const Color(0xFF38BDF8).withOpacity(0.15),
                            child: Icon(
                              isAdmin ? Icons.admin_panel_settings : Icons.person,
                              color: isAdmin ? Colors.amberAccent : const Color(0xFF38BDF8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(user['username'] ?? 'Unknown',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF38BDF8).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text("You", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ]),
                                Text(user['role'] ?? 'engineer',
                                    style: TextStyle(
                                      color: isAdmin ? Colors.amberAccent : Colors.white38,
                                      fontSize: 12,
                                    )),
                              ],
                            ),
                          ),
                          if (!isCurrentUser)
                            IconButton(
                              onPressed: () => _deleteUser(user),
                              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.lock_rounded, color: Colors.white24, size: 18),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildStatBox(String label, int count, Color color) {
    return Column(children: [
      Text(count.toString(),
          style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
    ]);
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDanger ? Colors.redAccent.withOpacity(0.05) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: isDanger ? Border.all(color: Colors.redAccent.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                      color: isDanger ? Colors.redAccent : Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDanger ? Colors.redAccent.withOpacity(0.5) : Colors.white24),
          ],
        ),
      ),
    );
  }
}
