import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:myproject/Catpage.dart/CatRegistrationPage.dart';
import 'package:myproject/Catpage.dart/cat.dart';
import 'CatDetailsPage.dart';

class CatHistoryPage extends StatefulWidget {
  const CatHistoryPage({Key? key}) : super(key: key);

  @override
  _CatHistoryPageState createState() => _CatHistoryPageState();
}

class _CatHistoryPageState extends State<CatHistoryPage> {
  List<Cat> cats = [];
  List<Cat> filteredCats = [];
  bool isLoading = true;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCats();
  }

  Future<void> loadCats() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      print("Current user: ${user?.uid}");

      if (user == null) {
        setState(() {
          cats = [];
          filteredCats = [];
          isLoading = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .get();

      print("Snapshot data: ${snapshot.docs.length} cats found");

      // ตรวจสอบข้อมูลดิบก่อนแปลงเป็นอ็อบเจกต์ Cat
      for (var doc in snapshot.docs) {
        print("Raw cat data for ${doc.id}: ${doc.data()}");
      }

      List<Cat> loadedCats = [];
      for (var doc in snapshot.docs) {
        try {
          Cat cat = Cat.fromFirestore(doc);
          print("Processed cat: ${cat.name}, ${cat.breed}");
          loadedCats.add(cat);
        } catch (e) {
          print("Error processing cat document ${doc.id}: $e");
        }
      }

      setState(() {
        cats = loadedCats;
        filteredCats = loadedCats;
        isLoading = false;
      });
    } catch (e) {
      print("Exception in loadCats(): $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> checkFirestoreConnection() async {
    try {
      await FirebaseFirestore.instance.collection('test').doc('test').get();
      return true;
    } catch (e) {
      print("Firestore connection error: $e");
      return false;
    }
  }

  String _calculateAge(Timestamp? birthDate) {
    if (birthDate == null) return 'ไม่ระบุ';

    try {
      DateTime now = DateTime.now();
      DateTime birth = birthDate.toDate();
      int years = now.year - birth.year;
      int months = now.month - birth.month;
      if (months < 0) {
        years--;
        months += 12;
      }
      return '$years ปี $months เดือน';
    } catch (e) {
      print("Error calculating age: $e");
      return 'ไม่ระบุ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'My Cats',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                setState(() {
                  isLoading = true;
                  cats = [];
                  filteredCats = [];
                });
                loadCats();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  filteredCats = cats
                      .where((cat) =>
                          cat.name.toLowerCase().contains(value.toLowerCase()))
                      .toList();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search cats...',
                hintStyle: TextStyle(color: Colors.grey[300]),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            )
          else if (filteredCats.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No cats found',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: Icon(Icons.add, color: Colors.white),
                      label: Text('Add a new cat',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CatRegistrationPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final cat = filteredCats[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CatDetailsPage(cat: cat),
                          ),
                        ).then((_) {
                          // โหลดข้อมูลใหม่เมื่อกลับมาจากหน้ารายละเอียด
                          loadCats();
                        });
                      },
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('Delete ${cat.name}?'),
                              content: Text(
                                  'Are you sure you want to delete this cat? This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  child: Text('Cancel'),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                TextButton(
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    try {
                                      final user =
                                          FirebaseAuth.instance.currentUser;
                                      if (user == null) return;

                                      // Delete image from Storage if exists
                                      if (cat.imagePath.isNotEmpty) {
                                        try {
                                          final ref = FirebaseStorage.instance
                                              .refFromURL(cat.imagePath);
                                          await ref.delete();
                                        } catch (e) {
                                          print('Error deleting image: $e');
                                        }
                                      }

                                      // Delete data from Firestore
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .collection('cats')
                                          .doc(cat.id)
                                          .delete();

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Successfully deleted ${cat.name}')),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Error deleting cat: $e')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 140,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(15),
                                      topRight: Radius.circular(15),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(15),
                                      topRight: Radius.circular(15),
                                    ),
                                    child: cat.imagePath.isNotEmpty
                                        ? Image.network(
                                            cat.imagePath,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              print(
                                                  "Error loading image for ${cat.name}: $error");
                                              return Container(
                                                color: Colors.grey[200],
                                                child: Center(
                                                  child: Icon(
                                                    Icons.pets,
                                                    size: 50,
                                                    color: Colors.grey[400],
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: Colors.grey[200],
                                            child: Center(
                                              child: Icon(
                                                Icons.pets,
                                                size: 50,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cat.name.isEmpty
                                                  ? 'ไม่มีชื่อ'
                                                  : cat.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(Icons.favorite,
                                              size: 20, color: Colors.red[300]),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        cat.breed.isEmpty
                                            ? 'ไม่ระบุสายพันธุ์'
                                            : cat.breed,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.cake,
                                              size: 14,
                                              color: Colors.orange[300]),
                                          const SizedBox(width: 4),
                                          Text(
                                            _calculateAge(cat.birthDate),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange[300],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.medical_services,
                                        size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      'วัคซีน: ${cat.vaccinations.isEmpty ? 'ไม่ระบุ' : cat.vaccinations}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
            ),
        ],
      ),
    );
  }
}
