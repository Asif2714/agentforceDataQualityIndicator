# Dynamic Data Quality Indicator

Simple Salesforce setup for scoring Account and Opportunity data quality.

The solution lets admins define field-level data quality rules and then automatically stamps a score and timestamp when records are saved.

## What To Deploy (New Org)

Deploy these folders:

1. `force-app/main/default/objects`
2. `force-app/main/default/classes`
3. `force-app/main/default/triggers`
4. `force-app/main/default/lwc`
5. `force-app/main/default/flexipages`
6. `force-app/main/default/layouts`
7. `force-app/main/default/tabs`
8. `force-app/main/default/permissionsets`
9. `force-app/main/default/matchingRules`
10. `force-app/main/default/duplicateRules`

Optional (if you also want reporting/dashboard assets):

1. `force-app/main/default/reports`
2. `force-app/main/default/dashboards`
3. `force-app/main/default/reportTypes`

## Setup Steps In Salesforce

1. Assign the `Data_Quality_Admin` permission set to admins.
2. Create a `Data_Quality_Config__c` record for each object you want to score (for example, Account and Opportunity).
3. Keep it to **one config record per object**.  
   There is matching + duplicate logic to prevent duplicates.
4. In each config record, use the Data Quality Config Editor to add field rules:
   - choose the field
   - set weight (importance)
   - mark required/recommended
5. Add the `dataQualityIndicator` LWC to the object record page in Lightning App Builder.
6. (Optional but recommended) Add these fields to the page layout/page:
   - `Data_Quality_Score__c`
   - `Data_Quality_Score_Timestamp__c`

At this point, new and updated records will be scored automatically.

## Existing Records (Backfill Scores)

If older records have no score/timestamp yet, run `update_scores.apex` in Execute Anonymous.

That script updates Account and Opportunity records so triggers recalculate and stamp scores.

## Notes

- Account and Opportunity scoring fields are already included in this repo.
- Scoring is metadata-driven through `Data_Quality_Config__c` and `Data_Quality_Field_Config__c`.
