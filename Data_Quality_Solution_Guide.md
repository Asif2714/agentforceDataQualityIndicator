# Data Quality Accelerator - Technical Implementation Guide

This document provides a comprehensive overview of the Data Quality Accelerator solution, including its components, logic, and configuration.

## 1. Solution Components

### Custom Objects & Fields
- **`Data_Quality_Config__c`**: The header record for an object's quality rules.
  - `Object_API_Name__c`: The API Name of the target SObject (e.g., "Account").
  - `Object_Label__c`: Friendly label for display.
  - `Name`: Auto-Number (Config ID) for internal reference.
- **`Data_Quality_Field_Config__c`**: Individual field rules.
  - `Field_API_Name__c`: API Name of the field to check.
  - `Field_Label__c`: Custom label for UI display.
  - `Weight__c`: Picklist (1-5) representing the field's importance.
  - `Is_Required__c`: Boolean flag for mandatory fields.
- **Standard Object Extensions**:
  - `Account.Data_Quality_Score__c`, `Account.Data_Quality_Score_Timestamp__c`
  - `Opportunity.Data_Quality_Score__c`, `Opportunity.Data_Quality_Score_Timestamp__c`

### User Interface (LWC)
- **`dataQualityIndicator`**: Embedded on record pages. Shows current score and a list of missing fields.
- **`dataQualityConfigEditor`**: Administrative tool on the `Data_Quality_Config__c` page to manage field rules dynamically.

### Apex Services & Automation
- **`DataQualityService.cls`**: Centralized service for UI-Apex communication.
  - `getRulesForObject`: Fetches active rules for the indicator.
  - `saveConfiguration`: Handles JSON-based rule saving from the editor.
- **`AccountDataQualityScoreHandler.cls`** / **`OpportunityDataQualityScoreHandler.cls`**: Logic specialized for each object to calculate scores during record saves.
- **Triggers**: Managed automation on `Account`, `Opportunity`, and `Data_Quality_Config__c`.

### Security & Compliance
- **Permission Set: `Data_Quality_Admin`**: Grants access to all custom objects, fields, and Apex classes.
- **Duplicate Rule**: Prevents multiple configurations for the same object.

---

## 2. System Logic & Communication

### LWC <-> Apex Interaction
The solution uses **LDS-aware LWCs** and **AuraEnabled Apex** methods:
1.  **Retrieval**: LWCs call `getRulesForObject` (indicator) or `getFieldConfigs` (editor). The Apex service queries the `Data_Quality_Config__c` hierarchy and returns a shaped DTO (Data Transfer Object) to JavaScript.
2.  **Persistence**: The Editor LWC sends a JSON string of rules to `saveConfiguration`. The Apex service parses this JSON, performs a "Delete and Replace" on child field configs to handle reordering efficiently, and commits the changes within a single transaction.

### Score Calculation Logic
The "Weighted Completeness" model ensures that important fields impact the score more heavily.
- **Potential Weight**: The mathematical sum of weights of **all** configured fields for the object.
- **Achieved Weight**: The sum of weights of configured fields that are actually **populated** on the record.
- **Formula**: `(Achieved / Potential) * 100`

> [!TIP]
> **Example**:
> - Field A (Weight 5), Field B (Weight 1).
> - Total Potential = 6.
> - If only Field A is populated, Score = `(5 / 6) * 100` = **83%**.

---

## 3. Reporting & Dashboards
The solution includes a unified **Data Quality Overview** dashboard:
- **Bar Charts**: Show "Average Score by User" per object.
- **Gauges**: Provide an "Overall Quality Index" for your pipeline.
- **Tables**: List the lowest scoring records for targeted cleanup.
- **Configuration**: Reports are minimalist summaries (1 grouping + 1 summary field), and the dashboard uses **Auto-Select** for maximum robustness.

## 4. Implementation Steps
1.  Deploy all metadata using the Salesforce CLI.
2.  Assign the `Data_Quality_Admin` permission set to administrators.
3.  Navigate to the **Data Quality Configs** tab and create a record for "Account" and "Opportunity".
4.  Use the **Data Quality Editor** on those records to define your rules.
5.  Add the **Data Quality Indicator** LWC to your Account and Opportunity Lightning Pages.
