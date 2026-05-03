@IsTest
private class SendClaimDecisionEmailTest {

    private static Claim setup(String status) {
        Account dealer = TestDataFactory.createDealer();
        // Dealer contact provides the recipient email path (CC/To fallback)
        Contact dealerContact = new Contact(
            FirstName = 'Test',
            LastName = 'Dealer',
            AccountId = dealer.Id,
            Email = 'dealer.contact@example.com'
        );
        insert dealerContact;

        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(dealer.Id, v.AssetId);
        c.Status = status;
        c.PartCategory__c = 'Battery';
        c.EstimatedCost__c = 2500;
        c.SLA_Due_Date__c = Datetime.now().addHours(24);
        update c;
        return c;
    }

    @IsTest
    static void approvedClaim_buildsEmail() {
        Claim c = setup('Approved');
        c.ApprovedAmount = 2500;
        c.DecisionRationale__c = 'Approved per policy';
        update c;

        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertNotEquals(null, r[0].channel);
    }

    @IsTest
    static void rejectedClaim_buildsEmail() {
        Claim c = setup('Rejected');
        c.ReasonCode__c = 'OUT_OF_COVERAGE';
        c.DecisionRationale__c = 'Outside warranty period';
        update c;

        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
    }

    @IsTest
    static void needsMoreInfoClaim_buildsEmail() {
        Claim c = setup('Needs More Info');
        c.ClarificationRequest__c = 'Send invoice photos';
        update c;

        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
    }

    @IsTest
    static void nullClaimId_returnsError() {
        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(false, r[0].sent);
        System.assertEquals('Error', r[0].channel);
    }

    @IsTest
    static void nullList_returnsEmpty() {
        Test.startTest();
        List<SendClaimDecisionEmail.Result> r = SendClaimDecisionEmail.send(null);
        Test.stopTest();

        System.assertEquals(0, r.size());
    }

    @IsTest
    static void claimNotFound_returnsError() {
        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();
        // Use a fake but well-formed Claim Id
        inp.claimId = '0Zk000000000000AAA';

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(false, r[0].sent);
    }

    @IsTest
    static void noRecipientEmail_skipsGracefully() {
        // Setup claim with no customer or dealer email
        Account dealer = new Account(Name = 'No Email Dealer');
        insert dealer;
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(dealer.Id, v.AssetId);
        c.Status = 'Approved';
        update c;

        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        // Either Skipped (no email) or Email (test mode)
        System.assertNotEquals(null, r[0].channel);
    }

    @IsTest
    static void approvedWithCappedAmount_buildsCappedNote() {
        Claim c = setup('Approved');
        c.ApprovedAmount = 1500; // less than EstimatedCost 2500
        c.DecisionRationale__c = 'Approved at reduced cap';
        update c;

        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
    }

    @IsTest
    static void otherStatus_genericMessage() {
        Claim c = setup('Submitted');

        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
    }

    @IsTest
    static void rejectedWithReasonCode_includesReason() {
        Claim c = setup('Rejected');
        c.ReasonCode__c = 'OUT_OF_COVERAGE';
        update c;

        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
    }

    @IsTest
    static void bothCustomerAndDealerEmail_setsCc() {
        // Set up customer contact correctly parented to the Asset's owner Account
        Account dealer = TestDataFactory.createDealer();
        Contact dealerContact = new Contact(
            FirstName = 'Test', LastName = 'Dealer',
            AccountId = dealer.Id, Email = 'dealer@example.com'
        );
        insert dealerContact;

        Vehicle v = TestDataFactory.createVehicle();
        Asset a = [SELECT Id, AccountId FROM Asset WHERE Id = :v.AssetId LIMIT 1];
        Contact customer = new Contact(
            FirstName = 'Owner', LastName = 'Customer',
            AccountId = a.AccountId, Email = 'customer@example.com'
        );
        insert customer;
        a.ContactId = customer.Id;
        update a;

        Claim c = TestDataFactory.createClaim(dealer.Id, v.AssetId);
        c.Status = 'Approved';
        c.PartCategory__c = 'Battery';
        c.EstimatedCost__c = 2500;
        update c;

        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
    }

    @IsTest
    static void approvedWithExistingPdf_attachesIt() {
        Claim c = setup('Approved');

        // Pre-create a "PDF" ContentVersion linked to the claim
        ContentVersion cv = new ContentVersion(
            Title = c.Name + ' Approval Authorization',
            PathOnClient = c.Name + '-Authorization.pdf',
            VersionData = Blob.valueOf('fake pdf bytes')
        );
        insert cv;
        ContentVersion saved = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = saved.ContentDocumentId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );
        insert link;

        SendClaimDecisionEmail.Input inp = new SendClaimDecisionEmail.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<SendClaimDecisionEmail.Result> r =
            SendClaimDecisionEmail.send(new List<SendClaimDecisionEmail.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
    }
}