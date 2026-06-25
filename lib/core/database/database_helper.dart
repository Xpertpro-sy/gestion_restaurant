import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../shared/models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('resto_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAppSettingsTable(db);
    }
  }

  Future<void> _createAppSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createDB(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        role TEXT NOT NULL,
        name TEXT NOT NULL
      )
    ''');

    // Tables table
    await db.execute('''
      CREATE TABLE tables (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        position INTEGER NOT NULL
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price REAL NOT NULL,
        image_path TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        is_available INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Orders table
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        payment_status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (table_id) REFERENCES tables (id) ON DELETE CASCADE
      )
    ''');

    // Order Items table
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        notes TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // Waiter Calls table
    await db.execute('''
      CREATE TABLE waiter_calls (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (table_id) REFERENCES tables (id) ON DELETE CASCADE
      )
    ''');

    await _createAppSettingsTable(db);

    // Seed default data
    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    // 1. Seed Staff Users
    final users = [
      {'username': 'admin', 'role': 'admin', 'name': 'Administrateur'},
      {'username': 'caisse', 'role': 'caissier', 'name': 'Caissier Principal'},
      {'username': 'cuisine', 'role': 'cuisine', 'name': 'Chef de Cuisine'},
      {'username': 'serveur', 'role': 'serveur', 'name': 'Serveur A'},
    ];
    for (var u in users) {
      await db.insert('users', u);
    }

    // 2. Seed Tables (Table 1 to 8)
    for (int i = 1; i <= 8; i++) {
      await db.insert('tables', {
        'id': i,
        'name': 'Table $i',
        'status': 'libre',
      });
    }

    // 3. Seed Categories
    final categories = [
      {'name': 'Entrées', 'description': 'Apéritifs et amuse-bouche', 'position': 1},
      {'name': 'Plats', 'description': 'Plats de résistance', 'position': 2},
      {'name': 'Desserts', 'description': 'Douceurs et gâteaux', 'position': 3},
      {'name': 'Boissons', 'description': 'Boissons fraîches et chaudes', 'position': 4},
    ];
    for (var cat in categories) {
      await db.insert('categories', cat);
    }

    // 4. Seed Products
    final products = [
      // Entrées
      {'name': 'Salade César', 'description': 'Salade romaine, poulet grillé, croûtons, parmesan', 'price': 8.50, 'image_path': '', 'category_id': 1, 'is_available': 1},
      {'name': 'Nems aux Légumes', 'description': '4 pièces de nems croustillants faits maison', 'price': 6.00, 'image_path': '', 'category_id': 1, 'is_available': 1},
      // Plats
      {'name': 'Steak Frites', 'description': 'Filet de bœuf grillé, frites maison, sauce poivre', 'price': 18.00, 'image_path': '', 'category_id': 2, 'is_available': 1},
      {'name': 'Pizza Margherita', 'description': 'Sauce tomate bio, mozzarella di bufala, basilic frais', 'price': 12.50, 'image_path': '', 'category_id': 2, 'is_available': 1},
      {'name': 'Burger Spécial Maison', 'description': 'Bœuf, cheddar fondu, oignons caramélisés, frites', 'price': 15.00, 'image_path': '', 'category_id': 2, 'is_available': 1},
      // Desserts
      {'name': 'Tiramisu', 'description': 'Le classique dessert italien au café et mascarpone', 'price': 7.00, 'image_path': '', 'category_id': 3, 'is_available': 1},
      {'name': 'Moelleux au Chocolat', 'description': 'Cœur coulant, servi avec une boule de glace vanille', 'price': 7.50, 'image_path': '', 'category_id': 3, 'is_available': 1},
      // Boissons
      {'name': 'Coca-Cola', 'description': 'Canette de 33cl', 'price': 3.00, 'image_path': '', 'category_id': 4, 'is_available': 1},
      {'name': 'Jus d\'Orange Frais', 'description': 'Pressé minute', 'price': 4.50, 'image_path': '', 'category_id': 4, 'is_available': 1},
    ];
    for (var prod in products) {
      await db.insert('products', prod);
    }
  }

  // --- USER CRUD ---
  Future<UserModel?> login(String username) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  // --- TABLE CRUD ---
  Future<List<RestaurantTable>> getAllTables() async {
    final db = await instance.database;
    final result = await db.query('tables', orderBy: 'id ASC');
    return result.map((json) => RestaurantTable.fromMap(json)).toList();
  }

  Future<void> updateTableStatus(int id, String status) async {
    final db = await instance.database;
    await db.update(
      'tables',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CATEGORIES CRUD ---
  Future<List<Category>> getAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'position ASC');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  Future<int> insertCategory(Category category) async {
    final db = await instance.database;
    return await db.insert('categories', category.toMap());
  }

  Future<int> updateCategory(Category category) async {
    final db = await instance.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- PRODUCTS CRUD ---
  Future<List<Product>> getAllProducts() async {
    final db = await instance.database;
    final result = await db.query('products');
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RestaurantOrder>> getActiveOrdersByTable(int tableId) async {
    final db = await instance.database;
    final orderMaps = await db.query(
      'orders',
      where: 'table_id = ? AND status NOT IN (?, ?)',
      whereArgs: [tableId, 'payee', 'annulee'],
      orderBy: 'created_at DESC',
    );
    final orders = <RestaurantOrder>[];
    for (final oMap in orderMaps) {
      final items = await getOrderItems(oMap['id'] as int);
      orders.add(RestaurantOrder.fromMap(oMap, items: items));
    }
    return orders;
  }

  // --- ORDERS CRUD ---
  Future<List<RestaurantOrder>> getAllOrders() async {
    final db = await instance.database;
    final orderMaps = await db.query('orders', orderBy: 'created_at DESC');
    List<RestaurantOrder> orders = [];
    for (var oMap in orderMaps) {
      final items = await getOrderItems(oMap['id'] as int);
      orders.add(RestaurantOrder.fromMap(oMap, items: items));
    }
    return orders;
  }

  Future<List<OrderItem>> getOrderItems(int orderId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT oi.*, p.name as product_name
      FROM order_items oi
      JOIN products p ON oi.product_id = p.id
      WHERE oi.order_id = ?
    ''', [orderId]);
    return result.map((json) => OrderItem.fromMap(json)).toList();
  }

  Future<int> createOrder(RestaurantOrder order) async {
    final db = await instance.database;
    int orderId = 0;
    await db.transaction((txn) async {
      orderId = await txn.insert('orders', {
        'table_id': order.tableId,
        'status': order.status,
        'total_amount': order.totalAmount,
        'payment_method': order.paymentMethod,
        'payment_status': order.paymentStatus,
        'created_at': order.createdAt,
        'updated_at': order.updatedAt,
      });

      for (var item in order.items) {
        await txn.insert('order_items', {
          'order_id': orderId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'notes': item.notes,
        });
      }
      
      // Update table status to occupied
      await txn.update(
        'tables',
        {'status': 'occupee'},
        where: 'id = ?',
        whereArgs: [order.tableId],
      );
    });
    return orderId;
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    final db = await instance.database;
    await db.update(
      'orders',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> payOrder(int orderId, String method) async {
    final db = await instance.database;
    final orderList = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (orderList.isNotEmpty) {
      final int tableId = orderList.first['table_id'] as int;
      await db.transaction((txn) async {
        await txn.update(
          'orders',
          {
            'status': 'payee',
            'payment_status': 'paid',
            'payment_method': method,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
        // Mark table as free
        await txn.update(
          'tables',
          {'status': 'libre'},
          where: 'id = ?',
          whereArgs: [tableId],
        );
      });
    }
  }

  // --- WAITER CALLS CRUD ---
  Future<List<WaiterCall>> getActiveWaiterCalls() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT wc.*, t.name as table_name
      FROM waiter_calls wc
      JOIN tables t ON wc.table_id = t.id
      WHERE wc.status = 'pending'
      ORDER BY wc.created_at DESC
    ''');
    return result.map((json) => WaiterCall.fromMap(json)).toList();
  }

  Future<int> createWaiterCall(int tableId) async {
    final db = await instance.database;
    return await db.insert('waiter_calls', {
      'table_id': tableId,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> completeWaiterCall(int id) async {
    final db = await instance.database;
    await db.update(
      'waiter_calls',
      {'status': 'completed'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- REPORTS / STATS ---
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        SUM(total_amount) as total_revenue,
        COUNT(id) as total_orders
      FROM orders
      WHERE status = 'payee'
    ''');

    double revenue = 0.0;
    int orders = 0;
    if (result.isNotEmpty && result.first['total_revenue'] != null) {
      revenue = (result.first['total_revenue'] as num).toDouble();
      orders = result.first['total_orders'] as int;
    }

    // Get distribution of payment methods
    final payments = await db.rawQuery('''
      SELECT payment_method, SUM(total_amount) as total
      FROM orders
      WHERE status = 'payee'
      GROUP BY payment_method
    ''');

    Map<String, double> paymentMethods = {};
    for (var row in payments) {
      String method = row['payment_method'] as String? ?? 'Inconnu';
      double total = (row['total'] as num).toDouble();
      paymentMethods[method] = total;
    }

    return {
      'revenue': revenue,
      'orders': orders,
      'payment_methods': paymentMethods,
    };
  }

  Future<String?> getAppSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setAppSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
