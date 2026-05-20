import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suika_multi_player/config/api_config.dart';
import 'package:suika_multi_player/screens/main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscure = true;
  final _hostCtrl = TextEditingController(text: ApiConfig.host);
  final _portCtrl = TextEditingController(text: ApiConfig.port.toString());
  bool _showServer = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userNameCtrl.dispose();
    _pwdCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loading) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final dio = _createDio();
      final resp = await dio.post('/api/login', data: {
        'user_name': _userNameCtrl.text.trim(),
        'pwd': _pwdCtrl.text,
      });
      final data = resp.data as Map<String, dynamic>;
      if (data['success'] != true) {
        if (!mounted) return;
        setState(() {
          _error = data['message'] ?? '登录失败';
          _loading = false;
        });
        return;
      }
      await SharedPreferences.getInstance().then((prefs) {
        prefs.setString('user_uuid', data['user_uuid'] as String);
      });
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '连接失败: ${e.message ?? "请检查服务器地址和端口"}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '错误: $e';
        _loading = false;
      });
    }
  }

  Dio _createDio() {
    return Dio(BaseOptions(
      baseUrl: 'http://${_hostCtrl.text.trim()}:${_portCtrl.text.trim()}',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  void _toggleServer() {
    setState(() => _showServer = !_showServer);
  }

  void _saveServer() async {
    final h = _hostCtrl.text.trim();
    final p = int.tryParse(_portCtrl.text.trim()) ?? 8001;
    if (h.isEmpty) return;
    ApiConfig.host = h;
    ApiConfig.port = p;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_host', h);
    await prefs.setString('server_port', p.toString());
    setState(() => _showServer = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(40),
              children: [
                Center(
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(colors: [Colors.white, Color(0xFF9E9E9E)]),
                    ),
                    child: const Icon(Icons.music_note_rounded, size: 36, color: Color(0xFF1A1A1A)),
                  ),
                ),
                const SizedBox(height: 24),
                Text('欢迎回来', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.95))),
                const SizedBox(height: 8),
                Text('登录 Suika Mulit Player', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.45))),
                const SizedBox(height: 36),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _userNameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: '用户名', prefixIcon: Icon(Icons.person_outline_rounded, size: 20)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? '请输入用户名' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pwdCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '密码',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20), onPressed: () => setState(() => _obscure = !_obscure)),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.red.withValues(alpha: 0.15)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: Colors.redAccent))),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(height: 48, child: ElevatedButton(
                  onPressed: _loading ? null : _doLogin,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)))
                      : const Text('登录', style: TextStyle(fontSize: 16)),
                )),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('还没有账号？注册', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _toggleServer,
                  child: Row(
                    children: [
                      Icon(Icons.dns_rounded, size: 14, color: Colors.white.withValues(alpha: 0.35)),
                      const SizedBox(width: 8),
                      Text('服务器: ${_hostCtrl.text}:${_portCtrl.text}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35))),
                      const Spacer(),
                      Icon(_showServer ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white.withValues(alpha: 0.35)),
                    ],
                  ),
                ),
                if (_showServer) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(flex: 3, child: SizedBox(height: 40, child: TextField(controller: _hostCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: '主机', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))))),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text(':')),
                    Expanded(flex: 2, child: SizedBox(height: 40, child: TextField(controller: _portCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: '端口', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))))),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _saveServer,
                      child: Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white), child: const Icon(Icons.check_rounded, size: 18, color: Color(0xFF1A1A1A))),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  bool _obscure = true;
  final _hostCtrl = TextEditingController(text: ApiConfig.host);
  final _portCtrl = TextEditingController(text: ApiConfig.port.toString());
  bool _showServer = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userNameCtrl.dispose();
    _pwdCtrl.dispose();
    _nicknameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _doRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loading) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final dio = _createDio();
      final resp = await dio.post('/api/register', data: {
        'user_name': _userNameCtrl.text.trim(),
        'pwd': _pwdCtrl.text,
        'nickname': _nicknameCtrl.text.trim(),
      });
      final data = resp.data as Map<String, dynamic>;
      if (data['success'] != true) {
        if (!mounted) return;
        setState(() {
          _error = data['message'] ?? '注册失败';
          _loading = false;
        });
        return;
      }
      await SharedPreferences.getInstance().then((prefs) {
        prefs.setString('user_uuid', data['user_uuid'] as String);
      });
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '连接失败: ${e.message ?? "请检查服务器地址和端口"}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '错误: $e';
        _loading = false;
      });
    }
  }

  Dio _createDio() {
    return Dio(BaseOptions(
      baseUrl: 'http://${_hostCtrl.text.trim()}:${_portCtrl.text.trim()}',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  void _toggleServer() {
    setState(() => _showServer = !_showServer);
  }

  void _saveServer() async {
    final h = _hostCtrl.text.trim();
    final p = int.tryParse(_portCtrl.text.trim()) ?? 8001;
    if (h.isEmpty) return;
    ApiConfig.host = h;
    ApiConfig.port = p;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_host', h);
    await prefs.setString('server_port', p.toString());
    setState(() => _showServer = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(40),
              children: [
                Center(child: const Icon(Icons.music_note_rounded, size: 48, color: Colors.white)),
                const SizedBox(height: 16),
                Text('创建账号', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.95))),
                const SizedBox(height: 28),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nicknameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: '昵称', prefixIcon: Icon(Icons.badge_outlined, size: 20)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? '请输入昵称' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _userNameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: '用户名', prefixIcon: Icon(Icons.person_outline_rounded, size: 20)),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '请输入用户名';
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) return '仅允许字母数字下划线';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pwdCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '密码',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20), onPressed: () => setState(() => _obscure = !_obscure)),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? '密码至少6位' : null,
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.red.withValues(alpha: 0.15)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: Colors.redAccent))),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(height: 48, child: ElevatedButton(
                  onPressed: _loading ? null : _doRegister,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)))
                      : const Text('注册', style: TextStyle(fontSize: 16)),
                )),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('已有账号？去登录', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _toggleServer,
                  child: Row(
                    children: [
                      Icon(Icons.dns_rounded, size: 14, color: Colors.white.withValues(alpha: 0.35)),
                      const SizedBox(width: 8),
                      Text('服务器: ${_hostCtrl.text}:${_portCtrl.text}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35))),
                      const Spacer(),
                      Icon(_showServer ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white.withValues(alpha: 0.35)),
                    ],
                  ),
                ),
                if (_showServer) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(flex: 3, child: SizedBox(height: 40, child: TextField(controller: _hostCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: '主机', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))))),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text(':')),
                    Expanded(flex: 2, child: SizedBox(height: 40, child: TextField(controller: _portCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: '端口', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))))),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _saveServer,
                      child: Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white), child: const Icon(Icons.check_rounded, size: 18, color: Color(0xFF1A1A1A))),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
