# ZS08 – Custom IDoc: Disposizione di Pagamento (Payment Disposition)
## SAP ECC 6 Implementation Guide

This directory contains the complete ABAP implementation for the ZS08 IDoc interface
between **Sistema Finanziario (SAP ECC 6)** and **ReGiS**, supporting the new *circuito
diretto* payment disposition flow.

---

## Architecture Overview

```
ReGiS ──► [Inbound IDoc ZS08_DP_DIRECTIN]
               │
               ▼
       ZFM_ZPRDISPSF_INBOUND          ← WE57 registered function module
               │
               ▼
       ZCL_ZS08_IDOC_PROCESSOR        ← Main OO processor class
         ├─ check_authority()
         ├─ read_idoc_data()           ← HANA-optimised SQL
         ├─ parse_idoc_segments()
         ├─ validate_header()
         ├─ create_payment_disposition()
         └─ trigger_outbound_idoc()
                    │
                    ▼
           ZCL_ZS08_IDOC_OUTBOUND     ← Outbound IDoc builder
                    │
                    ▼
       [Outbound IDoc ZS08_DP_DIRECTOUT / ZS08_DP_DIRECTOUT_T]
               │
               ▼
            ReGiS
```

---

## File Structure

```
idoc/
├── segments/
│   ├── ZPRDISPSF_T.abap        DD structure – Header segment (level 1)
│   ├── ZPRDISPSF_LINK.abap     DD structure – Link segment (level 1A)
│   ├── ZPRDISPSF_MSG.abap      DD structure – Message segment (BAPIRET2-like)
│   ├── ZPRDISPSF_D.abap        DD structure – Recipient segment (level 2)
│   ├── ZPRDISPSF_TRIB.abap     DD structure – Non-SICOGE tribute (level 3A)
│   ├── ZPRDISPSF_SIC.abap      DD structure – SICOGE invoice (level 3B)
│   └── ZPRDISPSF_SICTRIB.abap  DD structure – SICOGE tribute (level 4)
├── classes/
│   ├── ZCX_ZS08_IDOC_ERROR.abap    Custom exception class
│   ├── ZCL_ZS08_IDOC_PROCESSOR.abap Inbound processor (main class)
│   └── ZCL_ZS08_IDOC_OUTBOUND.abap  Outbound IDoc creator
├── function_modules/
│   └── ZFM_ZPRDISPSF_INBOUND.abap  WE57 entry point FM
└── tests/
    └── ZTEST_ZCL_ZS08_IDOC_PROCESSOR.abap  ABAP Unit tests
```

---

## Step-by-Step SAP Configuration

### 1. Create Data Dictionary Segment Structures (SE11)

For each segment, create a flat structure in SE11 with the fields listed below.
These structures are referenced by WE31.

#### ZPRDISPSF_T – Header (Testata) – Inbound fields
| Field        | Type | Length | Dec | Notes                    |
|-------------|------|--------|-----|--------------------------|
| ID_DP       | CHAR | 10     |     | Unique DP code (key)     |
| OGGETTO_PAG | CHAR | 50     |     | Payment object           |
| GRANT_NBR   | CHAR | 20     |     | Grant/financing number   |
| COD_CUP     | CHAR | 15     |     | Unique project code      |
| CLP         | CHAR | 80     |     | Local project code       |
| ZDESCRIZIONE| CHAR | 1000   |     | Description              |
| ZIMP_TOT    | CURR | 15     | 2   | Total amount             |

**Outbound-only additions (add to outbound-specific structure or use one structure for both):**
| Field       | Type | Length | Dec | Notes                            |
|------------|------|--------|-----|----------------------------------|
| ZDATA_ESITO| DATS | 8      |     | OPF outcome date (added by SF)   |
| ZNUMDP     | CHAR | 20     |     | DP number in SF (added by SF)    |
| ZSTATODP   | CHAR | 2      |     | Status: OK / KO (added by SF)    |

#### ZPRDISPSF_LINK – Link segment
| Field   | Type | Length | Notes                          |
|---------|------|--------|--------------------------------|
| LINK_SF | CHAR | 1000   | Link to SF DP (populated by SF)|

#### ZPRDISPSF_MSG – Message (reused for all levels)
| Field      | Type | Length |
|-----------|------|--------|
| TYPE      | CHAR | 1      |
| ID        | CHAR | 20     |
| NUMBER    | NUMC | 3      |
| MESSAGE   | CHAR | 220    |
| MESSAGE_V1| CHAR | 50     |
| MESSAGE_V2| CHAR | 50     |
| MESSAGE_V3| CHAR | 50     |
| MESSAGE_V4| CHAR | 50     |

