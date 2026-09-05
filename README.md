# 🚌 BusVerse — Smart Bus Ticket Reservation & Fleet Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-Local_DB-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org/)
[![Supabase](https://img.shields.io/badge/Supabase-Cloud_Sync-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**BusVerse** is a modern, cross-platform mobile application designed for intercity bus travel booking and fleet management. Featuring a seamless booking flow, interactive real-time seat selection, instant digital E-Ticket generation with QR codes, passenger management, and dual offline-first database synchronization (SQLite + Supabase).

---

## ✨ Key Features

### 👤 Passenger / Customer Portal
- 🔍 **Smart Trip Search:** Filter available buses by departure city, destination city, travel date, and coach class.
- 💺 **Interactive Seat Layout:** Real-time seat grid displaying available, selected, reserved, and gender-specific seating.
- 💳 **Flexible Payment Integration:** Seamless checkout flow supporting Debit/Credit Cards, Mobile Wallets (EasyPaisa / JazzCash), and Cash on Departure.
- 🎟️ **Instant Digital E-Tickets:** Generates verified E-tickets with booking references, passenger CNIC/Phone details, bus schedules, and QR code verification.
- 📜 **My Bookings History:** View active and past tickets anytime with quick access to full ticket details and cancellation options.
- ⚙️ **Profile & Security Management:** Update personal credentials, addresses, and secure password management with encrypted storage.

### 🛡️ Admin & Operator Dashboard
- 🚍 **Fleet & Route Management:** Add, update, and manage bus fleets, routes, departure schedules, terminal stops, and seat configurations.
- 📊 **Real-time Analytics:** Track active bookings, revenue metrics, passenger loads, and bus occupancy rates.
- 📋 **Passenger Manifest:** View passenger details, seat allocations, and check-in statuses.

---

## 🎨 UI & Design Architecture
- **Theme:** Modern Soft Dodger Blue (`#388AF6`) & Deep Royal Navy (`#1E3C72`) with clean cards, smooth elevation, and responsive typography.
- **State Management:** Modular and reactive state handling ensuring high performance across devices.
- **Data Persistence:** Dual-layer architecture:
  - **Local Layer:** SQLite (`sqflite`) for high-speed offline capabilities.
  - **Cloud Layer:** Supabase Cloud for real-time remote data sync and user authentication.

---

## 🛠️ Tech Stack & Dependencies

| Technology | Purpose |
|---|---|
| **Flutter / Dart** | Cross-platform UI toolkit & application logic |
| **SQLite (sqflite)** | Local relational database for offline-first architecture |
| **Supabase** | Cloud backend, real-time database, and authentication |
| **Shared Preferences** | Session caching and persistent user states |
| **Intl** | Date & currency formatting |
| **Google Fonts** | Modern typography (Inter / Poppins) |
| **QR Flutter** | Dynamic QR code generation for digital E-Tickets |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (v3.19+ recommended)
- Dart SDK
- Android Studio / VS Code with Flutter extension
- Android Device or Emulator / iOS Simulator

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/bus-system.git
   cd bus-system
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the App:**
   ```bash
   flutter run
   ```

---

## 📁 Project Structure

```
lib/
├── admin/                  # Admin portal (Fleet, Routes, Booking management)
│   ├── screens/
│   └── widgets/
├── database/               # Database helpers, migrations & models
│   ├── db_helper.dart      # SQLite local database manager
│   ├── bus_model.dart      # Bus data model
│   ├── booking_model.dart  # Ticket booking model
│   └── user_model.dart     # User profile model
├── user/                   # Passenger application
│   ├── screens/            # Home, Search, Seat Selection, Payment, E-Ticket, Profile
│   └── widgets/            # Custom reusable widgets
├── services/               # Backend API and sync services
└── main.dart               # App entry point & route definitions
```

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

