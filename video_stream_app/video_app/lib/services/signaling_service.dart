import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class SignalingService {
  WebSocketChannel? channel;
  final String wsUrl =
      'ws://your-server-url:8080'; // Replace with your Node.js WebSocket server URL
  Function(Map<String, dynamic>)? onMessage;

  void connect() {
    channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    channel!.stream.listen((message) {
      onMessage?.call(jsonDecode(message));
    });
  }

  void send(Map<String, dynamic> message) {
    channel?.sink.add(jsonEncode(message));
  }

  void disconnect() {
    channel?.sink.close();
  }
}
