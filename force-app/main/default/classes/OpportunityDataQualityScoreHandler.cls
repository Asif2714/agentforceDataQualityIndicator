/**
 * @description Calculates and stores Opportunity data quality scores on save.
 * @notes
 * - Uses Data_Quality_Rule__c configuration for Opportunity
 * - Keeps scoring logic aligned with the LWC (weighted completeness)
 */
public without sharing class OpportunityDataQualityScoreHandler {
    private class RuleModel {
        public String fieldApiName;
        public Boolean isRequired;
        public Decimal weight;
    }

    public static void applyScores(List<Opportunity> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        List<RuleModel> rules = loadRules();
        for (Opportunity opp : records) {
            Decimal pct = computeScore(opp, rules);
            opp.Data_Quality_Score__c = pct;
            opp.Data_Quality_Score_Timestamp__c = System.now();
        }
    }

    private static List<RuleModel> loadRules() {
        List<RuleModel> models = new List<RuleModel>();
        Map<String, Schema.SObjectField> fieldMap = Opportunity.SObjectType.getDescribe().fields.getMap();

        List<Data_Quality_Rule__c> rules = [
            SELECT Field_API_Name__c, Is_Required__c, Weight__c
            FROM Data_Quality_Rule__c
            WHERE Active__c = true
              AND Object_API_Name__c = 'Opportunity'
            ORDER BY CreatedDate ASC
        ];

        for (Data_Quality_Rule__c r : rules) {
            String api = (r.Field_API_Name__c == null) ? null : r.Field_API_Name__c.trim();
            if (String.isBlank(api) || !fieldMap.containsKey(api)) {
                continue;
            }

            RuleModel model = new RuleModel();
            model.fieldApiName = api;
            model.isRequired = (r.Is_Required__c == true);
            model.weight = (r.Weight__c != null) ? r.Weight__c : (model.isRequired ? 2 : 1);
            models.add(model);
        }

        return models;
    }

    private static Decimal computeScore(SObject record, List<RuleModel> rules) {
        if (rules == null || rules.isEmpty()) {
            return Decimal.valueOf(100).setScale(2);
        }

        Decimal totalWeight = 0;
        Decimal achievedWeight = 0;

        for (RuleModel r : rules) {
            totalWeight += r.weight;
            Object rawValue = record.get(r.fieldApiName);
            if (!isMissing(rawValue)) {
                achievedWeight += r.weight;
            }
        }

        if (totalWeight == 0) {
            return Decimal.valueOf(100).setScale(2);
        }

        Decimal pct = (achievedWeight / totalWeight) * 100;
        return pct.setScale(2, System.RoundingMode.HALF_UP);
    }

    private static Boolean isMissing(Object rawValue) {
        if (rawValue == null) {
            return true;
        }
        if (rawValue instanceof String) {
            return String.isBlank((String)rawValue);
        }
        return false;
    }
}
