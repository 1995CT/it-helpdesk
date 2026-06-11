# IT Helpdesk — Ticket Management System

A modern, mobile-first IT Helpdesk application built with **Flutter Web** and **Supabase**. Designed for IT teams to log, track, and resolve support tickets efficiently.

**Live:** [itdesk-pro.vercel.app](https://itdesk-pro.vercel.app)

---

## Features

| Feature | Description |
|---|---|
| **Ticket Management** | Create, edit, track, and delete support tickets with full audit trail |
| **PIN Authentication** | Secure 4-digit PIN login with admin-controlled reset flow |
| **Dynamic Categories** | Admin-configurable ticket categories with descriptions |
| **Daily Reports** | Auto-generated daily summary cards, shareable as PNG via WhatsApp |
| **Analytics Dashboard** | Visual charts — tickets by category, status, engineer, and trends |
| **Photo & Attachments** | Camera capture and file uploads attached to tickets |
| **OneDrive Backup** | Optional Microsoft OneDrive integration for media backup (Azure OAuth 2.0 PKCE) |
| **CSV Export** | Export ticket data with full edit history |
| **User Management** | Role-based access (Admin / Engineer), online status tracking |
| **Data Management** | Bulk cleanup tools — archive old tickets or full data reset |
| **PWA Support** | Installable as a native-like app on mobile and desktop |
| **Edit History** | Before → After tracking on every ticket modification |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter Web (Dart) |
| Backend | Supabase (Auth, Database, Storage) |
| Hosting | Vercel |
| Charts | fl_chart |
| OAuth | Azure AD (PKCE) for OneDrive |
| Sharing | share_plus, url_launcher |

---

## Project Structure

```
lib/
├── main.dart                            # App entry + PIN lock screen
├── screens/
│   ├── login_screen.dart                # PIN authentication
│   ├── home_screen.dart                 # Dashboard with ticket list
│   ├── create_ticket_screen.dart        # Create / Edit ticket form
│   ├── ticket_detail_screen.dart        # Ticket detail with photos
│   ├── analytics_screen.dart            # Charts and CSV export
│   ├── daily_report_screen.dart         # Daily summary report card
│   ├── category_management_screen.dart  # Admin: manage categories
│   ├── users_management_screen.dart     # Admin: manage engineers
│   ├── data_management_screen.dart      # Admin: bulk data operations
│   ├── onedrive_settings_screen.dart    # OneDrive integration
│   ├── signup_screen.dart               # New engineer registration
│   └── set_new_pin_screen.dart          # PIN reset flow
├── services/
│   ├── database.dart                    # Supabase CRUD operations
│   ├── onedrive_service.dart            # OneDrive OAuth + upload
│   ├── onedrive_web_helper.dart         # Web localStorage helpers
│   └── onedrive_stub_helper.dart        # Non-web platform stub
web/
├── index.html                           # PWA-enabled entry point
└── manifest.json                        # PWA manifest
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.24+
- Supabase project (Auth + Database + Storage)
- (Optional) Azure AD app registration for OneDrive backup

### Run Locally

```bash
git clone https://github.com/1995CT/it-helpdesk.git
cd it-helpdesk && git checkout source
flutter pub get
flutter run -d chrome
```

### Deploy to Production

```bash
flutter build web --release
vercel --prod
```

---

## Branches

| Branch | Purpose |
|---|---|
| `source` | Flutter source code (development) |
| `main` | Built web output (GitHub Pages) |

---

## License

This project is proprietary. All rights reserved.
