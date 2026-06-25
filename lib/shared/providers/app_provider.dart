import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import '../../core/database/database_helper.dart';
import '../../core/storage/product_image_storage.dart';
import '../../core/network/local_server.dart';
import '../../core/voice/voice_announcer.dart';
import '../models/models.dart';
import '../models/staff_notification.dart';

enum AppMode { selection, staffAuth, staffPortal }

class AppProvider extends ChangeNotifier {
  AppMode _currentMode = AppMode.selection;
  AppMode get currentMode => _currentMode;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool get isServerRunning => LocalServer.instance.isRunning;
  String get serverIp => LocalServer.instance.ipAddress;
  int get serverPort => LocalServer.instance.port;
  bool _serverBusy = false;
  bool get serverBusy => _serverBusy;

  bool _isDarkTheme = false;
  bool get isDarkTheme => _isDarkTheme;

  void toggleTheme() {
    _isDarkTheme = !_isDarkTheme;
    notifyListeners();
  }

  List<RestaurantTable> _tables = [];
  List<Category> _categories = [];
  List<Product> _products = [];
  List<RestaurantOrder> _orders = [];
  List<WaiterCall> _waiterCalls = [];
  final List<StaffNotification> _notifications = [];

  List<RestaurantTable> get tables => _tables;
  List<Category> get categories => _categories;
  List<Product> get products => _products;
  List<RestaurantOrder> get orders => _orders;
  List<WaiterCall> get waiterCalls => _waiterCalls;
  List<StaffNotification> get notifications => List.unmodifiable(_notifications);

  String? _alertMessage;
  String? get alertMessage => _alertMessage;
  int get unreadNotificationCount => _notifications.where((n) => !n.read).length;

  AppProvider() {
    LocalServer.instance.onServerEvent = _onServerWebSocketEvent;
  }

  void clearAlert() {
    _alertMessage = null;
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void markNotificationRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].read = true;
      notifyListeners();
    }
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  void changeMode(AppMode mode) {
    _currentMode = mode;
    notifyListeners();
  }

  Future<void> startLocalServer({int port = 8080}) async {
    if (_serverBusy || isServerRunning) return;
    _serverBusy = true;
    notifyListeners();
    try {
      await LocalServer.instance.start(port: port);
      await refreshRestaurantData();
      unawaited(VoiceAnnouncer.instance.warmUp());
    } finally {
      _serverBusy = false;
      notifyListeners();
    }
  }

  Future<void> stopLocalServer() async {
    if (_serverBusy || !isServerRunning) return;
    _serverBusy = true;
    notifyListeners();
    try {
      await LocalServer.instance.stop();
    } finally {
      _serverBusy = false;
      notifyListeners();
    }
  }

  Future<void> refreshRestaurantData() async {
    _categories = await DatabaseHelper.instance.getAllCategories();
    _products = await DatabaseHelper.instance.getAllProducts();
    if (isServerRunning) {
      _tables = await DatabaseHelper.instance.getAllTables();
      _orders = await DatabaseHelper.instance.getAllOrders();
      _waiterCalls = await DatabaseHelper.instance.getActiveWaiterCalls();
    }
    notifyListeners();
  }

  Future<bool> loginStaff(String username) async {
    final user = await DatabaseHelper.instance.login(username);
    if (user != null) {
      _currentUser = user;
      _currentMode = AppMode.staffPortal;
      await refreshRestaurantData();
      notifyListeners();
      return true;
    }
    return false;
  }

  void logoutStaff() {
    _currentUser = null;
    _currentMode = AppMode.selection;
    _alertMessage = null;
    notifyListeners();
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    await DatabaseHelper.instance.updateOrderStatus(orderId, status);
    LocalServer.instance.broadcastEvent('order_status_updated', {
      'order_id': orderId,
      'status': status,
    });
    await refreshRestaurantData();
  }

  Future<void> markTableWaitingBill(int tableId) async {
    await DatabaseHelper.instance.updateTableStatus(tableId, 'enAttenteAddition');
    LocalServer.instance.broadcastEvent('table_status_updated', {
      'table_id': tableId,
      'status': 'enAttenteAddition',
    });
    await refreshRestaurantData();
  }

  Future<void> completeWaiterCall(int callId) async {
    await DatabaseHelper.instance.completeWaiterCall(callId);
    await refreshRestaurantData();
  }

  Future<void> payOrder(int orderId, String method) async {
    await DatabaseHelper.instance.payOrder(orderId, method);
    LocalServer.instance.broadcastEvent('order_paid', {
      'order_id': orderId,
    });
    await refreshRestaurantData();
  }

  String _tableLabel(int tableId) {
    for (final table in _tables) {
      if (table.id == tableId) return table.name;
    }
    return 'Table $tableId';
  }

  void _pushNotification({
    required String type,
    required String title,
    required String body,
  }) {
    _notifications.insert(
      0,
      StaffNotification(
        id: '${DateTime.now().microsecondsSinceEpoch}-$type',
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
      ),
    );
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }
  }

  void _onServerWebSocketEvent(String event, Map<String, dynamic> data) async {
    if (event == 'new_order') {
      final tableId = (data['table_id'] as num).toInt();
      final orderId = data['order_id'];
      final total = (data['total_amount'] as num?)?.toDouble();
      final label = _tableLabel(tableId);
      final amountText = total != null ? ' — ${total.round()} FCFA' : '';
      _alertMessage = '🛎️ Nouvelle commande — $label$amountText';
      _pushNotification(
        type: 'new_order',
        title: 'Nouvelle commande',
        body: '$label · Commande #$orderId$amountText',
      );
      HapticFeedback.mediumImpact();
      unawaited(VoiceAnnouncer.instance.announceNewOrder(label));
    } else if (event == 'waiter_call') {
      HapticFeedback.heavyImpact();
      // Le bandeau « Appels serveurs en attente » affiche déjà l'info.
    }

    await refreshRestaurantData();
    notifyListeners();
  }

  Future<int> addCategory(String name, String desc) async {
    final cat = Category(name: name, description: desc, position: _categories.length + 1);
    final id = await DatabaseHelper.instance.insertCategory(cat);
    await refreshRestaurantData();
    return id;
  }

  Future<void> editCategory(Category category) async {
    await DatabaseHelper.instance.updateCategory(category);
    await refreshRestaurantData();
  }

  Future<void> deleteCategory(int id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    await refreshRestaurantData();
  }

  Future<void> addProduct(
    String name,
    String desc,
    double price,
    int catId, {
    File? imageFile,
  }) async {
    final prod = Product(
      name: name,
      description: desc,
      price: price,
      imagePath: '',
      categoryId: catId,
      isAvailable: true,
    );
    final id = await DatabaseHelper.instance.insertProduct(prod);
    if (imageFile != null) {
      final filename = await ProductImageStorage.saveForProduct(id, imageFile);
      await DatabaseHelper.instance.updateProduct(prod.copyWith(id: id, imagePath: filename));
    }
    await refreshRestaurantData();
  }

  Future<void> setProductImage(int productId, File imageFile) async {
    final product = _products.firstWhere((p) => p.id == productId);
    final filename = await ProductImageStorage.saveForProduct(productId, imageFile);
    await DatabaseHelper.instance.updateProduct(product.copyWith(imagePath: filename));
    await refreshRestaurantData();
  }

  Future<void> editProduct(Product product) async {
    await DatabaseHelper.instance.updateProduct(product);
    await refreshRestaurantData();
  }

  Future<void> deleteProduct(int id) async {
    await DatabaseHelper.instance.deleteProduct(id);
    await refreshRestaurantData();
  }
}
