@IsTest
private class OpportunityDataQualityScoreHandlerTest {
    @IsTest
    static void appliesScoreOnInsertAndUpdate() {
        List<Data_Quality_Rule__c> rules = new List<Data_Quality_Rule__c>{
            new Data_Quality_Rule__c(
                Object_API_Name__c = 'Opportunity',
                Field_API_Name__c = 'Name',
                Is_Required__c = true,
                Active__c = true
            ),
            new Data_Quality_Rule__c(
                Object_API_Name__c = 'Opportunity',
                Field_API_Name__c = 'Amount',
                Is_Required__c = false,
                Active__c = true
            )
        };
        insert rules;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Opportunity inserted = [
            SELECT Data_Quality_Score__c, Data_Quality_Score_Timestamp__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        System.assertNotEquals(null, inserted.Data_Quality_Score__c, 'Score should be set on insert.');
        System.assertNotEquals(null, inserted.Data_Quality_Score_Timestamp__c, 'Timestamp should be set on insert.');

        // Name present (weight 2), Amount missing (weight 1) => 2/3 => 66.67
        System.assertEquals(
            Decimal.valueOf('66.67').setScale(2),
            inserted.Data_Quality_Score__c
        );

        inserted.Amount = 100;
        update inserted;

        Opportunity updated = [
            SELECT Data_Quality_Score__c, Data_Quality_Score_Timestamp__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        System.assertEquals(
            Decimal.valueOf('100').setScale(2),
            updated.Data_Quality_Score__c
        );
        System.assertNotEquals(null, updated.Data_Quality_Score_Timestamp__c, 'Timestamp should be updated.');
    }
}
