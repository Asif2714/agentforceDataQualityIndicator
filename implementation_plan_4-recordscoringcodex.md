# Implementation Plan

## Overview
This implementation will add new fields to the Opportunity object to store the data quality score and calculation timestamp. The score will be automatically populated on Opportunity create/update (save) so it is available for reporting and historical tracking. The solution is Opportunity-only for MVP and is designed to minimize changes to existing functionality while maintaining backward compatibility.

## Types
The implementation will introduce:
1. Two new custom fields on the Opportunity object:
   - `Data_Quality_Score__c`: Number(18,2) field to store the percentage score (0-100)
   - `Data_Quality_Score_Timestamp__c`: DateTime field to store when the score was calculated

## Files
New files to be created:
- `force-app/main/default/objects/Opportunity/fields/Data_Quality_Score__c.field-meta.xml`
- `force-app/main/default/objects/Opportunity/fields/Data_Quality_Score_Timestamp__c.field-meta.xml`

Modified files:
- `force-app/main/default/triggers/OpportunityTrigger.trigger` - Created to calculate and save scores on create/update

## Functions
New functions:
- `OpportunityDataQualityScoreHandler.applyScores(List<Opportunity> records)` - Calculates and writes score/timestamp on save

Modified functions:
- `DataQualityService.getRulesForObject()` - No changes needed
- `DataQualityService` constructor - No changes needed

## Classes
New class:
- `OpportunityDataQualityScoreHandler` - Utility class to manage score calculation and saving

Modified classes:
- None

## Dependencies
No new dependencies required. The implementation will use existing Apex classes and LWC components.

## Testing
- Unit tests for the new `saveOpportunityScore` method in DataQualityService
- Trigger tests for OpportunityTrigger
- Integration tests to verify the complete workflow from record creation to score storage

## Implementation Order
1. Create new custom fields on Opportunity object
2. Create OpportunityTrigger to handle record creation/update
3. Create OpportunityDataQualityScoreHandler class
4. Update unit tests
5. Verify functionality works as expected
