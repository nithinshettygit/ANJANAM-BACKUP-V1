---
name: indian-address-invoice
description: Implement and debug Indian-language customer address transliteration and reliable English/Latin invoice and shipping-label rendering in Flutter, Supabase, and PDF generation. Use this skill whenever customer addresses, multilingual invoice PDFs, labels, printing, or address transliteration are involved.
---

# ANJANAM — INDIAN ADDRESS / INVOICE SKILL

## PRIMARY OBJECTIVE

Implement a reliable system where customers may enter names and addresses in
Indian languages, while Anjanam invoices and shipping labels display a
Latin/English-script version.

The customer's original address MUST NEVER be overwritten.

This skill is specifically for fixing the recurring problem where Kannada,
Malayalam, Hindi, Tamil, Telugu, Bengali, etc. are entered by customers but
the generated PDF does not print/render correctly.

---

# REQUIRED ARCHITECTURE

NEVER solve this by simply changing the PDF font.

Use TWO representations of customer address:

1. ORIGINAL
2. INVOICE/LABEL DISPLAY VERSION

Example:

original_address:
ಬೇಂದ್ರೆ ಹೌಸ್
ಮುಖ್ಯ ರಸ್ತೆ
ಬಂಟ್ವಾಳ
ದಕ್ಷಿಣ ಕನ್ನಡ
ಕರ್ನಾಟಕ

invoice_address:
Bendre House
Mukhya Road
Bantwal
Dakshina Kannada
Karnataka

Database concept:

customer/order address:
- original_name
- original_address
- invoice_name
- invoice_address

Do not delete or replace the original values.

---

# IMPORTANT: TRANSLITERATION, NOT TRANSLATION

For addresses, the default operation is ROMANIZATION / TRANSLITERATION.

Do NOT use ordinary machine translation as the default.

Reason:

Names, localities, house names, streets and landmarks must preserve their
identity.

Example:

Kannada:
ಬೇಂದ್ರೆ ಹೌಸ್

Preferred:
Bendre House

NOT:
Bendre Residence

Example:

ಕಾಸರಗೋಡು

Preferred:
Kasaragod

NOT:
Kasaragod District Headquarters

The objective is:

INDIAN SCRIPT → LATIN SCRIPT

NOT:

INDIAN LANGUAGE → SEMANTIC ENGLISH TRANSLATION

---

# EXACT PROCESS

When an address is saved or an order is created:

STEP 1
Keep the original customer input unchanged.

STEP 2
Detect whether the string contains non-Latin characters.

STEP 3
If the text is already Latin/English:
    invoice value = original value

STEP 4
If the text contains supported Indic scripts:
    transliterate/romanize to Latin characters.

STEP 5
Store the resulting value as invoice_name / invoice_address.

STEP 6
Generate invoice and shipping label using invoice_name /
invoice_address.

STEP 7
Keep original_name / original_address available in the order/customer
record.

---

# DO NOT TRANSLITERATE EVERYTHING BLINDLY

The following must NOT be modified:

- GSTIN
- HSN
- SKU
- Order ID
- Invoice number
- PIN code
- Phone number
- Email
- URLs
- Numeric values
- Product IDs

Only human-readable name/address fields should be processed.

---

# REQUIRED LANGUAGE SUPPORT

The implementation must support at minimum:

- Kannada
- Malayalam
- Hindi / Devanagari
- Tamil
- Telugu
- Bengali
- Marathi
- Gujarati
- Punjabi
- English

Do not hard-code only Kannada.

---

# WHERE THE TRANSFORMATION SHOULD HAPPEN

Prefer SERVER-SIDE generation of the invoice representation.

The authoritative invoice_address should be generated before the invoice
PDF is produced.

Do NOT depend on Flutter UI state to generate the final invoice address.

Preferred flow:

Customer App
    ↓
original address
    ↓
Supabase database
    ↓
server-side address normalization/transliteration
    ↓
invoice_address
    ↓
invoice generator
    ↓
PDF
    ↓
download / print

---

# DO NOT CALL AN AI MODEL FOR EVERY PDF RENDER

