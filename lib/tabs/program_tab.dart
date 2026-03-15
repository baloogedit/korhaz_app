import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:korhaz_app/constants/colors.dart';

class ProgramTab extends StatefulWidget {
  const ProgramTab({super.key});

  @override
  State<ProgramTab> createState() => _ProgramTabState();
}

class _ProgramTabState extends State<ProgramTab> {
  String? selectedSection;
  String? selectedDoctor;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? selectedTime;

  List<String> sections = [];
  List<Map<String, dynamic>> doctors = [];
  
  // Available times for the pills
  final List<String> availableTimes = [
    "08:00", "08:30", "09:00", "09:30", "10:00", "11:00", "13:00", "14:30"
  ];

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  // Fetch sections from Firestore
  Future<void> _loadSections() async {
    var snapshot = await FirebaseFirestore.instance.collection('Sections').get();
    setState(() {
      sections = snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  // Fetch doctors when a section is selected
  Future<void> _loadDoctors(String sectionName) async {
    setState(() {
      selectedDoctor = null; // Reset doctor when section changes
      doctors = [];
    });
    
    var snapshot = await FirebaseFirestore.instance
        .collection('Users')
        .where('role', isEqualTo: 'doctor')
        .where('section', isEqualTo: sectionName)
        .get();

    setState(() {
      doctors = snapshot.docs.map((doc) {
        return {"id": doc.id, "name": doc['name']};
      }).toList();
    });
  }

  // Booking logic
  Future<void> _makeAppointment() async {
    if (selectedSection == null || selectedDoctor == null || _selectedDay == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kérlek válassz szekciót, orvost, dátumot és időpontot!")),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDay!);

    await FirebaseFirestore.instance.collection("Appointments").add({
      "patient_id": userId,
      "section": selectedSection,
      "doctor": selectedDoctor,
      "date": dateString,
      "time": selectedTime,
      "status": "aktív"
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sikeres foglalás!")),
    );

    // Reset the form
    setState(() {
      selectedSection = null;
      selectedDoctor = null;
      _selectedDay = null;
      selectedTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgTeal,
      appBar: AppBar(
        title: const Text("Időpont Foglalása", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bgTeal,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SECTION DROPDOWN
            const Text("Szekció", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration(),
              hint: const Text("Válassz szekciót..."),
              value: selectedSection,
              items: sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) {
                setState(() => selectedSection = val);
                if (val != null) _loadDoctors(val);
              },
            ),
            const SizedBox(height: 20),

            // 2. DOCTOR DROPDOWN
            const Text("Orvos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: _dropdownDecoration(),
              hint: const Text("Válassz orvost..."),
              value: selectedDoctor,
              items: doctors.map((d) => DropdownMenuItem<String>(value: d['name'], child: Text(d['name']))).toList(),
              onChanged: (val) => setState(() => selectedDoctor = val),
            ),
            const SizedBox(height: 25),

            // 3. CALENDAR (Replacing your Java GridView)
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: TableCalendar(
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 90)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primaryTeal,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.primaryTeal.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
            ),
            const SizedBox(height: 25),

            // 4. MODERN TIME SLOTS (Pills instead of Dropdown)
            const Text("Elérhető Időpontok", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: availableTimes.map((time) {
                bool isSelected = selectedTime == time;
                return ChoiceChip(
                  label: Text(time),
                  selected: isSelected,
                  selectedColor: AppColors.primaryTeal,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: AppColors.cardWhite,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (selected) {
                    setState(() => selectedTime = selected ? time : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            // 5. BOOK BUTTON
            ElevatedButton(
              onPressed: _makeAppointment,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: AppColors.textWhite,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("Időpont Foglalása", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for cleaner code
  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.cardWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }
}