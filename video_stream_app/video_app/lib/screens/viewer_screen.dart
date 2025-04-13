import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  _ViewerScreenState createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final SignalingService signaling = SignalingService();
  WebRTCService? webRTC;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final _streamIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeViewer();
  }

  Future<void> _initializeViewer() async {
    try {
      await _remoteRenderer.initialize();
      signaling.connect();
      webRTC = WebRTCService(signaling);
      await webRTC!.init();

      signaling.onMessage = (message) {
        if (message['type'] == 'offer') {
          webRTC!.createAnswer(message);
        } else if (message['type'] == 'candidate') {
          webRTC!.handleCandidate(message['candidate']);
        }
      };

      webRTC!.peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams[0];
          setState(() {});
        }
      };
    } catch (e) {
      print('Error initializing viewer: $e');
    }
  }

  void _joinStream() {
    signaling.send({'type': 'join', 'streamId': _streamIdController.text});
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    webRTC?.dispose();
    signaling.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Stream')),
      body: Column(
        children: [
          TextField(
            controller: _streamIdController,
            decoration: const InputDecoration(labelText: 'Enter Stream ID'),
          ),
          ElevatedButton(onPressed: _joinStream, child: const Text('Join')),
          Expanded(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            ),
          ),
        ],
      ),
    );
  }
}
