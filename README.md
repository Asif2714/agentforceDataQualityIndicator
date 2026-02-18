# Dynamic Data Quality Indicator

Metadata-driven scoring for any object. Admins define field rules; triggers stamp a weighted completeness score and timestamp on save.

## Deploy
- Connect org:
  ```bash
  sf org login web --alias <org-alias> --instance-url <org-url> --set-default
  ```
- Deploy metadata:
  ```bash
  sf project deploy start --source-dir force-app --target-org <org-alias>
  ```

## Configure Scoring
- Ensure each scored object has:
  - `Data_Quality_Score__c` (Number(16,2))
  - `Data_Quality_Score_Timestamp__c` (Date/Time)
- Assign `Data_Quality_Admin` permission set.
- Create one `Data_Quality_Config__c` per object.
- Add child `Data_Quality_Field_Config__c` rows (field API, weight 1–5, required flag). One config per object.

## Enable UI
- Add `dataQualityIndicator` LWC to the object record page (Lightning App Builder).
- (Optional) Show `Data_Quality_Score__c` and `Data_Quality_Score_Timestamp__c` on the layout.

## Backfill Existing Records
- Run via Execute Anonymous:
  ```bash
  sf apex run --file update_scores.apex --target-org <org-alias>
  ```

## Optional Reporting Assets
- If wanted, also deploy: `force-app/main/default/reports`, `force-app/main/default/dashboards`, `force-app/main/default/reportTypes`.

## Notes
- Triggers call `DataQualityScoreService.evaluate`, which scores any object with the fields above.
- Scoring uses `Data_Quality_Config__c` + `Data_Quality_Field_Config__c`; missing/blank configured fields lower the score; if no rules, score defaults to 100.

## Key Project Files
- Apex services: `force-app/main/default/classes/DataQualityScoreService.cls`
- Triggers: `force-app/main/default/triggers/AccountTrigger.trigger`, `force-app/main/default/triggers/OpportunityTrigger.trigger` (pattern to copy for other objects)
- LWCs: `force-app/main/default/lwc/dataQualityIndicator/*`, `force-app/main/default/lwc/dataQualityConfigEditor/*`
- Custom objects/config: `force-app/main/default/objects/Data_Quality_Config__c/*`, `force-app/main/default/objects/Data_Quality_Field_Config__c/*`
- Object fields: `force-app/main/default/objects/*/fields/Data_Quality_Score__c.field-meta.xml`, `Data_Quality_Score_Timestamp__c.field-meta.xml`
- Backfill script: `update_scores.apex`
- Optional analytics: `force-app/main/default/reports/*`, `force-app/main/default/dashboards/*`, `force-app/main/default/reportTypes/*`
