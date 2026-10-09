# Friendify — Project Analysis & Production Implementation Plan

## 1. Executive Summary & Vision

**Friendify** is a mobile-first marketplace platform designed for **platonic companionship and shared social activities** (e.g., coffee chats, gym buddies, event plus-ones, city sightseeing, museum visits, board games). 

Unlike dating or escort applications, Friendify’s primary differentiator and legal/brand prerequisite is **strict platonic safety, verified trust, transparent escrow pricing, and zero tolerance for harassment**.

---

## 2. Current State Analysis

### 2.1 Architectural Overview
The codebase currently represents a **high-fidelity Flutter UI prototype** using modern Flutter architecture patterns:
- **Framework**: Flutter 3.44+ (Dart 3.12+) with Material 3 design system.
- **State Management**: `flutter_riverpod: ^2.6.1` with `Notifier` and `FutureProvider` patterns.
- **Routing**: `go_router: ^14.8.1` with `StatefulShellRoute.indexedStack` (preserves bottom nav branch state across Explore, Chat, Host, and Account).
- **Internationalization/Formatting**: `intl: ^0.19.0`.

### 2.2 Component Breakdown & File Inventory

```mermaid
graph TD
    App[FriendifyApp / main.dart] --> Shell[ScaffoldWithNav]
    Shell --> Explore[ExploreScreen - Branch 0]
    Shell --> Chat[ChatInboxScreen - Branch 1]
    Shell --> Host[OnboardingScreen - Branch 2]
    Shell --> Account[AccountScreen - Branch 3]
    
    Explore --> Details[ProfileDetailsScreen]
    Explore --> Filter[FilterBottomSheet]
    Details --> Modal[BookingModal - 4 Steps]
    Chat --> Room[ChatRoomScreen]
    Room --> SOS[showSosSheet / SafetyBanner]
```

