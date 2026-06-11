import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' as io;
import '../services/database.dart';
import 'package:intl/intl.dart';
import 'daily_report_screen.dart';

class UserProblemStats {
  final String userName;
  final int totalTickets;
  final Map<String, int> categoryCounts;
  UserProblemStats(this.userName, this.totalTickets, this.categoryCounts);
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _allTickets = [];
  String _timeFilter = "This Month";
  int _userLimit = 10;
  DateTimeRange? _customDateRange;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final tickets = await _db.getTickets();
    setState(() {
      _allTickets = tickets;
      _isLoading = false;
    });
  }

  Future<void> _pickCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _timeFilter = "Custom";
      });
    }
  }

  // Filter tickets based on selection
  List<Map<String, dynamic>> get _filteredTickets {
    final now = DateTime.now();
    return _allTickets.where((t) {
      final date = DateTime.parse(t["created_at"]);
      if (_timeFilter == "This Month") {
        return date.year == now.year && date.month == now.month;
      } else if (_timeFilter == "Quarterly") {
        return now.difference(date).inDays <= 90;
      } else if (_timeFilter == "This Year") {
        return date.year == now.year;
      } else if (_timeFilter == "Custom" && _customDateRange != null) {
        return date.isAfter(
                _customDateRange!.start.subtract(const Duration(days: 1))) &&
            date.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
      }
      return true; // All Time
    }).toList();
  }

  Map<String, int> _getCategoryData() {
    Map<String, int> data = {};
    for (var t in _filteredTickets) {
      final cat = t["category"] as String;
      data[cat] = (data[cat] ?? 0) + 1;
    }
    return data;
  }

  List<UserProblemStats> _getUserData() {
    Map<String, List<String>> userCategories = {};
    for (var t in _filteredTickets) {
      String user = t["user_name"] ?? "Unknown";
      String cat = t["category"] ?? "Other";
      userCategories.putIfAbsent(user, () => []).add(cat);
    }

    List<UserProblemStats> stats = [];
    userCategories.forEach((user, cats) {
      Map<String, int> catCounts = {};
      for (var c in cats) {
        catCounts[c] = (catCounts[c] ?? 0) + 1;
      }
      var sortedCats = Map.fromEntries(catCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)));
      stats.add(UserProblemStats(user, cats.length, sortedCats));
    });

    stats.sort((a, b) => b.totalTickets.compareTo(a.totalTickets));
    return stats.take(_userLimit).toList();
  }

  Future<void> _exportData() async {
    final rows = <List<dynamic>>[
      ["ID", "Caller Name", "Category", "Problem", "Resolution", "Engineer", "Status", "Created At", "Photo URL", "Attachment URL", "Edit Count", "Edit History"]
    ];
    for (var t in _allTickets) {
      // Fetch edit history for each ticket
      String editHistoryText = '';
      int editCount = 0;
      try {
        final history = await _db.getTicketHistory(t["id"]);
        editCount = history.length;
        final historyParts = <String>[];
        for (var h in history) {
          final editor = h['profiles']?['username'] ?? 'Unknown';
          final date = DateTime.parse(h['created_at']);
          final dateStr = DateFormat('dd MMM HH:mm').format(date);
          final changes = h['changes'] as Map<String, dynamic>? ?? {};
          final changeParts = <String>[];
          for (var entry in changes.entries) {
            final val = entry.value;
            if (val is Map && val.containsKey('from') && val.containsKey('to')) {
              changeParts.add('${entry.key}: ${val['from']} -> ${val['to']}');
            } else {
              changeParts.add('${entry.key}: $val');
            }
          }
          historyParts.add('[$dateStr by $editor] ${changeParts.join(', ')}');
        }
        editHistoryText = historyParts.join(' | ');
      } catch (_) {}

      rows.add([
        t["id"],
        t["caller_name"] ?? '',
        t["category"],
        t["problem"],
        t["resolution"],
        t["user_name"],
        t["status"],
        t["created_at"],
        t["before_photo_url"] ?? '',
        t["attachment_url"] ?? '',
        editCount,
        editHistoryText,
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    if (kIsWeb) {
      await Share.share(csv, subject: "IT Helpdesk Export");
    } else {
      final path = "${io.Directory.systemTemp.path}/IT_Helpdesk_Export.csv";
      await io.File(path).writeAsString(csv);
      await Share.shareXFiles([XFile(path)], text: "IT Helpdesk Complete Report");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
    }

    final catData = _getCategoryData();
    final userData = _getUserData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Analytics",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyReportScreen())),
                  icon: const Icon(Icons.today_rounded, color: Colors.black, size: 16),
                  label: const Text("Daily",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _exportData,
                  icon: const Icon(Icons.download, color: Colors.black, size: 16),
                  label: const Text("Export",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ])
            ],
          ),
          const SizedBox(height: 20),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...["This Month", "Quarterly", "This Year", "All Time"]
                    .map((filter) {
                  final isSelected = _timeFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(filter,
                          style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF38BDF8),
                      backgroundColor: const Color(0xFF1E293B),
                      onSelected: (val) {
                        if (val) setState(() => _timeFilter = filter);
                      },
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 16,
                            color: _timeFilter == "Custom"
                                ? Colors.black
                                : Colors.white),
                        const SizedBox(width: 4),
                        Text(
                            _timeFilter == "Custom" && _customDateRange != null
                                ? "${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM').format(_customDateRange!.end)}"
                                : "Custom",
                            style: TextStyle(
                                color: _timeFilter == "Custom"
                                    ? Colors.black
                                    : Colors.white)),
                      ],
                    ),
                    selected: _timeFilter == "Custom",
                    selectedColor: const Color(0xFF38BDF8),
                    backgroundColor: const Color(0xFF1E293B),
                    onSelected: (val) => _pickCustomDateRange(),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 30),

          _buildStatCard("Total Tickets Handled",
              _filteredTickets.length.toString(), Icons.confirmation_num),
          const SizedBox(height: 24),

          const Text("Top Problem Areas",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildPieChart(catData),
          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Most Problematic Users",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: _userLimit,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(
                    color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                underline: const SizedBox(),
                items: [10, 50, 100].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text("Top $value"),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _userLimit = val);
                },
              )
            ],
          ),
          const SizedBox(height: 16),
          _buildCustomUserBars(userData),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.2),
                  shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF38BDF8), size: 32)),
          const SizedBox(width: 20),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> data) {
    if (data.isEmpty) {
      return const SizedBox(
          height: 200,
          child: Center(
              child: Text("No Data", style: TextStyle(color: Colors.white54))));
    }
    final colors = [
      Colors.blue,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.orange,
      Colors.purple,
      Colors.cyan
    ];
    int c = 0;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: data.entries.map((e) {
                  final color = colors[c++ % colors.length];
                  return PieChartSectionData(
                      color: color,
                      value: e.value.toDouble(),
                      title: e.value.toString(),
                      radius: 50,
                      titleStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white));
                }).toList(),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.entries.map((e) {
                final color = colors[
                    (c - data.length + data.keys.toList().indexOf(e.key)) %
                        colors.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: color)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(e.key,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomUserBars(List<UserProblemStats> data) {
    if (data.isEmpty) {
      return const SizedBox(
          height: 200,
          child: Center(
              child: Text("No Data", style: TextStyle(color: Colors.white54))));
    }

    int maxTickets = data.first.totalTickets;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: data.asMap().entries.map((entry) {
          int index = entry.key;
          UserProblemStats stat = entry.value;
          bool isTopOffender = index == 0;

          Color barColor =
              isTopOffender ? Colors.redAccent : const Color(0xFF38BDF8);
          Color textColor = isTopOffender ? Colors.redAccent : Colors.white;

          // Prevent division by zero
          double barFraction =
              maxTickets > 0 ? stat.totalTickets / maxTickets : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Username area
                SizedBox(
                  width: 90,
                  child: Text(stat.userName.split(" ")[0],
                      style: TextStyle(
                          color: textColor,
                          fontWeight: isTopOffender
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                ),

                // Bar & Count Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Tickets: ${stat.totalTickets}",
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: stat.categoryCounts.entries.map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: isTopOffender
                                      ? Colors.redAccent.withOpacity(0.4)
                                      : const Color(0xFF38BDF8)
                                          .withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("${c.key}: ",
                                    style: TextStyle(
                                        color: isTopOffender
                                            ? Colors.red.shade200
                                            : Colors.white70,
                                        fontSize: 11)),
                                Text("${c.value}",
                                    style: TextStyle(
                                        color: isTopOffender
                                            ? Colors.redAccent
                                            : const Color(0xFF38BDF8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      if (index != data.length - 1)
                        Divider(color: Colors.white.withOpacity(0.05)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
