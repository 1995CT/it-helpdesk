import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database.dart';
import 'create_ticket_screen.dart';

class TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _historyLogs = [];
  bool _isLoadingHistory = true;
  bool _canEdit = false;
  late Map<String, dynamic> _currentTicket;

  @override
  void initState() {
    super.initState();
    _currentTicket = Map.from(widget.ticket);
    _checkPermissions();
    _loadHistory();
  }

  void _checkPermissions() async {
    final user = Supabase.instance.client.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('saved_role')?.toLowerCase() ?? 'engineer';
    
    if (user != null) {
      if (role == 'admin' || user.id == _currentTicket['user_id']) {
        setState(() => _canEdit = true);
      }
    }
  }

  Future<void> _loadHistory() async {
    final logs = await _db.getTicketHistory(_currentTicket['id']);
    if (mounted) {
      setState(() {
        _historyLogs = logs;
        _isLoadingHistory = false;
      });
    }
  }

  void _openEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateTicketScreen(existingTicket: _currentTicket)),
    );
    if (result == true && mounted) {
      // Refresh the specific ticket data by navigating back to home or reloading
      Navigator.pop(context, true); // Pop out to home to refresh
    }
  }

  Widget _buildPhotoCard(String label, String url) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenPhoto(url: url, label: label))),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(fit: StackFit.expand, children: [
            Image.network(url, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white38))),
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: Colors.black54,
                child: Text(label, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              )),
          ]),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> log) {
    final date = DateTime.parse(log['created_at']);
    final editor = log['profiles']?['username'] ?? "Unknown User";
    final Map<String, dynamic> changes = log['changes'] ?? {};

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF38BDF8),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 50,
                color: const Color(0xFF38BDF8).withOpacity(0.3),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(editor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(DateFormat('dd MMM, HH:mm').format(date), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("Changes:", style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...changes.entries.map((e) {
                    final val = e.value;
                    String display;
                    if (val is Map && val.containsKey('from') && val.containsKey('to')) {
                      final from = val['from']?.toString() ?? '';
                      final to = val['to']?.toString() ?? '';
                      display = from.isEmpty ? to : '$from  →  $to';
                    } else {
                      display = val.toString();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(display, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _currentTicket['status'] == 'Done';
    final date = DateTime.parse(_currentTicket['created_at']);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Ticket Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF38BDF8)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 22),
              tooltip: "Delete Ticket",
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: const Text("Delete Ticket?", style: TextStyle(color: Colors.white)),
                    content: const Text("Aa ticket permanently delete thase.\nAa action undo nahi thai shake!",
                        style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ],
                  ),
                );
                if (ok == true) {
                  await _db.deleteTicket(_currentTicket['id']);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Ticket deleted"), backgroundColor: Colors.green));
                    Navigator.pop(context, true);
                  }
                }
              },
            ),
        ],
      ),
      floatingActionButton: _canEdit ? FloatingActionButton.extended(
        onPressed: _openEdit,
        backgroundColor: const Color(0xFF38BDF8),
        icon: const Icon(Icons.edit, color: Colors.black),
        label: const Text("Edit Ticket", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ) : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Category Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(_currentTicket['category'], style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.greenAccent.withOpacity(0.1) : Colors.orangeAccent.withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(
                    isDone ? "RESOLVED" : _currentTicket['status'].toUpperCase(), 
                    style: TextStyle(
                      color: isDone ? Colors.greenAccent : Colors.orangeAccent, 
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1
                    )
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Core Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Problem", style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(_currentTicket['problem'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: Colors.white10),
                  ),
                  
                  if ((_currentTicket['caller_name'] ?? '').toString().isNotEmpty) ...[
                    Row(children: [
                      const Icon(Icons.person_pin_rounded, color: Color(0xFF38BDF8), size: 20),
                      const SizedBox(width: 8),
                      Text("Caller: ${_currentTicket['caller_name']}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.engineering_rounded, color: Color(0xFF38BDF8), size: 20),
                      const SizedBox(width: 8),
                      Text("IT Admin: ${_currentTicket['user_name']}", style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 8),
                      Text("Created: ${DateFormat('dd MMM yyyy, hh:mm a').format(date)}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Photo Section
            if (_currentTicket['before_photo_url'] != null) ...[
              const Text("Photo", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildPhotoCard("Photo", _currentTicket['before_photo_url']),
              const SizedBox(height: 24),
            ],

            // Attachment Section
            if (_currentTicket['attachment_url'] != null) ...[
              const Text("Attachment", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final url = Uri.parse(_currentTicket['attachment_url']);
                  if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.attach_file_rounded, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 12),
                    const Expanded(child: Text("Open Attachment", style: TextStyle(color: Colors.white, fontSize: 15))),
                    const Icon(Icons.open_in_new_rounded, color: Colors.white38, size: 18),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Resolution Section
            if (_currentTicket['resolution'] != null && _currentTicket['resolution'].toString().isNotEmpty) ...[
              const Text("Resolution", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                ),
                child: Text(_currentTicket['resolution'], style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
              ),
              const SizedBox(height: 24),
            ],

            if (_currentTicket['remarks'] != null && _currentTicket['remarks'].toString().isNotEmpty) ...[
              const Text("Remarks", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_currentTicket['remarks'], style: const TextStyle(color: Colors.white70, fontSize: 15)),
              ),
              const SizedBox(height: 24),
            ],

            // Audit Log / History
            const Text("Audit Log", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_isLoadingHistory)
              const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
            else if (_historyLogs.isEmpty)
              const Text("No edits made to this ticket.", style: TextStyle(color: Colors.white38, fontSize: 14))
            else
              ..._historyLogs.map(_buildTimelineItem),
            
            const SizedBox(height: 80), // Padding for FAB
          ],
        ),
      ),
    );
  }
}

// Full-screen photo viewer
class _FullScreenPhoto extends StatelessWidget {
  final String url;
  final String label;
  const _FullScreenPhoto({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(label, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38, size: 80)),
        ),
      ),
    );
  }
}
