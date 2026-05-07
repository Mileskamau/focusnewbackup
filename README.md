# Focus SwiftBill POS

Focus SwiftBill POS is a Flutter-based point of sale application for retail and supermarket workflows. The app combines local-first billing, product lookup, order history, receipt handling, scanner integration, and backend-ready API services in a single cross-platform codebase.

This repository is structured as a Flutter application with persistent local storage through Hive, secure user/session storage through `flutter_secure_storage`, network access through `dio`, and app-level state management through `provider`.

## Table of Contents

- [Overview](#overview)
- [Order Numbering Schemes](#order-numbering-schemes)
- [Receipt System](#receipt-system)
- [Current Capabilities](#current-capabilities)
- [Technology Stack](#technology-stack)
- [Architecture Summary](#architecture-summary)
- [Project Structure](#project-structure)
- [Application Flow](#application-flow)
- [The Billing Workflow](#the-billing-workflow)
- [The Sales Orders Workflow](#the-sales-orders-workflow)
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

## Order Numbering Schemes

The system uses **two distinct order numbering schemes** to differentiate retail transactions from formal sales orders:

### Retail / Billing Orders (`ORD-`)
- Generated during **billing/checkout** in the billing and payment screens  
- Format: `ORD-YYYYMMDD-000001` (incremental daily counter)  
- Also used as: `ORD-YYYYMMDD-TIMEOUT-00000` (timeout fallback)  
- Used for: Daily retail sales, walk-in customer purchases, cashier transactions  
- Location: `lib/screens/payment/payment_screen.dart`, `lib/models/order.dart`

### Sales Orders (`SRO-`)
- Generated in the **Sales Orders** workflow (`lib/screens/sales orders/salesorders.dart`)  
- Format: `SRO-YYYYMMDD-000001` (incremental daily counter)  
- Timeout fallback: `SRO-YYYYMMDD-TIMEOUT-00000`  
- Used for: Customer quotations, bulk orders, B2B sales, delayed fulfillment  
- Automatically converts the standard `ORD-` prefix from `Order.generateOrderNumber()` to `SRO-`

**Rationale**: Keeping these separate enables businesses to track formal sales proposals distinct from immediate cash sales, simplifies accounting, and supports different fulfillment workflows.

## Receipt System

The receipt system was redesigned for a professional POS printing experience:

### Screen Redesign (`lib/screens/receipt/receipt_screen.dart`)
- **Dark-themed app bar** contrasting with white receipt card  
- **Professional layout**: Header → Store Info → Transaction Info → Items Table → Totals → Payment Details → Footer  
- **Paid status badge** with green checkmark  
- **Gradient dashed dividers** resembling real thermal receipt paper  
- **Itemized table** with proper column alignment (Item | Qty | Amount)  
- **Clear section hierarchy** with appropriate typography and spacing  
- **Receipt width**: 280 logical pixels (~80mm thermal roll)

### Direct Printing
- **Previously**: Print button opened an intermediate `ReceiptPrintScreen` page  
- **Now**: Print button **directly** invokes the system print dialog — no intermediate page  
- Uses `printing` package for cross-platform printing  
- PDF preview available before printing  
- Printer selection handled natively by the OS

### PDF Generation
- Shared PDF generation logic between display and print flows  
- `lib/screens/receipt/receipt_screen.dart` includes `_buildPdf()` method  
- Uses `pdf: ^3.10.0` and `printing: ^5.11.0`  
- Standardized layout across display and physical print

### Receipt Content
- Store name, address, phone, GSTIN  
- Order number, date/time, cashier name  
- Full item list with quantities and line totals  
- Subtotal, tax (18%), grand total clearly separated  
- Payment method and change (if applicable)  
- Thank-you message with footer  



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

## The Billing Workflow

The retail billing flow (ORD- orders) progresses as follows:

1. **Billing Screen** (`lib/screens/billing/billing_screen.dart`)
   - Browse products by category or search
   - Scan barcodes via camera or hardware scanner
   - Real-time stock and pricing checks against local Hive cache
   - Add/remove items, adjust quantities
   - Cart summary (subtotal, tax, total) updated in real-time

2. **Payment Screen** (`lib/screens/payment/payment_screen.dart`)
   - Review final amounts
   - Select payment method (Cash / Card / Digital Wallet)
   - Calculate change for cash payments
   - Generate `ORD-XXXXXX` order number via `Order.generateOrderNumber()`
   - Save order to local `orders` Hive box
   - Navigate to receipt screen

3. **Receipt Screen** (`lib/screens/receipt/receipt_screen.dart`)
   - Display professional receipt UI with all order details
   - **Direct Print button** → invokes system print dialog (no intermediate page)
   - Return to dashboard or create new order

Key classes:
- `BillingScreen` – Main billing UI with product grid and cart
- `CartItem` – Cart line item with quantity, discount, line total
- `Product` – Product entity with live pricing from backend
- `DatabaseService` – Hive persistence layer

## The Sales Orders Workflow

The sales orders flow (SRO- orders) handles customer-facing orders and quotations:

1. **Sales Orders Screen** (`lib/screens/sales orders/salesorders.dart`)
   - Select member/customer from stored database
   - Add items to cart (identical UI/UX to billing)
   - Real-time pricing fetched from backend API with local fallback

2. **Order Number Generation**
   - Calls `Order.generateOrderNumber()` → gets `ORD-XXXXXX`  
   - **Converts to `SRO-`** by prefix replacement at line 925-928
   - Stores as `Order` with `SRO-XXXXXXXX` format
   - Timeout fallback generates `SRO-YYYYMMDD-TIMEOUT-00000` directly

3. **Payment and Completion**
   - Process payment (immediate or on-account)
   - Save order to local `orders` box with `SRO-` prefix
   - Display receipt with direct print option

**Code Location**: Order number conversion in `lib/screens/sales orders/salesorders.dart` lines 925-928:
```dart
if (orderNumber.startsWith('ORD-')) {
  orderNumber = 'SRO' + orderNumber.substring(3);
}
```

## Build, Code Generation, and Packaging

### Prerequisites

```bash
# Verify Flutter installation
flutter doctor

# Install dependencies
flutter pub get

# Generate code (Hive adapters, JSON serializers)
dart run build_runner build --delete-conflicting-outputs
```

If you modify any models in `lib/models/*.dart` or files using `json_annotation`, you **must** regenerate code.

### Debug Build

```bash
flutter build apk --debug
flutter build ios --debug
flutter build web --debug
```

### Release Build

```bash
# Android APK (for testing)
flutter build apk --release

# Android AppBundle (for Google Play)
flutter build appbundle --release

# iOS
flutter build ios --release

# Windows (desktop)
flutter build windows --release

# Web
flutter build web --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release
```

### Code Generation

The project uses `build_runner` for code generation:

| Generator | Purpose | Output |
|-----------|---------|--------|
| `hive_generator` | Hive TypeAdapters | `*.g.dart` files |
| `json_serializable` | JSON `fromJson`/`toJson` | `*.g.dart` files |

After modifying models:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For development watch mode:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### App Icons

Launcher icon configuration is in `pubspec.yaml` via `flutter_launcher_icons`. To regenerate:

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
- `lib/models/order.dart` – Order entity, ORD-/SRO- generation
- `lib/models/cart_item.dart` – Cart item, line totals, discounts
- `lib/screens/login_screen.dart`
- `lib/screens/billing/billing_screen.dart` – Retail billing (ORD-)
- `lib/screens/payment/payment_screen.dart` – Payment, order creation
- `lib/screens/receipt/receipt_screen.dart` – Receipt display, direct print
- `lib/screens/sales orders/salesorders.dart` – Sales Orders (SRO-)
- `pubspec.yaml`
- `SCANNER_IMPLEMENTATION.md`
- `SCANNER_PERMISSIONS.md`

### Project Metadata

- **App Name**: `Focus SwiftBill`
- **Package Name**: `focus_swiftbill`
- **Version**: `1.0.0+1`
- **Flutter Version**: Compatible with Dart `^3.10.8`
- **Assets**:
  - `assets/focusswiftbill.jpeg`
  - `assets/logo2-removebg-preview.png`

### Order Number Formats

| Type | Prefix | Example | Generated By |
|------|--------|---------|--------------|
| Retail Billing | `ORD-` | `ORD-20260507-000123` | `payment/payment_screen.dart` |
| Sales Orders | `SRO-` | `SRO-20260507-000456` | `sales orders/salesorders.dart` |
| Timeout Fallback | `ORD-/SRO-` | `ORD-20260507-TIMEOUT-01234` | Timeout handlers |
