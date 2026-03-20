import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '/constants/colors.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? selectedSection;
  Map<String, dynamic>? sectionDetails;
  String doctorNames = "Betöltés...";

  @override
  void initState() { //usage of provider
    super.initState();
    // Fetch user data when the tab loads
    // false: required when call provider inside initState
    Provider.of<UserProvider>(context, listen: false).fetchUserData();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgTeal,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. The Modern Top Header (Curved Teal Gradient)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 70, left: 20, right: 20, bottom: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E5665), Color(0xFF268585)], // Teal gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  Text(
                    // Ha az adat betöltött, kiírjuk a nevét, ha még nem, csak annyit: "Üdvözlünk!"
                    userProvider.userData != null 
                        ? "Üdvözlünk, ${userProvider.userData!['name']}!" 
                        : "Üdvözlünk!",
                    style: const TextStyle(color: AppColors.textWhiteFaded, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "KorhazApp Központ", // Your Hospital Name
                    style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // 2. The Floating Information Card
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Szekció kiválasztása", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        
                        // Firestore Stream for the Dropdown
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('Sections').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const CircularProgressIndicator();
                            
                            List<DropdownMenuItem<String>> sectionItems = snapshot.data!.docs.map((doc) {
                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text(doc.id),
                              );
                            }).toList();

                            return DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: AppColors.inputFill,
                              ),
                              hint: const Text("Válassz szekciót..."),
                              initialValue: selectedSection,
                              items: sectionItems,
                              onChanged: (value) {
                                setState(() => selectedSection = value);
                                _loadSectionDetails(value!);
                              },
                            );
                          },
                        ),
                        
                        const Divider(height: 40),

                        // Details Section
                        if (sectionDetails != null) ...[
                          _buildDetailRow(Icons.info_outline, "Leírás", sectionDetails!['description']),
                          const SizedBox(height: 15),
                          _buildDetailRow(Icons.location_on_outlined, "Cím", sectionDetails!['address']),
                          const SizedBox(height: 15),
                          _buildDetailRow(Icons.access_time, "Program", sectionDetails!['program']),
                          const SizedBox(height: 15),
                          _buildDetailRow(Icons.medical_services_outlined, "Orvosok", doctorNames),
                        ] else ...[
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text("Válassz egy szekciót a részletekért.", style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to draw clean rows with icons
  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryTeal, size: 24),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  // Logic to fetch details and doctors from Firestore
  void _loadSectionDetails(String sectionId) async {
    // Fetch section details
    var doc = await FirebaseFirestore.instance.collection('Sections').doc(sectionId).get();
    
    // Fetch doctors for this section
    var doctorsQuery = await FirebaseFirestore.instance
        .collection('Users')
        .where('role', isEqualTo: 'doctor')
        .where('section', isEqualTo: sectionId)
        .get();

    String loadedDoctors = doctorsQuery.docs.map((d) => d['name']).join(", ");

    setState(() {
      sectionDetails = doc.data();
      doctorNames = loadedDoctors.isEmpty ? "Nincsenek orvosok ebben a szekcióban." : loadedDoctors;
    });
  }
}