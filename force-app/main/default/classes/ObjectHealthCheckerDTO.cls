/**
 * @description DTOs for ObjectHealthChecker Invocable Action.
 * Provides request and response shapes that are Flow-friendly and LWC-consumable.
 */
public without sharing class ObjectHealthCheckerDTO {
    /**
     * @description Request payload for the invocable method.
     */
    public class Request {
        @InvocableVariable
        public String objectApiName;
        
        public Request() {}
        public Request(String objectApiName) { this.objectApiName = objectApiName; }
    }

    /**
     * @description A single field&#39;s population statistic.
     */
    public class FieldStat {
        @InvocableVariable
        public String fieldLabel;
        @InvocableVariable
        public String apiName;
        @InvocableVariable
        public Decimal populationPercentage;

        public FieldStat() {}
        public FieldStat(String fieldLabel, String apiName, Decimal populationPercentage) {
            this.fieldLabel = fieldLabel;
            this.apiName = apiName;
            this.populationPercentage = populationPercentage;
        }
    }

    /**
     * @description Response payload for the invocable method.
     */
    public class Response {
        @InvocableVariable
        public List<FieldStat> results;
        @InvocableVariable
        public String status;
        @InvocableVariable
        public String message;

        public Response() {
            results = new List<FieldStat>();
        }
        
        public Response(List<FieldStat> results, String status, String message) {
            this.results = results;
            this.status = status;
            this.message = message;
        }
    }
}