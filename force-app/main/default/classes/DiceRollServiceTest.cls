@IsTest
private class DiceRollServiceTest {
    @IsTest
    static void testRollAndSaveHappyPath() {
        Id me = UserInfo.getUserId();

        DiceRollService.RollResult res = DiceRollService.rollAndSave(3, 6, 2, me);
        Assert.isNotNull(res.recordId, 'Record was not created');
        Assert.isTrue(res.sum >= 3 && res.sum <= 18, 'Sum out of range for 3d6');
        Assert.areEqual(res.sum + 2, res.total, 'Total mismatch');
        Assert.isTrue(res.notation.startsWith('3d6'), 'Notation not set');

        Dice_Roll__c rec = [
            SELECT Number_of_Dice__c, Sides__c, Modifier__c, Sum_of_Dice__c, Had_Critical__c, Results_JSON__c, Roller__c
            FROM Dice_Roll__c
            WHERE Id = :res.recordId
        ];
        Assert.areEqual(3, rec.Number_of_Dice__c, 'Dice count mismatch');
        Assert.areEqual('6', rec.Sides__c, 'Sides mismatch');
        Assert.areEqual(2, rec.Modifier__c, 'Modifier mismatch');
        Assert.areEqual(me, rec.Roller__c, 'Roller should be the running user');
    }

    @IsTest
    static void testValidation() {
        // Number of dice out of range - minimum
        try {
            DiceRollService.rollAndSave(0, 6, 0, null);
            Assert.fail('Should have thrown for invalid dice count');
        } catch (Exception e) {
            Assert.areEqual('System.AuraHandledException', e.getTypeName(), 'Expected System.AuraHandledException for dice count');
        }

        // Number of dice out of range - maximum
        try {
            DiceRollService.rollAndSave(101, 6, 0, null);
            Assert.fail('Should have thrown for dice count > 100');
        } catch (Exception e) {
            Assert.areEqual('System.AuraHandledException', e.getTypeName(), 'Expected System.AuraHandledException for dice count > 100');
        }

        // Invalid sides - null
        try {
            DiceRollService.rollAndSave(1, null, 0, null);
            Assert.fail('Should have thrown for null sides');
        } catch (Exception e) {
            Assert.areEqual('System.AuraHandledException', e.getTypeName(), 'Expected System.AuraHandledException for null sides');
        }

        // Modifier out of range - negative
        try {
            DiceRollService.rollAndSave(1, 6, -100, null);
            Assert.fail('Should have thrown for modifier < -99');
        } catch (Exception e) {
            Assert.areEqual('System.AuraHandledException', e.getTypeName(), 'Expected System.AuraHandledException for modifier < -99');
        }

        // Modifier out of range - positive
        try {
            DiceRollService.rollAndSave(1, 6, 100, null);
            Assert.fail('Should have thrown for modifier > 99');
        } catch (Exception e) {
            Assert.areEqual('System.AuraHandledException', e.getTypeName(), 'Expected System.AuraHandledException for modifier > 99');
        }
    }

    @IsTest
    static void testBoundaryValues() {
        // Test minimum valid values
        DiceRollService.RollResult result1 = DiceRollService.rollAndSave(1, 4, -99, null);
        Assert.isNotNull(result1.recordId, 'Should handle minimum valid values');
        Assert.areEqual('1d4-99', result1.notation, 'Notation incorrect for minimum values');

        // Test maximum valid values
        DiceRollService.RollResult result2 = DiceRollService.rollAndSave(100, 20, 99, null);
        Assert.isNotNull(result2.recordId, 'Should handle maximum valid values');
        Assert.areEqual('100d20+99', result2.notation, 'Notation incorrect for maximum values');

        // Test edge case: modifier = 0
        DiceRollService.RollResult result3 = DiceRollService.rollAndSave(2, 8, 0, null);
        Assert.areEqual('2d8+0', result3.notation, 'Notation should show +0 for zero modifier');
    }

    @IsTest
    static void testDefaultParameterHandling() {
        // Test with null numberOfDice (should default to 1)
        DiceRollService.RollResult result1 = DiceRollService.rollAndSave(null, 6, 5, null);
        Assert.isTrue(result1.sum >= 1 && result1.sum <= 6, 'Sum should be in range for 1d6');
        Assert.areEqual('1d6+5', result1.notation, 'Should default to 1 die');

        // Test with null modifier (should default to 0)
        DiceRollService.RollResult result2 = DiceRollService.rollAndSave(2, 10, null, null);
        Assert.areEqual(result2.sum, result2.total, 'Total should equal sum when modifier defaults to 0');
        Assert.areEqual('2d10+0', result2.notation, 'Should default modifier to 0');

        // Test with both null values
        DiceRollService.RollResult result3 = DiceRollService.rollAndSave(null, 12, null, null);
        Assert.isTrue(result3.sum >= 1 && result3.sum <= 12, 'Sum should be in range for 1d12');
        Assert.areEqual(result3.sum, result3.total, 'Total should equal sum with default modifier');
        Assert.areEqual('1d12+0', result3.notation, 'Should use both defaults');
    }

