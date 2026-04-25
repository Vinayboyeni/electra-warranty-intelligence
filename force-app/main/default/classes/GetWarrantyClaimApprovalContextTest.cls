@IsTest
private class GetWarrantyClaimApprovalContextTest {
    @IsTest
    static void testGetContext() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        
        GetWarrantyClaimApprovalContext.Input req = new GetWarrantyClaimApprovalContext.Input();
        req.claimId = c.Id;
        
        Test.startTest();
        List<GetWarrantyClaimApprovalContext.Result> results = GetWarrantyClaimApprovalContext.getContext(new List<GetWarrantyClaimApprovalContext.Input>{ req });
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assertEquals(c.Id, results[0].claimId);
        System.assertEquals('Elite dealership', results[0].dealerName);
        System.assertEquals('15000', results[0].odometer);
    }
}