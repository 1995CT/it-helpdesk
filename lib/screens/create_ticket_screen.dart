import "dart:io";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:image_picker/image_picker.dart";
import "package:file_picker/file_picker.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "dart:typed_data";
import "../services/database.dart";
import "../services/onedrive_service.dart";

class CreateTicketScreen extends StatefulWidget {
  final Map<String, dynamic>? existingTicket;
  const CreateTicketScreen({super.key, this.existingTicket});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  final _resolutionCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  String? _selectedCategory;
  String _selectedStatus = "Done";
  bool _isSubmitting = false;

  XFile? _photo;
  PlatformFile? _attachment;

  final DatabaseService _db = DatabaseService();
  String _currentITAdminId = "IT Admin";
  List<Map<String, String>> _categoriesWithDesc = [];
  List<String> _categories = [];
  bool _loadingCategories = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAdminName();
    _loadCategories();
    if (widget.existingTicket != null) {
      final t = widget.existingTicket!;
      _selectedCategory = t['category'];
      _userCtrl.text = t['caller_name'] ?? "";
      _problemCtrl.text = t['problem'] ?? "";
      _resolutionCtrl.text = t['resolution'] ?? "";
      _remarksCtrl.text = t['remarks'] ?? "";
      _selectedStatus = t['status'] ?? "Pending";
    }
  }

  Future<void> _loadAdminName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('saved_username') ?? 'IT Admin';
    if (mounted) setState(() => _currentITAdminId = name.toUpperCase());
  }

  Future<void> _loadCategories() async {
    final catsWithDesc = await _db.getCategoriesWithDesc();
    if (mounted) {
      setState(() {
        _categoriesWithDesc = catsWithDesc;
        _categories = catsWithDesc.map((c) => c['name']!).toList();
        _loadingCategories = false;
        if (_selectedCategory == null && _categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    }
  }

  String _getDescForCategory(String name) {
    final match = _categoriesWithDesc.where((c) => c['name'] == name);
    return match.isNotEmpty ? match.first['description'] ?? '' : '';
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 40,
    );
    if (image != null) {
      setState(() => _photo = image);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => _attachment = result.files.first);
    }
  }

  Future<String?> _uploadFile(String folder, String fileName, Uint8List bytes) async {
    try {
      final oneDriveConnected = await OneDriveService.isConnected();
      if (oneDriveConnected) {
        final url = await OneDriveService.uploadFile(folder, fileName, bytes);
        if (url != null) return url;
      }
    } catch (_) {}

    try {
      final ext = fileName.contains('.') ? fileName.split('.').last : 'bin';
      final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage
          .from('ticket-media')
          .uploadBinary(path, bytes);
      return Supabase.instance.client.storage
          .from('ticket-media')
          .getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        String? photoUrl;
        if (_photo != null) {
          photoUrl = await _uploadFile('photos', _photo!.name, await _photo!.readAsBytes());
        }

        String? attachUrl;
        if (_attachment != null) {
          final bytes = kIsWeb ? _attachment!.bytes : await File(_attachment!.path!).readAsBytes();
          if (bytes != null) {
            attachUrl = await _uploadFile('docs', _attachment!.name, bytes);
          }
        }

        if (widget.existingTicket != null) {
          final updates = <String, dynamic>{
            'caller_name': _userCtrl.text,
            'category': _selectedCategory,
            'problem': _problemCtrl.text,
            'resolution': _resolutionCtrl.text,
            'remarks': _remarksCtrl.text,
            'status': _selectedStatus,
          };
          if (photoUrl != null) updates['before_photo_url'] = photoUrl;
          if (attachUrl != null) updates['attachment_url'] = attachUrl;
          await _db.updateTicket(widget.existingTicket!['id'], updates);
        } else {
          await _db.insertTicket({
            'caller_name': _userCtrl.text,
            'category': _selectedCategory,
            'problem': _problemCtrl.text,
            'resolution': _resolutionCtrl.text,
            'remarks': _remarksCtrl.text,
            'before_photo_url': photoUrl,
            'attachment_url': attachUrl,
            'status': _selectedStatus,
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(widget.existingTicket != null ? "Ticket Updated!" : "Ticket Saved!"),
              backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Error: ${e.toString()}"),
              backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
          title: Text(widget.existingTicket != null ? "Edit Ticket" : "New Ticket",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.transparent,
          toolbarHeight: 48),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        color: const Color(0xFF0F172A),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text(widget.existingTicket != null ? "Update Ticket" : "Save Ticket",
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTextField("User / Dept Name", Icons.person, _userCtrl),
                  const SizedBox(height: 14),

              if (_loadingCategories)
                const LinearProgressIndicator(color: Color(0xFF38BDF8))
              else
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: "Category",
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.category, color: Color(0xFF38BDF8), size: 20),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  selectedItemBuilder: (context) => _categories
                      .map((c) => Align(alignment: Alignment.centerLeft, child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                  validator: (val) => val == null ? "Select category" : null,
                ),
              if (_selectedCategory != null && _getDescForCategory(_selectedCategory!).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Text(_getDescForCategory(_selectedCategory!),
                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                ),
              const SizedBox(height: 14),

              if (widget.existingTicket != null) ...[
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "Status",
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.flag_rounded, color: Color(0xFF38BDF8), size: 20),
                  ),
                  items: ["Pending", "In Progress", "Done"]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStatus = val!),
                ),
                const SizedBox(height: 14),
              ],

              _buildExpandableField("Problem", Icons.warning_amber_rounded, _problemCtrl),
              const SizedBox(height: 12),

              _buildExpandableField("Resolution", Icons.check_circle_outline, _resolutionCtrl),
              const SizedBox(height: 12),

              _buildExpandableField("Remarks (optional)", Icons.notes, _remarksCtrl, isRequired: false),
              const SizedBox(height: 14),

              // Photo & Attachment — compact row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickImage,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_photo != null ? Icons.check_circle : Icons.camera_alt_outlined,
                                color: _photo != null ? Colors.greenAccent : const Color(0xFF38BDF8), size: 20),
                            const SizedBox(width: 8),
                            Text(_photo != null ? "Photo Added" : "Add Photo",
                                style: TextStyle(
                                    color: _photo != null ? Colors.greenAccent : Colors.white54, fontSize: 13)),
                            if (_photo != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => setState(() => _photo = null),
                                child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _pickFile,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_attachment != null ? Icons.check_circle : Icons.attach_file,
                                color: _attachment != null ? Colors.greenAccent : const Color(0xFF38BDF8), size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                  _attachment != null ? _attachment!.name : "Attach File",
                                  style: TextStyle(
                                      color: _attachment != null ? Colors.greenAccent : Colors.white54, fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (_attachment != null) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => _attachment = null),
                                child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Info bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Text(DateFormat("dd MMM yyyy, hh:mm a").format(DateTime.now()),
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const Spacer(),
                    Text("By: $_currentITAdminId",
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
      validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
    );
  }

  Widget _buildExpandableField(String label, IconData icon, TextEditingController ctrl,
      {bool isRequired = true}) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      minLines: 1,
      maxLines: 8,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
      validator: (val) {
        if (isRequired && (val == null || val.isEmpty)) return "Required";
        return null;
      },
    );
  }
}
