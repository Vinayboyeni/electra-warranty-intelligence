@IsTest
private class RejectWarrantyClaimTest {
    @IsTest
    static void testReject() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        c.Status = 'Pending Review';
        update c;
        
        RejectWarrantyClaim.Input req = new RejectWarrantyClaim.Input();
        req.claimId = c.Id;
        req.reasonCode = 'NotCovered';
        req.decisionRationale = 'Too much damage';
        
        Test.startTest();
        List<RejectWarrantyClaim.Result> res = RejectWarrantyClaim.reject(new List<RejectWarrantyClaim.Input>{ req });
        Test.stopTest();
        
        System.assertEquals('Success', res[0].status);
        
        Claim updated = [SELECT Status FROM Claim WHERE Id = :c.Id];
        System.assertEquals('Rejected', updated.Status);
    }
}