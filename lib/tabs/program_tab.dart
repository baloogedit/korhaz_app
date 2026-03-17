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
  List<String> bookedTimes = [];
  bool isLoadingTimes = false;

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

  // Fetch all existing appointments for the selected doctor & day
  Future<void> _fetchAvailableTimes() async {
    if (selectedDoctor == null || _selectedDay == null) {
      setState(() {
        bookedTimes = [];
        selectedTime = null;
      });
      return;
    }

    setState(() => isLoadingTimes = true);

    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDay!);

    var snapshot = await FirebaseFirestore.instance
        .collection('Appointments')
        .where('doctor', isEqualTo: selectedDoctor)
        .where('date', isEqualTo: dateString)
        .get();

    List<String> fetchedTimes = [];
    for (var doc in snapshot.docs) {
      // We assume if it's in the database, it takes up a slot!
      fetchedTimes.add(doc['time'] as String);
    }

    setState(() {
      bookedTimes = fetchedTimes;
      isLoadingTimes = false;
      selectedTime = null; // Reset user's time selection if they change days
    });
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  // NEW: The algorithmic magic that calculates 10-minute intervals and prevents overlaps!
  List<String> _getDynamicAvailableTimes() {
    List<String> times = [];
    int startMinutes = 8 * 60; // Start at 08:00
    int endMinutes = 16 * 60;  // End at 16:00

    bool isToday = isSameDay(_selectedDay, DateTime.now());
    int currentMinutes = DateTime.now().hour * 60 + DateTime.now().minute;

    // Loop through the day in 10-minute jumps
    for (int i = startMinutes; i <= endMinutes - 30; i += 10) {
      // Bonus: If it's today, don't show times that have already passed!
      if (isToday && i <= currentMinutes) continue;

      int candidateStart = i;
      int candidateEnd = i + 30; // Every appointment takes 30 minutes
      bool isOverlapping = false;

      // Check this candidate time against EVERY booked appointment
      for (String booked in bookedTimes) {
        int bookedStart = _timeToMinutes(booked);
        int bookedEnd = bookedStart + 30;

        // The formula to detect if two time periods overlap:
        if (candidateStart < bookedEnd && candidateEnd > bookedStart) {
          isOverlapping = true;
          break; // Stop checking, this slot is dead!
        }
      }

      // If it didn't overlap with anything, format it and add it to the list!
      if (!isOverlapping) {
        int h = i ~/ 60;
        int m = i % 60;
        String timeStr = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        times.add(timeStr);
      }
    }
    return times;
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
              initialValue: selectedSection,
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
              initialValue: selectedDoctor,
              items: doctors.map((d) => DropdownMenuItem<String>(value: d['name'], child: Text(d['name']))).toList(),
              onChanged: (val) {
                setState(() => selectedDoctor = val);
                _fetchAvailableTimes(); // Fetch times when doctor is chosen
              },
            ),
            const SizedBox(height: 25),

            // 3. CALENDAR (Replacing your Java GridView)
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10)],
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
                  _fetchAvailableTimes(); // Fetch times when day is chosen
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primaryTeal,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.3),
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

            // 4. DYNAMIC TIME SLOTS (Replacing your Java ListView)
            const Text("Elérhető Időpontok", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            // Logic to show loading, empty states, or the actual time chips
            if (selectedDoctor == null || _selectedDay == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text("Kérlek válassz orvost és dátumot az időpontokhoz!", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              )
            else if (isLoadingTimes)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
              )
            else if (_getDynamicAvailableTimes().isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text("Sajnos ezen a napon nincs több szabad időpont.", style: TextStyle(color: Colors.redAccent)),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _getDynamicAvailableTimes().map((time) {
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