const admin = require('firebase-admin');

// Connect to Firebase
const serviceAccount = require('./serviceAccountKey.json');
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}
const db = admin.firestore();

// The patient IDs from your screenshot
const patientIds = [
  "3D27Pi1k2cYjvUKQwMmmZ1qVoul2",
  "b4Ls2ZwUo2Trui4LAuBsmLuKk302",
  "FuEIYUXm3dc9hwUfV8KE1QaZ8nI2",
  "tpeq8CLCz5It6oj6gW6e",
  "0R2mCNCTA7Iwp7iN6FRp"
];

// SMART DIAGNOSES: Mapped to the specific section of the doctor!
const sectionDiagnoses = {
  "Kardiológia": [
    "Enyhe szívritmuszavar, EKG kontroll javasolt 6 hónap múlva.",
    "Magas vérnyomás, diéta és vérnyomáscsökkentő gyógyszer felírva.",
    "Mellkasi fájdalom kivizsgálása negatív, valószínűleg stressz okozta."
  ],
  "Neurológia": [
    "Migrénes fejfájás, specifikus fájdalomcsillapító kúra előírva.",
    "Zsibbadás a végtagokban, további MRI vizsgálat szükséges.",
    "Alvászavar és kimerültség, életmódváltás és vitaminok javasoltak."
  ],
  "Szemészet": [
    "Látásromlás, új szemüveg felírása szükséges (-1.5D).",
    "Kötőhártya-gyulladás, antibiotikumos szemcsepp felírva napi 3x.",
    "Száraz szem szindróma, műkönny rendszeres használata javasolt."
  ]
};

async function seedRecords() {
  console.log("⏳ Orvosok lekérése...");

  try {
    const doctorsSnapshot = await db.collection('Users').where('role', '==', 'doctor').get();
    if (doctorsSnapshot.empty) {
      console.log("❌ Nem találtam orvosokat! Futtasd le előbb a seed.js-t.");
      process.exit();
    }

    const doctors = [];
    doctorsSnapshot.forEach(doc => {
      doctors.push({ id: doc.id, ...doc.data() });
    });

    const formatDate = (dateObj) => dateObj.toISOString().split('T')[0];
    const today = new Date();

    console.log(`⏳ Generálom a logikus adatokat ${patientIds.length} páciens számára...`);

    for (let pIndex = 0; pIndex < patientIds.length; pIndex++) {
      const patientId = patientIds[pIndex];
      
      // --- PAST RECORDS ---
      for (let i = 0; i < 2; i++) {
        const doc = doctors[Math.floor(Math.random() * doctors.length)];
        
        // Pick a diagnosis THAT MATCHES the doctor's section!
        // (If a section somehow doesn't exist in our dictionary, use a generic fallback)
        const validDiagnoses = sectionDiagnoses[doc.section] || ["Általános kivizsgálás, az eredmények negatívak."];
        const diagnosis = validDiagnoses[Math.floor(Math.random() * validDiagnoses.length)];
        
        const pastDate = new Date(today);
        pastDate.setDate(today.getDate() - (Math.floor(Math.random() * 55) + 5)); 
        const dateString = formatDate(pastDate);
        const timeString = `${8 + Math.floor(Math.random() * 6)}:${Math.random() > 0.5 ? '00' : '30'}`;

        await db.collection('Appointments').add({
          date: dateString,
          doctor: doc.name,
          patient_id: patientId,
          section: doc.section,
          status: "befejezett",
          time: timeString
        });

        await db.collection('MedicalRecords').add({
          date: dateString,
          diagnosis: diagnosis,
          doctor_id: doc.id,
          doctor_name: doc.name,
          patient_id: patientId,
          section: doc.section
        });
      }

      // --- FUTURE APPOINTMENTS ---
      const futureDoc = doctors[Math.floor(Math.random() * doctors.length)];
      const futureDate = new Date(today);
      futureDate.setDate(today.getDate() + (Math.floor(Math.random() * 14) + 1));
      const futureDateString = formatDate(futureDate);
      const futureTimeString = `${9 + Math.floor(Math.random() * 5)}:${Math.random() > 0.5 ? '10' : '40'}`;

      await db.collection('Appointments').add({
        date: futureDateString,
        doctor: futureDoc.name,
        patient_id: patientId,
        section: futureDoc.section,
        status: "aktív",
        time: futureTimeString
      });

      console.log(`✅ Páciens (${patientId.substring(0,5)}...) logikus adatai feltöltve!`);
    }

    console.log("🎉 Minden teszt adat sikeresen feltöltve!");
    process.exit();

  } catch (error) {
    console.error("❌ Hiba történt:", error);
  }
}

seedRecords();