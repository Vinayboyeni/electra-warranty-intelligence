@IsTest
private class ApproveWarrantyClaimTest {
    @IsTest
    static void testApprove() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        c.Status = 'Pending Review';
        update c;
        
        ApproveWarrantyClaim.Input req = new ApproveWarrantyClaim.Input();
        req.claimId = c.Id;
        req.decisionRationale = 'Looks good';
        
        Test.startTest();
        List<ApproveWarrantyClaim.Result> res = ApproveWarrantyClaim.approve(new List<ApproveWarrantyClaim.Input>{ req });
        Test.stopTest();
        
        System.assertEquals('Success', res[0].status);
        
        Claim updated = [SELECT Status, AI_Recommendation__c FROM Claim WHERE Id = :c.Id];
        System.assertEquals('Approved', updated.Status);
    }
}