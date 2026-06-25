import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../../shared/models/models.dart';
import '../storage/product_image_storage.dart';
import 'client_web_content.dart';

class LocalServer {
  static final LocalServer instance = LocalServer._init();
  LocalServer._init();

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;
  final List<WebSocket> _clients = [];
  bool _isRunning = false;
  String _ipAddress = '127.0.0.1';
  int _port = 8080;
  Future<void>? _lifecycleLock;

  // Callback to notify the UI of state updates or server events
  Function(String event, Map<String, dynamic> data)? onServerEvent;

  bool get isRunning => _isRunning;
  String get ipAddress => _ipAddress;
  int get port => _port;

  Future<void> start({int port = 8080}) {
    _lifecycleLock ??= Future.value();
    final next = _lifecycleLock!.then((_) => _startInternal(port));
    _lifecycleLock = next.catchError((_) {});
    return next;
  }

  Future<void> stop() {
    _lifecycleLock ??= Future.value();
    final next = _lifecycleLock!.then((_) => _stopInternal());
    _lifecycleLock = next.catchError((_) {});
    return next;
  }

  Future<void> _startInternal(int port) async {
    if (_isRunning) return;
    _port = port;
    _ipAddress = await _getLocalIP();

    if (_server != null) {
      await _forceCleanup();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    try {
      await _bindServer();
    } catch (e) {
      if (_isAddressInUse(e)) {
        _debugLog('Port $_port busy, retrying after cleanup...');
        await _forceCleanup();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        try {
          await _bindServer();
          return;
        } catch (retryError) {
          _debugLog('Error starting server after retry: $retryError');
          await _forceCleanup();
          rethrow;
        }
      }
      _debugLog('Error starting server: $e');
      await _forceCleanup();
      rethrow;
    }
  }

  Future<void> _bindServer() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
    _isRunning = true;
    _debugLog('Server started on http://$_ipAddress:$_port');

    _subscription = _server!.listen(
      _onRequest,
      onError: (error) => _debugLog('Server stream error: $error'),
      cancelOnError: false,
    );
  }

  Future<void> _stopInternal() async {
    if (!_isRunning && _server == null) return;
    await _forceCleanup();
    _debugLog('Server stopped');
  }

  Future<void> _forceCleanup() async {
    _isRunning = false;

    final clients = List<WebSocket>.from(_clients);
    _clients.clear();
    for (final client in clients) {
      try {
        await client
            .close(WebSocketStatus.goingAway, 'Server stopping')
            .timeout(const Duration(seconds: 1));
      } catch (_) {
        try {
          client.close(WebSocketStatus.abnormalClosure);
        } catch (_) {}
      }
    }

    try {
      await _subscription?.cancel();
    } catch (e) {
      _debugLog('Error cancelling subscription: $e');
    }
    _subscription = null;

    final server = _server;
    _server = null;
    if (server != null) {
      try {
        await server.close(force: true).timeout(const Duration(seconds: 5));
      } on TimeoutException {
        _debugLog('Server close timed out — state reset anyway');
      } catch (e) {
        _debugLog('Error closing server socket: $e');
      }
    }
  }

  bool _isAddressInUse(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('address already in use') ||
        message.contains('errno = 98') ||
        message.contains('errno = 48') ||
        message.contains('eaddrinuse');
  }

