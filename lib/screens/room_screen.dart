import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/constants.dart';
import '../utils/signaling_service.dart';
import '../utils/webrtc_manager.dart';
import '../models/peer_model.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String userName;
  final bool isHost;

  const RoomScreen({
    super.key,
    required this.roomId,
    required this.userName,
    required this.isHost,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _signaling = SignalingService();
  WebRTCManager? _webrtc;

  final _remoteRenderer = RTCVideoRenderer();
  final _localRenderer = RTCVideoRenderer();

  bool _connected = false;
  bool _isSharing = false;
  bool _isConnecting = false;
  List<PeerModel> _peers = [];
  String _sharerName = '';
  MediaStream? _localStream;
  bool _hasRemoteStream = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _initSignaling();
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
    await _localRenderer.initialize();
  }

  Future<void> _initSignaling() async {
    try {
      await _signaling.connect(AppConfig.signalServer);

      setState(() => _connected = true);

      _webrtc = WebRTCManager(
        signaling: _signaling,
        roomId: widget.roomId,
        myId: _signaling.id ?? '',
      );

      _webrtc!.onRemoteStream = (peerId, stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _hasRemoteStream = true;
        });
      };

      _webrtc!.onPeerDisconnected = (peerId) {
        setState(() {
          _peers.removeWhere((p) => p.peerId == peerId);
          if (_hasRemoteStream) {
            _remoteRenderer.srcObject = null;
            _hasRemoteStream = false;
            _sharerName = '';
          }
        });
        _showToast('${_getPeerName(peerId)} 断开了连接');
      };

      _setupSignalingEvents();

      _signaling.send('join-room', {
        'roomId': widget.roomId,
        'userName': widget.userName,
        'isHost': widget.isHost,
      });

      _showToast('已进入房间 ${widget.roomId}', isSuccess: true);
    } catch (e) {
      _showToast('无法连接服务器，请检查网络');
    }
  }

  void _setupSignalingEvents() {
    _signaling.on('room-peers', (data) {
      final peersList = (data['peers'] as List?)
          ?.map((p) => PeerModel.fromMap(Map<String, dynamic>.from(p)))
          .where((p) => p.peerId != _signaling.id)
          .toList() ?? [];
      setState(() => _peers = peersList);
    });

    _signaling.on('peer-joined', (data) {
      final peerId = data['peerId'] as String;
      final userName = data['userName'] as String;
      if (peerId == _signaling.id) return;

      setState(() => _peers.add(PeerModel(peerId: peerId, userName: userName)));
      _showToast('$userName 加入了房间');

      // 如果我在共享，主动向新用户推流
      if (_isSharing && _webrtc != null) {
        _webrtc!.offerToPeer(peerId);
      }
    });

    _signaling.on('peer-left', (data) {
      final peerId = data['peerId'] as String;
      final name = _getPeerName(peerId);
      setState(() => _peers.removeWhere((p) => p.peerId == peerId));
      _webrtc?.removePeer(peerId);
      _showToast('$name 离开了房间');
    });

    _signaling.on('share-started', (data) {
      final peerId = data['peerId'] as String;
      final userName = data['userName'] as String;
      setState(() {
        final idx = _peers.indexWhere((p) => p.peerId == peerId);
        if (idx >= 0) _peers[idx].isSharing = true;
        _sharerName = userName;
      });
      _showToast('$userName 开始了屏幕共享');
    });

    _signaling.on('share-stopped', (data) {
      final peerId = data['peerId'] as String;
      setState(() {
        final idx = _peers.indexWhere((p) => p.peerId == peerId);
        if (idx >= 0) _peers[idx].isSharing = false;
        _remoteRenderer.srcObject = null;
        _hasRemoteStream = false;
        _sharerName = '';
      });
      _showToast('屏幕共享已结束');
      _webrtc?.removePeer(peerId);
    });
  }

  String _getPeerName(String peerId) {
    return _peers.firstWhere(
      (p) => p.peerId == peerId,
      orElse: () => PeerModel(peerId: peerId, userName: '用户'),
    ).userName;
  }

  // ===== 核心：安卓原生屏幕共享 =====
  Future<void> _startSharing() async {
    if (!_connected) { _showToast('请等待连接成功'); return; }
    setState(() => _isConnecting = true);

    try {
      // flutter_webrtc 原生调用 MediaProjection API
      // 会自动弹出系统级"开始录制屏幕"权限框
      // 支持安卓5.0+ 全部机型
      final stream = await navigator.mediaDevices.getDisplayMedia({
        'video': {
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'frameRate': {'ideal': 15, 'max': 30},
        },
        'audio': false,
      });

      _localStream = stream;
      setState(() {
        _localRenderer.srcObject = stream;
        _isSharing = true;
        _isConnecting = false;
      });

      // 通知其他成员
      _signaling.send('start-share', {
        'roomId': widget.roomId,
        'userName': widget.userName,
      });

      // 向所有在线成员推流
      final viewerIds = _peers.map((p) => p.peerId).toList();
      if (viewerIds.isNotEmpty && _webrtc != null) {
        await _webrtc!.startSharing(stream, viewerIds);
      }

      // 监听用户从系统通知栏停止共享
      stream.getVideoTracks().first.onEnded = () {
        _stopSharing();
      };

      _showToast('屏幕共享已开启', isSuccess: true);
    } catch (e) {
      setState(() => _isConnecting = false);
      final msg = e.toString();
      if (msg.contains('denied') || msg.contains('cancel')) {
        _showToast('屏幕共享权限被拒绝');
      } else {
        _showToast('无法启动屏幕共享: $msg');
      }
    }
  }

  Future<void> _stopSharing() async {
    if (!_isSharing) return;

    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;

    await _webrtc?.stopSharing();

    setState(() {
      _localRenderer.srcObject = null;
      _isSharing = false;
    });

    _signaling.send('stop-share', {'roomId': widget.roomId});
    _showToast('已停止屏幕共享');
  }

  void _leaveRoom() {
    _stopSharing();
    _signaling.send('leave-room', {'roomId': widget.roomId});
    _webrtc?.destroy();
    _signaling.disconnect();
    Navigator.pop(context);
  }

  void _copyRoomId() {
    Clipboard.setData(ClipboardData(text: widget.roomId));
    _showToast('房间号已复制', isSuccess: true);
  }

  void _showToast(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      backgroundColor: isSuccess ? AppColors.success : AppColors.bgCard,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _leaveRoom();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildScreenArea()),
              _buildControlBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _leaveRoom,
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.text, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.bgSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('房间号 ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    Text(
                      widget.roomId,
                      style: const TextStyle(
                        color: AppColors.primary, fontSize: 20,
                        fontWeight: FontWeight.w800, letterSpacing: 3,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _copyRoomId,
                      child: const Icon(Icons.copy, color: AppColors.textMuted, size: 16),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _connected ? AppColors.success : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _connected ? '已连接' : '连接中...',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: AppColors.textMuted, size: 16),
                const SizedBox(width: 4),
                Text('${_peers.length + 1}',
                    style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenArea() {
    if (_hasRemoteStream && !_isSharing) {
      // 观看远端共享
      return Stack(
        children: [
          Container(color: Colors.black, child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)),
          Positioned(
            top: 12, left: 12,
            child: _buildSharingBadge('● 正在接收 $_sharerName 的屏幕', false),
          ),
        ],
      );
    } else if (_isSharing && _localStream != null) {
      // 自己共享中
      return Stack(
        children: [
          Container(color: Colors.black, child: RTCVideoView(_localRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain, mirror: false)),
          Positioned(
            top: 12, left: 12,
            child: _buildSharingBadge('● 正在共享你的屏幕', true),
          ),
        ],
      );
    } else {
      // 等待状态
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.screen_share_outlined,
                size: 72,
                color: AppColors.textMuted.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isHost ? '开始共享你的屏幕' : '等待共享...',
                style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isHost ? '点击下方按钮开始屏幕共享' : '房主开启共享后，你将看到屏幕内容',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSharingBadge(String text, bool isSelf) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelf ? AppColors.danger : AppColors.success,
          fontSize: 12, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 共享按钮
          SizedBox(
            width: double.infinity,
            child: _isSharing
                ? _buildBtn('停止共享', _stopSharing, isStop: true)
                : _buildBtn(
                    _isConnecting ? '准备中...' : '开始共享屏幕',
                    _isConnecting ? null : _startSharing,
                  ),
          ),
          const SizedBox(height: 14),

          // 成员列表
          const Text('房间成员', style: TextStyle(
            color: AppColors.textMuted, fontSize: 12,
            fontWeight: FontWeight.w600, letterSpacing: 0.5,
          )),
          const SizedBox(height: 8),

          // 自己
          _buildMemberItem(widget.userName, isMe: true, isSharing: _isSharing, isHost: widget.isHost),

          // 其他成员
          ..._peers.map((p) => _buildMemberItem(
            p.userName, isSharing: p.isSharing,
          )),

          if (_peers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('暂无其他成员，邀请朋友加入吧',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _buildBtn(String text, VoidCallback? onTap, {bool isStop = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: onTap == null
              ? null
              : LinearGradient(colors: isStop
                  ? [const Color(0xFFF44336), const Color(0xFFC62828)]
                  : [AppColors.primary, AppColors.primaryDark]),
          color: onTap == null ? AppColors.bgSurface : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap == null ? [] : [
            BoxShadow(
              color: (isStop ? Colors.red : AppColors.primary).withOpacity(0.35),
              blurRadius: 15, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isStop ? Icons.stop_rounded : Icons.screen_share_rounded,
              color: Colors.white, size: 20,
            ),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberItem(String name, {
    bool isMe = false, bool isSharing = false, bool isHost = false,
  }) {
    final color = Color(getAvatarColor(name));
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: isMe ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(isMe ? '$name (我)' : name,
                style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
          ),
          if (isSharing)
            _buildBadge('共享中', AppColors.danger),
          if (isHost && !isSharing)
            _buildBadge('房主', AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _localRenderer.dispose();
    _webrtc?.destroy();
    _signaling.disconnect();
    super.dispose();
  }
}
