import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'websocket_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.grey[100],
        textTheme: GoogleFonts.poppinsTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 5,
          ),
        ),
      ),
      home: const LiveStreamPage(),
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
  bool isHost = false;
  String streamNumber = '';
  final TextEditingController _streamNumberController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    socketService.connect('ws://localhost:8080');

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

    MediaStream stream = await navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': true});
    _localRenderer.srcObject = stream;

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
      'streamNumber': streamNumber,
    }));
  }

  void handleAnswer(String answer) async {
    await _peerConnection!
        .setRemoteDescription(RTCSessionDescription(answer, 'answer'));
  }

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
    _streamNumberController.dispose();
    super.dispose();
  }

  void startLiveStream() {
    setState(() => isLoading = true);
    streamNumber = DateTime.now().millisecondsSinceEpoch.toString();
    _peerConnection!.createOffer().then((offer) {
      _peerConnection!.setLocalDescription(offer);
      socketService.send(json.encode({
        'type': 'offer',
        'sdp': offer.sdp,
        'streamNumber': streamNumber,
      }));
      setState(() => isLoading = false);
    });
  }

  void joinLiveStream() {
    setState(() => isLoading = true);
    streamNumber = _streamNumberController.text.trim();
    if (streamNumber.isNotEmpty) {
      socketService.send(json.encode({
        'type': 'join',
        'streamNumber': streamNumber,
      }));
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade200, Colors.purple.shade300],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              FadeInDown(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    isHost ? 'Host Live Stream' : 'Join Live Stream',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Video Streams
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: RTCVideoView(
                          isHost ? _localRenderer : _remoteRenderer,
                          mirror: isHost,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                    if (isHost)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FadeInUp(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: RTCVideoView(
                                _remoteRenderer,
                                mirror: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Controls
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isHost)
                        ZoomIn(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : startLiveStream,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Start Live Stream',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            SlideInLeft(
                              child: TextField(
                                controller: _streamNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Enter Stream Number',
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  prefixIcon: const Icon(Icons.videocam),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ZoomIn(
                              child: ElevatedButton(
                                onPressed: isLoading ? null : joinLiveStream,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Join Live Stream',
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      SlideInRight(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              isHost = !isHost;
                              _streamNumberController.clear();
                            });
                          },
                          child: Text(
                            isHost ? 'Switch to Viewer' : 'Switch to Host',
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
