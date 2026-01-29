/*
 * Your party’s trusty Dungeon Guide behind the screen.
 * Rolls dice on command, adds modifiers like enchanted gear or spell effects,
 * and checks for those glorious natural 20s that trigger a Critical.
 *
 * Every roll becomes part of the campaign log in Dice_Roll__c,
 * recording notation, totals, crit flags, and results for later bragging rights.
 * Think of it as your character sheet for random fate.
 *
 * In RPG terms, this service handles the dice mechanics,
 * keeps the quest fair by enforcing rules (1–100 dice only, valid sides),
 * and ensures every adventurer’s roll is logged in the tome.
 *
 * Roll initiative, cast your d20, and may the crits be ever in your favor.
 * — Dungeon Guide (Matheus Gonçalves, 2025)
 */
public with sharing class DiceRollService {
    /**
     * Wrapper class containing the results of a dice roll operation.
     * Used to return both the database record ID and calculated roll data.
     */
    public class RollResult { 
        public Id recordId;                         
        public Integer sum;                      // Raw sum of all dice rolls 
        public Integer total;                    // Sum + modifier 
        public Boolean hadCritical;              // True if any die rolled maximum value 
        @AuraEnabled public String notation;     // Dice notation (e.g., "3d6+2")
        @AuraEnabled public String resultsJson;  // JSON array of individual roll results 
   } 
   
    /**
     * Performs a dice roll, saves the result to the database, and returns a summary.
     */
    @AuraEnabled
    public static RollResult rollAndSave(Integer numberOfDice, Integer sides, Integer modifier, Id rollerId) {
        // Set defaults and validate inputs
        if (numberOfDice == null) numberOfDice = 1;
        if (modifier == null) modifier = 0;

        if (numberOfDice < 1 || numberOfDice > 100) {
            throw new AuraHandledException('Number of dice must be between 1 and 100.');
        }

        if (sides == null) {
            throw new AuraHandledException('Sides must be one of 4, 6, 8, 10, 12, or 20.');
        }

        if (modifier < -99 || modifier > 99) {
            throw new AuraHandledException('Modifier must be between -99 and 99.');
        }

        // Perform the dice rolls and calculate results
        List<Integer> results = new List<Integer>();
        Integer sum = 0;
        Boolean hadCritical = false;

        for (Integer num = 0; num < numberOfDice; num++) {
            // Generate random number from 1 to sides (inclusive)
            Integer roll = Integer.valueOf(Math.floor(Math.random() * sides)) + 1;
            results.add(roll);
            sum += roll;
            // Critical hit occurs when die shows maximum value
            if (roll == sides) hadCritical = true;
        }

        // Create and populate the Dice Roll record
        Dice_Roll__c rec = new Dice_Roll__c();
        rec.Number_of_Dice__c = numberOfDice;
        rec.Sides__c = String.valueOf(sides); // Picklist field stored as text
        rec.Modifier__c = modifier;
        rec.Sum_of_Dice__c = sum;
        rec.Results_JSON__c = JSON.serialize(results); // Store individual rolls as JSON
        rec.Had_Critical__c = hadCritical;
        if (rollerId != null) rec.Roller__c = rollerId;

        // Apply field-level security and CRUD permissions
        List<SObject> filtered = Security.stripInaccessible(
            AccessType.CREATABLE, new List<SObject>{ rec }
        ).getRecords();

        if (filtered.isEmpty()) {
            throw new AuraHandledException('You do not have create access to Dice Roll.');
        }

        // Insert the security-filtered record
        // There should only be one record in the list
        Dice_Roll__c clean = (Dice_Roll__c) filtered[0];
        insert clean;

        // Build and return the summary result
        RollResult out = new RollResult();
        out.recordId = clean.Id;
        out.sum = sum;
        out.hadCritical = hadCritical;
        out.resultsJson = clean.Results_JSON__c;
        out.total = sum + modifier; // Final total including modifier
        
        // Format dice notation (e.g., "2d6+3" or "1d20-1")
        out.notation = numberOfDice + 'd' + sides + (modifier >= 0 ? '+' + modifier : String.valueOf(modifier));

        return out;
    }

    /**
     * Simple data transfer object for label-value pairs.
     * Commonly used for populating UI picklists and dropdown components.
     */
    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        // Constructor to initialize label and value
        public Option(String l, String v) {
            label = l;
            value = v;
        }
    }

    /**
     * Retrieves a list of active users for roller selection.
     * Only returns users with Standard User or System Administrator profiles.
     */
    @AuraEnabled(cacheable=true)
    public static List<Option> getActiveUsers(Integer limitSize) {
        // Validate and set limit (default to 100, max 200)
        Integer lim = (limitSize == null || limitSize < 1 || limitSize > 200) ? 100 : limitSize;
        // Only include users with these profile types
        Set<String> allowedProfiles = new Set<String>{ 'Standard User', 'System Administrator' };

        // Query active users and convert to Option format
        List<Option> out = new List<Option>();
        for (User user : [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
              AND Profile.Name IN :allowedProfiles
            ORDER BY Name
            LIMIT :lim
        ]) {
            out.add(new Option(user.Name, String.valueOf(user.Id)));
        }

        return out;
    }
}