@IsTest
private class CreateWarrantyClaimTest {
    @TestSetup
    static void setupData() {
        Account dealer = TestDataFactory.createDealer();
        TestDataFactory.createCustomer(dealer.Id);
        TestDataFactory.createVehicle();
    }

    @IsTest
    static void testCreateClaimSuccess() {
        Vehicle v = [SELECT VehicleIdentificationNumber FROM Vehicle LIMIT 1];
        Account dealer = [SELECT Id FROM Account LIMIT 1];
        Contact customer = [SELECT Id FROM Contact LIMIT 1];
        
        CreateWarrantyClaimInput req = new CreateWarrantyClaimInput();
        req.vin = v.VehicleIdentificationNumber;
        req.dealerId = dealer.Id;
        req.customerId = customer.Id;
        req.odometer = 15000;
        req.partCategory = 'Battery';
        req.symptom = 'Will not hold charge';
        
        Test.startTest();
        List<CreateWarrantyClaimResult> results = CreateWarrantyClaim.createClaimInvocable(new List<CreateWarrantyClaimInput>{ req });
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assertEquals('Submitted', results[0].status, 'Create Claim failed: ' + results[0].rationale);
        System.assertNotEquals(null, results[0].claimId);
        
        Claim created = [SELECT Id, Odometer__c, Symptom__c FROM Claim WHERE Id = :results[0].claimId];
        System.assertEquals(15000, created.Odometer__c);
        System.assertEquals('Will not hold charge', created.Symptom__c);
    }
}