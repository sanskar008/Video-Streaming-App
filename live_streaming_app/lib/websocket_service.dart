import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  late WebSocketChannel channel;

  // Connect to the WebSocket server
  void connect(String url) {
    channel = WebSocketChannel.connect(Uri.parse(url));
  }

  // Listen to the WebSocket messages
  Stream get messages => channel.stream;

  // Send data to the WebSocket server
  void send(String message) {
    channel.sink.add(message);
  }

  // Disconnect from the WebSocket server
  void disconnect() {
    channel.sink.close();
  }
}