#### ZPRDISPSF_D – Recipient/Destinatario – Inbound fields
| Field            | Type | Length | Dec |
|-----------------|------|--------|-----|
| TAXNUM          | CHAR | 16     |     |
| COD_BP_SF       | CHAR | 10     |     |
| IBAN            | CHAR | 34     |     |
| NUMERO_TES      | CHAR | 15     |     |
| CIG             | CHAR | 30     |     |
| NOTA_DEST       | CHAR | 1000   |     |
| IMPORTO         | CURR | 15     | 2   |
| CODICE_GESTIONALE| CHAR| 10     |     |
| ZFLAG           | CHAR | 1      |     |

**Outbound-only additions:**
| Field      | Type | Length | Dec |
|-----------|------|--------|-----|
| ZNUMOPF   | NUMC | 10     |     |
| ZSTATOOPF | CHAR | 3      |     |
| ZERRORE   | CHAR | 1000   |     |
| ZDATAOPF  | DATS | 8      |     |
| ZCROQUIET | NUMC | 30     |     |
| ZIMPAGOPF | CURR | 17     | 2   |

#### ZPRDISPSF_TRIB – Non-SICOGE tribute – Inbound
| Field            | Type | Length | Dec |
|-----------------|------|--------|-----|
| COD_TRIBUTO     | CHAR | 10     |     |
| CHIAVE_BANCA    | CHAR | 15     |     |
| CODICE_GESTIONALE| CHAR| 10     |     |
| TRIB_PAG        | CURR | 15     | 2   |

**Outbound-only additions:**
| Field          | Type | Length | Dec |
|---------------|------|--------|-----|
| ZNUMOPF       | NUMC | 10     |     |
| ZSTATOOPF     | CHAR | 3      |     |
| ZCROQUIET     | DATS | 8      |     |
| ZDATA_OPF     | NUMC | 30     |     |
| IMPORTO_PAG_OPF| CURR| 15     | 2   |

#### ZPRDISPSF_SIC – SICOGE Invoice – Inbound
| Field       | Type | Length | Dec |
|------------|------|--------|-----|
| ID_FATTURA | CHAR | 20     |     |
| DATA_PAG   | DATS | 8      |     |
| NUM_FATTURA| CHAR | 40     |     |
| IMPORTO    | CURR | 15     | 2   |

**Outbound-only addition:**
| Field    | Type | Length | Dec |
|---------|------|--------|-----|
| IMPIVAPAG| CURR| 15     | 2   |

#### ZPRDISPSF_SICTRIB – SICOGE Invoice Tribute
Same fields as ZPRDISPSF_TRIB.

---

### 2. Create Segment Types (WE31)

For each ZPRDISPSF_* structure, create a segment type in WE31:

1. Transaction **WE31**
2. Enter segment name (e.g. `ZPRDISPSF_T`), click Create
3. Enter description
4. In the field table, reference the SE11 structure created above
5. Activate the segment

---

### 3. Create IDoc Type (WE30)

1. Transaction **WE30**, enter `ZPRDISPSF`, click Create
2. Build the hierarchy:

```
ZPRDISPSF (IDoc type)
└── ZPRDISPSF_T          Level 1, mandatory (min=1, max=1)
    ├── ZPRDISPSF_LINK   Level 1A, optional (min=0, max=1)
    ├── ZPRDISPSF_MSG    Level 1B, optional (min=0, max=9999)
    └── ZPRDISPSF_D      Level 2, optional (min=0, max=9999)
        ├── ZPRDISPSF_MSG  Level 2A (min=0, max=9999)
        ├── ZPRDISPSF_TRIB Level 3A (min=0, max=9999)
        │   └── ZPRDISPSF_MSG Level 3A1 (min=0, max=9999)
        ├── ZPRDISPSF_SIC  Level 3B (min=0, max=9999)
        │   ├── ZPRDISPSF_MSG    Level 3B1 (min=0, max=9999)
        │   └── ZPRDISPSF_SICTRIB Level 4 (min=0, max=9999)
        │       └── ZPRDISPSF_MSG Level 4A (min=0, max=9999)
```

3. Activate the IDoc type.

---

### 4. Create Message Types (WE81)

Create the following message types:

| Message Type         | Description                                   |
|---------------------|-----------------------------------------------|
| ZS08_DP_DIRECTIN    | DP inbound from ReGiS                         |
| ZS08_DP_DIRECTOUT   | DP outbound to ReGiS (full, all segments)     |
| ZS08_DP_DIRECTOUT_T | DP outbound to ReGiS (header/testata only)    |

---

