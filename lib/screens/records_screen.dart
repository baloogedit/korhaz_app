import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:korhaz_app/constants/colors.dart';

class RecordsScreen extends StatelessWidget {
  final String mode; // 'patient' or 'doctor'

  const RecordsScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    // Determine the title based on the mode
    final String title = mode == 'doctor' ? "Kórlapok Kezelése" : "Múltbeli Programálások";

    // Build the query based on the mode
    // (Matching the logic from your original Java app)
    Query query = FirebaseFirestore.instance.collection('MedicalRecords');
    if (mode == 'doctor') {
      query = query.where('doctor_id', isEqualTo: userId);
    } else {
      query = query.where('patient_id', isEqualTo: userId);
    }

    return Scaffold(
      backgroundColor: AppColors.bgTeal,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bgTeal,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Hiba történt: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 15),
                  const Text(
                    "Nincsenek elérhető kórlapok.",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final records = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: records.length,
            itemBuilder: (context, index) {
              var record = records[index];
              return _buildRecordCard(record);
            },
          );
        },
      ),
    );
  }

  // Modern Card UI for each medical record
  Widget _buildRecordCard(QueryDocumentSnapshot record) {
    String date = record['date'] ?? "Ismeretlen dátum";
    String doctorName = record['doctor_name'] ?? "Ismeretlen orvos";
    String section = record['section'] ?? "Ismeretlen szekció";
    String diagnosis = record['diagnosis'] ?? "Nincs diagnózis megadva.";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.navIndicator,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  date,
                  style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const Icon(Icons.medical_information_outlined, color: AppColors.primaryTeal),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "$doctorName - $section",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          const Text(
            "Diagnózis:",
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          const SizedBox(height: 5),
          Text(
            diagnosis,
            style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
          ),
        ],
      ),
    );
  }
}