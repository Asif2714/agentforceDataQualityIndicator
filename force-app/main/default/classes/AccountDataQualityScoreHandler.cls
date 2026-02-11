/**
 * @description Calculates and stores Account data quality scores on save.
 */
public without sharing class AccountDataQualityScoreHandler {
    private class RuleModel {
        public String fieldApiName;
        public Boolean isRequired;
        public Decimal weight;
    }

    public static void applyScores(List<Account> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        List<RuleModel> rules = loadRules();
        for (Account acc : records) {
            Decimal pct = computeScore(acc, rules);
            acc.Data_Quality_Score__c = pct;
            acc.Data_Quality_Score_Timestamp__c = System.now();
        }
    }

    private static List<RuleModel> loadRules() {
        List<RuleModel> models = new List<RuleModel>();
        Map<String, Schema.SObjectField> fieldMap = Account.SObjectType.getDescribe().fields.getMap();

        List<Data_Quality_Field_Config__c> rules = [
            SELECT Field_API_Name__c, Is_Required__c, Weight__c
            FROM Data_Quality_Field_Config__c
            WHERE Data_Quality_Config__r.Object_API_Name__c = 'Account'
            WITH USER_MODE
            ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC
        ];

        for (Data_Quality_Field_Config__c r : rules) {
            String api = (r.Field_API_Name__c == null) ? null : r.Field_API_Name__c.trim();
            if (String.isBlank(api) || !fieldMap.containsKey(api)) {
                continue;
            }

            RuleModel model = new RuleModel();
            model.fieldApiName = api;
            model.isRequired = (r.Is_Required__c == true);
            model.weight = parseWeight(r.Weight__c);
            models.add(model);
        }

        return models;
    }

    private static Decimal parseWeight(String weightStr) {
        if (String.isBlank(weightStr)) return 1;
        String firstChar = weightStr.substring(0, 1);
        if (firstChar.isNumeric()) {
            return Decimal.valueOf(firstChar);
        }
        return 1;
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
