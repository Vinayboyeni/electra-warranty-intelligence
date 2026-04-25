/**
 * @description Legacy smoke test — uses only standard Claim fields available in org.
 *              Full coverage is in WarrantyAgentActionsTest.cls.
 */
@isTest
private class WarrantyClaimSlackFlowTest {

    private static Account createTestDealer() {
        Account dealer = new Account(Name = 'Legacy Test Dealer');
        insert dealer;
        return dealer;
    }

    /** Minimal Claim using only standard fields — custom fields may not exist in org yet */
    private static Claim createMinimalClaim(Id accountId) {
        Claim claim = new Claim(
            AccountId = accountId,
            Name      = 'Legacy Test Claim',
            ClaimType = 'Warranty',
            Status    = 'Submitted'
        );
        insert claim;
        return claim;
    }

    @isTest
    static void testApproveWarrantyClaim() {
        Account dealer = createTestDealer();
        Claim claim = createMinimalClaim(dealer.Id);

        ApproveWarrantyClaim.Input inp = new ApproveWarrantyClaim.Input();
        inp.claimId = claim.Id;
        inp.decisionRationale = 'Approved after coverage check.';
        inp.approverSlackRef  = 'SLACK-THREAD-123';

        Test.startTest();
        List<ApproveWarrantyClaim.Result> results = ApproveWarrantyClaim.approve(
            new List<ApproveWarrantyClaim.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Success', results[0].status);

        Claim updated = [SELECT Status, Status__c FROM Claim WHERE Id = :claim.Id];
        System.assertEquals('Approved', updated.Status);
        System.assertEquals('Approved', updated.Status__c);
    }

    @isTest
    static void testRejectWarrantyClaim() {
        Account dealer = createTestDealer();
        Claim claim = createMinimalClaim(dealer.Id);

        RejectWarrantyClaim.Input inp = new RejectWarrantyClaim.Input();
        inp.claimId           = claim.Id;
        inp.reasonCode        = 'NotCovered';
        inp.decisionRationale = 'Part not covered.';
        inp.approverSlackRef  = 'SLACK-THREAD-456';

        Test.startTest();
        List<RejectWarrantyClaim.Result> results = RejectWarrantyClaim.reject(
            new List<RejectWarrantyClaim.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Success', results[0].status);

        Claim updated = [SELECT Status, Status__c FROM Claim WHERE Id = :claim.Id];
        System.assertEquals('Rejected', updated.Status);
        System.assertEquals('Rejected', updated.Status__c);
    }

    @isTest
    static void testRequestDealerClarification() {
        Account dealer = createTestDealer();
        Claim claim = createMinimalClaim(dealer.Id);

        RequestDealerClarification.Input inp = new RequestDealerClarification.Input();
        inp.claimId              = claim.Id;
        inp.clarificationRequest = 'Please confirm part serial number.';
        inp.approverSlackRef     = 'SLACK-THREAD-789';
        inp.requiresFollowUp     = true;

        Test.startTest();
        List<RequestDealerClarification.Result> results = RequestDealerClarification.requestClarification(
            new List<RequestDealerClarification.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Success', results[0].status);
        
        Claim updated = [SELECT Status, Status__c FROM Claim WHERE Id = :claim.Id];
        System.assertEquals('Needs More Info', updated.Status);
        System.assertEquals('Needs More Info', updated.Status__c);
    }

    @isTest
    static void testGetApprovalContext_smoke() {
        Account dealer = createTestDealer();
        Claim claim = createMinimalClaim(dealer.Id);

        GetWarrantyClaimApprovalContext.Input inp = new GetWarrantyClaimApprovalContext.Input();
        inp.claimId = claim.Id;

        Test.startTest();
        List<GetWarrantyClaimApprovalContext.Result> results = GetWarrantyClaimApprovalContext.getContext(
            new List<GetWarrantyClaimApprovalContext.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(claim.Id, results[0].claimId);
        System.assertEquals('Pending Approver Review', results[0].status);
    }

    @isTest
    static void testLinkUploadedEvidence_empty() {
        Account dealer = createTestDealer();
        Claim claim = createMinimalClaim(dealer.Id);

        LinkUploadedEvidenceToClaim.Input inp = new LinkUploadedEvidenceToClaim.Input();
        inp.claimId      = claim.Id;
        inp.attachmentIds = '';

        Test.startTest();
        List<LinkUploadedEvidenceToClaim.Result> results = LinkUploadedEvidenceToClaim.linkEvidence(
            new List<LinkUploadedEvidenceToClaim.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(0, results[0].linkedCount);
    }
}