# 🚗 FleetFlow - Fleet Management Mobile Application

A cross-platform mobile application built with Flutter for vehicle fleet management, featuring real-time GPS tracking, trip management, and role-based authentication.

![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Latest-FFCA28?logo=firebase)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)

## 📱 Features

### Driver Features

- ✅ **Authentication** - Email/password login with Firebase
- 🗺️ **Real-time GPS Tracking** - Live location tracking during trips
- 🚀 **Trip Management** - Start/end trips with automatic logging
- 🚙 **Vehicle Request System** - Request and manage assigned vehicles
- 📊 **Dashboard** - View current trip status and statistics
- 📜 **Trip History** - Access completed trip records

### Fleet Owner Features

- 👥 **Driver Management** - Monitor driver activities
- 🚗 **Vehicle Assignment** - Assign vehicles to drivers
- 📊 **Analytics Dashboard** - Overview of fleet operations

### Security Features

- 🔒 **Firebase Security Rules** - Backend-level data protection
- 🛡️ **Role-based Access Control** - Driver and Owner role separation
- 🔐 **Secure Authentication** - Firebase Auth with email verification

## 🛠️ Tech Stack

| Technology          | Version | Purpose                         |
| ------------------- | ------- | ------------------------------- |
| Flutter             | 3.9.2+  | Cross-platform mobile framework |
| Dart                | 3.0+    | Programming language            |
| Firebase Auth       | 5.1.0   | User authentication             |
| Cloud Firestore     | 5.4.4   | NoSQL database                  |
| Google Maps Flutter | 2.13.1  | Map integration                 |
| Geolocator          | 14.0.2  | Location services               |
| Google Sign In      | 6.2.1   | OAuth authentication            |

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Android Studio / Xcode
- Firebase account
- Google Cloud Platform account (for Maps API)

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/github.com/mehmetyasinuzun/FleetFlow-Mobile-App
cd aracfilo
```

2. **Install dependencies**

```bash
flutter pub get
```

3. **Firebase Setup**

   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add Android/iOS apps to your project
   - Download `google-services.json` (Android) and place in `android/app/`
   - Run FlutterFire CLI:

   ```bash
   flutterfire configure
   ```
4. **Google Maps API Setup**

   - Enable Maps SDK in [Google Cloud Console](https://console.cloud.google.com/)
   - Get API key
   - Add to `android/app/src/main/AndroidManifest.xml`:

   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_API_KEY_HERE"/>
   ```
5. **Run the app**

```bash
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

## 📂 Project Structure

```
lib/
├── main.dart                 # Entry point
├── app_router/              # Navigation management
│   ├── app_routes.dart
│   └── app_router.dart
├── auth/                    # Authentication screens
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── forgot_password_screen.dart
│   └── auth_service.dart
├── driver/                  # Driver-specific screens
│   ├── driver_ana_ekran.dart
│   ├── map/
│   │   └── driver_map_screen.dart
│   ├── arac_talep.dart
│   └── tum_gecmis_turlarim_ekran.dart
├── owner/                   # Owner-specific screens
│   └── owner_ana_ekran.dart
├── common/                  # Shared components
│   ├── role_guard.dart
│   └── theme/
├── firebase/               # Firebase configuration
│   └── firebase_options.dart
└── firestore/             # Firestore repositories
    └── driver_repository.dart
```

## 🔐 Firebase Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null 
                    && request.auth.uid == userId
                    && request.resource.data.role == resource.data.role;
    }
  
    // Drivers collection
    match /drivers/{driverId} {
      allow read, write: if request.auth != null && request.auth.uid == driverId;
    }
  
    // Vehicles collection
    match /vehicles/{vehicleId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null 
                   && (resource == null || resource.data.assignedTo == request.auth.uid);
    }
  
    // Trips collection
    match /trips/{tripId} {
      allow read: if request.auth != null 
                  && resource.data.driverId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.driverId == request.auth.uid;
      allow update: if request.auth != null 
                    && resource.data.driverId == request.auth.uid;
    }
  }
}
```

## 🗺️ Firestore Data Model

### Collections

