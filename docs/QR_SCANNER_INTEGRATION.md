# SRISHTI 2.7 — QR Scanner & Generator Integration Guide

**Document:** QR Code Specification & Mobile Scanner Decoding  
**Project:** SRISHTI 2.7 Attendance & Pass System  
**Integration Partner:** Srishti 2.7 QR Generator Web Application  
**Status:** Implemented & Verified  

---

## 1. Overview

The Srishti 2.7 attendee pass generator produces high-contrast, machine-readable QR codes (with Error Correction Level **H**, Srishti vertical pillar styling, and cyan-to-blue gradient).

This guide describes how the Flutter Volunteer Scanner application (`srishti_volunteer`) decodes, verifies, and looks up participants in Supabase.

---

## 2. Supported QR Formats

The mobile scanner now transparently supports all 5 Srishti QR formats through `QRPayloadParser`:

### Format A: Compact Pipe Format (Primary / Production Standard)
* **Payload:** `SR27|<ATTENDEE_ID>`
* **Examples:**
  * `SR27|A8F29KX4`
  * `SR27|001`
  * `SR27|SR27-001`
* **Resolution Strategy:**
  1. Extracts primary ID: `A8F29KX4`
  2. Generates candidate database codes: `['A8F29KX4', 'SR27-A8F29KX4', 'SRI27-A8F29KX4', 'TEST-SRI27-A8F29KX4']`
  3. Queries `participants` table by `participant_code`
  4. Fallback search via `ilike`

### Format B: Srishti 2.7 JSON QR
* **Payload:**
  ```json
  {
    "v": 1,
    "event": "SRISHTI27",
    "id": "A8F29KX4"
  }
  ```
* **Resolution Strategy:**
  1. Decodes JSON and validates event namespace (`SRISHTI27`).
  2. Extracts `id` and queries Supabase.

### Format C: Formatted Token QR
* **Payload:** `SR27-A8F29KX4` or `SR27-001` or `SRI27-0001` or `TEST-SRI27-001`
* **Resolution Strategy:**
  1. Matches exact token.
  2. Extracts suffix and matches un-prefixed ID.

### Format D: Participant UUID
* **Payload:** `123e4567-e89b-12d3-a456-426614174000`
* **Resolution Strategy:** Matches `participants.id` directly.

---

## 3. Architecture & Code Changes

### A. `lib/core/utils/qr_payload_parser.dart`
New parser engine that parses any raw barcode string into a `ParsedQRPayload` with prioritized candidate database keys.

### B. `lib/features/participants/services/participant_service.dart`
Upgraded `getParticipantByCode(String participantCode)`:
* Uses `QRPayloadParser.parse` to extract clean identifier.
* Queries Supabase across all candidate keys (`A8F29KX4`, `SR27-A8F29KX4`, `SR27-001`, etc.).
* Handles direct UUID matches and fallback fuzzy search.

### C. `lib/features/checkin/services/checkin_service.dart`
Upgraded `resolveParticipantId(String identifier)`:
* Resolves participant UUIDs for both festival arrival check-in and event-specific check-in from scanned QR strings.

### D. `lib/features/scanner/screens/scan_screen.dart`
* **Haptic Feedback:** Instant vibration upon optical barcode detection.
* **Enhanced Diagnostics:** If a code is scanned but not found in Supabase, the dialog displays:
  * Extracted attendee ID
  * Detected Srishti QR format
  * Raw scanned payload

---

## 4. How to Test End-to-End

1. Start the QR generator website (`http://localhost:5174/`).
2. Generate any attendee pass (e.g. Arun Krishna `SR27-001`, token `SR27-A8F29KX4`).
3. Point the Flutter Mobile Scanner camera at the generated QR code on screen.
4. The scanner locks on $\rightarrow$ haptic click $\rightarrow$ decodes `SR27|A8F29KX4` $\rightarrow$ retrieves participant details sheet immediately!
