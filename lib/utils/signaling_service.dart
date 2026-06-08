import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/peer_model.dart';

typedef SignalCallback = void Function(dynamic data);

class SignalingService {
  IO.Socket? _socket;
  final Map<String, List<SignalCallback>> _callbacks = {};

  bool get connected => _socket?.connected ?? false;
  String? get id => _socket?.id;

  Future<void> connect(String serverUrl) async {
    final completer = Future<void>.value();

    _socket = IO.io(serverUrl, IO.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .setReconnectionAttempts(5)
        .setReconnectionDelay(1000)
        .setTimeout(10000)
        .enableReconnection()
        .build());

    _socket!.onConnect((_) {
      print('[Signal] Connected: ${_socket!.id}');
    });

    _socket!.onConnectError((err) {
      print('[Signal] Connect error: $err');
    });

    // 转发所有事件
    final events = [
      'room-joined', 'room-error', 'peer-joined', 'peer-left',
      'offer', 'answer', 'ice-candidate', 'share-started',
      'share-stopped', 'room-peers'
    ];

    for (final event in events) {
      _socket!.on(event, (data) {
        _emit(event, data);
      });
    }

    // 等待连接
    await Future.delayed(const Duration(seconds: 2));
    return completer;
  }

  void on(String event, SignalCallback cb) {
    _callbacks.putIfAbsent(event, () => []).add(cb);
  }

  void off(String event) {
    _callbacks.remove(event);
  }

  void _emit(String event, dynamic data) {
    final cbs = _callbacks[event] ?? [];
    for (final cb in cbs) {
      cb(data);
    }
  }

  void send(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _callbacks.clear();
  }
}
