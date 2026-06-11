import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';

class SetNewPinScreen extends StatefulWidget {
  final String userId;
  final String username;
  final int requestId;

  const SetNewPinScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.requestId,
  });

  @override
  State<SetNewPinScreen> createState() => _SetNewPinScreenState();
}

class _SetNewPinScreenState extends State<SetNewPinScreen> {
  final List<TextEditingController> _pinCtrls =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes =
      List.generate(4, (_) => FocusNode());
  bool _isLoading = false;

  String get _fullPin => _pinCtrls.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _pinFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var c in _pinCtrls) c.dispose();
    for (var f in _pinFocusNodes) f.dispose();
    super.dispose();
  }

  void _onPinChanged(int index, String val) {
    if (val.isNotEmpty) {
      setState(() {});
      if (index < 3) {
        _pinFocusNodes[index + 1].requestFocus();
      } else {
        _pinFocusNodes[index].unfocus();
        _saveNewPin();
      }
    } else {
      setState(() {});
      if (index > 0) _pinFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _saveNewPin() async {
    final pin = _fullPin;
    if (pin.length != 4) return;

    setState(() => _isLoading = true);
    try {
      // Login with backend password to authenticate
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: '${widget.username}@helpdesk.local',
        password: const String.fromEnvironment('BACKEND_PASSWORD'),
      );

      if (res.user != null) {
        // Update PIN in profiles
        await Supabase.instance.client
            .from('profiles')
            .update({'pin': pin})
            .eq('id', widget.userId);

        // Delete the reset request
        await Supabase.instance.client
            .from('pin_reset_requests')
            .delete()
            .eq('id', widget.requestId);

        // Save locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_username', widget.username);
        await prefs.setString('saved_pin', pin);

        // Get role
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', widget.userId)
            .single();
        await prefs.setString('saved_role', profile['role'] ?? 'engineer');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("✅ Navo PIN set thayu! Welcome!"),
              backgroundColor: Colors.green));
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        for (var c in _pinCtrls) c.clear();
        setState(() {});
        _pinFocusNodes[0].requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPinBox(int index) {
    final isFilled = _pinCtrls[index].text.isNotEmpty;
    return Container(
      width: 62,
      height: 68,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFilled ? Colors.greenAccent : Colors.white24,
          width: isFilled ? 2 : 1,
        ),
        boxShadow: isFilled
            ? [BoxShadow(
                color: Colors.greenAccent.withOpacity(0.2), blurRadius: 8)]
            : null,
      ),
      child: RawKeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKey: (event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _pinCtrls[index].text.isEmpty &&
              index > 0) {
            _pinFocusNodes[index - 1].requestFocus();
            _pinCtrls[index - 1].clear();
            setState(() {});
          }
        },
        child: TextField(
          controller: _pinCtrls[index],
          focusNode: _pinFocusNodes[index],
          keyboardType: TextInputType.number,
          maxLength: 1,
          textAlign: TextAlign.center,
          obscureText: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (val) => _onPinChanged(index, val),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_open_rounded,
                  size: 80, color: Colors.greenAccent),
              const SizedBox(height: 24),
              const Text("Set New PIN",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(widget.username.toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2)),
              const SizedBox(height: 8),
              const Text("Admin e tamaro PIN reset karyo che.\nNavo 4-digit PIN set karo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6)),
              const SizedBox(height: 40),

              _isLoading
                  ? const CircularProgressIndicator(color: Colors.greenAccent)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) => _buildPinBox(i)),
                    ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  for (var c in _pinCtrls) c.clear();
                  setState(() {});
                  _pinFocusNodes[0].requestFocus();
                },
                child: const Text("Clear",
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),
              const SizedBox(height: 12),
              const Text("4th digit nakhtaj auto save thashe",
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
