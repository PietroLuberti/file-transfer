# Function Point Evaluation Guide
## FFPA V3 + Tailoring Open Fiber v4.0

**Issue Reference:** #5  
**Date:** February 5, 2026  
**Method:** CHANGESET_END  
**File:** `odata/FIORI_ACCET_RIS-CHANGESET_END.abap`

---

## Table of Contents
1. [Overview](#overview)
2. [Evaluation Methodology](#evaluation-methodology)
3. [Step-by-Step Evaluation Process](#step-by-step-evaluation-process)
4. [Data Functions Analysis](#data-functions-analysis)
5. [Transactional Functions Analysis](#transactional-functions-analysis)
6. [Complexity Assessment](#complexity-assessment)
7. [Recording Results Template](#recording-results-template)
8. [References](#references)

---

## Overview

This guide provides instructions for performing a Function Point (FP) evaluation of the delta changes in the CHANGESET_END method using:
- **FFPA V3** (Finnish Function Point Analysis Version 3)
- **Tailoring Open Fiber v4.0** standards

### Scope of Evaluation

**Commit Range:**
- Start Commit: `aa92ee020bdd89ded4e4b18e7cbad2274214023b`
- End Commit: `d527b915d984e7893c34fc566d4db5ea04a617e1`

**Key Changes:**
1. Replacement of WS_DELIVERY_UPDATE_2 with BAPI_GOODSMVT_CREATE (Lines 410-593)
2. Removal of Email Notification Code
3. Addition of ZMM_CONS_PARZ Table Processing (Lines 690-715)
4. Removal of Goods Movement Creation for Rejected Records

**Statistics:**
- Lines removed: 404
- Lines added: 252
- Net reduction: 152 lines
- Total method lines: 1,475

---

## Evaluation Methodology

### FFPA V3 Framework

FFPA V3 (Finnish Function Point Analysis) is based on IFPUG standards but includes specific adaptations for Nordic software development practices.

**Key Principles:**
1. Focus on functionality from user's perspective
2. Measure logical transactions and data structures
3. Consider complexity factors specific to the business domain
4. Apply industry-specific tailoring (Open Fiber v4.0)

### Tailoring Open Fiber v4.0

Open Fiber v4.0 provides telecommunications and fiber optic industry adaptations:
- Enhanced weighting for integration complexity
- Specialized handling of data synchronization functions
- Emphasis on real-time processing capabilities
- Industry-specific quality factors

---

## Step-by-Step Evaluation Process

### Phase 1: Identify Changed Components

Review the detailed changes document (`MODIFICHE_CHANGESET_END.md`) and identify:

1. **Added Functions**
   - [ ] New ZMM_CONS_PARZ table processing
   - [ ] New BAPI_GOODSMVT_CREATE implementation for accepted items
   - [ ] New data grouping logic with COLLECT

2. **Modified Functions**
   - [ ] Data retrieval from ZFIORI_RIS_TMP (changed filtering logic)
   - [ ] LIPS table interaction (new order data retrieval)
   - [ ] Serial number handling (enhanced logic)

3. **Removed Functions**
   - [ ] Email notification system
   - [ ] WS_DELIVERY_UPDATE_2 calls
   - [ ] Goods movement creation for rejected items (types 344, 322)

### Phase 2: Map to Function Point Components

For each identified component, determine:
- **Type**: Data Function (ILF/EIF) or Transactional Function (EI/EO/EQ)
- **Complexity**: Low, Average, or High
- **FP Value**: Based on FFPA V3 tables

### Phase 3: Apply Complexity Weighting

Use Tailoring Open Fiber v4.0 adjustments for:
- Integration point modifications
- Data transformation complexity
- Real-time processing requirements
- Error handling sophistication

### Phase 4: Calculate Total Function Points

Sum all individual function points and apply adjustment factors.

---

## Data Functions Analysis

### Internal Logical Files (ILF)

**Definition**: User-identifiable groups of logically related data maintained within the application boundary.

#### ILF-1: ZMM_CONS_PARZ Table (NEW)

**Description**: New custom table for storing partially accepted/rejected records

**Data Element Types (DETs)**: 10
- VBELN (delivery number)
- POSNR (item position)
- MATNR (material)
- MOTIVO_COD (reason code)
- MOTIVO (reason description)
- FLAG (management type)
- LFDAT (delivery date)
- ERDAT (creation date)
- ERZET (creation time)
- ERNAM (creation user)

**Record Element Types (RETs)**: 1

**Complexity Determination**:
- RETs: 1 (Low threshold < 2)
- DETs: 10 (Average threshold 2-19)
- **Result**: Low Complexity

**FFPA V3 Weight**: 7 FP (Low ILF)

**Change Type**: ADD (+7 FP)

---

#### ILF-2: ZFIORI_RIS_TMP Table (MODIFIED)

**Description**: Temporary table for delivery acceptance data - modified read logic

**Change Analysis**:
- Previous: Generic read with simple filtering
- Current: Enhanced filtering with motivo = blank AND qta_acc <> 0

**Data Element Types (DETs)**: No change in structure (existing fields used)
**Record Element Types (RETs)**: No change

**Complexity**: Maintained (No structural change)

**Change Type**: Logic modification only - count as EI enhancement (see Transactional Functions)

---

### External Interface Files (EIF)

**Definition**: User-identifiable groups of logically related data referenced by but maintained outside the application.

#### EIF-1: LIPS Table (ENHANCED USAGE)

**Description**: Standard SAP delivery item table - new fields retrieved

**New Data Elements Retrieved**: 3
- EBELN (purchasing document number)
- EBELP (purchasing document item)
- Additional relationship data

**Previous Usage**: Basic delivery data
**Current Usage**: Enhanced with purchasing order linkage

**Complexity**: Low (< 5 new DETs used)

**FFPA V3 Weight**: 5 FP (Low EIF)

**Change Type**: CHANGE (+2 FP delta for enhanced usage)

---

## Transactional Functions Analysis

### External Inputs (EI)

**Definition**: Elementary processes that process data from outside the application boundary to maintain ILFs.

#### EI-1: ZMM_CONS_PARZ Data Creation (NEW)

**Description**: Process to insert rejected item records into ZMM_CONS_PARZ table

**File Types Referenced (FTRs)**: 2
- ZFIORI_RIS_TMP (read)
- ZMM_CONS_PARZ (write)

**Data Element Types (DETs)**: 10
- All fields from ZMM_CONS_PARZ structure
- Includes transformation logic (VBELN, POSNR, MATNR, MOTIVO_COD, etc.)

**Processing Logic**:
- Read with WHERE motivo NE space
- Data mapping and transformation
- Insert with MODIFY statement
- COMMIT WORK

**Complexity Determination**:
- FTRs: 2 (Average threshold)
- DETs: 10 (Average range 5-15)
- Processing logic: Simple loop with direct mapping
- **Result**: Average Complexity

**FFPA V3 Weight**: 4 FP (Average EI)

**Change Type**: ADD (+4 FP)

---

#### EI-2: Goods Movement Creation via BAPI_GOODSMVT_CREATE (MODIFIED)

**Description**: Replaced WS_DELIVERY_UPDATE_2 with direct BAPI call for accepted items

**File Types Referenced (FTRs)**: 4
- ZFIORI_RIS_TMP (read)
- LIPS (read for PO data)
- SAP Material Documents (via BAPI - write)
- Serial Number tables (conditional write)

**Data Element Types (DETs)**: 15+
- Material (MATNR)
- Batch (CHARG)
- Quantity (QTA_ACC)
- Movement type (101)
- Plant (WERKS)
- Storage location (LGORT)
- Unit of measure (ERFME)
- Purchase order number (EBELN)
- Purchase order item (EBELP)
- Delivery number (VBELN)
- Delivery item (POSNR)
- Serial numbers (conditional)
- Document number output (MATDOC)
- Document year (MATDOCYEAR)
- Return messages (BAPIRET2)

**Processing Logic**:
- Read and filter data (motivo = blank, qta_acc <> 0)
- Join with LIPS table for PO information
- Group data using COLLECT (aggregate quantities)
- Build BAPI structures for items
- Handle serial numbers for flag 'Q' and 'S'
- Call BAPI_GOODSMVT_CREATE
- Process return messages
- Error logging to ZMM_LOG_BAPI
- Transaction management (COMMIT/ROLLBACK)

**Complexity Determination**:
- FTRs: 4 (High threshold > 3)
- DETs: 15+ (High range > 15)
- Processing logic: Complex - includes grouping, conditional serial number handling, BAPI integration, error handling
- **Result**: High Complexity

**FFPA V3 Weight**: 6 FP (High EI)

**Change Analysis**:
- Previous (WS_DELIVERY_UPDATE_2): Standard function call, Average complexity ~4 FP
- Current (BAPI_GOODSMVT_CREATE): Enhanced logic with grouping, High complexity 6 FP
- **Change Type**: CHANGE (+2 FP delta)

---

#### EI-3: Email Notification Process (REMOVED)

**Description**: Complete email sending functionality removed

**Previous Complexity Assessment**:
- FTRs: 3 (ZFIORI_GRUPPI, ZFIORI_MAIL, SO_DOCUMENT tables)
- DETs: 8+ (recipients, subject, body, attachments, etc.)
- Processing: Average complexity
- **Previous Value**: 4 FP (Average EI)

**Change Type**: DELETE (-4 FP)

---

#### EI-4: Rejected Items Goods Movement (REMOVED)

**Description**: BAPI_GOODSMVT_CREATE calls for movement types 344 and 322 removed

**Previous Complexity Assessment**:
- Movement type 344 (blocked material): 3 FP (Low EI)
- Movement type 322 (acceptance with reserve): 3 FP (Low EI)
- **Previous Value**: 6 FP total (2 x Low EI)

**Change Type**: DELETE (-6 FP)

---

### External Outputs (EO)

**Definition**: Elementary processes that send data outside the application boundary with processing logic beyond direct retrieval.

#### EO-1: Error Logging to ZMM_LOG_BAPI (ENHANCED)

**Description**: Enhanced error and success logging for BAPI operations

**File Types Referenced (FTRs)**: 2
- BAPI return structures (read)
- ZMM_LOG_BAPI (write)

**Data Element Types (DETs)**: 6+
- Timestamp
- User ID
- BAPI name
- Return messages
- Document numbers
- Status codes

**Processing Logic**:
- Format BAPI return messages
- Aggregate error information
- Write to log table

**Complexity**: Low (Simple logging)

**FFPA V3 Weight**: 4 FP (Low EO)

**Change Type**: ENHANCE (+1 FP delta for additional BAPI logging)

---

### External Inquiries (EQ)

**Definition**: Elementary processes that retrieve data without altering ILFs, combining input and output.

#### EQ-1: Purchase Order Data Retrieval from LIPS (NEW)

**Description**: New query to retrieve PO information for accepted items

**File Types Referenced (FTRs)**: 2
- ZFIORI_RIS_TMP (input keys)
- LIPS (query)

**Data Element Types (DETs)**: 5
- VBELN (input)
- POSNR (input)
- EBELN (output)
- EBELP (output)
- Join logic

**Processing Logic**: Simple SELECT query with WHERE clause

**Complexity**: Low (Simple retrieval)

**FFPA V3 Weight**: 3 FP (Low EQ)

**Change Type**: ADD (+3 FP)

---

## Complexity Assessment

### FFPA V3 Complexity Matrix

**Data Functions (ILF/EIF)**

| DETs →<br>RETs ↓ | 1-19 | 20-50 | 51+ |
|------------------|------|-------|-----|
| 1                | Low  | Low   | Avg |
| 2-5              | Low  | Avg   | High|
| 6+               | Avg  | High  | High|

**Transactional Functions (EI/EO/EQ)**

| DETs →<br>FTRs ↓ | 1-4  | 5-15  | 16+ |
|------------------|------|-------|-----|
| 0-1              | Low  | Low   | Avg |
| 2-3              | Low  | Avg   | High|
| 4+               | Avg  | High  | High|

### Tailoring Open Fiber v4.0 Adjustments

#### Integration Complexity Factor

**Criteria**: Changes involve external system integration (SAP standard BAPIs)

**Multiplier**: 1.1x for functions with BAPI integration

**Affected Functions**:
- EI-2: Goods Movement Creation via BAPI_GOODSMVT_CREATE
  - Base: 6 FP → Adjusted: 6.6 FP (round to 7 FP)

#### Data Synchronization Factor

**Criteria**: New data persistence mechanism for partial deliveries

**Multiplier**: 1.05x for new data storage patterns

**Affected Functions**:
- ILF-1: ZMM_CONS_PARZ Table
  - Base: 7 FP → Adjusted: 7.35 FP (round to 7 FP)
- EI-1: ZMM_CONS_PARZ Data Creation
  - Base: 4 FP → Adjusted: 4.2 FP (round to 4 FP)

#### Error Handling Enhancement Factor

**Criteria**: Comprehensive error handling with logging

**Multiplier**: 1.05x for enhanced error handling

**Affected Functions**:
- EI-2: Goods Movement Creation
  - Already adjusted above (included in BAPI integration factor)

---

## Recording Results Template

### Summary Table

Copy this table to Issue #5 comments to record your evaluation results:

```markdown
## Function Point Evaluation Results

**Evaluation Date:** [Insert Date]  
**Evaluator:** [Your Name]  
**Methodology:** FFPA V3 + Tailoring Open Fiber v4.0

### Data Functions

| ID | Component | Type | Complexity | Base FP | Adjustment | Final FP | Change |
|----|-----------|------|------------|---------|------------|----------|--------|
| ILF-1 | ZMM_CONS_PARZ | ILF | Low | 7 | 1.05x | 7 | ADD |
| ILF-2 | ZFIORI_RIS_TMP | ILF | - | 0 | - | 0 | MODIFY* |
| EIF-1 | LIPS Table | EIF | Low | 5 | - | 5 | CHANGE |
| **Subtotal** | | | | **12** | | **12** | **+12** |

*MODIFY without structural change - counted in transactional functions

### Transactional Functions

| ID | Component | Type | Complexity | Base FP | Adjustment | Final FP | Change |
|----|-----------|------|------------|---------|------------|----------|--------|
| EI-1 | ZMM_CONS_PARZ Creation | EI | Average | 4 | 1.05x | 4 | ADD |
| EI-2 | BAPI_GOODSMVT_CREATE | EI | High | 6 | 1.1x | 7 | CHANGE |
| EI-3 | Email Notification | EI | Average | -4 | - | -4 | DELETE |
| EI-4 | Rejected Items Movement | EI | Low | -6 | - | -6 | DELETE |
| EO-1 | Error Logging | EO | Low | 4 | - | 4 | ENHANCE |
| EQ-1 | PO Data Retrieval | EQ | Low | 3 | - | 3 | ADD |
| **Subtotal** | | | | **7** | | **8** | **+8** |

### Total Calculation

| Category | Function Points | Delta |
|----------|----------------|-------|
| Data Functions | 12 | +12 |
| Transactional Functions | 8 | +8 |
| **TOTAL UNADJUSTED FP** | **20** | **+20** |

### Value Adjustment Factor (VAF)

Apply FFPA V3 General System Characteristics (0-5 scale, 14 factors):

| Factor | Description | Rating | Justification |
|--------|-------------|--------|---------------|
| 1. Data communications | | [0-5] | [Your assessment] |
| 2. Distributed functions | | [0-5] | [Your assessment] |
| 3. Performance | | [0-5] | [Your assessment] |
| 4. Heavily used configuration | | [0-5] | [Your assessment] |
| 5. Transaction rate | | [0-5] | [Your assessment] |
| 6. Online data entry | | [0-5] | [Your assessment] |
| 7. End-user efficiency | | [0-5] | [Your assessment] |
| 8. Online update | | [0-5] | [Your assessment] |
| 9. Complex processing | | [0-5] | [Your assessment] |
| 10. Reusability | | [0-5] | [Your assessment] |
| 11. Installation ease | | [0-5] | [Your assessment] |
| 12. Operational ease | | [0-5] | [Your assessment] |
| 13. Multiple sites | | [0-5] | [Your assessment] |
| 14. Facilitate change | | [0-5] | [Your assessment] |
| **Total Degree of Influence (TDI)** | | **[Sum]** | |

**VAF Formula:** 0.65 + (0.01 × TDI)

**Calculated VAF:** [0.65 + (0.01 × TDI)]

### Final Adjusted Function Points

**Formula:** Adjusted FP = Unadjusted FP × VAF

**Calculation:** [20] × [VAF] = **[Final FP]**

### Net Delta Analysis

| Metric | Value |
|--------|-------|
| Functions Added | [Count and FP] |
| Functions Modified | [Count and FP delta] |
| Functions Deleted | [Count and FP] |
| **Net Change** | **[Total Delta FP]** |

```

---

## Impact Analysis

### Maintainability Impact

Record your assessment of how the changes affect code maintainability:

**Improvements:**
- [ ] Reduced code complexity (152 lines removed)
- [ ] Simplified logic flow (removed email notification)
- [ ] Enhanced data persistence (ZMM_CONS_PARZ)
- [ ] Better error handling and logging

**Considerations:**
- [ ] New BAPI integration requires maintenance knowledge
- [ ] Additional table to monitor (ZMM_CONS_PARZ)

**Overall Maintainability Score:** [1-5, where 5 is most maintainable]

**Justification:** [Explain your rating]

---

### Performance Impact

Record your assessment of performance changes:

**Improvements:**
- [ ] Eliminated external email processing overhead
- [ ] Removed unnecessary goods movements for rejected items
- [ ] Data grouping with COLLECT reduces BAPI calls

**Considerations:**
- [ ] Additional table write operation (ZMM_CONS_PARZ)
- [ ] JOIN with LIPS table for PO data retrieval

**Overall Performance Score:** [1-5, where 5 is best performance]

**Justification:** [Explain your rating]

---

### Code Quality Impact

Assess code quality using Clean ABAP principles:

**Improvements:**
- [ ] ABAP Doc comments added
- [ ] Consistent naming conventions
- [ ] Structured error handling
- [ ] Clear separation of concerns

**Code Quality Score:** [1-5, where 5 is highest quality]

**Justification:** [Explain your rating]

---

## References

### FFPA V3 Documentation
- Finnish Software Measurement Association (FiSMA)
- FFPA V3 Counting Practices Manual
- https://www.fisma.fi/

### Tailoring Open Fiber v4.0
- Open Fiber Telecommunications Standards
- Version 4.0 Function Point Tailoring Guide
- Industry-specific complexity adjustments

### IFPUG Resources
- IFPUG Counting Practices Manual (CPM)
- Function Point counting for enhancement projects
- https://www.ifpug.org/

### Repository Documentation
- `MODIFICHE_CHANGESET_END.md` - Detailed change documentation
- Issue #5 - Original evaluation request
- Commit `aa92ee020bdd89ded4e4b18e7cbad2274214023b` - Base commit
- Commit `d527b915d984e7893c34fc566d4db5ea04a617e1` - End commit

---

## Notes for Evaluator

### Important Considerations

1. **Delta Evaluation**: This is an enhancement project evaluation. Focus on what changed, not the entire system.

2. **Complexity Reassessment**: Always validate complexity determinations against your organization's standards.

3. **Tailoring Adjustments**: Apply Open Fiber v4.0 multipliers consistently across similar functions.

4. **Documentation**: Record all assumptions and decisions for future reference.

5. **Validation**: Consider peer review of the evaluation for critical projects.

### Common Pitfalls to Avoid

- ❌ Don't count the same data element in both data and transactional functions
- ❌ Don't apply adjustment factors multiple times
- ❌ Don't count deleted functions as negative unless doing net delta analysis
- ❌ Don't forget to document complexity determination rationale
- ❌ Don't skip the VAF calculation (it can significantly impact results)

### Next Steps After Evaluation

1. **Record Results**: Post completed evaluation tables in Issue #5 comments
2. **Documentation**: Update project metrics dashboard
3. **Lessons Learned**: Document any unusual cases or decisions
4. **Archive**: Save evaluation worksheet for future reference
5. **Communicate**: Share results with stakeholders

---

**Document Version:** 1.0  
**Last Updated:** February 5, 2026  
**Status:** Ready for use
