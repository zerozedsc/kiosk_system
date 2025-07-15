import '../../configs/configs.dart';

/// [050725] KioskData
class KioskData {
  final String name;
  final String location;
  final String? description;

  KioskData({required this.name, required this.location, this.description});

  Map<String, dynamic> toJson() => {
    'name': name,
    'location': location,
    if (description != null) 'description': description,
  };

  @override
  String toString() =>
      'KioskData(name: $name, location: $location, description: $description)';
}

class ProductData {
  final String name;
  final double price;
  final String? description;
  final String? category;

  ProductData({
    required this.name,
    required this.price,
    this.description,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    if (description != null) 'description': description,
    if (category != null) 'category': category,
  };

  @override
  String toString() =>
      'ProductData(name: $name, price: $price, description: $description, category: $category)';
}

/// [050725] EmployeeData
class EmployeeData {
  final int? id;
  final String kioskId;
  final String username;
  final String name;
  final int age;
  final String? address;
  final String? phoneNumber;
  final String? email;
  final String? description;
  final String password;
  final bool exist;
  final bool isAdmin;
  final Uint8List?
  image; // BLOB data as bytes (equivalent to LargeBinary in Python)
  final DateTime? createdAt;

  EmployeeData({
    this.id,
    required this.kioskId,
    required this.username,
    required this.name,
    required this.age,
    this.address,
    this.phoneNumber,
    this.email,
    this.description,
    required this.password,
    required this.exist,
    required this.isAdmin,
    this.image,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'kiosk_id': kioskId,
    'username': username,
    'name': name,
    'age': age,
    if (address != null) 'address': address,
    if (phoneNumber != null) 'phone_number': phoneNumber,
    if (email != null) 'email': email,
    if (description != null) 'description': description,
    'password': password,
    'exist': exist,
    'is_admin': isAdmin,
    if (image != null) 'image': image, // Send as bytes or base64 if needed
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  @override
  String toString() =>
      'EmployeeData(id: $id, kioskId: $kioskId, username: $username, name: $name, age: $age, address: $address, phoneNumber: $phoneNumber, email: $email, description: $description, password: [REDACTED], exist: $exist, isAdmin: $isAdmin, image: ${image != null}, createdAt: $createdAt)';
}

/// [FIX:140725] Kiosk Transaction Data
class KioskTransactionData {
  final int timestamp;
  final String employeeId;
  final int receiptId;
  final String receiptList;
  final String paymentMethod;
  final double totalAmount;

  KioskTransactionData({
    required this.timestamp,
    required this.employeeId,
    required this.receiptList,
    required this.paymentMethod,
    required this.totalAmount,
    required this.receiptId,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'employee_id': employeeId,
    'receipt_id': receiptId, // Assuming receiptId is part of the data
    'receipt_list': receiptList,
    'payment_method': paymentMethod,
    'total_amount': totalAmount,
  };

  @override
  String toString() =>
      'KioskTransactionData(timestamp: $timestamp, employeeId: $employeeId, receiptList: $receiptList, paymentMethod: $paymentMethod, totalAmount: $totalAmount)';
}

/// [140725] Inventory Transaction Data
class InventoryTransactionData {
  final DateTime date;
  final String employeeId;
  final Map<String, dynamic> data;

  InventoryTransactionData({
    required this.date,
    required this.employeeId,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'employeeId': employeeId,
    'receipt_list': jsonEncode(data),
  };

  @override
  String toString() =>
      'InventoryTransactionData(date: $date, employeeId: $employeeId, data: $data)';
}

/// [050725] AttendanceData
class AttendanceData {
  final int employeeId;
  final DateTime checkIn;
  final DateTime? checkOut;
  final String? notes;

  AttendanceData({
    required this.employeeId,
    required this.checkIn,
    this.checkOut,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'check_in': checkIn.toIso8601String(),
    if (checkOut != null) 'check_out': checkOut!.toIso8601String(),
    if (notes != null) 'notes': notes,
  };

  @override
  String toString() =>
      'AttendanceData(employeeId: $employeeId, checkIn: $checkIn, checkOut: $checkOut, notes: $notes)';
}

class DiscountData {
  final String name;
  final double percentage;
  final String? description;
  final DateTime? validFrom;
  final DateTime? validTo;

  DiscountData({
    required this.name,
    required this.percentage,
    this.description,
    this.validFrom,
    this.validTo,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'percentage': percentage,
    if (description != null) 'description': description,
    if (validFrom != null) 'valid_from': validFrom!.toIso8601String(),
    if (validTo != null) 'valid_to': validTo!.toIso8601String(),
  };

  @override
  String toString() =>
      'DiscountData(name: $name, percentage: $percentage, description: $description, validFrom: $validFrom, validTo: $validTo)';
}
