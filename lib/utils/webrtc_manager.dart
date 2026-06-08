import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

class WebRTCManager {
  final Map<String, RTCPeerConnection> _peers = {};
  MediaStream? localStream;
  final SignalingService _signaling;
  final String roomId;
  final String myId;

  Function(String peerId, MediaStream stream)? onRemoteStream;
  Function(String peerId)? onPeerDisconnected;

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
    ]
  };

  static const _offerConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  WebRTCManager({
    required SignalingService signaling,
    required this.roomId,
    required this.myId,
  }) : _signaling = signaling {
    _setupHandlers();
  }

  void _setupHandlers() {
    _signaling.on('offer', (data) async {
      final from = data['from'] as String;
      final offer = data['offer'];
      print('[WebRTC] Got offer from $from');
      await _handleOffer(from, offer);
    });

    _signaling.on('answer', (data) async {
      final from = data['from'] as String;
      final answer = data['answer'];
      final pc = _peers[from];
      if (pc != null) {
        await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
      }
    });

    _signaling.on('ice-candidate', (data) async {
      final from = data['from'] as String;
      final candidate = data['candidate'];
      final pc = _peers[from];
      if (pc != null && candidate != null) {
        try {
          await pc.addCandidate(RTCIceCandidate(
            candidate['candidate'],
            candidate['sdpMid'],
            candidate['sdpMLineIndex'],
          ));
        } catch (e) {
          print('[WebRTC] addCandidate error: $e');
        }
      }
    });
  }

  Future<RTCPeerConnection> _createPC(String peerId) async {
    if (_peers.containsKey(peerId)) return _peers[peerId]!;

    final pc = await createPeerConnection(_iceServers);

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _signaling.send('ice-candidate', {
          'to': peerId,
          'roomId': roomId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        print('[WebRTC] Got remote track from $peerId');
        onRemoteStream?.call(peerId, event.streams[0]);
      }
    };

    pc.onConnectionState = (state) {
      print('[WebRTC] $peerId state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        removePeer(peerId);
        onPeerDisconnected?.call(peerId);
      }
    };

    _peers[peerId] = pc;
    return pc;
  }

  // 屏幕共享：向所有观看者推流
  Future<void> startSharing(MediaStream stream, List<String> viewerIds) async {
    localStream = stream;
    for (final viewerId in viewerIds) {
      await _createOfferTo(viewerId);
    }
  }

  // 新用户加入时，主动推流
  Future<void> offerToPeer(String peerId) async {
    if (localStream != null) {
      await _createOfferTo(peerId);
    }
  }

  Future<void> _createOfferTo(String peerId) async {
    final pc = await _createPC(peerId);

    // 添加本地轨道
    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await pc.addTrack(track, localStream!);
      }
    }

    final offer = await pc.createOffer(_offerConstraints);
    await pc.setLocalDescription(offer);

    _signaling.send('offer', {
      'to': peerId,
      'roomId': roomId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  Future<void> _handleOffer(String sharerId, dynamic offer) async {
    final pc = await _createPC(sharerId);
    await pc.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _signaling.send('answer', {
      'to': sharerId,
      'roomId': roomId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });
  }

  Future<void> stopSharing() async {
    localStream?.getTracks().forEach((t) => t.stop());
    localStream?.dispose();
    localStream = null;
    for (final pc in _peers.values) {
      await pc.close();
    }
    _peers.clear();
  }

  void removePeer(String peerId) {
    _peers[peerId]?.close();
    _peers.remove(peerId);
  }

  Future<void> destroy() async {
    await stopSharing();
  }
}
