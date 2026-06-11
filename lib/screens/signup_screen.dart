import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _userCtrl = TextEditingController();
  final List<TextEditingController> _pinCtrls =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes =
      List.generate(4, (_) => FocusNode());
  bool _isLoading = false;

  String get _fullPin => _pinCtrls.map((c) => c.text).join();

  @override
  void dispose() {
    _userCtrl.dispose();
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
      }
    } else {
      setState(() {});
      if (index > 0) _pinFocusNodes[index - 1].requestFocus();
    }
  }

  void _signup() async {
    final username = _userCtrl.text.trim().toLowerCase();
    final pin = _fullPin;

    if (username.isEmpty || pin.length != 4) {
      _showError("Username ane 4-digit PIN jaruri che");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fakeEmail = '$username@helpdesk.local';
      const backendPassword = String.fromEnvironment('BACKEND_PASSWORD');

      final res = await Supabase.instance.client.auth.signUp(
        email: fakeEmail,
        password: backendPassword,
      );

      if (res.user != null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': res.user!.id,
          'username': username,
          'pin': pin,
          'role': 'engineer',
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_pin', pin);
        await prefs.setString('saved_role', 'engineer');

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
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
          color: isFilled ? const Color(0xFF38BDF8) : Colors.white24,
          width: isFilled ? 2 : 1,
        ),
        boxShadow: isFilled
            ? [BoxShadow(
                color: const Color(0xFF38BDF8).withOpacity(0.2),
                blurRadius: 8)]
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
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF38BDF8)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.person_add_rounded,
                  size: 80, color: Color(0xFF38BDF8)),
              const SizedBox(height: 20),
              const Text("Engineer Signup",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

              // Username field
              TextFormField(
                controller: _userCtrl,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _pinFocusNodes[0].requestFocus(),
                decoration: InputDecoration(
                  hintText: "Enter Name (Username)",
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.person_outline,
                      color: Color(0xFF38BDF8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),

              // PIN label
              const Text("Set your 4-Digit PIN",
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
              const SizedBox(height: 16),

              // 4-Box UPI Style PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => _buildPinBox(i)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  for (var c in _pinCtrls) c.clear();
                  setState(() {});
                  _pinFocusNodes[0].requestFocus();
                },
                child: const Text("Clear PIN",
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("SIGN UP & LOGIN",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
