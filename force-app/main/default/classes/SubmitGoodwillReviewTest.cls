@IsTest
private class SubmitGoodwillReviewTest {

    @IsTest
    static void testNullInput() {
        List<SubmitGoodwillReview.Result> results = SubmitGoodwillReview.submit(null);
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testNoClaimNoVin() {
        SubmitGoodwillReview.Input inp = new SubmitGoodwillReview.Input();
        // Neither claimId nor vin provided
        Test.startTest();
        List<SubmitGoodwillReview.Result> results = SubmitGoodwillReview.submit(
            new List<SubmitGoodwillReview.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals('Error', results[0].status);
    }

    @IsTest
    static void testExistingClaim() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);

        SubmitGoodwillReview.Input inp = new SubmitGoodwillReview.Input();
        inp.claimId = c.Id;
        inp.goodwillReason = 'Customer loyalty — first-time request.';
        Test.startTest();
        List<SubmitGoodwillReview.Result> results = SubmitGoodwillReview.submit(
            new List<SubmitGoodwillReview.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals('Success', results[0].status);
        System.assertEquals(c.Id, results[0].claimId);
        System.assertNotEquals(null, results[0].claimNumber);

        Claim updated = [SELECT Authorization_Type__c, Priority__c, DealerResponseSummary__c FROM Claim WHERE Id = :c.Id];
        System.assertEquals('Goodwill', updated.Authorization_Type__c);
        System.assertEquals('High', updated.Priority__c);
        System.assertEquals('Customer loyalty — first-time request.', updated.DealerResponseSummary__c);
    }

    @IsTest
    static void testVinPathWithExplicitDealerId() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();

        SubmitGoodwillReview.Input inp = new SubmitGoodwillReview.Input();
        inp.vin = v.VehicleIdentificationNumber;
        inp.dealerId = a.Id;
        inp.partCategory = 'Battery';
        inp.goodwillReason = 'Battery degraded faster than expected.';
        Test.startTest();
        List<SubmitGoodwillReview.Result> results = SubmitGoodwillReview.submit(
            new List<SubmitGoodwillReview.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals('Success', results[0].status);
        System.assertNotEquals(null, results[0].claimId);

        Claim created = [SELECT Authorization_Type__c, Priority__c, PartCategory__c FROM Claim WHERE Id = :results[0].claimId];
        System.assertEquals('Goodwill', created.Authorization_Type__c);
        System.assertEquals('Battery', created.PartCategory__c);
    }

    @IsTest
    static void testVinPathAutoResolveDealer() {
        // No dealerId provided — should resolve from Asset.AccountId
        Vehicle v = TestDataFactory.createVehicle();

        SubmitGoodwillReview.Input inp = new SubmitGoodwillReview.Input();
        inp.vin = v.VehicleIdentificationNumber;
        // dealerId intentionally omitted
        Test.startTest();
        List<SubmitGoodwillReview.Result> results = SubmitGoodwillReview.submit(
            new List<SubmitGoodwillReview.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals('Success', results[0].status);
        System.assertNotEquals(null, results[0].claimId);
    }

    @IsTest
    static void testVinNotFound() {
        SubmitGoodwillReview.Input inp = new SubmitGoodwillReview.Input();
        inp.vin = 'INVALIDVIN000000X';
        Test.startTest();
        List<SubmitGoodwillReview.Result> results = SubmitGoodwillReview.submit(
            new List<SubmitGoodwillReview.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals('Error', results[0].status);
        System.assert(results[0].message.contains('Vehicle not found'), results[0].message);
    }
}