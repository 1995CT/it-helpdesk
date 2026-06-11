import 'package:flutter/material.dart';
import '../services/onedrive_service.dart';

class OneDriveSettingsScreen extends StatefulWidget {
  const OneDriveSettingsScreen({super.key});

  @override
  State<OneDriveSettingsScreen> createState() => _OneDriveSettingsScreenState();
}

class _OneDriveSettingsScreenState extends State<OneDriveSettingsScreen> {
  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() => _isLoading = true);
    final connected = await OneDriveService.isConnected();
    if (mounted) setState(() {
      _isConnected = connected;
      _isLoading = false;
    });
  }

  Future<void> _disconnect() async {
    await OneDriveService.disconnect();
    _checkConnection();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OneDrive disconnected"), backgroundColor: Colors.orange));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("OneDrive Storage", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF38BDF8)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Microsoft OneDrive icon
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0078D4).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_rounded, size: 45, color: Color(0xFF0078D4)),
            ),
            const SizedBox(height: 20),
            const Text("Microsoft OneDrive", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Photos & attachments OneDrive maa save thashe\n1 TB free space",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6)),
            const SizedBox(height: 40),

            if (_isLoading)
              const CircularProgressIndicator(color: Color(0xFF38BDF8))
            else if (_isConnected) ...[
              // Connected state
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                ),
                child: Column(children: [
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
                    SizedBox(width: 12),
                    Text("OneDrive Connected!", style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  const Text("Badha nava photos ane attachments\ntamari OneDrive maa save thashe.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _disconnect,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Disconnect OneDrive", style: TextStyle(color: Colors.redAccent)),
                  ),
                ]),
              ),
            ] else ...[
              // Not connected state
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(children: [
                  const Text("Connect karva Microsoft login thashe",
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 8),
                  const Text("• 1 TB free storage\n• Photos auto-compressed\n• Company data secure rahese",
                      style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.8)),
                ]),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => OneDriveService.startAuthFlow(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0078D4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  label: const Text("Connect Microsoft OneDrive",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("ℹ️ Kem kaam karse?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("Connect karya pachi, jyare koi navi ticket banave ane photo/attachment add kare, te automatically tamari Office OneDrive maa 'IT-Helpdesk' folder maa save thashe. Ticket maa view button thi khulshe.",
                    style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
