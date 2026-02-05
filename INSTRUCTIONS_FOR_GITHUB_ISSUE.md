# Instructions for Creating GitHub Issue

## Overview
The file `ISSUE_FUNCTION_POINT_EVALUATION.md` contains the complete content for a GitHub issue that needs to be created in the PietroLuberti/file-transfer repository.

## Steps to Create the Issue

Since automated issue creation is not available, please follow these manual steps:

### 1. Navigate to GitHub
Go to: https://github.com/PietroLuberti/file-transfer/issues

### 2. Create New Issue
Click on the "New Issue" button

### 3. Copy the Title
From `ISSUE_FUNCTION_POINT_EVALUATION.md`, copy the text under the "## Title" section:
```
Function Point evaluation (FFPA V3 + Tailoring Open Fiber v4.0) for delta changes in CHANGESET_END method
```

### 4. Copy the Description
From `ISSUE_FUNCTION_POINT_EVALUATION.md`, copy everything under the "## Description" section (all the content after line 6)

### 5. Add Labels (if available)
Add the following labels to the issue:
- `function-point-analysis`
- `technical-debt`
- `metrics`
- `evaluation`

### 6. Set Priority
Set the priority to: **Medium**

### 7. Submit the Issue
Click "Submit new issue"

## Issue Summary

**Purpose:** Request a Function Point (FP) evaluation using FFPA V3 methodology with Tailoring Open Fiber v4.0 standards

**Scope:** Delta changes between commits `aa92ee020bdd89ded4e4b18e7cbad2274214023b` and `d527b915d984e7893c34fc566d4db5ea04a617e1`

**Target Method:** `/iwbep/if_mgw_appl_srv_runtime~changeset_end` in file `odata/FIORI_ACCET_RIS-CHANGESET_END.abap`

**Key Changes to Evaluate:**
1. Replacement of WS_DELIVERY_UPDATE_2 with BAPI_GOODSMVT_CREATE
2. Removal of email notification code
3. Addition of ZMM_CONS_PARZ table processing
4. Removal of goods movement creation for rejected records

## Note
This is an evaluation request only - no code changes are required as part of this issue.
