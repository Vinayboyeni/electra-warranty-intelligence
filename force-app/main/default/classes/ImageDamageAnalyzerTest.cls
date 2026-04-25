@IsTest
private class ImageDamageAnalyzerTest {
    
    @IsTest
    static void testAnalyzePumpDamage() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        
        ImageDamageAnalyzer.Input req = new ImageDamageAnalyzer.Input();
        req.claimId = c.Id;
        req.partName = 'Water Pump'; // pump triggers damage true
        
        Test.startTest();
        List<ImageDamageAnalyzer.Result> results = ImageDamageAnalyzer.analyze(new List<ImageDamageAnalyzer.Input>{ req });
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assert(results[0].isDamaged, 'Should detect pump damage');
        
        Claim updatedClaim = [SELECT AI_Image_Analysis__c FROM Claim WHERE Id = :c.Id];
        System.assert(updatedClaim.AI_Image_Analysis__c.contains('crack'));
    }

    @IsTest
    static void testAnalyzeBattery() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        
        ImageDamageAnalyzer.Input req = new ImageDamageAnalyzer.Input();
        req.claimId = c.Id;
        req.partName = 'Main Battery';
        
        Test.startTest();
        List<ImageDamageAnalyzer.Result> results = ImageDamageAnalyzer.analyze(new List<ImageDamageAnalyzer.Input>{ req });
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isDamaged);
    }
}