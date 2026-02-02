/**
 * @description Lightweight service that returns active Data_Quality_Rule__c records for an object.
 * @notes
 * - No business logic: just retrieval and shaping DTOs for LWC
 * - Enforces sharing and runs SOQL in USER_MODE to honor FLS/sharing
 * - Cacheable for LDS-like usage
 */
public with sharing class DataQualityService {
    public class RuleDTO {
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Decimal weight;
    }

    /**
     * @description Fetch active rules for a given object API name.
     * @param objectApiName The sObject API name (e.g., Account, Opportunity)
     * @return List of RuleDTO with field API name, required flag, and optional weight
     */
    @AuraEnabled(cacheable=true)
    public static List<RuleDTO> getRulesForObject(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return new List<RuleDTO>();
        }

        String normalized = objectApiName.trim();

        // SOQL in USER_MODE to respect field/object access.
        List<Data_Quality_Rule__c> rules = [
            SELECT Id, Field_API_Name__c, Is_Required__c, Weight__c, Active__c
            FROM Data_Quality_Rule__c
            WHERE Active__c = true
              AND Object_API_Name__c = :normalized
            WITH USER_MODE
            ORDER BY CreatedDate ASC
        ];

        List<RuleDTO> results = new List<RuleDTO>();
        for (Data_Quality_Rule__c r : rules) {
            RuleDTO dto = new RuleDTO();
            dto.fieldApiName = r.Field_API_Name__c;
            dto.isRequired = (r.Is_Required__c == true);
            dto.weight = r.Weight__c;
            results.add(dto);
        }
        return results;
    }
}
