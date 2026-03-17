const admin = require('firebase-admin');

// Connect to Firebase using your admin key
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 1. Prepare the Fake Data
const sections = [
  { id: "Kardiológia", description: "Szív és érrendszeri megbetegedések", address: "1. Emelet", program: "08:00 - 16:00" },
  { id: "Neurológia", description: "Idegrendszeri problémák kezelése", address: "2. Emelet", program: "08:00 - 15:00" },
  { id: "Szemészet", description: "Látásvizsgálat és szemészeti műtétek", address: "Földszint", program: "09:00 - 14:00" },
];

const doctors = [
  { name: "Dr. Kiss Péter", email: "kissp@korhaz.hu", role: "doctor", section: "Kardiológia", cnp: "1234567890" },
  { name: "Dr. Nagy Anna", email: "nagya@korhaz.hu", role: "doctor", section: "Kardiológia", cnp: "1234567891" },
  { name: "Dr. Szabó Gábor", email: "szabog@korhaz.hu", role: "doctor", section: "Neurológia", cnp: "1234567892" },
  { name: "Dr. Tóth Ilona", email: "tothi@korhaz.hu", role: "doctor", section: "Neurológia", cnp: "1234567893" },
  { name: "Dr. Varga Béla", email: "vargab@korhaz.hu", role: "doctor", section: "Szemészet", cnp: "1234567894" },
];

// 2. Function to upload everything automatically
async function seedDatabase() {
  console.log("⏳ Adatok feltöltése folyamatban...");

  try {
    // Upload Sections
    for (const sec of sections) {
      await db.collection('Sections').doc(sec.id).set({
        description: sec.description,
        address: sec.address,
        program: sec.program
      });
      console.log(`✅ Szekció hozzáadva: ${sec.id}`);
    }

    // Upload Doctors
    for (const doc of doctors) {
      // Create a random user ID for the doctor, or use email as ID
      await db.collection('Users').add(doc);
      console.log(`✅ Orvos hozzáadva: ${doc.name}`);
    }

    console.log("🎉 Minden adat sikeresen feltöltve!");
    process.exit(); // Closes the script when finished

  } catch (error) {
    console.error("❌ Hiba történt:", error);
  }
}

// 3. Run the function
seedDatabase();