Do not send the address to an LLM every time an invoice is opened.

The transliteration result should be generated once and stored.

Only regenerate when the original address changes.

This avoids:
- unnecessary API cost
- latency
- inconsistent results
- different spelling on different invoice generations

---

# TRANSLITERATION IMPLEMENTATION

FIRST inspect the existing project architecture and determine whether
transliteration can be performed reliably using an existing package/library.

If the project is Flutter/Dart, prefer a maintained deterministic
transliteration library that supports the required Indic scripts.

If the existing backend is Supabase Edge Functions / TypeScript,
prefer a deterministic server-side JavaScript/TypeScript transliteration
library if it supports the required scripts.

Do NOT invent a transliteration algorithm.

Do NOT create a huge manually maintained Kannada/Hindi/Malayalam character
mapping unless no suitable maintained library is available.

If a deterministic local library cannot reliably support the required
languages, use a dedicated romanization API.

Google Cloud Translation Romanization may be used as a fallback/approved
external service because romanization specifically converts non-Latin scripts
to Latin script.

Do NOT use semantic translation for addresses.

---

# API FALLBACK REQUIREMENTS

If an external romanization service is used:

1. Never expose API credentials in Flutter/web client code.
2. Call the service only from a secure backend/Edge Function.
3. Store the result in the database.
4. Do not call the service every time the invoice PDF is opened.
5. Add timeout handling.
6. Add failure handling.
7. If the service fails, preserve the original address.
8. Never invent an address.
9. Log failures without logging unnecessary sensitive customer information.

---

# PDF FONT REQUIREMENT

Even though the preferred invoice address is Latin/English,
the PDF generator MUST still support Unicode.

Use an embedded Unicode-capable font.

Do NOT depend on the operating system's fonts.

Do NOT assume Helvetica/Arial alone is sufficient.

The PDF must correctly render:

- English
- Latin characters
- Indian names if original fallback is required
- ₹
- special punctuation

If the current PDF library cannot embed fonts correctly, inspect the
existing PDF generation implementation and replace/configure the font
properly.

---

# FALLBACK RULE

NEVER destroy address information.

If transliteration fails:

invoice_address = original_address

Then the PDF renderer must still be capable of displaying Unicode.

Never return:

"undefined"

"null"

"?"

"????"

or an empty address.

---

# IMPORTANT: DO NOT MODIFY CUSTOMER DISPLAY

Customer app should continue showing the original address.

Example:

Customer app:
ಬೇಂದ್ರೆ ಹೌಸ್, ಮುಖ್ಯ ರಸ್ತೆ, ಬಂಟ್ವಾಳ

Invoice:
Bendre House, Mukhya Road, Bantwal

Shipping label:
Bendre House
Mukhya Road
Bantwal

---

# DATA MODEL

Before changing the database, inspect the current schema.

Reuse existing address columns if possible.

If necessary, add:

invoice_name
invoice_address

Do not duplicate entire customer/address systems unnecessarily.

If address is copied into an order snapshot already, add the invoice
representation to the ORDER ADDRESS SNAPSHOT as well.

Historical orders MUST NOT change when the customer's current profile
address changes.

---

# CRITICAL ORDER SNAPSHOT RULE

At order/invoice creation time:

copy:

- original_name
- original_address
- invoice_name
- invoice_address

into the order/invoice snapshot.

Do not dynamically read the customer's current profile address when
generating an old invoice.

---

# PDF GENERATION

Invoice PDF must use:

invoice_name
invoice_address

NOT:

customer.profile.address

NOT:

current user address

NOT:

raw UI text

The invoice must be reproducible.

If an invoice is generated today and again one year later,
the address on the historical invoice must remain identical.

---

# SHIPPING LABEL

Use invoice_name / invoice_address or a dedicated normalized
shipping representation.

Do not display the original script by default if the purpose is
operational courier readability.

Keep the label simple.

---

# TEST DATA

The implementation is NOT complete until all of these cases work.

TEST 1 — Kannada

