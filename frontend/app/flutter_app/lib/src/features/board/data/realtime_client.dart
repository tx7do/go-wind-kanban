import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:flutter_app/src/features/board/models/board_models.dart';

/// 看板实时事件客户端。
///
/// 连接 GET /app/v1/ws?board_id=<id>&access_token=<jwt>（与后端 WsServer 对齐，
/// protojson camelCase 帧）。自动重连（指数退避），断线期间事件静默丢弃——
/// 最终一致性由重新拉取快照保证（controller 在重连成功后 refetch）。
class RealtimeClient {
  final String baseWsUrl;
  final String Function() tokenProvider;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;

  final _events = StreamController<BoardEvent>.broadcast();
  final _connected = StreamController<bool>.broadcast();

  int _boardId = 0;
  int _retries = 0;
  bool _closedByUser = false;

  RealtimeClient({
    required this.baseWsUrl,
    required this.tokenProvider,
  });

  Stream<BoardEvent> get events => _events.stream;

  /// 连接状态流：true=已建立，false=断开。
  Stream<bool> get connected => _connected.stream;

  void subscribe(int boardId) {
    _boardId = boardId;
    _closedByUser = false;
    _retries = 0;
    _connect();
  }

  void _connect() {
    final token = tokenProvider();
    if (token.isEmpty || _boardId == 0) {
      _scheduleReconnect();
      return;
    }

    final uri = Uri.parse('$baseWsUrl/app/v1/ws?board_id=$_boardId&access_token=$token');
    try {
      _channel = WebSocketChannel.connect(uri);
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    _sub = _channel!.stream.listen(
      (data) {
        _retries = 0;
        _connected.add(true);
        _handleFrame(data);
      },
      onError: (_) => _onDown(),
      onDone: () => _onDown(),
      cancelOnError: true,
    );
  }

  void _handleFrame(dynamic data) {
    if (data is! String) return;
    try {
      final j = (jsonDecode(data) as Map).cast<String, dynamic>();
      _events.add(BoardEvent.fromJson(j));
    } catch (_) {
      // 非业务帧（如心跳文本）忽略
    }
  }

  void _onDown() {
    _connected.add(false);
    _sub?.cancel();
    _sub = null;
    _channel = null;
    if (!_closedByUser) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _retries < 5 ? 1 << _retries : 30);
    _retries++;
    _reconnectTimer = Timer(delay, _connect);
  }

  /// 切换订阅的看板。
  void resubscribe(int boardId) {
    _boardId = boardId;
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _retries = 0;
    _connect();
  }

  void dispose() {
    _closedByUser = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _events.close();
    _connected.close();
  }
}
