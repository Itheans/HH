import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class Cat {
  final String id;
  final String name;
  final String breed;
  final String imagePath;
  final Timestamp? birthDate;
  final String vaccinations;
  final String description;
  final bool isForSitting;
  final String? sittingStatus;
  final Timestamp? lastSittingDate;

  Cat({
    required this.id,
    required this.name,
    required this.breed,
    required this.imagePath,
    this.birthDate,
    required this.vaccinations,
    required this.description,
    this.isForSitting = false,
    this.sittingStatus,
    this.lastSittingDate,
  });

  factory Cat.fromFirestore(DocumentSnapshot doc) {
    try {
      // ตรวจสอบว่ามีข้อมูลหรือไม่
      if (!doc.exists) {
        print("Document ${doc.id} does not exist");
        return Cat(
          id: doc.id,
          name: 'ไม่พบข้อมูล',
          breed: 'ไม่ทราบ',
          imagePath: '',
          vaccinations: '',
          description: '',
        );
      }

      // ตรวจสอบว่าแปลงข้อมูลเป็น Map ได้หรือไม่
      Map<String, dynamic>? data;
      try {
        data = doc.data() as Map<String, dynamic>?;
      } catch (e) {
        print("Error casting doc.data() to Map<String, dynamic>: $e");
        return Cat(
          id: doc.id,
          name: 'ข้อมูลไม่ถูกต้อง',
          breed: 'ไม่ทราบ',
          imagePath: '',
          vaccinations: '',
          description: '',
        );
      }

      // ถ้าไม่มีข้อมูล
      if (data == null) {
        print("Data is null for document ${doc.id}");
        return Cat(
          id: doc.id,
          name: 'ข้อมูลว่างเปล่า',
          breed: 'ไม่ทราบ',
          imagePath: '',
          vaccinations: '',
          description: '',
        );
      }

      // ตรวจสอบข้อมูลสำคัญแต่ละอย่าง
      String name = '';
      if (data.containsKey('name')) {
        var nameValue = data['name'];
        if (nameValue is String) {
          name = nameValue;
        } else {
          print("Name is not a string: $nameValue");
          name = 'ชื่อไม่ถูกต้อง';
        }
      } else {
        print("Document ${doc.id} does not contain 'name' field");
        name = 'ไม่มีชื่อ';
      }

      return Cat(
        id: doc.id,
        name: name,
        breed: data['breed'] as String? ?? 'ไม่ทราบ',
        imagePath: data['imagePath'] as String? ?? '',
        birthDate: data['birthDate'] as Timestamp?,
        vaccinations: data['vaccinations'] as String? ?? '',
        description: data['description'] as String? ?? '',
        isForSitting: data['isForSitting'] as bool? ?? false,
        sittingStatus: data['sittingStatus'] as String?,
        lastSittingDate: data['lastSittingDate'] as Timestamp?,
      );
    } catch (e) {
      print("Error in Cat.fromFirestore for document ${doc.id}: $e");
      return Cat(
        id: doc.id,
        name:
            'Error: ${e.toString().substring(0, min(20, e.toString().length))}',
        breed: 'Error',
        imagePath: '',
        vaccinations: '',
        description: '',
      );
    }
  }

  // เพิ่ม method นี้เพื่อดีบัก
  @override
  String toString() {
    return 'Cat{id: $id, name: $name, breed: $breed, vaccinations: $vaccinations}';
  }
}
