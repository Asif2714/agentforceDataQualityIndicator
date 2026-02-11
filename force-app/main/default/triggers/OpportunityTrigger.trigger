trigger OpportunityTrigger on Opportunity (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            OpportunityDataQualityScoreHandler.applyScores(Trigger.new);
        }
    }
}