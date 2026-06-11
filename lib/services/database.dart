import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getTickets() async {
    try {
      final response = await _supabase
          .from('tickets')
          .select('*, profiles(username)')
          .order('created_at', ascending: false);
      
      // Map response to expected format
      return (response as List).map((t) {
        return {
          'id': t['id'],
          'title': '${t['category']} Issue',
          'category': t['category'],
          'problem': t['problem'],
          'resolution': t['resolution'],
          'remarks': t['remarks'],
          'user_name': t['profiles']?['username'] ?? 'Unknown',
          'user_id': t['user_id'],
          'caller_name': t['caller_name'] ?? '',
          'before_photo_url': t['before_photo_url'],
          'after_photo_url': t['after_photo_url'],
          'attachment_url': t['attachment_url'],
          'status': t['status'],
          'created_at': t['created_at'],
        };
      }).toList();
    } catch (e) {
      print("Error fetching tickets: $e");
      return [];
    }
  }

  Future<void> insertTicket(Map<String, dynamic> ticketData) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    await _supabase.from('tickets').insert({
      'user_id': user.id,
      'caller_name': ticketData['caller_name'] ?? '',
      'category': ticketData['category'],
      'problem': ticketData['problem'],
      'resolution': ticketData['resolution'],
      'remarks': ticketData['remarks'],
      'before_photo_url': ticketData['before_photo_url'],
      'after_photo_url': ticketData['after_photo_url'],
      'attachment_url': ticketData['attachment_url'],
      'status': ticketData['status'] ?? 'Done',
    });
  }

  Future<void> updateTicket(int ticketId, Map<String, dynamic> updates) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    // 1. Get old values first (for history comparison)
    Map<String, dynamic> changeLog = {};
    try {
      final old = await _supabase.from('tickets').select().eq('id', ticketId).single();
      for (var key in updates.keys) {
        final oldVal = old[key]?.toString() ?? '';
        final newVal = updates[key]?.toString() ?? '';
        if (oldVal != newVal && updates[key] != null) {
          changeLog[key] = {'from': oldVal, 'to': newVal};
        }
      }
    } catch (_) {
      changeLog = updates.map((k, v) => MapEntry(k, {'to': v.toString()}));
    }

    // 2. Update the ticket
    await _supabase.from('tickets').update(updates).eq('id', ticketId);

    // 3. Log the history with before→after
    if (changeLog.isNotEmpty) {
      try {
        await _supabase.from('ticket_history').insert({
          'ticket_id': ticketId,
          'edited_by': user.id,
          'changes': changeLog,
        });
      } catch (e) {
        print("Warning: ticket_history insert failed. $e");
      }
    }
  }

  Future<List<Map<String, dynamic>>> getTicketHistory(int ticketId) async {
    try {
      final response = await _supabase
          .from('ticket_history')
          .select('*, profiles(username)')
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error fetching history: $e");
      return [];
    }
  }

  Future<List<String>> getProblemHistory(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _supabase
          .from('tickets')
          .select('problem')
          .ilike('problem', '%$query%')
          .limit(10);
      
      final Set<String> problems = {};
      for (var row in response as List) {
        problems.add(row['problem'] as String);
      }
      return problems.toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> getResolutionHistory(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _supabase
          .from('tickets')
          .select('resolution')
          .ilike('resolution', '%$query%')
          .limit(10);

      final Set<String> resolutions = {};
      for (var row in response as List) {
        resolutions.add(row['resolution'] as String);
      }
      return resolutions.toList();
    } catch (e) {
      return [];
    }
  }

  // ─── CATEGORIES (Dynamic) ─────────────────────────────
  static const List<Map<String, String>> _defaultCategories = [
    {'name': 'System Setup & AD Join', 'description': 'PC format, AD join, Windows install, drivers, new joinee setup'},
    {'name': 'Hardware & Repairs', 'description': 'RAM/SSD upgrade, laptop/desktop repair, stock system repair, component change'},
    {'name': 'Software & ERP', 'description': 'Application install/crash, ERP/SAP/Tally, license, antivirus'},
    {'name': 'Network & Switches', 'description': 'Internet, Wi-Fi, LAN cable, switch replace, IP issue, VPN'},
    {'name': 'Email & Accounts', 'description': 'Mailbox full, PST backup, email create/reset, AD account, exit clearance'},
    {'name': 'GitLab & Dev Access', 'description': 'Developer project access, new project create, repo management'},
    {'name': 'Printers & Biometrics', 'description': 'Printer jam/toner, scanner, biometric device, CCTV'},
    {'name': 'Meeting Room & AV', 'description': 'Projector, conference TV, display connect, AV setup'},
    {'name': 'Infra & Physical', 'description': 'Door access plate, lock fix, device mounting, desk shift, cable management'},
  ];

  Future<List<Map<String, String>>> getCategoriesWithDesc() async {
    try {
      final response = await _supabase
          .from('categories')
          .select('name, description')
          .order('sort_order', ascending: true);
      if ((response as List).isEmpty) throw Exception('empty');
      return response.map<Map<String, String>>((r) => {
        'name': r['name'] as String,
        'description': (r['description'] ?? '') as String,
      }).toList();
    } catch (_) {
      return _defaultCategories;
    }
  }

  Future<List<String>> getCategories() async {
    final cats = await getCategoriesWithDesc();
    return cats.map((c) => c['name']!).toList();
  }

  Future<void> addCategory(String name, {String description = ''}) async {
    final maxOrder = await _supabase
        .from('categories')
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1);
    final next = (maxOrder as List).isNotEmpty ? (maxOrder[0]['sort_order'] as int) + 1 : 1;
    await _supabase.from('categories').insert({'name': name, 'description': description, 'sort_order': next});
  }

  Future<void> removeCategory(String name) async {
    await _supabase.from('categories').delete().eq('name', name);
  }

  Future<void> updateCategory(String oldName, {String? newName, String? description}) async {
    final updates = <String, dynamic>{};
    if (newName != null) updates['name'] = newName;
    if (description != null) updates['description'] = description;
    if (updates.isNotEmpty) {
      await _supabase.from('categories').update(updates).eq('name', oldName);
    }
  }

  // ─── DAILY REPORT ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTodayTickets() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toUtc().toIso8601String();
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toUtc().toIso8601String();

      final response = await _supabase
          .from('tickets')
          .select('*, profiles(username)')
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .order('created_at', ascending: false);

      return (response as List).map((t) {
        return {
          'id': t['id'],
          'category': t['category'],
          'problem': t['problem'],
          'resolution': t['resolution'],
          'caller_name': t['caller_name'] ?? '',
          'user_name': t['profiles']?['username'] ?? 'Unknown',
          'status': t['status'],
          'created_at': t['created_at'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── DELETE OPERATIONS (Admin only) ────────────────────
  Future<void> deleteTicket(int ticketId) async {
    // Delete history first (FK), then ticket
    try {
      await _supabase.from('ticket_history').delete().eq('ticket_id', ticketId);
    } catch (_) {}
    await _supabase.from('tickets').delete().eq('id', ticketId);
  }

  Future<int> deleteOldTickets(int daysOld) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysOld)).toUtc().toIso8601String();
    // Get IDs first
    final tickets = await _supabase
        .from('tickets')
        .select('id')
        .eq('status', 'Done')
        .lt('created_at', cutoff);
    final ids = (tickets as List).map((t) => t['id'] as int).toList();
    if (ids.isEmpty) return 0;
    // Delete history, then tickets
    try {
      await _supabase.from('ticket_history').delete().inFilter('ticket_id', ids);
    } catch (_) {}
    await _supabase.from('tickets').delete().inFilter('id', ids);
    return ids.length;
  }

  Future<int> deleteAllTickets() async {
    final tickets = await _supabase.from('tickets').select('id');
    final count = (tickets as List).length;
    if (count == 0) return 0;
    try {
      await _supabase.from('ticket_history').delete().neq('id', 0);
    } catch (_) {}
    await _supabase.from('tickets').delete().neq('id', 0);
    return count;
  }

  Future<void> deleteUser(String userId) async {
    // Delete user's ticket history, tickets, then profile
    try {
      final userTickets = await _supabase.from('tickets').select('id').eq('user_id', userId);
      final ids = (userTickets as List).map((t) => t['id'] as int).toList();
      if (ids.isNotEmpty) {
        await _supabase.from('ticket_history').delete().inFilter('ticket_id', ids);
      }
    } catch (_) {}
    await _supabase.from('tickets').delete().eq('user_id', userId);
    try {
      await _supabase.from('pin_reset_requests').delete().eq('user_id', userId);
    } catch (_) {}
    await _supabase.from('profiles').delete().eq('id', userId);
  }

  Future<int> getTicketCount() async {
    final res = await _supabase.from('tickets').select('id');
    return (res as List).length;
  }

  Future<int> getOldTicketCount(int daysOld) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysOld)).toUtc().toIso8601String();
    final res = await _supabase
        .from('tickets')
        .select('id')
        .eq('status', 'Done')
        .lt('created_at', cutoff);
    return (res as List).length;
  }
}
