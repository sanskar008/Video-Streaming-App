import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  _HostScreenState createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final SignalingService signaling = SignalingService();
  WebRTCService? webRTC;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initializeHost();
  }

  Future<void> _initializeHost() async {
    try {
      await _localRenderer.initialize();
      signaling.connect();
      webRTC = WebRTCService(signaling);
      await webRTC!.init();
      _localRenderer.srcObject = webRTC!.localStream;
      await webRTC!.createOffer();

      signaling.onMessage = (message) {
        if (message['type'] == 'answer') {
          webRTC!.peerConnection!.setRemoteDescription(
            RTCSessionDescription(message['sdp'], message['type']),
          );
        } else if (message['type'] == 'candidate') {
          webRTC!.handleCandidate(message['candidate']);
        }
      };
      setState(() {});
    } catch (e) {
      print('Error initializing host: $e');
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    webRTC?.dispose();
    signaling.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host Stream')),
      body: Column(
        children: [
          Expanded(
            child: RTCVideoView(
              _localRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            ),
          ),
          const Text('Stream ID: 12345'), // Replace with dynamic ID
        ],
      ),
    );
  }
}
