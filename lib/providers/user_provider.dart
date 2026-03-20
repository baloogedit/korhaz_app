import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ChangeNotifier tells Flutter to update the UI whenever notifyListeners() is called
class UserProvider with ChangeNotifier {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  // Getters so other files can read the data securely
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isDoctor => _userData?['role'] == 'doctor';

  // Fetch the data from Firebase
  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _userData = doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print("Hiba a felhasználói adatok lekérésekor: $e");
    } finally {
      _isLoading = false;
      notifyListeners(); // This triggers the UI to redraw with the new data!
    }
  }

  // Clear data on logout
  void clearUser() {
    _userData = null;
    notifyListeners();
  }
}