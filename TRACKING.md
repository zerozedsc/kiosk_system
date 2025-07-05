# Project Tracking Log

_Last updated: 2025-06-30_

---

## 2025-06-30

### Combined Sales & Inventory Report: Low Stock Warning Feature
- **Requirement:** The combined sales & inventory report (TXT and PDF) must include a "Low Stock Warning" section, listing all products with `total_stocks < 5` so the owner can easily identify which items need restocking.
- **Implementation:**
  - Added `_getLowStockProducts` helper to fetch products with low stock from the `kiosk_product` table.
  - Updated both `generateCombinedReportTxt` and `generateCombinedReportPdf` to include a "Low Stock Warning (< 5)" section at the top of the report.
  - The section lists product names and their remaining stock, or a message if all products have sufficient stock.
  - Ensured the section appears before sales, payment, and inventory analytics in both TXT and PDF outputs.
  - Confirmed that product names are shown (not just IDs) for clarity.

### Combined Report: Inventory Changes Section Fix
- **Requirement:** Ensure the "Inventory Changes" section in both TXT and PDF reports accurately displays "Used Stock" and "Used Piece" for each product.
- **Implementation:**
  - Corrected column headers and data mapping in both TXT and PDF reports to use "Used Stock" (`total_stocks`) and "Used Piece" (`total_pieces_used`).
  - Ensured product IDs are mapped to product names using the `kiosk_product` table for user-friendly output.

### Combined Report: Kiosk Info in Header
- **Requirement:** Both TXT and PDF reports must display Kiosk ID and Kiosk Name in the header.
- **Implementation:**
  - Updated report generators to fetch and display `globalAppConfig['kiosk_info']['kiosk_id']` and `globalAppConfig['kiosk_info']['kiosk_name']` at the top of each report.
  - Removed QR code from PDF header as requested.

### Advanced Sales Summary: Payment Method Summary Feature
- **Requirement:** Show a summary of payment methods (count and total amount) in the advanced sales summary dialog, with a modern, responsive, kiosk-friendly layout.
- **Implementation:**
  - Added `updatePaymentMethodSummaryWithRange` to `HomepageService`, aggregating both transaction count and total amount per payment method for a given date range.
  - Fixed a bug where the total amount was always zero by ensuring the correct field (`total_amount`) is used from the database model.
  - Updated the advanced dialog UI to display payment method summary as horizontally scrollable cards, with large icons, clear labels, and responsive sizing for both kiosk and mobile screens.
  - Used `LayoutBuilder` and `ConstrainedBox` to prevent overflow and ensure the summary adapts to various screen sizes.
  - Ensured the summary updates dynamically with the selected date range and filter.
  - Improved code modularity and maintainability for future analytics features.

### Live Sales Summary Section Refactor & Layout Fix
- **Requirement:** The Live Sales Summary section should be modular, maintainable, and not cause layout overflow.
- **Implementation:**
  - Refactored `LiveSalesSummarySection` to be a self-contained `StatefulWidget` with all dialog and filter logic internalized.
  - Removed any redundant or duplicate summary tile builder methods from the parent (`_HomePageState`).
  - Updated the summary tiles layout from a `GridView` (which caused bottom overflow) to a `Row` with three `Expanded` children for responsive, overflow-free display.
  - Ensured the advanced summary dialog is triggered from within the section itself, not via parent callbacks.
  - Verified that the section is now DRY, modular, and visually robust across screen sizes.

### Database Model Integration
- **Requirement:** Use Dart models for all database tables for type safety and maintainability.
- **Implementation:**
  - Created Dart model classes in `model.dart` for each table: `discount_info`, `employee_attendance`, `employee_info`, `inventory_transaction`, `kiosk_product`, `kiosk_transaction`, and `set_product`.
  - Each model includes `fromMap` and `toMap` methods for easy conversion between database rows and Dart objects.
  - Provided guidance and example extension methods for integrating these models with database operations in `db.dart`.
  - Recommended using extension methods or helpers in `db.dart` for CRUD operations, ensuring all database access is type-safe and model-driven.

### Inventory Page Authentication
- **Requirement:** Inventory page must require admin authentication every time the user navigates to it from another tab/page.
- **Implementation:**
  - Used a `GlobalKey<InventoryPageState>` in `page_controller.dart` to access the `resetAuthentication()` method of the `InventoryPage`.
  - On tab switch to Inventory (index 2), call `resetAuthentication()` to force re-authentication.
  - Removed unnecessary `resetAuth` callback parameter from `InventoryPage` for cleaner design.
  - Ensured `InventoryPageState` is public (not private) so it can be referenced by the global key.

---
