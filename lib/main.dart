import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:google_fonts/google_fonts.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:shared_preferences/shared_preferences.dart";
import "screens/login_screen.dart";
import "screens/home_screen.dart";
import "services/onedrive_service.dart";
import "services/onedrive_web_helper.dart"
    if (dart.library.io) "services/onedrive_stub_helper.dart" as webHelper;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  // Handle OneDrive OAuth callback — exchange FIRST, then clear URL
  if (kIsWeb) {
    final currentUrl = webHelper.getCurrentUrl();
    final uri = Uri.tryParse(currentUrl);
    if (uri != null && uri.queryParameters.containsKey('code')) {
      final code = uri.queryParameters['code']!;
      await OneDriveService.handleCallback(code);
      webHelper.clearUrlParams();
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "IT Call Log",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF38BDF8),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final List<TextEditingController> _pinCtrls =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes =
      List.generate(4, (_) => FocusNode());

  String _username = '';
  String _statusMsg = '';
  bool _isLoading = false;
  bool _showPinScreen = false;

  String get _fullPin => _pinCtrls.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    for (var c in _pinCtrls) c.dispose();
    for (var f in _pinFocusNodes) f.dispose();
    super.dispose();
  }

  void _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('saved_username');

    if (user == null || user.isEmpty) {
      _goLogin();
      return;
    }

    setState(() {
      _username = user;
      _showPinScreen = true;
      _statusMsg = '';
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _pinFocusNodes[0].requestFocus();
    });
  }

  void _clearPin() {
    for (var c in _pinCtrls) c.clear();
    setState(() => _statusMsg = '');
    _pinFocusNodes[0].requestFocus();
  }

  void _onPinChanged(int index, String val) {
    if (val.isNotEmpty) {
      setState(() {});
      if (index < 3) {
        _pinFocusNodes[index + 1].requestFocus();
      } else {
        _pinFocusNodes[index].unfocus();
        _verifyAndLogin();
      }
    } else {
      setState(() {});
      if (index > 0) {
        _pinFocusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verifyAndLogin() async {
    final pin = _fullPin;
    if (pin.length != 4) return;

    setState(() {
      _isLoading = true;
      _statusMsg = '';
    });

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: '$_username@helpdesk.local',
        password: const String.fromEnvironment('BACKEND_PASSWORD'),
      );

      if (res.user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('pin, role')
            .eq('id', res.user!.id)
            .single();

        final dbPin = profile['pin']?.toString() ?? '';
        final role = profile['role']?.toString() ?? 'engineer';

        if (pin == dbPin) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_pin', pin);
          await prefs.setString('saved_role', role);
          await OneDriveService.flushPendingTokens();
          _goHome();
          return;
        } else {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            _clearPin();
            setState(() => _statusMsg = '❌ Incorrect PIN! Try again.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _clearPin();
        setState(() => _statusMsg = '❌ Login failed. Check connection.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goHome() {
    if (mounted) Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _goLogin() {
    if (mounted) Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded,
                  size: 72, color: Color(0xFF38BDF8)),
              const SizedBox(height: 24),

              if (_username.isNotEmpty) ...[
                Text(_username.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text("Enter your PIN to unlock",
                    style: TextStyle(color: Colors.white54, fontSize: 15)),
              ],

              const SizedBox(height: 40),

              if (_showPinScreen) ...[
                _isLoading
                    ? const SizedBox(
                        height: 68,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF38BDF8))))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children:
                            List.generate(4, (i) => _buildPinBox(i)),
                      ),

                const SizedBox(height: 16),

                if (_statusMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_statusMsg,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 14)),
                  ),

                TextButton(
                  onPressed: _clearPin,
                  child: const Text("Clear",
                      style: TextStyle(color: Colors.white24, fontSize: 12)),
                ),

                const SizedBox(height: 24),
                TextButton(
                  onPressed: _goLogin,
                  child: const Text("Switch Account",
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
