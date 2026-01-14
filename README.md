<div align="center">
  <img src="assets/img/Logo.png" alt="stockD Logo" width="180" height="180" style="border-radius: 20px; box-shadow: 0 8px 16px rgba(0,0,0,0.2);">
  
  <h1>🛒 stockD</h1>
  
  <p><strong>AI-powered grocery management to reduce household food waste, track expiry, and enable real-time family sharing.</strong></p>
  
  ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
  ![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
  ![Gemini AI](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=google-gemini&logoColor=white)
  
  
  ![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-brightgreen)

</div>

---

## 📋 Table of Contents

- [About](#-about)
- [Features](#-features)
- [Architecture](#️-architecture)
- [Tech Stack](#️-tech-stack)
- [Getting Started](#-getting-started)
- [Screenshots](#-screenshots)
- [Impact](#-impact)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 About

StockD App helps families reduce food waste through intelligent tracking and AI-powered features. With automatic receipt scanning, expiry monitoring, and real-time family synchronization, managing groceries has never been easier.

**Key Problems We Solve:**
- 🗑️ 40% of household food goes to waste due to poor tracking
- 💰 Families lose ₹5,000–₹15,000 annually on expired groceries
- 👨‍👩‍👧‍👦 Difficult coordination among family members

---

## ✨ Features

### 🤖 Smart Receipt Scanning
- **AI-Powered OCR** using Google Gemini for automatic text extraction
- **Intelligent Expiry Prediction** based on product categories
- **Auto-categorization** of grocery items

### 📂 Organized Storage
5 smart categories to match your real storage:
- 🥛 Dairy & Chilled
- 🥗 Fresh Produce
- 📦 Packaged Goods
- 🌾 Dry Storage
- ❄️ Frozen Foods

### ⏰ Expiry Tracking
- **Color-coded warnings**: Red (≤3 days), Yellow (4-7 days), Green (>7 days)
- **Real-time countdown** for all items
- **Push notifications** before items expire

### 👨‍👩‍👧‍👦 Family Collaboration
- Create or join family groups with secure codes
- Real-time inventory sync across all devices
- Shared shopping lists
- Support for 4-10 family members

### 📱 Cross-Platform
- Native Android application
- Responsive web interface
- Seamless data sync

---

## 🏗️ Architecture

### Component Overview

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Frontend** | Flutter | Cross-platform UI |
| **Authentication** | Firebase Auth | User management |
| **Database** | Cloud Firestore | Real-time data storage |
| **AI/ML** | Gemini API | OCR & smart categorization |
| **Notifications** | FCM | Push notifications |

### How It Works

1. **User captures receipt** using camera or uploads image
2. **Gemini AI processes** image and extracts product details
3. **System categorizes items** and estimates expiry dates
4. **Data syncs** to Firestore for family access
5. **FCM sends alerts** when items are about to expire



---

## 🛠️ Tech Stack

**Frontend**
- Flutter 3.24+
- Material Design
- Responsive layouts

**Backend & Services**
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging

**AI & Machine Learning**
- Google Gemini API (OCR & NLP)

**Key Packages**
- `image_picker` - Camera integration
- `file_picker` - File uploads
- `uuid` - Unique ID generation
- `font_awesome_flutter` - Icons

---

## 🚀 Getting Started

### Prerequisites

Before running the project, ensure you have:

- Flutter SDK (3.24+) - [Install Flutter](https://flutter.dev/docs/get-started/install)
- Firebase account - [Create one here](https://console.firebase.google.com)
- Gemini API key - [Get it here](https://aistudio.google.com/app/apikey)
- Android Studio or VS Code

Verify your Flutter installation:
```bash
flutter doctor
```

### Installation

**1. Clone the repository**
```bash
git clone https://github.com/yashrajken01/stockD.git
cd stockD
```

**2. Install dependencies**
```bash
flutter pub get
```

**3. Configure Firebase**

For Android:
- Download `google-services.json` from Firebase Console
- Place it in `android/app/`

For Web:
- Add your Firebase config to `web/index.html`

**4. Add Gemini API Key**


**5. Run the app**

For Android:
```bash
flutter run
```

For Web:
```bash
flutter run -d chrome
```

### Firebase Setup

1. Enable **Authentication** (Email/Password)
2. Create **Firestore Database** (test mode initially)
3. Enable **Cloud Messaging** for notifications

---

## 📸 Screenshots

<div align="center">

| Login Screen | Home Dashboard | Receipt Scan |
|--------------|----------------|--------------|
| ![Login](screenshots/login.png) | ![Home](screenshots/home.png) | ![Scan](screenshots/scan.png) |

| Category View | Expiry Tracking | Family Groups |
|---------------|-----------------|---------------|
| ![Categories](screenshots/categories.png) | ![Expiry](screenshots/expiry.png) | ![Family](screenshots/family.png) |

</div>


---

## 🎯 Impact

### Environmental & Economic Benefits

- 🌱 Reduce household food waste by **25-40%**
- 💰 Save **₹5,000–₹15,000 annually** per family
- 👨‍👩‍👧‍👦 Enable collaboration for **family members**
- ♻️ Promote sustainability in urban households



---

## 🗺️ Roadmap

**Current Features (Phase 1)**
- ✅ Receipt scanning with AI
- ✅ Family group sharing
- ✅ Expiry tracking
- ✅ Android & Web support

**Future Plans**
- 💡 Voice commands
- 💡 Smart home integration
- 💡 Recipe recommendations
- 💡 Offline mode

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a new branch for your changes 
3. **Commit** your changes 
4. **Push** your branch to your fork
5. **Open** a Pull Request with a breif description of your changes

**Ways to Contribute:**
- 🐛 Report bugs
- 💡 Suggest new features
- 📝 Improve documentation
- 🔧 Submit code improvements

---

## 📜 License

This project currently does not include a license file. If you plan to use, distribute, or modify this project publicly, consider adding an appropriate open source license.

---


<div align="center">
  
  **⭐ Star this repo if you find it helpful!**
  
  Made with ❤️ to reduce food waste and promote sustainability
  
  <sub>Built with Flutter 🚀 | Powered by Gemini AI 🤖 | Backed by Firebase 🔥</sub>

</div>
