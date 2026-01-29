@isTest
public class ObjectHealthCheckerTest {
    
    @isTest
    static void testGetHealthStats() {
        // Test the getHealthStats method with a basic object
        List<ObjectHealthChecker.FieldStat> results = ObjectHealthChecker.getHealthStats('Account');
        System.assertNotEquals(null, results);
    }
    
    @isTest
    static void testEvaluate() {
        // Test the evaluate method
        ObjectHealthChecker.Response response = ObjectHealthChecker.evaluate('Account');
        System.assertNotEquals(null, response);
        System.assert(response.results != null, 'Response results should not be null');
    }
    
    @isTest
    static void testRun() {
        // Test the run method for flows
        List<String> results = ObjectHealthChecker.run(new List<String>{'Account'});
        System.assertNotEquals(null, results);
        System.assert(results.size() > 0, 'Should return at least one result string');
    }
    
    @isTest
    static void testGetHealthStatsFromMap() {
        // Test the getHealthStatsFromMap method
        Map<String, Object> params = new Map<String, Object>();
        params.put('objectApiName', 'Account');
        List<ObjectHealthChecker.FieldStat> results = ObjectHealthChecker.getHealthStatsFromMap(params);
        System.assertNotEquals(null, results);
    }
    
    @isTest
    static void testRunWithNullAndEmpty() {
        // Test the run method with null and empty inputs
        List<String> results1 = ObjectHealthChecker.run(null);
        System.assertNotEquals(null, results1);
        System.assert(results1.size() > 0, 'Should return error result for null input');
        
        List<String> results2 = ObjectHealthChecker.run(new List<String>{});
        System.assertNotEquals(null, results2);
        System.assert(results2.size() > 0, 'Should return error result for empty input');
    }
    
    @isTest
    static void testRunWithBlankValues() {
        // Test the run method with blank values
        List<String> results = ObjectHealthChecker.run(new List<String>{'', '   ', null});
        System.assertNotEquals(null, results);
        System.assert(results.size() > 0, 'Should handle blank values gracefully');
    }
}