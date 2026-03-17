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

  try {
    // --- SERVER RULE 1: Check WiFi ---
    // TODO: change the wifi name
    const requiredWifi = "AndroidWifi"; // Change this to your home wifi for testing!
    if (wifiName !== requiredWifi) {
      return res.status(400).json({ 
        success: false, 
        message: `Nem a kórház WiFi hálózatán vagy! (Jelenlegi: ${wifiName})` 
      });
    }

    // --- SERVER RULE 2: Check Time ---
    // Create a date object from the appointment time string
    const apptTime = new Date(`${date}T${time}:00`);
    const now = new Date();
    
    // Calculate difference in minutes
    const diffMinutes = (now - apptTime) / (1000 * 60);

    if (diffMinutes < -5 || diffMinutes > 5) {
      return res.status(400).json({ 
        success: false, 
        message: "Csak az időpontod előtt/után 5 perccel jelentkezhetsz be!" 
      });
    }

    // --- SERVER RULE 3: Update Database ---
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
app.listen(PORT, () => {
  console.log(`🏥 Korhaz Server is running on http://localhost:${PORT}`);
});