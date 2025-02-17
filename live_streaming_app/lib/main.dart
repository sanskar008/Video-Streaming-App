import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'websocket_service.dart';
import 'dart:convert'; // Import to use json.decode

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LiveStreamPage(),
    );
  }
}

class LiveStreamPage extends StatefulWidget {
  const LiveStreamPage({super.key});

  @override
  _LiveStreamPageState createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  final WebSocketService socketService = WebSocketService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;

  @override
  void initState() {
    super.initState();
    socketService.connect('ws://localhost:8080'); // Connect to WebSocket server
    socketService.socketStream.listen((data) {
      final message = data.toString();
      if (message.contains('offer')) {
        handleOffer(message);
      } else if (message.contains('answer')) {
        handleAnswer(message);
      } else if (message.contains('candidate')) {
        handleCandidate(message);
      }
    });

    initializeWebRTC();
  }

  Future<void> initializeWebRTC() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // Access the camera and microphone
    MediaStream stream = await navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': true});
    _localRenderer.srcObject = stream;

    // Create a PeerConnection
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ],
    });

    _peerConnection!.addStream(stream);
  }

  void handleOffer(String offer) async {
    await _peerConnection!
        .setRemoteDescription(RTCSessionDescription(offer, 'offer'));
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    socketService.send('answer: ${answer.sdp}');
  }

  void handleAnswer(String answer) async {
    await _peerConnection!
        .setRemoteDescription(RTCSessionDescription(answer, 'answer'));
  }

  void handleCandidate(String candidate) async {
    // Parse the candidate string into a Map
    var candidateMap = json.decode(candidate); // Decode the candidate to a Map

    // Create RTCIceCandidate using the decoded values
    RTCIceCandidate iceCandidate = RTCIceCandidate(
      candidateMap['candidate'], // Candidate string (stays the same)
      candidateMap['sdpMid'], // sdpMid should be a String
      candidateMap['sdpMLineIndex'], // sdpMLineIndex should be an int
    );

    await _peerConnection!.addCandidate(iceCandidate);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Streaming App")),
      body: Column(
        children: [
          Expanded(child: RTCVideoView(_localRenderer)),
          Expanded(child: RTCVideoView(_remoteRenderer)),
          ElevatedButton(
            onPressed: () {
              // Start streaming (Host will send offer to WebSocket server)
              socketService.send('offer');
            },
            child: const Text('Start Live Stream'),
          ),
        ],
      ),
    );
  }
}
