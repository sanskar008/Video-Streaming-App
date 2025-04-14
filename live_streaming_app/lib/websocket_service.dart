import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? channel;
  final String url;
  final StreamController<dynamic> _messagesController =
      StreamController.broadcast();

  WebSocketService({this.url = 'ws://localhost:8080'});

  Stream get messages => _messagesController.stream;

  void connect() {
    try {
      channel = WebSocketChannel.connect(Uri.parse(url));
      channel!.stream.listen(
        (data) {
          _messagesController.add(data);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _reconnect();
        },
        onDone: () {
          print('WebSocket closed');
          _reconnect();
        },
      );
    } catch (e) {
      print('Failed to connect to WebSocket: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_messagesController.isClosed) {
        connect();
      }
    });
  }

  void send(String message) {
    if (channel != null) {
      channel!.sink.add(message);
    } else {
      print('Cannot send message: WebSocket not connected');
    }
  }

  void disconnect() {
    channel?.sink.close();
    _messagesController.close();
  }
}
