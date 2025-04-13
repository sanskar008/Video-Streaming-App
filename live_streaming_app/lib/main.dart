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
      home: RoleSelectionPage(),
    );
  }
}

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  _RoleSelectionPageState createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Role")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LiveStreamPage(isHost: true),
                  ),
                );
              },
              child: const Text('Host a Stream'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LiveStreamPage(isHost: false),
                  ),
                );
              },
              child: const Text('Join a Stream'),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveStreamPage extends StatefulWidget {
  final bool isHost;

  const LiveStreamPage({super.key, required this.isHost});

  @override
  _LiveStreamPageState createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  final WebSocketService socketService = WebSocketService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  String streamNumber = '';
  final TextEditingController _streamNumberController = TextEditingController();
  List<String> liveStreams = []; // List of live streams available for viewers

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
      } else if (message.contains('newStream')) {
        // Handle new streams added by hosts
        setState(() {
          liveStreams.add(message);
        });
      }
    });

    initializeWebRTC();
  }

  // Initialize WebRTC setup
  Future<void> initializeWebRTC() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // Initialize local camera and microphone
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

  // Handle Offer received from host
  void handleOffer(String offer) async {
    await _peerConnection!
        .setRemoteDescription(RTCSessionDescription(offer, 'offer'));

    // Create an answer
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Send the answer to the host via WebSocket
    socketService.send(json.encode({
      'type': 'answer',
      'sdp': answer.sdp,
      'streamNumber': streamNumber,
    }));
  }

  // Handle Answer received from viewer
  void handleAnswer(String answer) async {
    await _peerConnection!
        .setRemoteDescription(RTCSessionDescription(answer, 'answer'));
  }

  // Handle ICE candidates
  void handleCandidate(String candidate) async {
    var candidateMap = json.decode(candidate);
    RTCIceCandidate iceCandidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'] as int?,
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

  // Function to start the live stream as host
  void startLiveStream() {
    streamNumber = DateTime.now().millisecondsSinceEpoch.toString();

    // Create an offer and send it to the WebSocket server with the stream number
    _peerConnection!.createOffer().then((offer) {
      _peerConnection!.setLocalDescription(offer);
      socketService.send(json.encode({
        'type': 'offer',
        'sdp': offer.sdp,
        'streamNumber': streamNumber,
      }));

      // Inform all clients about the new stream
      socketService.send(json.encode({
        'type': 'newStream',
        'streamNumber': streamNumber,
      }));
    });
  }

  // Join a live stream as a user
  void joinLiveStream() {
    streamNumber = _streamNumberController.text;
    socketService.send(json.encode({
      'type': 'join',
      'streamNumber': streamNumber,
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Streaming App")),
      body: Column(
        children: [
          // Local stream (host video)
          Expanded(child: RTCVideoView(_localRenderer)),

          // Remote stream (viewer video - to see the host's stream)
          Expanded(child: RTCVideoView(_remoteRenderer)),

          if (widget.isHost) ...[
            // For host to start stream
            ElevatedButton(
              onPressed: startLiveStream,
              child: const Text('Start Live Stream'),
            ),
            // Show stream number after stream is started
            if (streamNumber.isNotEmpty)
              Text(
                'Stream Number: $streamNumber',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
          ] else ...[
            // For user to select stream
            Column(
              children: [
                TextField(
                  controller: _streamNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Stream Number to Join',
                  ),
                ),
                ElevatedButton(
                  onPressed: joinLiveStream,
                  child: const Text('Join Live Stream'),
                ),
                // Show available streams
                if (liveStreams.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: liveStreams.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text('Stream Number: ${liveStreams[index]}'),
                        onTap: () {
                          _streamNumberController.text = liveStreams[index];
                          joinLiveStream();
                        },
                      );
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