  void _onRequest(HttpRequest request) {
    if (!_isRunning) {
      _rejectRequest(request);
      return;
    }

    _handleCORS(request);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      request.response.close();
      return;
    }

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      _handleWebSocket(request);
    } else {
      _handleHttpRequest(request);
    }
  }

  void _rejectRequest(HttpRequest request) {
    try {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.close();
    } catch (_) {}
  }

  Future<String> _getLocalIP() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      _debugLog('Failed to get network interfaces: $e');
    }
    return '127.0.0.1';
  }

  void _handleCORS(HttpRequest request) {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE');
    request.response.headers.add('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  }

  void _handleWebSocket(HttpRequest request) async {
    if (!_isRunning) {
      _rejectRequest(request);
      return;
    }
    try {
      WebSocket socket = await WebSocketTransformer.upgrade(request);
      _clients.add(socket);
      _debugLog('New WebSocket client connected (Total: ${_clients.length})');

      socket.listen(
        (message) {
          _handleWebSocketMessage(socket, message);
        },
        onDone: () {
          _clients.remove(socket);
          _debugLog('WebSocket client disconnected (Total: ${_clients.length})');
        },
        onError: (error) {
          _clients.remove(socket);
          _debugLog('WebSocket error: $error');
        },
      );
    } catch (e) {
      _debugLog('Error upgrading to WebSocket: $e');
    }
  }

  void _handleWebSocketMessage(WebSocket socket, String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;
      
      _debugLog('WebSocket message received: $type');

      if (type == 'ping') {
        socket.add(jsonEncode({'type': 'pong'}));
        return;
      }

      // Broadcast message to all other clients (Relay server role)
      _broadcast(message, exclude: socket);

      if (onServerEvent != null && type != null) {
        onServerEvent!(type, data);
      }
    } catch (e) {
      _debugLog('Error parsing WebSocket message: $e');
    }
  }

  void _broadcast(String message, {WebSocket? exclude}) {
    for (var client in _clients) {
      if (client != exclude && client.readyState == WebSocket.open) {
        client.add(message);
      }
    }
  }

  // Broadcasts event programmatically from the server device (e.g. staff updates status)
  void broadcastEvent(String type, Map<String, dynamic> payload) {
    final data = <String, dynamic>{
      'type': type,
      ...payload,
    };
    final message = jsonEncode(data);
    _broadcast(message);
    if (onServerEvent != null) {
      onServerEvent!(type, data);
    }
  }

  void _handleHttpRequest(HttpRequest request) async {
    if (!_isRunning) {
      _rejectRequest(request);
      return;
    }

    final response = request.response;
    final path = request.uri.path;

    try {
      if (request.method == 'GET') {
        final tableRoute = RegExp(r'^/t/(\d+)$').firstMatch(path);
        if (tableRoute != null) {
          _sendHtml(response, ClientWebContent.indexHtml);
          return;
        }
      }
      if (request.method == 'GET' && (path == '/menu' || path == '/')) {
        _sendHtml(response, ClientWebContent.indexHtml);
        return;
      }
      if (request.method == 'GET' && path == '/client/manifest.webmanifest') {
        response.headers.contentType = ContentType('application', 'manifest+json', charset: 'utf-8');
        response.write(ClientWebContent.manifestJson);
        response.close();
        return;
      }
      if (request.method == 'GET' && path == '/client/sw.js') {
        response.headers.contentType = ContentType('application', 'javascript', charset: 'utf-8');
        response.write(ClientWebContent.serviceWorkerJs);
        response.close();
        return;
      }

      if (request.method == 'GET' && path.startsWith('/api/images/')) {
        final filename = Uri.decodeComponent(path.substring('/api/images/'.length));
        final file = await ProductImageStorage.fileFor(filename);
        if (file == null) {
          response.statusCode = HttpStatus.notFound;
          response.close();
          return;
        }
        final contentType = ProductImageStorage.contentTypeFor(filename) ?? 'application/octet-stream';
        response.headers.contentType = ContentType.parse(contentType);
        await response.addStream(file.openRead());
        await response.close();
        return;
      }

      if (path == '/api/orders' && request.method == 'GET') {
        final tableId = int.tryParse(request.uri.queryParameters['table_id'] ?? '');
        if (tableId == null) {
          response.statusCode = HttpStatus.badRequest;
          _sendJSON(response, {'error': 'table_id required'});
          return;
        }
        final orders = await DatabaseHelper.instance.getActiveOrdersByTable(tableId);
        _sendJSON(response, orders.map((o) => {
          'order_id': o.id,
          'status': o.status,
          'total_amount': o.totalAmount,
          'created_at': o.createdAt,
        }).toList());
        return;
      }

      if (path == '/api/menu' && request.method == 'GET') {
        final categories = await DatabaseHelper.instance.getAllCategories();
        final products = await DatabaseHelper.instance.getAllProducts();

        final result = categories.map((cat) {
          return {
            'id': cat.id,
            'name': cat.name,
            'description': cat.description,
            'position': cat.position,
            'products': products
                .where((prod) => prod.categoryId == cat.id)
                .map((prod) => prod.toMap())
                .toList(),
          };
        }).toList();

        _sendJSON(response, result);
      } else if (path == '/api/orders' && request.method == 'POST') {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        
        // Parse order
        final tableId = data['table_id'] as int;
        final totalAmount = (data['total_amount'] as num).toDouble();
        
        final List<dynamic> itemsData = data['items'] as List<dynamic>;
        final items = itemsData.map((itemMap) => OrderItem.fromMap(itemMap)).toList();

        final newOrder = RestaurantOrder(
          tableId: tableId,
          status: 'nouvelle',
          totalAmount: totalAmount,
          paymentMethod: 'none',
          paymentStatus: 'pending',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          items: items,
        );

        final orderId = await DatabaseHelper.instance.createOrder(newOrder);
        
        // Broadcast new order notification to all listening clients (waiters, kitchen, cashier)
        broadcastEvent('new_order', {
          'order_id': orderId,
          'table_id': tableId,
          'total_amount': totalAmount,
        });

        _sendJSON(response, {'success': true, 'order_id': orderId});
      } else if (path == '/api/waiter_call' && request.method == 'POST') {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final tableId = data['table_id'] as int;

        final callId = await DatabaseHelper.instance.createWaiterCall(tableId);

        // Broadcast notification
        broadcastEvent('waiter_call', {
          'id': callId,
          'table_id': tableId,
          'created_at': DateTime.now().toIso8601String(),
        });

        _sendJSON(response, {'success': true, 'call_id': callId});
      } else {
        response.statusCode = HttpStatus.notFound;
        _sendJSON(response, {'error': 'Route not found'});
      }
    } catch (e) {
      _debugLog('HTTP Handler Error: $e');
      response.statusCode = HttpStatus.internalServerError;
      _sendJSON(response, {'error': 'Internal server error: $e'});
    }
  }

  void _sendJSON(HttpResponse response, dynamic data) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    response.close();
  }

  void _sendHtml(HttpResponse response, String html) {
    response.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
    response.headers.add('Cache-Control', 'no-cache');
    response.write(html);
    response.close();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      print('[LocalServer] $message');
    }
  }
}