| Area | Current Implementation | Status | Deficiencies / Technical Debt |
| :--- | :--- | :--- | :--- |
| **Authentication** | Absent | 🔴 Missing | No user sessions, guest restrictions, or user profiles. |
| **Data Layer** | `MockCompanionRepository`, `MockBookingRepository` in [repositories.dart](file:///d:/Android%20Projects/friendify/lib/repositories/repositories.dart) | 🟡 Mocked | Hardcoded in-memory dummy list with fake pravatar URLs. Data resets on reload. |
| **Search & Filtering** | [companion_provider.dart](file:///d:/Android%20Projects/friendify/lib/providers/companion_provider.dart) & [filter_bottom_sheet.dart](file:///d:/Android%20Projects/friendify/lib/widgets/filter_bottom_sheet.dart) | 🟢 Functional Prototype | Client-side in-memory string filtering only. Lacks server-side geospatial/distance queries. |
| **Booking Flow** | 4-step wizard in [booking_modal.dart](file:///d:/Android%20Projects/friendify/lib/screens/booking_modal.dart) | 🟡 Mocked | Step 3 has a mock Google Maps placeholder. Step 4 mock calls `MockPaymentService`. |
| **Payments** | `MockPaymentService` | 🔴 Mocked | Fixed 1-second delay returning `true`. No Stripe Payment Sheet or backend PaymentIntent. |
| **Chat & Messaging** | [chat_screen.dart](file:///d:/Android%20Projects/friendify/lib/screens/chat_screen.dart) | 🟡 Mocked | Local ephemeral state list in `_ChatRoomState`. No WebSockets, Firebase, or push notifications. |
| **Host Onboarding** | [onboarding_screen.dart](file:///d:/Android%20Projects/friendify/lib/screens/onboarding_screen.dart) | 🟡 Mocked | UI Stepper without document uploads, selfie liveness check, or Stripe Connect onboarding. |
| **Trust & Safety** | [safety_banner.dart](file:///d:/Android%20Projects/friendify/lib/widgets/safety_banner.dart) | 🟡 Mocked | Mock SOS sheet showing snackbars. No real GPS dispatch or emergency SMS/call webhook. |

---

## 3. Gap Analysis (Prototype vs. Production)

```mermaid
pie title Production Readiness Gap
    "Ready UI & Interaction Logic" : 25
    "Backend, Auth & Database" : 30
    "Payments & Escrow (Stripe)" : 15
    "Trust, Safety & Verification" : 15
    "Maps & Geolocation Services" : 15
```

1. **Authentication & Identity**: Needs Phone OTP (Firebase Auth / Supabase Auth) to verify real phone numbers, plus Google/Apple Sign-in.
2. **Geospatial Proximity**: Currently uses static `distanceKm: 0.8 + i * 1.3`. Real apps require GeoFirestore or PostgreSQL PostGIS queries (`ST_DWithin`) to find companions within X km.
3. **Escrow Financial Pipeline**: Companion services cannot use direct charging. Funds must be **authorized and held in escrow**, released upon QR-code check-in or booking completion, with a 15% platform commission deducted.
4. **Trust, Safety & Compliance**: Government ID upload, automated biometric face-match (e.g., Persona, Sumsub, or Stripe Identity), emergency contact dispatch, and in-chat automated content screening for prohibited behavior.
5. **Real-time Push & Messaging**: Firestore / Supabase Realtime for chat messages, read receipts, and FCM (Firebase Cloud Messaging) for background alerts.

---

## 4. Proposed Production Architecture

### 4.1 Technology Stack Recommendation

| Tier | Recommended Option | Alternative Option | Rationale |
| :--- | :--- | :--- | :--- |
| **Mobile Client** | **Flutter 3.44+** (Existing) | Native Android/iOS | Codebase already has high quality UI components. |
| **Backend & Database** | **Firebase** (Firestore + Cloud Functions + Auth) | **Supabase** (PostgreSQL + PostGIS + Edge Functions) | Firebase dependencies are already outlined in `pubspec.yaml`; Firestore is fast for chat & real-time updates. Supabase is a strong alternative if complex SQL queries or PostGIS are prioritized. |
| **Maps & Places** | **Google Maps Flutter & Google Places API** | OpenStreetMap / Mapbox | Industry standard for address auto-completion and public meetup spot discovery. |
| **Payments & Payouts** | **Stripe Connect & PaymentSheet** | Razorpay / Cashfree (if India-specific) | Companion marketplace requires split payments (buyer payment $\rightarrow$ escrow $\rightarrow$ companion payout via Express account). |
| **Identity / KYC** | **Stripe Identity / Persona** | AWS Rekognition / Digilocker (India) | Automated ID document verification and selfie liveness detection. |

---

## 5. Production Database Schema Design

### 5.1 Firestore / Document Structure

```mermaid
erDiagram
    USERS ||--o{ BOOKINGS : places
    COMPANIONS ||--o{ BOOKINGS : accepts
    BOOKINGS ||--|| PAYMENTS : has
    USERS ||--o{ CHAT_THREADS : participates
    COMPANIONS ||--o{ CHAT_THREADS : participates
    CHAT_THREADS ||--o{ MESSAGES : contains
    COMPANIONS ||--o{ REVIEWS : receives

    USERS {
        string uid PK
        string phone
        string email
        string displayName
        string avatarUrl
        string role "client|companion|admin"
        list emergencyContacts
        timestamp createdAt
    }

    COMPANIONS {
        string id PK
        string userId FK
        string bio
        double hourlyRate
        list activities
        list languages
        geopoint location
        string city
        boolean isVerified
        boolean isBackgroundChecked
        string stripeAccountId
        map availability
        double ratingAverage
        int reviewCount
    }

    BOOKINGS {
        string id PK
        string clientId FK
        string companionId FK
        timestamp startTime
        int durationHours
        string activity
        string locationName
        geopoint meetupCoordinates
        string status "pending|confirmed|active|completed|canceled|disputed"
        double subtotal
        double platformFee
        double totalAmount
        string checkInCode
        timestamp checkedInAt
    }

    PAYMENTS {
        string id PK
        string bookingId FK
        string paymentIntentId
        string transferId
        string status "requires_capture|captured|refunded"
        double amount
    }

    CHAT_THREADS {
        string id PK
        list participantIds
        string bookingId FK
        string lastMessageText
        timestamp lastMessageTime
    }

    MESSAGES {
        string id PK
        string threadId FK
        string senderId FK
        string type "text|image|location|voice"
        string text
        map payload
        timestamp sentAt
        boolean isRead
    }
```

---

## 6. Phased Implementation Roadmap

```mermaid
gantt
    title Friendify Implementation Timeline
    dateFormat  YYYY-MM-DD
    section Phase 1: Foundation & Auth
    Firebase Setup & Architecture Refactor :2026-10-10, 5d
    Phone OTP & Social Auth Integration    :2026-10-15, 4d
    User Profile & Role Setup              :2026-10-19, 3d

    section Phase 2: Companion Directory & Geo
    Firestore Companion Store & Queries    :2026-10-22, 5d
    Google Maps & Location Picker          :2026-10-27, 4d
    Host Onboarding & KYC Pipeline         :2026-10-31, 6d

    section Phase 3: Bookings & Stripe Escrow
    Booking Lifecycle State Machine        :2026-11-06, 5d
    Stripe PaymentSheet & Escrow Capture   :2026-11-11, 6d
    QR Check-in & Companion Payouts        :2026-11-17, 4d

    section Phase 4: Real-time Communication
    Firestore Realtime Chat Sync           :2026-11-21, 5d
    Voice Notes & Location Sharing         :2026-11-26, 4d
    FCM Push Notifications                 :2026-11-30, 4d

    section Phase 5: Trust, Safety & Polishing
    SOS Trigger & Emergency Alert Dispatch :2026-12-04, 4d
    Review, Rating & Dispute Workflow      :2026-12-08, 4d
    End-to-End QA, Testing & Store Deploy  :2026-12-12, 6d
```

### Detailed Breakdown:

#### **Phase 1: Foundation & Identity (Sprint 1)**
- [ ] Initialize Firebase project (`flutterfire configure` for Android, iOS, Web).
- [ ] Wire `firebase_core`, `firebase_auth`, and `cloud_firestore`.
- [ ] Implement Phone Number OTP Authentication + Apple/Google Sign-In.
- [ ] Create User Profile screen with role selection (`client` vs `companion`).

#### **Phase 2: Geospatial Search & Host Onboarding (Sprint 2)**
- [ ] Replace `MockCompanionRepository` with real Firestore data store.
- [ ] Implement Geohash indexing / GeoFlutterFire queries for proximity filtering.
- [ ] Integrate `google_maps_flutter` and Google Places autocomplete for meeting point selection in [booking_modal.dart](file:///d:/Android%20Projects/friendify/lib/screens/booking_modal.dart).
- [ ] Build ID document & selfie capture with Cloud Storage upload.

#### **Phase 3: Booking Engine & Escrow Payments (Sprint 3)**
- [ ] Implement Booking State Machine:
  $$\text{Draft} \longrightarrow \text{Pending Companion Approval} \longrightarrow \text{Authorized (Card Held)} \longrightarrow \text{Active (Checked-in)} \longrightarrow \text{Completed (Funds Released)}$$
- [ ] Integrate Stripe PaymentSheet:
  - Client authorizes payment on booking confirmation.
  - Payment is captured upon mutual check-in via QR code or 4-digit PIN.
  - Companion payouts handled via Stripe Express Connect accounts.

#### **Phase 4: Real-Time Chat & Notifications (Sprint 4)**
- [ ] Replace local mock messages in [chat_screen.dart](file:///d:/Android%20Projects/friendify/lib/screens/chat_screen.dart) with real-time Firestore collection listener.
- [ ] Add image sharing, voice message recording, and live location snippets.
- [ ] Implement FCM background notifications for new messages, booking confirmations, and reminders.

#### **Phase 5: Trust, Safety, Ratings & Production Hardening (Sprint 5)**
- [ ] Implement real SOS action in [safety_banner.dart](file:///d:/Android%20Projects/friendify/lib/widgets/safety_banner.dart):
  - Sends immediate push alert & SMS with live GPS link to stored emergency contacts.
  - One-tap local emergency dialer (`tel:112` or `tel:911`).
- [ ] Post-meetup review & star rating system updating companion average metrics.
- [ ] Comprehensive unit, widget, and integration testing across real Android and web devices.

---

## 7. Immediate Decision Matrix for Next Steps

To begin implementation, the key foundational decisions are:

1. **Target Backend Ecosystem**:
   - **Option A (Recommended)**: Firebase (Firestore + Firebase Auth + Cloud Functions). Quickest setup, native FlutterFire support, real-time by default.
   - **Option B**: Supabase (PostgreSQL + PostGIS + Supabase Auth). Better for complex spatial queries and SQL relations.
2. **Target Region & Payment Gateway**:
   - **International**: Stripe (Payment Intents + Stripe Connect for host payouts).
   - **India-centric**: Razorpay / Cashfree (with Route/Marketplace split payouts) + Digilocker / Aadhaar verification.
3. **Target Device Testing**:
   - Run immediately on the connected Android phone (`220733SPI`) or in Chrome for live hot-reload development.
