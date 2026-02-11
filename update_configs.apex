List<Data_Quality_Config__c> configs = [SELECT Id, Object_API_Name__c FROM Data_Quality_Config__c];
for(Data_Quality_Config__c c : configs) {
    if(String.isNotBlank(c.Object_API_Name__c)) {
        c.Name = c.Object_API_Name__c;
    }
}
update configs;
