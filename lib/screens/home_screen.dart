import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/peer_model.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();
  bool _showJoin = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = generateUserName();
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('userName');
    if (saved != null && saved.isNotEmpty) {
      setState(() => _nameController.text = saved);
    }
  }

  Future<void> _saveName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', _nameController.text.trim());
  }

  void _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showToast('请先输入昵称');
      return;
    }
    await _saveName();
    final roomId = generateRoomId();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RoomScreen(
        roomId: roomId,
        userName: name,
        isHost: true,
      ),
    ));
  }

  void _joinRoom() async {
    final name = _nameController.text.trim();
    final roomId = _roomController.text.trim().toUpperCase();
    if (name.isEmpty) { _showToast('请先输入昵称'); return; }
    if (roomId.length < 4) { _showToast('请输入正确的房间号'); return; }
    await _saveName();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RoomScreen(
        roomId: roomId,
        userName: name,
        isHost: false,
      ),
    ));
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              _buildLogo(),
              const SizedBox(height: 40),

              // 昵称输入
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('👤 你的昵称'),
                    const SizedBox(height: 10),
                    _buildInput(
                      controller: _nameController,
                      hint: '输入昵称...',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 创建房间
              _buildActionCard(
                icon: Icons.add_circle_outline,
                iconColor: AppColors.primary,
                iconBg: const Color(0x266C63FF),
                title: '创建房间',
                subtitle: '创建新房间并分享给其他人',
                onTap: _createRoom,
              ),
              const SizedBox(height: 12),

              // 加入房间
              _buildActionCard(
                icon: Icons.login_rounded,
                iconColor: AppColors.secondary,
                iconBg: const Color(0x26FF6584),
                title: '加入房间',
                subtitle: '输入房间号加入他人的房间',
                onTap: () => setState(() => _showJoin = !_showJoin),
              ),

              // 加入输入框
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('🔑 房间号'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInput(
                                controller: _roomController,
                                hint: '输入6位房间号...',
                                isRoomId: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildButton('加入', _joinRoom),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                crossFadeState: _showJoin
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),

              const SizedBox(height: 32),

              // 特性说明
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFeature('🔒', '端对端加密'),
                  const SizedBox(width: 20),
                  _buildFeature('⚡', '低延迟共享'),
                  const SizedBox(width: 20),
                  _buildFeature('📱', '全机型支持'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.screen_share_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
          ).createShader(bounds),
          child: const Text(
            'ScreenShare',
            style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('实时屏幕共享，随时随地协作',
            style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(
      color: AppColors.textMuted, fontSize: 12,
      fontWeight: FontWeight.w600, letterSpacing: 0.5,
    ));
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    bool isRoomId = false,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
        color: AppColors.text,
        fontSize: isRoomId ? 20 : 16,
        fontWeight: isRoomId ? FontWeight.w700 : FontWeight.normal,
        letterSpacing: isRoomId ? 4 : 0,
      ),
      textCapitalization: isRoomId
          ? TextCapitalization.characters
          : TextCapitalization.none,
      maxLength: isRoomId ? 6 : 20,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.bgSurface,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13,
                  )),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(text, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700,
        )),
      ),
    );
  }

  Widget _buildFeature(String icon, String text) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    super.dispose();
  }
}