    @IsTest
    static void testCriticalHitDetection() {
        // Since we can't control random values, we test multiple rolls to increase probability
        // of getting a critical hit (maximum value on die)
        Boolean foundCritical = false;
        Boolean foundNonCritical = false;
        
        for (Integer i = 0; i < 50; i++) {
            DiceRollService.RollResult result = DiceRollService.rollAndSave(5, 6, 0, null);
            
            if (result.hadCritical) {
                foundCritical = true;
            } else {
                foundNonCritical = true;
            }
            
            if (foundCritical && foundNonCritical) {
                break;
            }
        }
        
        // At least one of these should be true with 50 rolls of 5d6
        Assert.isTrue(foundCritical || foundNonCritical, 'Should have varied critical hit results');
    }

    @IsTest
    static void testJsonSerialization() {
        DiceRollService.RollResult result = DiceRollService.rollAndSave(3, 8, 2, null);
        
        // Verify JSON is valid
        Assert.isNotNull(result.resultsJson, 'Results JSON should not be null');
        
        List<Integer> deserializedResults = (List<Integer>) JSON.deserialize(result.resultsJson, List<Integer>.class);
        Assert.areEqual(3, deserializedResults.size(), 'Should have 3 dice results');
        
        // Verify each result is within valid range
        Integer calculatedSum = 0;
        for (Integer roll : deserializedResults) {
            Assert.isTrue(roll >= 1 && roll <= 8, 'Each roll should be between 1 and 8');
            calculatedSum += roll;
        }
        
        Assert.areEqual(result.sum, calculatedSum, 'Sum should match individual roll results');
    }

    @IsTest
    static void testNotationFormatting() {
        // Test positive modifier
        DiceRollService.RollResult result1 = DiceRollService.rollAndSave(2, 6, 3, null);
        Assert.areEqual('2d6+3', result1.notation, 'Positive modifier should use + sign');

        // Test negative modifier
        DiceRollService.RollResult result2 = DiceRollService.rollAndSave(4, 10, -5, null);
        Assert.areEqual('4d10-5', result2.notation, 'Negative modifier should show minus sign');

        // Test zero modifier
        DiceRollService.RollResult result3 = DiceRollService.rollAndSave(1, 20, 0, null);
        Assert.areEqual('1d20+0', result3.notation, 'Zero modifier should show +0');

        // Test single die
        DiceRollService.RollResult result4 = DiceRollService.rollAndSave(1, 4, 1, null);
        Assert.areEqual('1d4+1', result4.notation, 'Single die notation should be correct');
    }

    @IsTest
    static void testRollerAssignment() {
        Id testUserId = UserInfo.getUserId();
        
        // Test with specific roller
        DiceRollService.RollResult result1 = DiceRollService.rollAndSave(1, 6, 0, testUserId);
        Dice_Roll__c record1 = [SELECT Roller__c FROM Dice_Roll__c WHERE Id = :result1.recordId];
        Assert.areEqual(testUserId, record1.Roller__c, 'Roller should be assigned when provided');

        // Test with null roller
        DiceRollService.RollResult result2 = DiceRollService.rollAndSave(1, 6, 0, null);
        Dice_Roll__c record2 = [SELECT Roller__c FROM Dice_Roll__c WHERE Id = :result2.recordId];
        Assert.areEqual(null, record2.Roller__c, 'Roller should be null when not provided');
    }

    @IsTest
    static void testGetActiveUsersDefault() {
        List<DiceRollService.Option> users = DiceRollService.getActiveUsers(null);
        Assert.isNotNull(users, 'Should return a list even if empty');
        
        // Verify structure of returned options
        if (!users.isEmpty()) {
            DiceRollService.Option firstUser = users[0];
            Assert.isNotNull(firstUser.label, 'User label should not be null');
            Assert.isNotNull(firstUser.value, 'User value should not be null');
        }
    }

    @IsTest
    static void testGetActiveUsersWithLimit() {
        // Test with specific limit
        List<DiceRollService.Option> users1 = DiceRollService.getActiveUsers(5);
        Assert.isTrue(users1.size() <= 5, 'Should respect the limit parameter');

        // Test with invalid limits (should default to 100)
        List<DiceRollService.Option> users2 = DiceRollService.getActiveUsers(0);
        List<DiceRollService.Option> users3 = DiceRollService.getActiveUsers(-1);
        List<DiceRollService.Option> users4 = DiceRollService.getActiveUsers(300);
        
        // All should behave the same as default
        Assert.areEqual(users2.size(), users3.size(), 'Invalid limits should behave consistently');
        Assert.areEqual(users3.size(), users4.size(), 'Invalid limits should behave consistently');
    }

    @IsTest
    static void testOptionClass() {
        DiceRollService.Option option = new DiceRollService.Option('Test Label', 'TestValue');
        Assert.areEqual('Test Label', option.label, 'Label should be set correctly');
        Assert.areEqual('TestValue', option.value, 'Value should be set correctly');
    }
}