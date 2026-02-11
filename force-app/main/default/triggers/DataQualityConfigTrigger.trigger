trigger DataQualityConfigTrigger on Data_Quality_Config__c (before insert, before update) {
    // Standard Name is now AutoNumber (Config ID), so no manual sync is required.
    // Logic for Object_API_Name__c validation or other pre-processing can go here.
}