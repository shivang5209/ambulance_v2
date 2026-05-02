import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  WebSocketChannel? _channel;
  final StreamController<dynamic> _streamController = StreamController<dynamic>.broadcast();

  WebSocketService._internal();

  static WebSocketService getInstance() {
    return _instance;
  }

  Stream<dynamic> get stream => _streamController.stream;

  void connect(String url) {
    if (_channel != null && _channel!.closeCode == null) {
      // Already connected
      return;
    }
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen(
      (data) {
        _streamController.add(data);
      },
      onDone: () {
        // Handle connection closed
      },
      onError: (error) {
        // Handle errors
      },
    );
  }

  void sendMessage(String message) {
    if (_channel != null) {
      _channel!.sink.add(message);
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
  }
}
