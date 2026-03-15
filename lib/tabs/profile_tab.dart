// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:korhaz_app/constants/colors.dart';
import 'package:korhaz_app/screens/records_screen.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

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
        boxShadow: [BoxShadow(color: AppColors.primaryTeal.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))],
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
            return _buildAppointmentCard(
              appt.id, // Pass the document ID
              appt['date'], 
              appt['time'], 
              appt['doctor'], 
              appt['section'],
              appt['status'] // Pass the status
            );
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
  Widget _buildAppointmentCard(String appId, String date, String time, String doctor, String section, String status) {
    bool isCheckedIn = status == 'megérkezett';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
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
          const SizedBox(height: 15),
          
          // The Check-in Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isCheckedIn ? null : () => _tryCheckIn(appId, date, time, doctor),
              icon: Icon(isCheckedIn ? Icons.check_circle : Icons.location_on),
              label: Text(isCheckedIn ? "Sikeresen bejelentkezve!" : "Megérkeztem (Check-in)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCheckedIn ? Colors.green : AppColors.primaryTeal,
                foregroundColor: Colors.white,
              ),
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

  Future<void> _tryCheckIn(
    String appointmentId,
    String date,
    String time,
    String doctorName,
  ) async {
    // --- 1. TIME CHECK ---
    // Combine date and time to create a DateTime object
    DateTime apptTime = DateFormat('yyyy-MM-dd HH:mm').parse('$date $time');
    DateTime now = DateTime.now();

    // Calculate the difference in minutes
    int diffMinutes = now.difference(apptTime).inMinutes;

    // Is it outside the +/- 5 minute window?
    if (diffMinutes < -5 || diffMinutes > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Csak az időpontod előtt/után 5 perccel jelentkezhetsz be!",
          ),
        ),
      );
      return;
    }

    // --- 2. WIFI CHECK ---
    // Request location permission (required by Android/iOS to read WiFi names)
    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Helymeghatározás engedélye szükséges a WiFi ellenőrzéséhez!",
          ),
        ),
      );
      return;
    }

    // Read the WiFi name
    final info = NetworkInfo();
    String? wifiName = await info.getWifiName();

    // Clean up the wifi name (Android sometimes wraps it in quotes like "MyWiFi")
    wifiName = wifiName?.replaceAll('"', '');

    // TODO: Change "HOSPITAL_WIFI" to your actual HOME WiFi name so you can test it!
    const String requiredWifi = "TP-Link_404F";

    if (wifiName != requiredWifi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Nem a kórház WiFi hálózatán vagy! (Jelenlegi: $wifiName)",
          ),
        ),
      );
      return;
    }

    // --- 3. SUCCESS! UPDATE DATABASE & SHOW ROOM ---

    // Generate a random room/floor for the prototype based on the doctor's name length
    // (In a real app, you would fetch this from the Doctor's Firestore document)
    int floor = (doctorName.length % 3) + 1;
    int room = (doctorName.length * 12) % 100 + 100;

    // Update the appointment status to checked-in
    await FirebaseFirestore.instance
        .collection('Appointments')
        .doc(appointmentId)
        .update({'status': 'megérkezett'});

    if (!mounted) return;

    // Show the massive success dialog with directions!
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Sikeres Bejelentkezés!",
          style: TextStyle(color: AppColors.primaryTeal),
        ),
        content: Text(
          "Az orvosod már vár rád.\n\n"
          "Kérjük fáradj a(z) $floor. emeletre, a $room-as terembe.",
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Rendben", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
