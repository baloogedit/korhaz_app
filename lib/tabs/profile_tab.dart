import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:korhaz_app/constants/colors.dart';
import 'package:korhaz_app/screens/records_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? userData;
  bool isDoctorMode = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          userData = doc.data();
          isDoctorMode = userData?['role'] == 'doctor';
          isLoading = false;
        });
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    // main.dart will automatically redirect to the Login screen!
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
    }

    if (userData == null) {
      return const Center(child: Text("Hiba az adatok betöltésekor."));
    }

    bool isUserDoctor = userData?['role'] == 'doctor';

    return Scaffold(
      backgroundColor: AppColors.bgTeal,
      appBar: AppBar(
        title: Text(isDoctorMode ? "Orvosi Oldal" : "Páciens Oldal", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bgTeal,
        elevation: 0,
        centerTitle: true,
        actions: [
          // If the user is a doctor, show a toggle button to switch modes
          if (isUserDoctor)
            IconButton(
              icon: Icon(isDoctorMode ? Icons.personal_injury : Icons.medical_services, color: AppColors.primaryTeal),
              tooltip: "Nézet váltása",
              onPressed: () => setState(() => isDoctorMode = !isDoctorMode),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(),
            const SizedBox(height: 30),
            
            if (isDoctorMode) _buildDoctorView() else _buildPatientView(),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 10),

            // Settings & Logout
            _buildSettingsTile(Icons.lock_outline, "Jelszó megváltoztatása", () {}),
            _buildSettingsTile(Icons.delete_outline, "Profil törlése", () {}, color: Colors.red),
            _buildSettingsTile(Icons.logout, "Kijelentkezés", _logout, color: Colors.red),
          ],
        ),
      ),
    );
  }

  // 1. THE PROFILE CARD
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primaryTeal.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userData?['name'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(userData?['email'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProfileInfoRow("CNP:", userData?['cnp'] ?? ""),
          if (isDoctorMode && userData?['section'] != null) ...[
            const SizedBox(height: 5),
            _buildProfileInfoRow("Szekció:", userData?['section'] ?? ""),
          ]
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // 2. PATIENT SPECIFIC VIEW
  Widget _buildPatientView() {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Közeledő programálások", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 15),
        
        // Fetch the active appointment from Firestore
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Appointments')
              .where('patient_id', isEqualTo: userId)
              .where('status', isEqualTo: 'aktív')
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyCard("Nincs közeledő időpontod.");
            }

            var appt = snapshot.data!.docs.first;
            return _buildAppointmentCard(appt['date'], appt['time'], appt['doctor'], appt['section']);
          },
        ),
        
        const SizedBox(height: 20),
        
        // Button to open Medical Records (Past appointments)
        _buildActionCard(
          "Múltbeli programálások", 
          Icons.history, 
          () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const RecordsScreen(mode: 'patient')));
          }
        ),
      ],
    );
  }

  // 3. DOCTOR SPECIFIC VIEW
  Widget _buildDoctorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Orvosi Eszközök", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 15),
        
        _buildActionCard(
          "Kórlapok kezelése", 
          Icons.folder_shared, 
          () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const RecordsScreen(mode: 'doctor')));
          }
        ),
      ],
    );
  }

  // Helper Widgets for UI
  Widget _buildAppointmentCard(String date, String time, String doctor, String section) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.navIndicator, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.calendar_today, color: AppColors.primaryTeal),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$date | $time", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text("$doctor ($section)", style: const TextStyle(color: AppColors.textGrey)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(message, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryTeal),
            const SizedBox(width: 15),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap, {Color color = Colors.black87}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}