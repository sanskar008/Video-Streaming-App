import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

class WebRTCService {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  final SignalingService signaling;

  WebRTCService(this.signaling);

  Future<void> init() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    };
    peerConnection = await createPeerConnection(configuration);

    peerConnection!.onIceCandidate = (candidate) {
      signaling.send({'type': 'candidate', 'candidate': candidate.toMap()});
    };

    localStream = await navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': true});
    localStream!.getTracks().forEach((track) {
      peerConnection!.addTrack(track, localStream!);
    });
  }

  Future<void> createOffer() async {
    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    signaling.send({'type': 'offer', 'sdp': offer.sdp});
  }

  Future<void> createAnswer(Map<String, dynamic> offer) async {
    await peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );
    final answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);
    signaling.send({'type': 'answer', 'sdp': answer.sdp});
  }

  Future<void> handleCandidate(Map<String, dynamic> candidate) async {
    await peerConnection!.addCandidate(
      RTCIceCandidate(
        candidate['candidate'],
        candidate['sdpMid'],
        candidate['sdpMLineIndex'],
      ),
    );
  }

  void dispose() {
    localStream?.dispose();
    peerConnection?.close();
  }
}
