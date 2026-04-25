@IsTest
private class RequestDealerClarificationTest {
    @IsTest
    static void testClarify() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        c.Status = 'Pending Review';
        update c;
        
        RequestDealerClarification.Input req = new RequestDealerClarification.Input();
        req.claimId = c.Id;
        req.clarificationRequest = 'Need better photos';
        
        Test.startTest();
        List<RequestDealerClarification.Result> res = RequestDealerClarification.requestClarification(new List<RequestDealerClarification.Input>{ req });
        Test.stopTest();
        
        System.assertEquals('Success', res[0].status);
        
        Claim updated = [SELECT Status, ClarificationRequest__c FROM Claim WHERE Id = :c.Id];
        System.assertEquals('Needs More Info', updated.Status);
        System.assertEquals('Need better photos', updated.ClarificationRequest__c);
    }
}