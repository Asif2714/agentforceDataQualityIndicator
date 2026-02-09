trigger OpportunityTrigger on Opportunity (before insert, before update) {
    OpportunityDataQualityScoreHandler.applyScores(Trigger.new);
}