Input:
ನಿತಿನ್
ಬೇಂದ್ರೆ ಹೌಸ್
ಮುಖ್ಯ ರಸ್ತೆ
ಬಂಟ್ವಾಳ
ದಕ್ಷಿಣ ಕನ್ನಡ
ಕರ್ನಾಟಕ
574211

Expected:
Original remains unchanged.

Invoice contains readable Latin-script output such as:

Nithin
Bendre House
Mukhya Road
Bantwal
Dakshina Kannada
Karnataka
574211

Exact transliteration may vary, but it must remain recognizable and
must NOT semantically invent information.

---

TEST 2 — Malayalam

Input:
നിതിൻ
ബെന്ദ്രെ ഹൗസ്
പ്രധാന റോഡ്
കാസർഗോഡ്
കേരളം
671321

Expected:
Readable Latin-script invoice output.

---

TEST 3 — Hindi

Input:
नितिन
बेंद्रे हाउस
मुख्य सड़क
बंतवाल
कर्नाटक
574211

Expected:
Readable Latin-script invoice output.

---

TEST 4 — Tamil

Input:
நிதின்
பெந்திரே ஹவுஸ்
முக்கிய சாலை
கர்நாடகா

Expected:
Readable Latin-script output.

---

TEST 5 — English

Input:
Nithin
Bendre House
Main Road
Bantwal
Karnataka
574211

Expected:
No transformation.

Output must remain exactly the same.

---

TEST 6 — Mixed address

Input:
Nithin
ಬೇಂದ್ರೆ ಹೌಸ್
Main Road
ಬಂಟ್ವಾಳ
Karnataka
574211

Expected:
Latin/English invoice representation without destroying existing
English text.

---

TEST 7 — Special fields

Input contains:

GSTIN: 32CQRPM1694P1ZZ
Phone: 8129107108
PIN: 671321
Email: support.anjanam@gmail.com

Expected:
All remain exactly unchanged.

---

# PDF TEST

Generate an actual invoice PDF.

Verify:

1. Browser preview works.
2. Print works.
3. Download works.
4. Downloaded PDF opens.
5. No boxes/tofu characters.
6. No question marks.
7. No missing characters.
8. Rupee symbol renders.
9. Long Indian addresses wrap correctly.
10. Address does not overflow invoice boxes.
11. Address does not overlap other invoice sections.

---

# DOWNLOAD TEST

Do not rely on Chrome PDF viewer's Download button.

The application must provide its own:

Download Invoice PDF

implementation.

Use the generated PDF Blob/bytes directly.

Do not prematurely revoke the object URL.

---

# DO NOT MAKE THESE COMMON FAILED FIXES

DO NOT:

- simply replace the address with English using a hard-coded map
- only add a Google Font to Flutter UI
- only add a Unicode font to the PDF
- translate the address semantically
- overwrite the original address
- call an LLM every time an invoice is viewed
- generate invoice text on the client from current profile data
- silently discard characters
- replace unknown characters with '?'
- store only the transliterated version

---

# REQUIRED DEBUGGING PROCESS

Before writing code:

1. Inspect current database schema.
2. Inspect customer address model.
3. Inspect order address snapshot.
4. Inspect invoice generation service.
5. Inspect PDF generation library.
6. Inspect current font configuration.
7. Inspect download implementation.
8. Identify exactly where native-language text is lost.

Then implement the smallest complete solution.

Do not rewrite unrelated invoice code.

---

# REQUIRED FINAL REPORT

After implementation report exactly:

STATUS:
PASS / PARTIAL / FAILED

DATABASE:
- fields added/changed

BACKEND:
- transliteration function/service
- where it runs

PDF:
- PDF library
- font used

FRONTEND:
- customer address behavior

TESTS:
- Kannada: PASS/FAIL
- Malayalam: PASS/FAIL
- Hindi: PASS/FAIL
- Tamil: PASS/FAIL
- Telugu: PASS/FAIL
- English: PASS/FAIL
- mixed address: PASS/FAIL
- PDF print: PASS/FAIL
- PDF download: PASS/FAIL

Do NOT claim PASS unless an actual generated PDF has been tested.