import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'websocket_service.dart';

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

    // Listen to WebSocket messages
    socketService.messages.listen((data) {
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
    socketService.send(json.encode({
      'type': 'answer',
      'sdp': answer.sdp,
    }));
  }

  void handleAnswer(String answer) async {
    await _peerConnection!
        .setRemoteDescription(RTCSessionDescription(answer, 'answer'));
  }

  void handleCandidate(String candidate) async {
    // Decode the candidate and send it to the peer connection
    var candidateMap = json.decode(candidate);
    RTCIceCandidate iceCandidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'] as int?,
    );
    await _peerConnection!.addCandidate(iceCandidate);
  }

  void startLiveStream() async {
    // Create an offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Send the offer to the WebSocket server
    socketService.send(json.encode({
      'type': 'offer',
      'sdp': offer.sdp,
    }));
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
            onPressed: startLiveStream, // Trigger the live stream start here
            child: const Text('Start Live Stream'),
          ),
        ],
      ),
    );
  }
}
