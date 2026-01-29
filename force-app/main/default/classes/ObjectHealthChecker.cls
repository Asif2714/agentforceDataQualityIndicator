/**
 * @description Invocable service that returns population statistics (non-null percentage) for fields on a given sObject.
 * This class is designed to work with both Flows and LWC components.
 * 
 * For LWC usage, use the getHealthStats method directly.
 * For Flow usage, use the run method with List<String>.
 */
public with sharing class ObjectHealthChecker {

    private static final Integer MAX_FIELDS = 60;

    /**
     * Flow-compatible method that accepts a list of object names
     * @param objectApiNames List of object API names to check
     * @return List of String results for flow compatibility
     */
    @InvocableMethod(label='Object Health Checker' description='Returns population statistics for fields on an object')
    public static List<String> run(List<String> objectApiNames) {
        List<String> results = new List<String>();
        if (objectApiNames == null || objectApiNames.isEmpty()) {
            results.add('ERROR: No request received.');
            return results;
        }
        
        // Process each object and collect results as strings for flow compatibility
        for (String objName : objectApiNames) {
            // Ensure we handle null or blank values properly
            String cleanObjName = String.isBlank(objName) ? null : objName.trim();
            Response resp = evaluate(cleanObjName);
            
            // Convert response to a simple string format for flows
            if (resp != null) {
                String result = resp.status + '|' + resp.message;
                if (resp.results != null && !resp.results.isEmpty()) {
                    // Add field statistics in a simple format
                    for (FieldStat stat : resp.results) {
                        result += '|' + stat.fieldLabel + ':' + stat.apiName + ':' + stat.populationPercentage;
                    }
                }
                results.add(result);
            } else {
                results.add('ERROR: Failed to process ' + objName);
            }
        }
        return results;
    }

    /**
     * Core evaluation logic for a single object API name - designed for LWC usage
     * @param objectApiName The API name of the object to evaluate
     * @return Response object with health statistics
     */
    @AuraEnabled(cacheable=true)
    public static Response evaluate(String objectApiName) {
        Response resp = new Response();
        if (String.isBlank(objectApiName)) {
            resp.status = 'ERROR';
            resp.message = 'objectApiName is required.';
            return resp;
        }

        try {
            // Describe object, gather candidate fields (only queryable & accessible).
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjType == null) {
                resp.status = 'ERROR';
                resp.message = 'Invalid objectApiName: ' + objectApiName;
                return resp;
            }
            Schema.DescribeSObjectResult d = sObjType.getDescribe();

            Map<String, Schema.SObjectField> fieldMap = d.fields.getMap();
            List<FieldDescriptor> descriptors = new List<FieldDescriptor>();

            for (String apiName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fr = fieldMap.get(apiName).getDescribe();
                // Keep only accessible fields
                if (!fr.isAccessible()) continue;
                // Skip rich text fields that cannot be used in WHERE clauses
                // Using string comparison to avoid compilation issues
                if (String.valueOf(fr.getType()).equals('RichText')) continue;
                String label = fr.getLabel();
                descriptors.add(new FieldDescriptor(label, apiName));
            }

            if (descriptors.isEmpty()) {
                resp.status = 'SUCCESS';
                resp.message = 'No accessible queryable fields on ' + objectApiName + '.';
                return resp;
            }

            // Sort by Field Label asc and cap to MAX_FIELDS
            descriptors.sort();
            if (descriptors.size() > MAX_FIELDS) {
                // manually cap since List.subList is not supported in Apex
                List<FieldDescriptor> capped = new List<FieldDescriptor>();
                for (Integer i = 0; i < Math.min(MAX_FIELDS, descriptors.size()); i++) {
                    capped.add(descriptors[i]);
                }
                descriptors = capped;
            }

            // Compute total record count
            System.debug('About to get total count for: ' + d.getName());
            Integer totalCount = getTotalCount(d.getName());
            System.debug('Total count result: ' + totalCount);
            if (totalCount == null) {
                resp.status = 'ERROR';
                resp.message = 'Failed to count total records for ' + objectApiName + '.';
                return resp;
            }
            if (totalCount == 0) {
                // Nothing to evaluate, return 0% for all selected fields
                for (FieldDescriptor fd : descriptors) {
                    resp.results.add(new FieldStat(fd.label, fd.apiName, 0));
                }
                resp.status = 'SUCCESS';
                resp.message = 'No records found for ' + objectApiName + '.';
                return resp;
            }

            // For each field, compute populated count (field != null)
            for (FieldDescriptor fd : descriptors) {
                System.debug('Processing field: ' + fd.apiName);
                try {
                    Integer populated = getPopulatedCount(d.getName(), fd.apiName);
                    System.debug('Populated count for ' + fd.apiName + ': ' + populated);
                    Decimal pct = 0;
                    if (populated != null && populated > 0) {
                        pct = (Decimal.valueOf(populated) / Decimal.valueOf(totalCount)) * 100;
                        pct = pct.setScale(2);
                    }
                    resp.results.add(new FieldStat(fd.label, fd.apiName, pct));
                } catch (Exception e) {
                    // Log the error but continue processing other fields
                    System.debug('Warning: Failed to process field ' + fd.apiName + ': ' + e.getMessage());
                    // Skip this field but continue with others
                }
            }

            // Ensure final results sorted by fieldLabel (defensive)
            resp.results.sort(new FieldStatLabelComparator());
            resp.status = 'SUCCESS';
            resp.message = 'Evaluated ' + resp.results.size() + ' fields on ' + objectApiName + '.';
            return resp;

        } catch (Exception e) {
            resp.status = 'ERROR';
            resp.message = 'Failed: ' + e.getMessage();
            return resp;
        }
    }

    /**
     * LWC-specific method that directly returns the field statistics
     * This is the method that should be called from LWC components
     * @param objectApiName The API name of the object to evaluate
     * @return List of FieldStat objects
     */
    @AuraEnabled(cacheable=true)
    public static List<FieldStat> getHealthStats(String objectApiName) {
        Response resp = evaluate(objectApiName);
        return resp.results;
    }

    /**
     * Alternative LWC method that accepts a map parameter for more complex scenarios
     * @param params Map containing objectApiName
     * @return List of FieldStat objects
     */
    @AuraEnabled(cacheable=true)
    public static List<FieldStat> getHealthStatsFromMap(Map<String, Object> params) {
        String objectApiName = (String)params.get('objectApiName');
        if (objectApiName == null) {
            // Try alternative key names for backwards compatibility
            objectApiName = (String)params.get('ObjectName');
        }
        if (objectApiName == null) {
            // Return empty list if no object name provided
            return new List<FieldStat>();
        }
        return getHealthStats(objectApiName);
    }

    // Helper: COUNT() total
    private static Integer getTotalCount(String objectApiNameNormalized) {
        String soql = 'SELECT COUNT() FROM ' + objectApiNameNormalized + ' WITH SECURITY_ENFORCED';
        return (Integer)Database.countQuery(soql);
    }

    // Helper: COUNT() where field != null
    private static Integer getPopulatedCount(String objectApiNameNormalized, String fieldApi) {
        // WHERE must come before WITH SECURITY_ENFORCED; build defensively
        String soql = 'SELECT COUNT() FROM ' + objectApiNameNormalized +
                      ' WHERE ' + fieldApi + ' != null WITH SECURITY_ENFORCED';
        return (Integer)Database.countQuery(soql);
    }

    // Internal DTO for sorting fields by label
    private class FieldDescriptor implements Comparable {
        String label;
        String apiName;
        FieldDescriptor(String label, String apiName) {
            this.label = label;
            this.apiName = apiName;
        }
        public Integer compareTo(Object o) {
            FieldDescriptor other = (FieldDescriptor)o;
            if (this.label == null && other.label == null) return 0;
            if (this.label == null) return -1;
            if (other.label == null) return 1;
            return this.label.toLowerCase().compareTo(other.label != null ? other.label.toLowerCase() : null);
        }
    }

    // Comparator for final result sorting by fieldLabel
    private class FieldStatLabelComparator implements System.Comparator<FieldStat> {
        public Integer compare(FieldStat a, FieldStat b) {
            String la = a != null ? a.fieldLabel : null;
            String lb = b != null ? b.fieldLabel : null;
            if (la == null && lb == null) return 0;
            if (la == null) return -1;
            if (lb == null) return 1;
            return la.toLowerCase().compareTo(lb.toLowerCase());
        }
    }
    
    // DTO Classes - moved inline to avoid dependency issues
    public class Response {
        public String status { get; set; }
        public String message { get; set; }
        public List<FieldStat> results { get; set; }
        
        public Response() {
            this.results = new List<FieldStat>();
        }
    }
    
    public class FieldStat {
        @AuraEnabled
        public String fieldLabel { get; set; }
        
        @AuraEnabled
        public String apiName { get; set; }
        
        @AuraEnabled
        public Decimal populationPercentage { get; set; }
        
        public FieldStat(String fieldLabel, String apiName, Decimal populationPercentage) {
            this.fieldLabel = fieldLabel;
            this.apiName = apiName;
            this.populationPercentage = populationPercentage;
        }
    }
}