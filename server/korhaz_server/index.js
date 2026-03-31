const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

// 1. Initialize Firebase Admin using your downloaded key
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const app = express();

app.use(cors());
app.use(express.json());

// 2. The Check-in API Endpoint
app.post('/api/checkin', async (req, res) => {
  const { appointmentId, date, time, wifiName, doctorName } = req.body;
  console.log("SERVER RECEIVED:", req.body); // This is what you saw in your screenshot

  try {
    const requiredWifi = "TP-Link_404F"; // otthoni Wi-Fi hálózat neve teszteléshez
    // SZERVER SZABÁLY 1: WiFi hálózat ellenőrzése
    if (wifiName !== requiredWifi && wifiName !== "AndroidWifi" && wifiName !== "<unknown ssid>") {
      return res.status(400).json({ 
        success: false, 
        message: `Nem a kórház WiFi hálózatán vagy! (Jelenlegi: ${wifiName})` // kiírja, ha helytelen a Wi-Fi hálózat
      });
    }
    // SZERVER SZABÁLY 2: Időkorlát ellenőrzése (5 perccel a bejelentkezés előtt vagy után)
    const apptTime = new Date(`${date}T${time}:00`); // Átalakítjuk a dátumot és időt egy JavaScript Date objektummá
    const now = new Date();      
    const diffMinutes = (now - apptTime) / (1000 * 60);// Kiszámoljuk a különbséget percben
    if (diffMinutes < -5 || diffMinutes > 5) {
      return res.status(400).json({ 
        success: false, 
        message: "Csak az időpontod előtt/után 5 perccel jelentkezhetsz be!" 
      });
    }
    // SZERVER SZABÁLY 3: Időpont státuszának frissítése "megérkezett"-re az adatbázisban
    await db.collection('Appointments').doc(appointmentId).update({
      status: 'megérkezett'
    });

    // Generate Room Data on the server
    const floor = (doctorName.length % 3) + 1;
    const room = (doctorName.length * 12) % 100 + 100;

    // Send Success Response to the Phone
    return res.status(200).json({ 
      success: true, 
      floor: floor, 
      room: room 
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: "Szerver hiba történt." });
  }
});

// Start the server
const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🏥 Korhaz Server is running on http://localhost:${PORT}`);
});