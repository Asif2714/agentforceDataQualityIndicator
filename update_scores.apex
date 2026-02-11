List<Account> accs = [SELECT Id FROM Account LIMIT 1000];
if(!accs.isEmpty()) {
    update accs;
}
List<Opportunity> opps = [SELECT Id FROM Opportunity LIMIT 1000];
if(!opps.isEmpty()) {
    update opps;
}