**users/**

```json
{
  "userId": "string",
  "name": "string",
  "fullName": "string",
  "email": "string",
  "role": "driver | owner",
  "createdAt": "timestamp"
}
```

**drivers/**

```json
{
  "email": "string",
  "assignedVehicleId": "string | null",
  "vehicleId": "string | null",
  "status": "string",
  "updatedAt": "timestamp"
}
```

**vehicles/**

```json
{
  "plateNumber": "string",
  "model": "string",
  "year": "number",
  "type": "string",
  "assignedTo": "string | null",
  "available": "boolean",
  "updatedAt": "timestamp"
}
```

**trips/**

```json
{
  "driverId": "string",
  "vehicleId": "string",
  "startTime": "timestamp",
  "endTime": "timestamp | null",
  "startLocation": "GeoPoint",
  "endLocation": "GeoPoint | null",
  "distance": "number",
  "status": "active | completed"
}
```

## 📱 Key Features Implementation

### Real-time Location Tracking

Uses Geolocator package with position stream for continuous GPS updates:

```dart
getPositionStream(
  locationSettings: LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Update every 10 meters
  ),
)
```

### Role-based Access Control

Custom RoleGuard widget wraps protected routes:

```dart
RoleGuard(
  requiredRole: 'driver',
  child: DriverAnaEkran(),
)
```

### Transaction-based Vehicle Assignment

Prevents race conditions when multiple drivers request the same vehicle:

```dart
await firestore.runTransaction((transaction) async {
  // Check availability
  // Release old vehicle
  // Assign new vehicle
});
```

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📝 Development Timeline

This project was developed during a 22-day internship at ArterSoft:

- **Week 1 (Day 1-5)**: Environment setup, Firebase integration, UI/UX design
- **Week 2 (Day 6-10)**: Authentication system, driver dashboard
- **Week 3 (Day 11-17)**: Trip management, Google Maps integration, real-time tracking
- **Week 4 (Day 18-22)**: Centralized router, security improvements, vehicle request system, release build

## 🐛 Known Issues

- Owner dashboard is basic (skeleton only)
- Route drawing not implemented yet
- Push notifications pending
- iOS version not fully tested

## 🔮 Future Enhancements

- [ ] Google Sign-In integration (UI ready)
- [ ] Complete Owner Dashboard with analytics
- [ ] Route optimization with Directions API
- [ ] Push notifications for trip updates
- [ ] Detailed analytics and PDF reports
- [ ] iOS release and App Store deployment
- [ ] Web admin panel
- [ ] Multi-language support (i18n)
- [ ] Dark mode theme
- [ ] Offline mode with local database

## 📊 Project Statistics

- **Total Lines of Code**: ~5,000+
- **Screens**: 10+
- **Firebase Collections**: 5 (users, drivers, owners, vehicles, trips)
- **Main Packages**: 8
- **Development Time**: 22 working days
- **Test Scenarios**: 8 comprehensive scenarios

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Mehmet Yasin Uzun**

- GitHub: [@mehmetyasinuzun](https://github.com/mehmetyasinuzun)
- LinkedIn: [Mehmet Yasin Uzun](https://linkedin.com/in/mehmetyasinuzun)
- Email: mehmetyasinuzun@gmail.com

## 🙏 Acknowledgments

- **[ArterSoft](https://www.artersoft.com)** - Internship opportunity and professional guidance
- **[Veli Bacık (HardwareAndro)](https://www.youtube.com/@HardwareAndro)** - Excellent Turkish Flutter tutorials
- **[Flutter Team](https://flutter.dev)** - Amazing cross-platform framework
- **[Firebase](https://firebase.google.com)** - Backend services and authentication

## 📚 Resources

Helpful resources used during development:

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Google Maps Platform](https://developers.google.com/maps)
- [Dart Language Tour](https://dart.dev/guides/language)
- [Material Design 3](https://m3.material.io)
- [Stack Overflow Flutter](https://stackoverflow.com/questions/tagged/flutter)

## 💡 Lessons Learned

Key takeaways from this project:

1. **Async/await mastery**: Real-world practice with asynchronous programming
2. **Firebase integration**: Authentication, Firestore, Security Rules
3. **State management**: Understanding setState and StreamBuilder
4. **Google Maps API**: Location tracking and map integration
5. **Security first**: Importance of backend validation and security rules
6. **Clean code**: Meaningful variable names and code documentation
7. **Git workflow**: Version control and project management

---

**⭐ If you found this project helpful, please give it a star!**

**📧 For questions or suggestions, feel free to open an issue or contact me.**

---

*Developed with ❤️ using Flutter*
