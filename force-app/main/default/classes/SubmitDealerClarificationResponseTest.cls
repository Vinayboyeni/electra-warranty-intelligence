@IsTest
private class SubmitDealerClarificationResponseTest {

    @IsTest
    static void testNullInput() {
        List<SubmitDealerClarificationResponse.Result> results =
            SubmitDealerClarificationResponse.submitResponse(null);
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testNullClaimNumber() {
        SubmitDealerClarificationResponse.Input inp = new SubmitDealerClarificationResponse.Input();
        inp.claimNumber = null;
        inp.dealerResponse = 'Some response.';
        Test.startTest();
        List<SubmitDealerClarificationResponse.Result> results =
            SubmitDealerClarificationResponse.submitResponse(
                new List<SubmitDealerClarificationResponse.Input>{ inp }
            );
        Test.stopTest();
        // Blank claimNumber not added to responseMap → empty map → early return
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testSuccess() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        c.Status = 'Needs More Info';
        c.ClarificationRequest__c = 'Please send diagnostic scan results.';
        update c;

        SubmitDealerClarificationResponse.Input inp = new SubmitDealerClarificationResponse.Input();
        inp.claimNumber = c.Name;
        inp.dealerResponse = 'OBD-II scan shows fault code P0300. Report attached.';
        Test.startTest();
        List<SubmitDealerClarificationResponse.Result> results =
            SubmitDealerClarificationResponse.submitResponse(
                new List<SubmitDealerClarificationResponse.Input>{ inp }
            );
        Test.stopTest();
        System.assertEquals(true, results[0].submitted);
        System.assertEquals('Response submitted successfully.', results[0].message);

        Claim updated = [SELECT Status, DealerResponseSummary__c, RequiresFollowUp__c FROM Claim WHERE Id = :c.Id];
        System.assertEquals('Pending Approver Review', updated.Status);
        System.assertEquals('OBD-II scan shows fault code P0300. Report attached.', updated.DealerResponseSummary__c);
        System.assertEquals(false, updated.RequiresFollowUp__c);
    }

    @IsTest
    static void testBulkResponse() {
        Account a = TestDataFactory.createDealer();
        Vehicle v1 = TestDataFactory.createVehicle();
        Vehicle v2 = TestDataFactory.createVehicle();
        Claim c1 = TestDataFactory.createClaim(a.Id, v1.AssetId);
        Claim c2 = TestDataFactory.createClaim(a.Id, v2.AssetId);
        c1.Status = 'Needs More Info'; c1.ClarificationRequest__c = 'Need photos.';
        c2.Status = 'Needs More Info'; c2.ClarificationRequest__c = 'Need receipt.';
        update new List<Claim>{ c1, c2 };

        SubmitDealerClarificationResponse.Input inp1 = new SubmitDealerClarificationResponse.Input();
        inp1.claimNumber = c1.Name;
        inp1.dealerResponse = 'Photos attached.';
        SubmitDealerClarificationResponse.Input inp2 = new SubmitDealerClarificationResponse.Input();
        inp2.claimNumber = c2.Name;
        inp2.dealerResponse = 'Receipt attached.';

        Test.startTest();
        List<SubmitDealerClarificationResponse.Result> results =
            SubmitDealerClarificationResponse.submitResponse(
                new List<SubmitDealerClarificationResponse.Input>{ inp1, inp2 }
            );
        Test.stopTest();
        System.assertEquals(2, results.size());
        System.assertEquals(true, results[0].submitted);
        System.assertEquals(true, results[1].submitted);

        for (Claim updated : [SELECT Status FROM Claim WHERE Id IN (:c1.Id, :c2.Id)]) {
            System.assertEquals('Pending Approver Review', updated.Status);
        }
    }
}