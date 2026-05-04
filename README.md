# Focus SwiftBill POS

Focus SwiftBill POS is a Flutter-based point of sale application for retail and supermarket workflows. The app combines local-first billing, product lookup, order history, receipt handling, scanner integration, and backend-ready API services in a single cross-platform codebase.

This repository is structured as a Flutter application with persistent local storage through Hive, secure user/session storage through `flutter_secure_storage`, network access through `dio`, and app-level state management through `provider`.

## Table of Contents

- [Overview](#overview)
- [Current Capabilities](#current-capabilities)
- [Technology Stack](#technology-stack)
- [Architecture Summary](#architecture-summary)
- [Project Structure](#project-structure)
- [Application Flow](#application-flow)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [API Integration](#api-integration)
- [Local Storage and Data Model](#local-storage-and-data-model)
- [Scanner Support](#scanner-support)
- [Build, Code Generation, and Packaging](#build-code-generation-and-packaging)
- [Routes and Screens](#routes-and-screens)
- [Services and Providers](#services-and-providers)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Roadmap and Improvement Areas](#roadmap-and-improvement-areas)
- [Contributing](#contributing)
- [License](#license)

## Overview

The application is designed for day-to-day store operations such as:

- cashier billing
- barcode-assisted product lookup
- payment processing workflows
- receipt presentation
- order tracking and review
- pending bill handling
- offline/local persistence
- configurable backend connectivity

The app starts on a login screen, allows a user to choose a company from the configured backend, and then routes into the main POS workflow. Local persistence makes it suitable for offline-friendly or partially connected environments.

## Current Capabilities

### Authentication and Session

- Login screen with:
  - username
  - password
  - base URL entry
  - company selection
- Company loading from backend based on the entered API base URL
- Cached company list per base URL using `SharedPreferences`
- Session timeout management through `SessionService`
- Secure session identifier storage through `flutter_secure_storage`
- Quick login and biometric-related screens/services present in the project

### POS and Billing

- Product browsing and product lookup
- Billing workflows under `lib/screens/billing/`
- Payment screen with multiple payment mode support in the UI flow
- Receipt screen and receipt list
- Order history and order detail access
- Pending bill management
- Held order storage support through Hive

### Local Data

- Hive-backed local storage for:
  - products
  - customers
  - cart
  - orders
  - pending bills
  - settings
  - held orders
- Seeded sample products on first run when the products box is empty
- Backup screen for export/import related workflows

### Scanner and Device Features

- Camera scanner screen
- Scanner selection dialog
- Scanner service for external scanning workflows
- Bluetooth-related dependencies and scanner documentation included
- Permission guidance for barcode scanner setup in dedicated markdown docs

### Dashboard and Operations

- Dashboard screen with sales and order summaries
- More/settings area with store utilities
- Role-based structure through `AuthService` and RBAC-related service files

## Technology Stack

### Framework and Language

- Flutter
- Dart SDK `^3.10.8`

### State Management

- `provider`

### Persistence and Security

- `hive`
- `hive_flutter`
- `shared_preferences`
- `flutter_secure_storage`

### Networking

- `dio`
- `connectivity_plus`
- `flutter_dotenv`

### Device and Platform Features

- `local_auth`
- `mobile_scanner`
- `flutter_blue_plus`
- `permission_handler`
- `path_provider`

### UI and Utilities

- `fl_chart`
- `intl`
- `uuid`
- `json_annotation`

### Development Tooling

- `build_runner`
- `hive_generator`
- `json_serializable`
- `flutter_lints`
- `flutter_launcher_icons`

## Architecture Summary

The app follows a fairly standard Flutter layered structure:

- `screens/` holds UI pages and feature flows
- `services/` holds API, auth, persistence, session, and scanner logic
- `models/` holds app entities and generated serialization/adapters
- `providers/` holds app-wide state containers
- `theme/` centralizes theming
- `utils/` stores constants and shared configuration

At runtime:

1. Flutter initializes Hive and app services in `main.dart`
2. `DatabaseService.init()` opens all Hive boxes and seeds products if needed
3. `AuthService.init()` restores a stored user session
4. `ApiService.init()` prepares Dio and session header behavior
5. `SessionService` starts inactivity monitoring
6. `MaterialApp` launches at `/login`

## Project Structure

```text
.
|-- android/
|-- ios/
|-- linux/
|-- macos/
|-- web/
|-- windows/
|-- assets/
|   |-- focusswiftbill.jpeg
|   `-- logo2-removebg-preview.png
|-- lib/
|   |-- main.dart
|   |-- models/
|   |   |-- api_models.dart
|   |   |-- cart_item.dart
|   |   |-- customer.dart
|   |   |-- order.dart
|   |   |-- product.dart
|   |   `-- generated *.g.dart files
|   |-- providers/
|   |   |-- data_refresh_provider.dart
|   |   |-- navigation_provider.dart
|   |   `-- orders_provider.dart
|   |-- screens/
|   |   |-- login_screen.dart
|   |   |-- main_screen.dart
|   |   |-- pending_bills.dart
|   |   |-- quick_login_screen.dart
|   |   |-- quick_login_setup_screen.dart
|   |   |-- admin_settings/
|   |   |-- billing/
|   |   |-- camera_scanner/
|   |   |-- dashboard/
|   |   |-- more/
|   |   |-- orders/
|   |   |-- payment/
|   |   |-- receipt/
|   |   `-- sales orders/
|   |-- services/
|   |   |-- api_service.dart
|   |   |-- auth_service.dart
|   |   |-- database_service.dart
|   |   |-- rbac_service.dart
|   |   |-- scanner_service.dart
|   |   `-- session_service.dart
|   |-- theme/
|   |   `-- app_theme.dart
|   |-- utils/
|   |   `-- constants.dart
|   `-- widgets/
|       `-- custom_widgets.dart
|-- test/
|   `-- widget_test.dart
|-- .env.example
|-- SCANNER_IMPLEMENTATION.md
|-- SCANNER_PERMISSIONS.md
|-- pubspec.yaml
`-- README.md
```

## Application Flow

### Startup

1. App initializes Flutter bindings
2. Hive is initialized
3. Local boxes are opened
4. Auth and API services restore stored state
5. Session timeout watcher starts
6. Login screen is shown

### Login Flow

The login flow is backend-aware:

1. User enters or confirms the API base URL
2. The app loads companies from the selected backend
3. User selects a company
4. User submits username and password
5. A session ID from the server response is stored securely
6. App navigates to the main POS interface

### Operational Flow

After login, the user can move through:

- dashboard
- billing
- orders
- payment
- receipt
- pending bills
- settings/more

## Getting Started

### Prerequisites

Install the following before running the project:

- Flutter SDK compatible with the project environment
- Dart SDK compatible with `sdk: ^3.10.8`
- Android Studio, VS Code, or another Flutter-capable IDE
- Android emulator, iOS simulator, desktop target, or physical device

To verify your environment:

```bash
flutter doctor
```

### Clone the Repository

```bash
git clone <your-repository-url>
cd focusnewbackup-main
```

### Install Dependencies

```bash
flutter pub get
```

### Generate Code

This project uses generated files for Hive adapters and JSON serialization.

```bash
dart run build_runner build --delete-conflicting-outputs
```

If you want a watch mode during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### Run the App

```bash
flutter run
```

Examples:

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

## Configuration

### Environment File

An example file is provided:

```bash
.env.example
```

Create a local `.env` if you want environment-based configuration:

```bash
copy .env.example .env
```

Example values:

```env
API_BASE_URL=http://localhost:3000/api
APP_ENV=development
LOG_LEVEL=debug
```

### Base URL Behavior

The app supports multiple ways of determining the API base URL:

- saved base URL from `SharedPreferences`
- `.env` value via `API_BASE_URL`
- fallback base URL inside `ApiService`
- manual base URL entry on the login screen

For Focus8 API-style login flows, the login screen commonly uses a base URL such as:

```text
http://localhost/focus8API
```

The login screen also stores a recent base URL history and caches company lists per base URL.

## API Integration

`lib/services/api_service.dart` contains the current API client implementation.

### Supported Endpoint Patterns

The service currently includes methods for:

- `POST /login`
- `GET /List/Company`
- `GET /List/Masters/Core_Product`
- `GET /Screen/Masters/Core_Product/{code}`
- `GET /List/Masters/Core_Account`
- `GET /List/Transactions/Sales Orders`
- `GET /Screen/Transactions/Sales Orders/{voucherNo}`
- `POST /Transactions/Sales Orders`
- `DELETE /Transactions/Sales Orders/{voucherNo}`
- `GET /Screen/Transactions/AlertApprovalCount`
- `GET /Screen/Transactions/Approvals`
- `GET /utility/preferences`
- `GET /Reports/pagedata?id={id}`

### Login Request Format

The login flow is currently documented around a Focus8-style payload:

**Endpoint**

```text
POST http://localhost/focus8API/login
```

**Request body**

```json
{
  "data": [
    {
      "Username": "su",
      "password": "su",
      "CompanyId": "36"
    }
  ],
  "result": 1,
  "message": ""
}
```

**Typical response**

```json
{
  "url": "http://localhost/focus8API/login",
  "data": [
    {
      "iLoginId": 1,
      "Status": 4,
      "EmployeeId": 0,
      "LoginName": "SU",
      "AltLanguageId": 0,
      "fSessionId": "010-0305202613710612361",
      "EmployeeName": ""
    }
  ],
  "result": 1,
  "message": ""
}
```

### Session Handling

The API layer stores `fSessionId` in secure storage and automatically attaches it to subsequent requests through a Dio interceptor.

### Error Handling

`ApiService` centralizes API error handling and converts network failures or non-success responses into `ApiException`.

Areas already covered:

- missing server response
- timeout/no connection
- HTTP-based failures
- invalid login fallback messaging

## Local Storage and Data Model

### Hive Boxes

The following boxes are initialized in `DatabaseService`:

- `products`
- `customers`
- `cart`
- `orders`
- `pending_bills`
- `settings`
- `held_orders`

Additional custom cart boxes are supported through:

- `DatabaseService.getCartBox(String name)`

### Seed Data

When the `products` box is empty, the app seeds sample products such as:

- Amul Toned Milk
- Britannia Brown Bread
- Tata Salt
- Surf Excel Refill
- Parle-G Biscuits
- Maggi Noodles
- Coca Cola 750ml
- Pringles

### Main Models

- `Product`
- `Customer`
- `CartItem`
- `Order`
- API models in `api_models.dart`

### Storage Responsibilities

- `Hive`
  - products
  - customers
  - carts
  - orders
  - settings
- `SharedPreferences`
  - selected company metadata
  - base URL history
  - cached company lists
  - lightweight preferences
- `flutter_secure_storage`
  - session ID
  - auth-related secure data
  - quick login and biometric flags

## Scanner Support

Scanner-related implementation and setup are documented separately:

- [SCANNER_IMPLEMENTATION.md](SCANNER_IMPLEMENTATION.md)
- [SCANNER_PERMISSIONS.md](SCANNER_PERMISSIONS.md)

### Scanner Capabilities in the Repository

- camera scanning UI
- scanner selection dialog
- scanner service abstraction
- Bluetooth scanner integration groundwork
- keyboard/HID style scanner support path

### Related Files

- `lib/services/scanner_service.dart`
- `lib/screens/camera_scanner/camera_scanner_screen.dart`
- `lib/screens/billing/scanner_selection_dialog.dart`

## Build, Code Generation, and Packaging

### Debug Build

```bash
flutter build apk --debug
```

### Release Build

```bash
flutter build apk --release
flutter build appbundle --release
flutter build windows --release
flutter build web --release
```

### iOS

```bash
flutter build ios --release
```

### App Icons

Launcher icon configuration is already present in `pubspec.yaml` via `flutter_launcher_icons`.

To regenerate icons:

```bash
dart run flutter_launcher_icons
```

## Routes and Screens

### Registered Routes

The main route table in `lib/main.dart` currently includes:

- `/login`
- `/billing`
- `/pending_bills`
- `/main`
- `/payment`
- `/receipt`
- `/camera_scanner`
- `/view_all_billings`
- `/salesorders`
- `/settings`

### Key Screens

- `login_screen.dart`
  - login UI
  - base URL entry
  - company selection
- `main_screen.dart`
  - main shell/navigation
- `dashboard/dashboard_screen.dart`
  - overview metrics
  - summary cards/charts
- `billing/billing_screen.dart`
  - billing workflow
  - cart interactions
  - scanner entry points
- `billing/billing_hub_screen.dart`
  - billing navigation or orchestration
- `payment/payment_screen.dart`
  - payment handling
- `receipt/receipt_screen.dart`
  - receipt rendering
- `orders/orders_screen.dart`
  - order history
- `pending_bills.dart`
  - pending bill workflow
- `more/more_screen.dart`
  - app settings and operational utilities

## Services and Providers

### Services

- `ApiService`
  - backend communication
  - session header injection
  - login and data endpoints
- `AuthService`
  - current user state
  - secure persistence
  - logout behavior
- `DatabaseService`
  - Hive initialization
  - box access
  - seed data
- `SessionService`
  - inactivity timeout
  - auto-logout callback integration
- `ScannerService`
  - scanner coordination
- `RbacService`
  - role and permissions-related behavior

### Providers

- `NavigationProvider`
  - current navigation state
- `OrdersProvider`
  - order-related state
- `DataRefreshProvider`
  - app refresh coordination

## Testing

The repository currently contains the default Flutter widget test scaffold:

- `test/widget_test.dart`

Run tests with:

```bash
flutter test
```

Static analysis:

```bash
dart analyze
```

Recommended additional test coverage:

- login/API authentication flow
- company cache loading
- order creation and totals
- pending bill conversion
- session timeout behavior
- scanner service input buffering

## Troubleshooting

### App Does Not Start

Check:

- `flutter doctor`
- dependency installation with `flutter pub get`
- generated files via `build_runner`
- correct Flutter/Dart versions

### Hive Errors or Adapter Issues

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

If local data is corrupted during development, clear the app data for the target device or emulator.

### API Calls Fail

Verify:

- the base URL is correct
- the server is reachable
- the company list endpoint is available
- the login endpoint path matches your backend
- the stored session is still valid

### Login Problems

Check the following:

- the base URL includes the correct app path such as `http://localhost/focus8API`
- a valid company is selected
- credentials are valid for the selected company
- the backend returns `result: 1`
- the response includes a usable `fSessionId`

### Scanner Issues

Use the dedicated scanner docs:

- `SCANNER_IMPLEMENTATION.md`
- `SCANNER_PERMISSIONS.md`

## Roadmap and Improvement Areas

This repository already includes a strong local-first foundation, but there are several natural next steps:

- strengthen automated test coverage
- finish end-to-end backend integration for all data flows
- expand user and role management
- harden sync and conflict resolution
- improve receipt printing and device integrations
- add more production-ready reporting/export features
- refine quick login and biometric flows
- improve error states and retry flows across networked screens

## Contributing

If you are contributing internally:

1. Create a feature branch
2. Make changes in small, reviewable commits
3. Regenerate code if models change
4. Run `flutter test`
5. Run `dart analyze`
6. Open a pull request or internal review request

Suggested workflow:

```bash
git checkout -b feature/your-change
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
dart analyze
```

## License

This project is proprietary and confidential unless your organization explicitly states otherwise.

Do not redistribute or publish the code, assets, or internal documentation without approval.

---

## Quick Reference

### Useful Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
flutter test
dart analyze
flutter build apk --release
```

### Important Files

- `lib/main.dart`
- `lib/services/api_service.dart`
- `lib/services/database_service.dart`
- `lib/services/auth_service.dart`
- `lib/screens/login_screen.dart`
- `pubspec.yaml`
- `SCANNER_IMPLEMENTATION.md`
- `SCANNER_PERMISSIONS.md`

### Project Metadata

- App name: `Focus SwiftBill`
- Package name: `focus_swiftbill`
- Version: `1.0.0+1`
- Flutter assets:
  - `assets/focusswiftbill.jpeg`
  - `assets/logo2-removebg-preview.png`
