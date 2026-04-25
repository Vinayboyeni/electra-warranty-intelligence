@IsTest
private class RouteClaimToApproverQueueTest {
    @IsTest
    static void testRoute() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        
        RouteClaimToApproverQueue.Input req = new RouteClaimToApproverQueue.Input();
        req.claimId = c.Id;
        req.priority = 'Normal';
        req.preferredQueueDeveloperName = 'Warranty_Claim_Approvers';
        
        Test.startTest();
        List<RouteClaimToApproverQueue.Result> res = RouteClaimToApproverQueue.route(new List<RouteClaimToApproverQueue.Input>{ req });
        Test.stopTest();
        
        System.assertEquals('Pending Approver Review', res[0].status);
    }
}