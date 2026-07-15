import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suika_multi_player/config/api_config.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/screens/main_shell.dart';
import 'package:suika_multi_player/widgets/crop_avatar_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscure = true;
  final _hostCtrl = TextEditingController(text: ApiConfig.host);
  final _portCtrl = TextEditingController(text: ApiConfig.port.toString());
  bool _useSSL = ApiConfig.useSSL;
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

    // 确保服务器配置已应用到 ApiConfig
    _applyServerConfig();

    try {
      await ref.read(authProvider.notifier).login(
        _userNameCtrl.text.trim(),
        _pwdCtrl.text,
      );
      if (!mounted) return;

      // 检查登录结果
      final authState = ref.read(authProvider);
      if (authState.error != null) {
        setState(() {
          _error = authState.error;
          _loading = false;
        });
        ref.read(authProvider.notifier).clearError();
        return;
      }

      if (authState.isLoggedIn) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '连接失败: $e';
        _loading = false;
      });
    }
  }

  void _applyServerConfig() {
    final h = _hostCtrl.text.trim();
    final p = int.tryParse(_portCtrl.text.trim()) ?? 8001;
    if (h.isNotEmpty) {
      ApiConfig.host = h;
      ApiConfig.port = p;
    }
    ApiConfig.useSSL = _useSSL;
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
    ApiConfig.useSSL = _useSSL;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_host', h);
    await prefs.setString('server_port', p.toString());
    await prefs.setString('server_use_ssl', _useSSL.toString());
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
                    child: Image.asset('assets/images/icon_clear.png', width: 36, height: 36),
                  ),
                ),
                const SizedBox(height: 24),
                Text('欢迎回来', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.95))),
                const SizedBox(height: 8),
                Text('登录 Suika Multi Player', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.45))),
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
                      Icon(_useSSL ? Icons.lock_rounded : Icons.lock_open_rounded, size: 14, color: Colors.white.withValues(alpha: 0.35)),
                      const SizedBox(width: 8),
                      Text('${_hostCtrl.text}:${_portCtrl.text}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35))),
                      const Spacer(),
                      Text(_useSSL ? 'HTTPS' : 'HTTP', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.25))),
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        _useSSL ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _useSSL ? 'HTTPS' : 'HTTP',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _useSSL,
                        onChanged: (v) => setState(() => _useSSL = v),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  bool _obscure = true;
  final _hostCtrl = TextEditingController(text: ApiConfig.host);
  final _portCtrl = TextEditingController(text: ApiConfig.port.toString());
  bool _useSSL = ApiConfig.useSSL;
  bool _showServer = false;
  bool _loading = false;
  String? _error;
  String? _avatarPath;         // 本地图片路径（预览用）
  String? _avatarImageId;      // 上传后的 image_id
  String? _avatarUrl;          // 上传后的 URL

  @override
  void dispose() {
    _userNameCtrl.dispose();
    _pwdCtrl.dispose();
    _nicknameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    // 1:1 裁切
    final croppedPath = await CropAvatarDialog.show(context, path);
    if (croppedPath == null || !mounted) return;

    setState(() {
      _avatarPath = croppedPath;
      _avatarImageId = null;
      _avatarUrl = null;
    });
  }

  Future<void> _doRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loading) return;
    setState(() {
      _error = null;
      _loading = true;
    });

    // 确保服务器配置已应用到 ApiConfig
    _applyServerConfig();

    try {
      // 如果选择了头像，先上传
      if (_avatarPath != null && _avatarImageId == null) {
        try {
          final api = ref.read(apiServiceProvider);
          final uploadData = await api.uploadImage(_avatarPath!);
          _avatarImageId = uploadData['image_id'] as String;
          _avatarUrl = uploadData['url'] as String;
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _error = '头像上传失败: $e';
            _loading = false;
          });
          return;
        }
      }

      // 注册
      await ref.read(authProvider.notifier).register(
        _userNameCtrl.text.trim(),
        _pwdCtrl.text,
        _nicknameCtrl.text.trim(),
      );
      if (!mounted) return;

      // 检查注册结果
      final authState = ref.read(authProvider);
      if (authState.error != null) {
        setState(() {
          _error = authState.error;
          _loading = false;
        });
        ref.read(authProvider.notifier).clearError();
        return;
      }

      // 如果上传了头像，注册后更新头像
      if (_avatarImageId != null && _avatarUrl != null && authState.user != null) {
        try {
          final api = ref.read(apiServiceProvider);
          await api.updateAvatar(
            userUuid: authState.user!.userUuid,
            avatarUrl: _avatarUrl!,
            avatarKey: _avatarImageId!,
          );
          // 刷新用户信息以获取最新头像
          await ref.read(authProvider.notifier).refreshUser();
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '连接失败: $e';
        _loading = false;
      });
    }
  }

  void _applyServerConfig() {
    final h = _hostCtrl.text.trim();
    final p = int.tryParse(_portCtrl.text.trim()) ?? 8001;
    if (h.isNotEmpty) {
      ApiConfig.host = h;
      ApiConfig.port = p;
    }
    ApiConfig.useSSL = _useSSL;
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
    ApiConfig.useSSL = _useSSL;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_host', h);
    await prefs.setString('server_port', p.toString());
    await prefs.setString('server_use_ssl', _useSSL.toString());
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
                Center(child: Image.asset('assets/images/icon_clear.png', width: 48, height: 48)),
                const SizedBox(height: 16),
                Text('创建账号', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.95))),
                const SizedBox(height: 24),
                // 头像选择
                Center(
                  child: GestureDetector(
                    onTap: _loading ? null : _pickAvatar,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _avatarPath == null
                            ? const LinearGradient(colors: [Colors.white, Color(0xFF9E9E9E)])
                            : null,
                      ),
                      child: _avatarPath != null
                          ? ClipOval(
                              child: Image.file(
                                File(_avatarPath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.camera_alt_rounded,
                                  size: 28, color: Color(0xFF1A1A1A)),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _pickAvatar,
                    child: Text(
                      _avatarPath != null ? '更换头像' : '选择头像（可选）',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                      Icon(_useSSL ? Icons.lock_rounded : Icons.lock_open_rounded, size: 14, color: Colors.white.withValues(alpha: 0.35)),
                      const SizedBox(width: 8),
                      Text('${_hostCtrl.text}:${_portCtrl.text}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35))),
                      const Spacer(),
                      Text(_useSSL ? 'HTTPS' : 'HTTP', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.25))),
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        _useSSL ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _useSSL ? 'HTTPS' : 'HTTP',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _useSSL,
                        onChanged: (v) => setState(() => _useSSL = v),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
