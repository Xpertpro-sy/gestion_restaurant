class UserModel {
  final int? id;
  final String username;
  final String role; // admin, cuisine, serveur, caissier
  final String name;

  UserModel({
    this.id,
    required this.username,
    required this.role,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'role': role,
      'name': name,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      username: map['username'] as String,
      role: map['role'] as String,
      name: map['name'] as String,
    );
  }
}

class RestaurantTable {
  final int id;
  final String name;
  final String status; // libre, occupee, enAttenteAddition, fermee

  RestaurantTable({
    required this.id,
    required this.name,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status,
    };
  }

  factory RestaurantTable.fromMap(Map<String, dynamic> map) {
    return RestaurantTable(
      id: map['id'] as int,
      name: map['name'] as String,
      status: map['status'] as String,
    );
  }
}

class Category {
  final int? id;
  final String name;
  final String description;
  final int position;

  Category({
    this.id,
    required this.name,
    required this.description,
    required this.position,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'position': position,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String,
      position: map['position'] as int,
    );
  }
}

class Product {
  final int? id;
  final String name;
  final String description;
  final double price;
  final String imagePath;
  final int categoryId;
  final bool isAvailable;

  Product({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.categoryId,
    required this.isAvailable,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image_path': imagePath,
      'category_id': categoryId,
      'is_available': isAvailable ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String,
      price: (map['price'] as num).toDouble(),
      imagePath: map['image_path'] as String? ?? '',
      categoryId: map['category_id'] as int,
      isAvailable: (map['is_available'] as int) == 1,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    String? imagePath,
    int? categoryId,
    bool? isAvailable,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imagePath: imagePath ?? this.imagePath,
      categoryId: categoryId ?? this.categoryId,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class RestaurantOrder {
  final int? id;
  final int tableId;
  final String status; // nouvelle, acceptee, enPreparation, prete, servie, payee, annulee
  final double totalAmount;
  final String paymentMethod; // especes, orangeMoney, moovMoney, none
  final String paymentStatus; // pending, paid
  final String createdAt;
  final String updatedAt;
  final List<OrderItem> items;

  RestaurantOrder({
    this.id,
    required this.tableId,
    required this.status,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'table_id': tableId,
      'status': status,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory RestaurantOrder.fromMap(Map<String, dynamic> map, {List<OrderItem> items = const []}) {
    return RestaurantOrder(
      id: map['id'] as int?,
      tableId: map['table_id'] as int,
      status: map['status'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String? ?? 'none',
      paymentStatus: map['payment_status'] as String? ?? 'pending',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      items: items,
    );
  }

  RestaurantOrder copyWith({
    int? id,
    int? tableId,
    String? status,
    double? totalAmount,
    String? paymentMethod,
    String? paymentStatus,
    String? createdAt,
    String? updatedAt,
    List<OrderItem>? items,
  }) {
    return RestaurantOrder(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}

class OrderItem {
  final int? id;
  final int? orderId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final String notes;
  final String productName; // Joined/cached helper

  OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.notes,
    this.productName = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'notes': notes,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      productId: map['product_id'] as int,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      notes: map['notes'] as String? ?? '',
      productName: map['product_name'] as String? ?? '',
    );
  }
}

class WaiterCall {
  final int? id;
  final int tableId;
  final String status; // pending, completed
  final String createdAt;
  final String tableName; // Helper joined name

  WaiterCall({
    this.id,
    required this.tableId,
    required this.status,
    required this.createdAt,
    this.tableName = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'table_id': tableId,
      'status': status,
      'created_at': createdAt,
    };
  }

  factory WaiterCall.fromMap(Map<String, dynamic> map) {
    return WaiterCall(
      id: map['id'] as int?,
      tableId: map['table_id'] as int,
      status: map['status'] as String,
      createdAt: map['created_at'] as String,
      tableName: map['table_name'] as String? ?? '',
    );
  }
}
