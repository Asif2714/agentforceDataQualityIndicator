/**
 * @description Lightweight service that returns Data_Quality_Rule__c records for an object.
 * @notes
 * - No business logic: just retrieval and shaping DTOs for LWC
 * - Enforces sharing and runs SOQL in USER_MODE to honor FLS/sharing
 * - Cacheable for LDS-like usage
 * - Active__c is no longer used; all rules are considered active
 */
public with sharing class DataQualityService {
    /**
     * @description Simple DTO for LWC consumption.
     */

    public class RuleDTO {
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Decimal weight;
    }

    /**
     * @description DTO for saving configuration from LWC.
     */
    public class FieldConfigDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String apiName;
        @AuraEnabled public String fieldApiName; // Legacy/Cache support
        @AuraEnabled public String label;
        @AuraEnabled public String fieldLabel; // Legacy/Cache support
        @AuraEnabled public String weight;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Integer sortOrder;
    }

    /**
     * @description Fetch rules for a given object API name using the new Data_Quality_Config__c model.
     * @param objectApiName The sObject API name (e.g., Account, Opportunity)
     * @return List of RuleDTO
     */
    @AuraEnabled(cacheable=true)
    public static List<RuleDTO> getRulesForObject(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            return new List<RuleDTO>();
        }

        String normalized = objectApiName.trim();

        // 1. Try to find a Data_Quality_Config__c for this object
        List<Data_Quality_Config__c> configs = [
            SELECT Id 
            FROM Data_Quality_Config__c 
            WHERE Object_API_Name__c = :normalized 
            WITH USER_MODE 
            LIMIT 1
        ];

        if (configs.isEmpty()) {
            return new List<RuleDTO>();
        }

        // 2. Fetch children
        List<Data_Quality_Field_Config__c> children = [
            SELECT Field_API_Name__c, Field_Label__c, Is_Required__c, Weight__c
            FROM Data_Quality_Field_Config__c
            WHERE Data_Quality_Config__c = :configs[0].Id
            WITH USER_MODE
            ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC
        ];

        List<RuleDTO> results = new List<RuleDTO>();
        for (Data_Quality_Field_Config__c r : children) {
            RuleDTO dto = new RuleDTO();
            dto.fieldApiName = r.Field_API_Name__c;
            dto.label = r.Field_Label__c;
            dto.isRequired = (r.Is_Required__c == true);
            
            // Parse weight (Picklist: "1 - Low", "5 - Critical", etc.)
            dto.weight = parseWeight(r.Weight__c);
            results.add(dto);
        }
        return results;
    }
    
    /**
     * @description Get existing field configs for a Config record ID (used by Editor LWC)
     */
    @AuraEnabled(cacheable=true)
    public static List<FieldConfigDTO> getFieldConfigs(Id configId) {
        List<Data_Quality_Field_Config__c> children = [
            SELECT Id, Field_API_Name__c, Field_Label__c, Weight__c, Is_Required__c, Sort_Order__c
            FROM Data_Quality_Field_Config__c
            WHERE Data_Quality_Config__c = :configId
            WITH USER_MODE
            ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC
        ];
        
        List<FieldConfigDTO> dtos = new List<FieldConfigDTO>();
        for(Data_Quality_Field_Config__c c : children) {
            FieldConfigDTO dto = new FieldConfigDTO();
            dto.id = c.Id;
            dto.apiName = c.Field_API_Name__c;
            dto.fieldApiName = c.Field_API_Name__c; // Populate both
            dto.label = c.Field_Label__c;
            dto.fieldLabel = c.Field_Label__c; // Populate both
            dto.weight = c.Weight__c;
            dto.isRequired = c.Is_Required__c;
            dto.sortOrder = (Integer)c.Sort_Order__c;
            dtos.add(dto);
        }
        return dtos;
    }

    /**
     * @description Save the configuration (delete existing for this config, insert new)
     * NOTE: A full delete/replace is easiest for this list-editor UI to handle reordering/removals.
     * Use JSON string to avoid strict Aura deserialization issues.
     */
    @AuraEnabled
    public static void saveConfiguration(Id configId, String itemsJson) {
        if (configId == null) {
            AuraHandledException e = new AuraHandledException('Config ID is required.');
            e.setMessage('Config ID is required.');
            throw e;
        }
        
        if (String.isBlank(itemsJson)) {
            AuraHandledException e = new AuraHandledException('No data received. Please hard-refresh your browser (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows) and try again.');
            e.setMessage('No data received. Please hard-refresh your browser (Cmd+Shift+R on Mac, Ctrl+Shift+R on Windows) and try again.');
            throw e;
        }
        
        List<Object> rawItems;
        try {
            rawItems = (List<Object>)JSON.deserializeUntyped(itemsJson);
        } catch(Exception ex) {
            AuraHandledException e = new AuraHandledException('Invalid configuration data: ' + ex.getMessage());
            e.setMessage('Invalid configuration data: ' + ex.getMessage());
            throw e;
        }
        try {
            // 1. Delete existing children
            List<Data_Quality_Field_Config__c> existing = [
                SELECT Id 
                FROM Data_Quality_Field_Config__c 
                WHERE Data_Quality_Config__c = :configId
                WITH USER_MODE
            ];
            if (!existing.isEmpty()) {
                if (Data_Quality_Field_Config__c.SObjectType.getDescribe().isDeletable()) {
                    delete existing;
                } else {
                    throw new AuraHandledException('Insufficient permissions to delete configuration.');
                }
            }
            
            // 2. Insert new children
            List<Data_Quality_Field_Config__c> toInsert = new List<Data_Quality_Field_Config__c>();
            Integer sortOrder = 1;

            for(Object rawItem : rawItems) {
                Map<String, Object> item = (Map<String, Object>)rawItem;
                // Resolve ambiguous properties (Handle both old cache and new JS)
                String apiName = (String)(item.get('apiName') != null ? item.get('apiName') : item.get('fieldApiName'));
                String label = (String)(item.get('label') != null ? item.get('label') : item.get('fieldLabel'));
                String weight = (String)item.get('weight');
                Boolean isRequired = (item.get('isRequired') == true);
                
                if(String.isBlank(apiName)) {
                     AuraHandledException e = new AuraHandledException('Field API Name cannot be empty. Received: ' + JSON.serialize(item));
                     e.setMessage('Field API Name cannot be empty. Received: ' + JSON.serialize(item));
                     throw e;
                }
                
                Data_Quality_Field_Config__c rec = new Data_Quality_Field_Config__c();
                rec.Data_Quality_Config__c = configId;
                rec.Field_API_Name__c = apiName;
                rec.Field_Label__c = label;
                rec.Weight__c = weight;
                rec.Is_Required__c = isRequired;
                rec.Sort_Order__c = sortOrder++;
                toInsert.add(rec);
            }
            
            if(!toInsert.isEmpty()) {
                if (Data_Quality_Field_Config__c.SObjectType.getDescribe().isCreateable()) {
                    insert toInsert;
                } else {
                    AuraHandledException e = new AuraHandledException('Insufficient permissions to create configuration.');
                    e.setMessage('Insufficient permissions to create configuration.');
                    throw e;
                }
            }
        } catch (Exception e) {
            String msg = 'Error saving configuration: ' + e.getMessage();
            AuraHandledException ahe = new AuraHandledException(msg);
            ahe.setMessage(msg);
            throw ahe;
        }
    }

    private static Decimal parseWeight(String weightStr) {
        if (String.isBlank(weightStr)) return 1;
        // Handle "5 - Critical" -> 5
        if (weightStr.contains(' - ') || weightStr.contains(' – ')) { // dash or en-dash
             String[] parts = weightStr.split('[^0-9]'); 
             // simple regex or split might be safer
             // Let's just grab the first char since it is single digit 1-5
             String firstChar = weightStr.substring(0, 1);
             if (firstChar.isNumeric()) {
                 return Decimal.valueOf(firstChar);
             }
        }
        // Fallback or direct number
        try {
            return Decimal.valueOf(weightStr);
        } catch(Exception e) {
            return 1;
        }
    }
}