### 5. Assign Message Type to IDoc Type (WE82)

Link each message type to IDoc type `ZPRDISPSF`:

| Message Type         | IDoc Basic Type |
|---------------------|-----------------|
| ZS08_DP_DIRECTIN    | ZPRDISPSF       |
| ZS08_DP_DIRECTOUT   | ZPRDISPSF       |
| ZS08_DP_DIRECTOUT_T | ZPRDISPSF       |

---

### 6. Create ABAP Objects in SE24 / SE80

1. **ZCX_ZS08_IDOC_ERROR** – Exception class (inherits `CX_STATIC_CHECK`)
2. **ZCL_ZS08_IDOC_PROCESSOR** – Inbound processor
3. **ZCL_ZS08_IDOC_OUTBOUND** – Outbound builder
4. Copy ABAP source from files in `idoc/classes/`

---

### 7. Create Function Module (SE37)

Create `ZFM_ZPRDISPSF_INBOUND` in function group `ZS08_IDOC` (create new FG if needed).
Use the standard IDoc inbound interface (see `idoc/function_modules/ZFM_ZPRDISPSF_INBOUND.abap`).

---

### 8. Register Function Module in WE57

1. Transaction **WE57**
2. New entry:
   - Function module: `ZFM_ZPRDISPSF_INBOUND`
   - Direction: `1` (Inbound)
   - Message type: `ZS08_DP_DIRECTIN`
   - Basic type: `ZPRDISPSF`

---

### 9. Create Inbound Processing Code (WE42)

1. Transaction **WE42**, create process code `ZS08IN`
2. Processing type: `F` (function module)
3. Function module: `ZFM_ZPRDISPSF_INBOUND`

---

### 10. Create Authority Object (SU21)

Create a new authorization object `Z_ZS08_DP` with field `ACTVT`:

| Activity | Meaning                           |
|---------|-----------------------------------|
| 01      | Process inbound IDoc              |
| 02      | Send outbound IDoc                |
| 06      | Create payment disposition (post) |

Assign roles accordingly and execute SU24 to add the object to the FM/program.

---

### 11. Maintain Partner Profiles (WE20)

For the ReGiS partner:

**Inbound parameters:**
- Partner type: `LS` (logical system)
- Partner number: ReGiS logical system name
- Message type: `ZS08_DP_DIRECTIN`
- Process code: `ZS08IN`

**Outbound parameters:**
- Message type: `ZS08_DP_DIRECTOUT`
- Receiver port: as configured for ReGiS ALE connection
- Output mode: transfer IDoc immediately

---

### 12. Create Message Class ZS08 (SE91)

Create message class `ZS08` with the following messages used in the code:

| No. | Text                                                     |
|-----|----------------------------------------------------------|
| 001 | Unknown segment: &1                                      |
| 002 | IDoc status update failed: &1 status &2                  |
| 010 | No authorization to create payment disposition           |
| 011 | Recipient amount must be greater than zero (TAX: &1)     |
| 020 | Payment disposition created: &1                          |
| 099 | General error: &1                                        |

---

## Error Handling Logic

### Entire DP in error (validation failure)
- IDoc status set to `51` (application document not posted)
- Header `ZSTATODP` = `KO`
- Message segments populated with error details
- Outbound IDoc sent with `ZS08_DP_DIRECTOUT_T` (header only)

### Individual OPF in error (partial failure)
- Other OPFs processed normally
- Individual `ZSTATOOPF` = `KO` for failed OPFs
- Header `ZSTATODP` = `OK`
- Full outbound IDoc sent with `ZS08_DP_DIRECTOUT`

---

## ABAP Unit Tests

Run unit tests via:
- **SE80** → Class → Menu → Test → ABAP Unit
- **SAUNIT** transaction

All test classes are in `idoc/tests/`.

---

## Clean ABAP Compliance

| Principle              | How it is applied                                                        |
|-----------------------|--------------------------------------------------------------------------|
| Modern syntax         | Inline declarations `DATA(...)`, `VALUE(...)`, `NEW`, `COND`, `SWITCH`   |
| OO only               | All logic in classes; no FORM routines; no global variables              |
| Naming conventions    | `lo_` objects, `lt_` tables, `lv_` variables, `iv_/ev_/it_/et_` params  |
| HANA Code-to-Data     | SELECT only required columns; no SELECT *; precise WHERE clauses         |
| Authority checks      | `AUTHORITY-CHECK` on every public entry point                            |
| Exception handling    | `TRY...CATCH cx_root` in all critical paths; custom exception class      |
| Self-documenting code | ABAP Doc (`"!`) on all public methods; English identifiers               |
