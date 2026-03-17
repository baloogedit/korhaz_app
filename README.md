# KorhazApp - Okos Kórházi Időpontfoglaló Rendszer

## Hallgatói Információk
**Név:** Balog Edit
**Azonosító / Neptun kód:** 78 (nr. matricol)
**Kurzus:** Android / Mobilalkalmazás-fejlesztés

## Projekt Címe
KorhazApp (Okos Kórházmenedzsment és Időpontfoglaló Rendszer)

## Leírás
Egy átfogó, háromrétegű (3-tier) architektúrára épülő mobilalkalmazás páciensek és orvosok számára. Az alkalmazás leegyszerűsíti a kórházi folyamatokat: a betegek dinamikusan foglalhatnak időpontokat, böngészhetnek az osztályok között, és egy intelligens, helyalapú Wi-Fi bejelentkezési (check-in) rendszert használhatnak. Az orvosok egy valós idejű felületen követhetik a megérkező pácienseket, kezelhetik a beosztásukat, és biztonságosan rögzíthetik az orvosi diagnózisokat.

## Funkciók
- **Szerepkör-alapú hitelesítés:** Különböző felületek és jogosultságok a "Páciensek" és az "Orvosok" számára a Firebase Auth segítségével.
- **Dinamikus ütemező algoritmus:** Egy intelligens, 10 perces csúszóablakos foglalási rendszer, amely automatikusan kiszámítja a 30 perces blokkokat, és megakadályozza az időpontok ütközését (dupla foglalás).
- **Okos Wi-Fi Bejelentkezés (Node.js Szerver):** A páciensek csak akkor tudnak bejelentkezni ("Megérkeztem"), ha a kórház specifikus Wi-Fi hálózatára csatlakoznak, és a foglalásuk időpontjához képest egy $\pm 5$ perces ablakon belül vannak.
- **Valós idejű orvosi nézet:** Az orvosok azonnal, zöld jelzéssel látják a képernyőn, ha egy beteg sikeresen bejelentkezett és megérkezett a váróterembe.
- **Kórlapok kezelése:** Az orvosok az aktív időpontokat végleges kórlapokká alakíthatják a diagnózis megadásával, amelyet a betegek később a saját előzményeik között bármikor megtekinthetnek.

<!-- ## Képernyőképek>
![Főoldal](link_to_image)
![Időpontfoglalás](link_to_image) -->

## Felhasznált Technológiák
- **Flutter & Dart:** Keresztplatformos mobil frontend keretrendszer (Material 3 UI dizájnnal).
- **Firebase Authentication:** Biztonságos felhasználói regisztráció és bejelentkezés.
- **Cloud Firestore:** Valós idejű NoSQL adatbázis az időpontok és kórlapok szinkronizálásához.
- **Node.js & Express:** Egyedi háttérszerver (backend), amely a biztonságos Wi-Fi bejelentkezési logikát kezeli.
- **Firebase Admin SDK:** Szerveroldali adatbázis-validáció és frissítés.
- **Flutter Csomagok:** Table Calendar (naptár felület) és Network Info Plus (natív Wi-Fi szenzor elérés).

## Futtatási Útmutató

### 1. A helyi szerver elindítása
1. Nyiss egy terminált, és lépj a szerver mappájába: `cd korhaz_server`
2. Telepítsd a függőségeket: `npm install`
3. Indítsd el a szervert: `node index.js`
*(Megjegyzés: Győződj meg róla, hogy a `serviceAccountKey.json` fájl benne van a szerver mappájában).*

### 2. A mobilalkalmazás futtatása
1. Klónozd ezt a repozitóriumot.
2. Nyisd meg a Flutter projektet Visual Studio Code-ban vagy Android Studio-ban.
3. Futtasd a `flutter pub get` parancsot a terminálban a csomagok letöltéséhez.
4. Futtasd az alkalmazást Android emulátoron vagy fizikai eszközön a `flutter run` paranccsal vagy a Lejátszás (Play) gombbal.