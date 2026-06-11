import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/onedrive_service.dart';
import 'set_new_pin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final List<TextEditingController> _pinCtrls =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes =
      List.generate(4, (_) => FocusNode());

  bool _isLoading = false;
  bool _hasSavedUser = false;

  String get _fullPin => _pinCtrls.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    for (var c in _pinCtrls) c.dispose();
    for (var f in _pinFocusNodes) f.dispose();
    super.dispose();
  }

  void _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('saved_username');
    if (user != null && user.isNotEmpty && mounted) {
      setState(() {
        _userCtrl.text = user;
        _hasSavedUser = true;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _pinFocusNodes[0].requestFocus();
      });
    }
  }

  void _clearPin() {
    for (var c in _pinCtrls) c.clear();
    setState(() {});
    _pinFocusNodes[0].requestFocus();
  }

  void _onPinChanged(int index, String val) {
    if (val.isNotEmpty) {
      setState(() {});
      if (index < 3) {
        _pinFocusNodes[index + 1].requestFocus();
      } else {
        _pinFocusNodes[index].unfocus();
        _login();
      }
    } else {
      setState(() {});
      if (index > 0) {
        _pinFocusNodes[index - 1].requestFocus();
      }
    }
  }

  void _login() async {
    final username = _userCtrl.text.trim().toLowerCase();
    final inputPin = _fullPin;

    if (username.isEmpty || inputPin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Username and 4-digit PIN are required"),
              backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fakeEmail = '$username@helpdesk.local';
      const backendPassword = String.fromEnvironment('BACKEND_PASSWORD');

      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: fakeEmail,
        password: backendPassword,
      );

      if (res.user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('pin, role')
            .eq('id', res.user!.id)
            .single();

        final dbPin = profile['pin']?.toString() ?? '';
        final role = profile['role']?.toString() ?? 'engineer';

        if (inputPin == dbPin) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_username', username);
          await prefs.setString('saved_pin', inputPin);
          await prefs.setString('saved_role', role);
          await Supabase.instance.client.from('profiles')
              .update({'is_online': true, 'last_seen': DateTime.now().toUtc().toIso8601String()})
              .eq('id', res.user!.id);
          await OneDriveService.flushPendingTokens();
          if (mounted) _goHome();
        } else {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            _clearPin();
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("❌ Incorrect PIN! Try again."),
                    backgroundColor: Colors.red));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _clearPin();
        final msg = e.toString().contains('Invalid login credentials')
            ? "User not found. Check username."
            : "Login failed. Check connection.";
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("❌ $msg"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Future<void> _forgotPin() async {
    final username = _userCtrl.text.trim().toLowerCase();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Pehla username nakho"),
          backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id, username')
          .eq('username', username)
          .maybeSingle();

      if (profile == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("❌ Username maldyu nahi"),
            backgroundColor: Colors.red));
        return;
      }

      final existing = await Supabase.instance.client
          .from('pin_reset_requests')
          .select('id, status')
          .eq('user_id', profile['id'])
          .eq('status', 'pending')
          .maybeSingle();

      if (existing != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("⏳ Request pehla thi j mokli che — Admin approve karse"),
            backgroundColor: Colors.orange));
        return;
      }

      final approved = await Supabase.instance.client
          .from('pin_reset_requests')
          .select('id')
          .eq('user_id', profile['id'])
          .eq('status', 'approved')
          .maybeSingle();

      if (approved != null) {
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SetNewPinScreen(
              userId: profile['id'],
              username: username,
              requestId: approved['id'],
            ),
          ));
        }
        return;
      }

      final serviceClient = Supabase.instance.client;
      await serviceClient.from('pin_reset_requests').insert({
        'user_id': profile['id'],
        'username': username,
        'status': 'pending',
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ Request mokli! Admin PIN reset karse — pachi login karo"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red));
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
          color: isFilled ? const Color(0xFF38BDF8) : Colors.white24,
          width: isFilled ? 2 : 1,
        ),
        boxShadow: isFilled
            ? [BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.2), blurRadius: 8)]
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
            children: [
              const Icon(Icons.support_agent_rounded,
                  size: 80, color: Color(0xFF38BDF8)),
              const SizedBox(height: 20),
              const Text("IT Helpdesk",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

              // Username area
              if (_hasSavedUser) ...[
                Text("Welcome back,",
                    style: TextStyle(color: Colors.white54, fontSize: 15)),
                const SizedBox(height: 6),
                Text(_userCtrl.text.toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _hasSavedUser = false;
                      _userCtrl.clear();
                    });
                    _clearPin();
                  },
                  child: const Text("Not you? Switch User",
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
                const SizedBox(height: 8),
              ] else ...[
                TextField(
                  controller: _userCtrl,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _pinFocusNodes[0].requestFocus(),
                  decoration: InputDecoration(
                    hintText: "Enter Username",
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
                const SizedBox(height: 24),
              ],

              // PIN Label
              const Text("Enter PIN",
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 16),

              // 4-Box PIN Entry
              _isLoading
                  ? const SizedBox(
                      height: 68,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF38BDF8))))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) => _buildPinBox(i)),
                    ),

              const SizedBox(height: 12),
              TextButton(
                onPressed: _clearPin,
                child: const Text("Clear PIN",
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),

              const SizedBox(height: 20),
              const Text("Type your PIN — auto login on 4th digit",
                  style: TextStyle(color: Colors.white24, fontSize: 13)),
              const SizedBox(height: 8),

              // Forgot PIN Button
              TextButton.icon(
                onPressed: _forgotPin,
                icon: const Icon(Icons.lock_reset_rounded, color: Colors.orangeAccent, size: 18),
                label: const Text("Forgot PIN? Send request to Admin",
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 14)),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignupScreen())),
                child: const Text("New Engineer? Sign Up",
                    style: TextStyle(color: Color(0xFF38BDF8))),
              ),
              const SizedBox(height: 30),
              const Text("App Version: v1.0.0",
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
