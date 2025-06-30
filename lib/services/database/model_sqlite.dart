/// Data models for the kiosk system database.
/// Each class represents a table schema and provides serialization helpers.
/// These models are useful for type safety, data parsing, and database operations.

import 'dart:typed_data';

class DiscountInfo {
  final int? id;
  final String code;
  final num? cutPrice;
  final num? cutPercent;
  final String? productId;
  final String? setId;
  final String? condition;
  final int? usageCount;
  final int exist;

  DiscountInfo({
    this.id,
    required this.code,
    this.cutPrice,
    this.cutPercent,
    this.productId,
    this.setId,
    this.condition,
    this.usageCount,
    required this.exist,
  });

  factory DiscountInfo.fromMap(Map<String, dynamic> map) => DiscountInfo(
    id: map['id'],
    code: map['code'],
    cutPrice: map['cut_price'],
    cutPercent: map['cut_percent'],
    productId: map['product_id'],
    setId: map['set_id'],
    condition: map['condition'],
    usageCount: map['usage_count'],
    exist: map['exist'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'cut_price': cutPrice,
    'cut_percent': cutPercent,
    'product_id': productId,
    'set_id': setId,
    'condition': condition,
    'usage_count': usageCount,
    'exist': exist,
  };
}

class EmployeeAttendance {
  final int? id;
  final String employeeId;
  final String date;
  final String clockIn;
  final String clockOut;
  final num? totalHour;

  EmployeeAttendance({
    this.id,
    required this.employeeId,
    required this.date,
    required this.clockIn,
    required this.clockOut,
    this.totalHour,
  });

  factory EmployeeAttendance.fromMap(Map<String, dynamic> map) =>
      EmployeeAttendance(
        id: map['id'],
        employeeId: map['employee_id'],
        date: map['date'],
        clockIn: map['clock_in'],
        clockOut: map['clock_out'],
        totalHour: map['total_hour'],
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'employee_id': employeeId,
    'date': date,
    'clock_in': clockIn,
    'clock_out': clockOut,
    'total_hour': totalHour,
  };
}

class EmployeeInfo {
  final int? id;
  final String username;
  final String name;
  final int age;
  final String address;
  final String phoneNumber;
  final String email;
  final String? description;
  final String password;
  final int exist;
  final Uint8List? image;

  EmployeeInfo({
    this.id,
    required this.username,
    required this.name,
    required this.age,
    required this.address,
    required this.phoneNumber,
    required this.email,
    this.description,
    required this.password,
    required this.exist,
    this.image,
  });

  factory EmployeeInfo.fromMap(Map<String, dynamic> map) => EmployeeInfo(
    id: map['id'],
    username: map['username'],
    name: map['name'],
    age: map['age'],
    address: map['address'],
    phoneNumber: map['phone_number'],
    email: map['email'],
    description: map['description'],
    password: map['password'],
    exist: map['exist'],
    image: map['image'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'username': username,
    'name': name,
    'age': age,
    'address': address,
    'phone_number': phoneNumber,
    'email': email,
    'description': description,
    'password': password,
    'exist': exist,
    'image': image,
  };
}

class InventoryTransaction {
  final int? id;
  final String date;
  final String employeeId;
  final String data;

  InventoryTransaction({
    this.id,
    required this.date,
    required this.employeeId,
    required this.data,
  });

  factory InventoryTransaction.fromMap(Map<String, dynamic> map) =>
      InventoryTransaction(
        id: map['id'],
        date: map['date'],
        employeeId: map['employee_id'],
        data: map['data'],
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'employee_id': employeeId,
    'data': data,
  };
}

class KioskProduct {
  final int? id;
  final String name;
  final String? shortform;
  final String categories;
  final num price;
  final int totalStocks;
  final int totalPieces;
  final int? totalPiecesUsed;
  final int exist;
  final Uint8List? image;

  KioskProduct({
    this.id,
    required this.name,
    this.shortform,
    required this.categories,
    required this.price,
    required this.totalStocks,
    required this.totalPieces,
    this.totalPiecesUsed,
    required this.exist,
    this.image,
  });

  factory KioskProduct.fromMap(Map<String, dynamic> map) => KioskProduct(
    id: map['id'],
    name: map['name'],
    shortform: map['shortform'],
    categories: map['categories'],
    price: map['price'],
    totalStocks: map['total_stocks'],
    totalPieces: map['total_pieces'],
    totalPiecesUsed: map['total_pieces_used'],
    exist: map['exist'],
    image: map['image'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'shortform': shortform,
    'categories': categories,
    'price': price,
    'total_stocks': totalStocks,
    'total_pieces': totalPieces,
    'total_pieces_used': totalPiecesUsed,
    'exist': exist,
    'image': image,
  };
}

class KioskTransaction {
  final int? id;
  final int timestamp;
  final String employeeId;
  final String receiptList;
  final String paymentMethod;
  final double totalAmount;

  KioskTransaction({
    this.id,
    required this.timestamp,
    required this.employeeId,
    required this.receiptList,
    required this.paymentMethod,
    required this.totalAmount,
  });

  factory KioskTransaction.fromMap(Map<String, dynamic> map) =>
      KioskTransaction(
        id: map['id'],
        timestamp: map['timestamp'],
        employeeId: map['employee_id'],
        receiptList: map['receipt_list'],
        paymentMethod: map['payment_method'],
        totalAmount:
            map['total_amount'] is int
                ? (map['total_amount'] as int).toDouble()
                : map['total_amount'],
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp,
    'employee_id': employeeId,
    'receipt_list': receiptList,
    'payment_method': paymentMethod,
    'total_amount': totalAmount,
  };
}

class SetProduct {
  final int? id;
  final String name;
  final String groupNames;
  final double price;
  final String setItems;
  final int maxQty;
  final int exist;
  final Uint8List? image;

  SetProduct({
    this.id,
    required this.name,
    required this.groupNames,
    required this.price,
    required this.setItems,
    required this.maxQty,
    required this.exist,
    this.image,
  });

  factory SetProduct.fromMap(Map<String, dynamic> map) => SetProduct(
    id: map['id'],
    name: map['name'],
    groupNames: map['group_names'],
    price:
        map['price'] is int ? (map['price'] as int).toDouble() : map['price'],
    setItems: map['set_items'],
    maxQty: map['max_qty'],
    exist: map['exist'],
    image: map['image'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'group_names': groupNames,
    'price': price,
    'set_items': setItems,
    'max_qty': maxQty,
    'exist': exist,
    'image': image,
  };
}
