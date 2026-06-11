import 'package:flutter/material.dart';
import '../services/database.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});
  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, String>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cats = await _db.getCategoriesWithDesc();
    if (mounted) setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  Future<void> _addCategory() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Add Category", style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl, autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: "Category name", hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8)))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 2,
            decoration: const InputDecoration(hintText: "Description (keva problems cover thay)", hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8)))),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'desc': descCtrl.text.trim()}),
              child: const Text("Add", style: TextStyle(color: Color(0xFF38BDF8)))),
        ],
      ),
    );
    if (result != null && result['name']!.isNotEmpty) {
      try {
        await _db.addCategory(result['name']!, description: result['desc'] ?? '');
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _editCategory(String oldName, String oldDesc) async {
    final nameCtrl = TextEditingController(text: oldName);
    final descCtrl = TextEditingController(text: oldDesc);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Edit Category", style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl, autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: "Name", labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8)))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Description", labelStyle: TextStyle(color: Colors.white54, fontSize: 13),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8)))),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'desc': descCtrl.text.trim()}),
              child: const Text("Save", style: TextStyle(color: Color(0xFF38BDF8)))),
        ],
      ),
    );
    if (result != null && result['name']!.isNotEmpty) {
      await _db.updateCategory(oldName, newName: result['name'], description: result['desc']);
      _load();
    }
  }

  Future<void> _deleteCategory(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Delete Category?", style: TextStyle(color: Colors.white)),
        content: Text("\"$name\" permanently delete thase.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      await _db.removeCategory(name);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Manage Categories", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF38BDF8)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _addCategory,
            icon: const Icon(Icons.add_circle_rounded, color: Colors.greenAccent, size: 28),
            tooltip: "Add Category",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _categories.isEmpty
              ? const Center(child: Text("No categories", style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final name = cat['name'] ?? '';
                    final desc = cat['description'] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26, height: 26,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(child: Text("${index + 1}",
                                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.3)),
                              ],
                            ],
                          )),
                          IconButton(
                            onPressed: () => _editCategory(name, desc),
                            icon: const Icon(Icons.edit_rounded, color: Colors.white38, size: 18),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                          IconButton(
                            onPressed: () => _deleteCategory(name),
                            icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 18),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
