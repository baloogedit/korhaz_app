// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:korhaz_app/constants/colors.dart';
import 'package:korhaz_app/screens/records_screen.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    final String doctorName = userData?['name'] ?? "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Mai és Közeledő Páciensek", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 15),
        
        // Listen to all appointments for THIS doctor
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Appointments')
              .where('doctor', isEqualTo: doctorName)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyCard("Jelenleg nincs aktív előjegyzésed.");
            }

            // Filter out completed ("befejezett") appointments locally
            var activeAppointments = snapshot.data!.docs.where((doc) {
              return doc['status'] == 'aktív' || doc['status'] == 'megérkezett';
            }).toList();

            // Sort them by Date, then by Time so the schedule is in order
            activeAppointments.sort((a, b) {
              int dateComp = (a['date'] as String).compareTo(b['date'] as String);
              if (dateComp != 0) return dateComp;
              return (a['time'] as String).compareTo(b['time'] as String);
            });

            if (activeAppointments.isEmpty) {
              return _buildEmptyCard("Jelenleg nincs aktív előjegyzésed.");
            }

            // Build a list of cards for the patients
            return ListView.builder(
              shrinkWrap: true, // Needed because we are inside a SingleChildScrollView
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeAppointments.length,
              itemBuilder: (context, index) {
                var appt = activeAppointments[index];
                bool isCheckedIn = appt['status'] == 'megérkezett';
                
                return _buildDoctorAppointmentCard(
                  appt.id,
                  appt['date'],
                  appt['time'],
                  appt['patient_id'],
                  isCheckedIn,
                );
              },
            );
          },
        ),
        
        const SizedBox(height: 30),
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

  
  // Smart Card for the Doctor's View (with Consultation Button)
  Widget _buildDoctorAppointmentCard(String appId, String date, String time, String patientId, bool isCheckedIn) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('Users').doc(patientId).get(),
      builder: (context, snapshot) {
        String patientName = "Páciens betöltése...";
        if (snapshot.hasData && snapshot.data!.exists) {
          patientName = snapshot.data!['name'] ?? "Ismeretlen Páciens";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(15),
            border: isCheckedIn ? Border.all(color: Colors.green, width: 2) : Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCheckedIn ? Colors.green.shade50 : AppColors.navIndicator, 
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Icon(
                      isCheckedIn ? Icons.how_to_reg : Icons.person_outline, 
                      color: isCheckedIn ? Colors.green : AppColors.primaryTeal
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("$date | $time", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 5),
                        Text(patientName, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (isCheckedIn) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 5),
                  child: Text("✅ A páciens megérkezett a váróba!", style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                 const SizedBox(height: 15),
              ],

              // The Consultation Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showDiagnosisDialog(appId, patientId, patientName, date),
                  icon: const Icon(Icons.edit_document, size: 18),
                  label: const Text("Konzultáció Indítása"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCheckedIn ? AppColors.primaryTeal : Colors.grey.shade100,
                    foregroundColor: isCheckedIn ? Colors.white : AppColors.primaryTeal,
                    elevation: isCheckedIn ? 2 : 0,
                  ),
                ),
              )
            ],
          ),
        );
      }
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

  Future<void> _tryCheckIn(String appointmentId, String date, String time, String doctorName) async {
    // 1. Get Location Permission & WiFi Name (Client side)
    var status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Helymeghatározás engedélye szükséges a WiFi ellenőrzéséhez!")),
      );
      return;
    }

    final info = NetworkInfo();
    String? wifiName = await info.getWifiName();
    wifiName = wifiName?.replaceAll('"', ''); // Clean up name

    // 2. Call the Node.js Server
    // TODO: change wifi name in server (index.js) to match testing environment (ln. 24)
    // IMPORTANT: If testing on an Android Emulator, use "10.0.2.2" instead of "localhost"
    // If testing on a real phone via USB, use your computer's local IP (e.g., 192.168.1.X)
    final String serverUrl = "http://10.0.2.2:3000/api/checkin";

    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "appointmentId": appointmentId,
          "date": date,
          "time": time,
          "wifiName": wifiName ?? "Ismeretlen",
          "doctorName": doctorName,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (!mounted) return;

      // 3. Handle Server Response
      if (response.statusCode == 200 && responseData['success'] == true) {
        // Success! The server updated the DB and sent us the room info
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Sikeres Bejelentkezés!", style: TextStyle(color: AppColors.primaryTeal)),
            content: Text(
              "Az orvosod már vár rád.\n\n"
              "Kérjük fáradj a(z) ${responseData['floor']}. emeletre, a ${responseData['room']}-as terembe.",
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Rendben", style: TextStyle(fontSize: 16)),
              )
            ],
          ),
        );
      } else {
        // The server rejected the check-in (Wrong WiFi or Time)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? "Ismeretlen hiba")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nem sikerült kapcsolódni a szerverhez: $e")),
      );
    }
  }


// 4. THE CONSULTATION DIALOG
  Future<void> _showDiagnosisDialog(String appointmentId, String patientId, String patientName, String date) async {
    final TextEditingController diagnosisController = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Konzultáció: $patientName", style: const TextStyle(color: AppColors.primaryTeal, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Kérlek írd be a diagnózist és a javasolt kezelést:"),
                  const SizedBox(height: 15),
                  TextField(
                    controller: diagnosisController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      hintText: "Például: Enyhe vírusos fertőzés, pihenés javasolt...",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Mégse", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (diagnosisController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A diagnózis nem lehet üres!")));
                      return;
                    }

                    setDialogState(() => isSaving = true);

                    try {
                      // 1. Create the permanent Medical Record
                      await FirebaseFirestore.instance.collection('MedicalRecords').add({
                        'date': date, // Keeping the original appointment date
                        'diagnosis': diagnosisController.text.trim(),
                        'doctor_id': FirebaseAuth.instance.currentUser!.uid,
                        'doctor_name': userData?['name'],
                        'patient_id': patientId,
                        'section': userData?['section'] ?? "Általános",
                      });

                      // 2. Change the appointment status so it disappears from the active list
                      await FirebaseFirestore.instance.collection('Appointments').doc(appointmentId).update({
                        'status': 'befejezett'
                      });

                      if (!mounted) return;
                      Navigator.pop(context); // Close the dialog
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Konzultáció sikeresen befejezve és elmentve!")),
                      );
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hiba történt: $e")));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("Befejezés és Mentés"),
                ),
              ],
            );
          }
        );
      }
    );
  }


}