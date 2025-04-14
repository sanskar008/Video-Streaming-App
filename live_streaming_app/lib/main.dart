import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'websocket_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    socketService.connect();

    socketService.messages.listen((data) {
      final message = json.decode(data.toString());
      if (message['type'] == 'offer') {
        handleOffer(message);
      } else if (message['type'] == 'answer') {
        handleAnswer(message);
      } else if (message['type'] == 'candidate') {
        handleCandidate(message);
      } else if (message['type'] == 'error') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message['message'])),
        );
      }
    });

    initializeWebRTC();
  }

  Future<void> initializeWebRTC() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          // Add TURN server for production
        ],
      });

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
        });
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          socketService.send(json.encode({
            'type': 'candidate',
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'streamNumber': streamNumber,
          }));
        }
      };

      if (isHost) {
        try {
          MediaStream stream = await navigator.mediaDevices
              .getUserMedia({'video': true, 'audio': true});
          _localRenderer.srcObject = stream;
          stream.getTracks().forEach((track) {
            _peerConnection!.addTrack(track, stream);
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to access camera/microphone')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error initializing WebRTC')),
      );
    }
  }

  void handleOffer(Map<String, dynamic> data) async {
    try {
      await _peerConnection!
          .setRemoteDescription(RTCSessionDescription(data['sdp'], 'offer'));
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      socketService.send(json.encode({
        'type': 'answer',
        'sdp': answer.sdp,
        'streamNumber': streamNumber,
      }));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error handling offer')),
      );
    }
  }

  void handleAnswer(Map<String, dynamic> data) async {
    try {
      await _peerConnection!
          .setRemoteDescription(RTCSessionDescription(data['sdp'], 'answer'));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error handling answer')),
      );
    }
  }

  void handleCandidate(Map<String, dynamic> data) async {
    try {
      RTCIceCandidate iceCandidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(iceCandidate);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error handling ICE candidate')),
      );
    }
  }

  void startLiveStream() async {
    setState(() => isLoading = true);
    try {
      // Request server to create a stream
      socketService.send(json.encode({'type': 'createStream'}));
      // Assume server responds with streamNumber (handled in socketService.messages)
      // For simplicity, we’ll set a temporary streamNumber here
      streamNumber = DateTime.now().millisecondsSinceEpoch.toString();
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      socketService.send(json.encode({
        'type': 'offer',
        'sdp': offer.sdp,
        'streamNumber': streamNumber,
      }));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stream started: $streamNumber')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start live stream')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void joinLiveStream() async {
    setState(() => isLoading = true);
    try {
      streamNumber = _streamNumberController.text.trim();
      if (streamNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a stream number')),
        );
        return;
      }
      socketService.send(json.encode({
        'type': 'join',
        'streamNumber': streamNumber,
      }));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join live stream')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.close();
    socketService.disconnect();
    _streamNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Stream'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Video renderers
            Expanded(
              child: Row(
                children: [
                  // Local video (host's camera)
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            RTCVideoView(
                              _localRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isHost ? 'Host Camera' : 'No Camera',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Remote video (streamed content)
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            RTCVideoView(
                              _remoteRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Live Stream',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Controls
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isHost
                  ? Column(
                      children: [
                        const Text(
                          'Host Mode',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : startLiveStream,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.videocam),
                          label: const Text('Start Live Stream'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const Text(
                          'Viewer Mode',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _streamNumberController,
                          decoration: InputDecoration(
                            labelText: 'Stream Number',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.live_tv),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : joinLiveStream,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.play_arrow),
                          label: const Text('Join Live Stream'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            // Toggle mode
            TextButton.icon(
              onPressed: () async {
                setState(() {
                  isHost = !isHost;
                  isLoading = true;
                });
                await _peerConnection?.close();
                _localRenderer.srcObject = null;
                _remoteRenderer.srcObject = null;
                await initializeWebRTC();
                setState(() => isLoading = false);
              },
              icon: const Icon(Icons.swap_horiz),
              label: Text(isHost ? 'Switch to Viewer' : 'Switch to Host'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
