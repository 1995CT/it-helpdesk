import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' as io;
import '../services/database.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});
  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final DatabaseService _db = DatabaseService();
  final GlobalKey _reportKey = GlobalKey();
  List<Map<String, dynamic>> _todayTickets = [];
  bool _isLoading = true;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tickets = await _db.getTodayTickets();
    if (mounted) setState(() {
      _todayTickets = tickets;
      _isLoading = false;
    });
  }

  int get _completedCount => _todayTickets.where((t) => t['status'] == 'Done').length;
  int get _pendingCount => _todayTickets.where((t) => t['status'] != 'Done').length;
  int get _totalCount => _todayTickets.length;

  Map<String, List<Map<String, dynamic>>> get _groupedByCategory {
    final map = <String, List<Map<String, dynamic>>>{};
    for (var t in _todayTickets) {
      final cat = t['category'] ?? 'Other';
      map.putIfAbsent(cat, () => []).add(t);
    }
    return map;
  }

  Future<void> _shareReport() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _reportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final today = DateFormat('dd-MMM-yyyy').format(DateTime.now());

      if (kIsWeb) {
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'image/png', name: 'Daily_Report_$today.png')],
          text: 'IT Helpdesk Daily Report - $today',
        );
      } else {
        final path = '${io.Directory.systemTemp.path}/Daily_Report_$today.png';
        await io.File(path).writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(path)],
          text: 'IT Helpdesk Daily Report - $today',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Share failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Daily Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF38BDF8)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            _isSharing
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8))))
                : IconButton(
                    onPressed: _shareReport,
                    icon: const Icon(Icons.share_rounded, color: Color(0xFF38BDF8)),
                    tooltip: "Share via WhatsApp",
                  ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  RepaintBoundary(
                    key: _reportKey,
                    child: _buildReportCard(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSharing ? null : _shareReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: const Text("Share Report",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReportCard() {
    final today = DateFormat('dd MMMM yyyy (EEEE)').format(DateTime.now());
    final grouped = _groupedByCategory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_rounded, color: Color(0xFF38BDF8), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text("IT Helpdesk — Daily Report",
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(today, style: const TextStyle(color: Colors.white54, fontSize: 13)),

          const SizedBox(height: 16),
          // Divider
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat("Completed", _completedCount, Colors.greenAccent),
              _buildStat("Pending", _pendingCount, Colors.orangeAccent),
              _buildStat("Total", _totalCount, const Color(0xFF38BDF8)),
            ],
          ),

          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 16),

          // Tickets by category
          if (_todayTickets.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text("No tickets today", style: TextStyle(color: Colors.white38, fontSize: 14)),
              ),
            )
          else
            ...grouped.entries.map((entry) => _buildCategorySection(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(count.toString(),
            style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildCategorySection(String category, List<Map<String, dynamic>> tickets) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(category,
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          ...tickets.map((t) => _buildTicketRow(t)),
        ],
      ),
    );
  }

  Widget _buildTicketRow(Map<String, dynamic> ticket) {
    final status = ticket['status'] ?? 'Pending';
    final isDone = status == 'Done';

    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16, color: isDone ? Colors.greenAccent : Colors.orangeAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket['problem'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text("User: ${ticket['caller_name'] ?? 'N/A'}",
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(width: 12),
                    Text("Engineer: ${ticket['user_name'] ?? 'N/A'}",
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
