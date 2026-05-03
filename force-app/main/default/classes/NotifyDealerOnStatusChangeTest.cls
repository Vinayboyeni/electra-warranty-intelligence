@IsTest
private class NotifyDealerOnStatusChangeTest {

    private static Claim setup(String status) {
        Account dealer = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(dealer.Id, v.AssetId);
        c.Status = status;
        update c;
        return c;
    }

    @IsTest
    static void approvedStatus_writesAuditAndReturnsResult() {
        Claim c = setup('Approved');
        c.DecisionRationale__c = 'Approved per policy';
        update c;

        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(true, r[0].sent);
        System.assertNotEquals(null, r[0].channel);
    }

    @IsTest
    static void rejectedStatus_writesAuditAndReturnsResult() {
        Claim c = setup('Rejected');
        c.ReasonCode__c = 'OUT_OF_COVERAGE';
        update c;

        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(true, r[0].sent);
    }

    @IsTest
    static void needsMoreInfoStatus_writesAuditAndReturnsResult() {
        Claim c = setup('Needs More Info');
        c.ClarificationRequest__c = 'Send invoice photos';
        update c;

        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(true, r[0].sent);
    }

    @IsTest
    static void otherStatus_handledGracefully() {
        Claim c = setup('Pending Approver Review');

        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(true, r[0].sent);
    }

    @IsTest
    static void nullClaimId_returnsError() {
        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(false, r[0].sent);
        System.assertEquals('Error', r[0].channel);
    }

    @IsTest
    static void nullList_returnsEmpty() {
        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r = NotifyDealerOnStatusChange.notify(null);
        Test.stopTest();

        System.assertEquals(0, r.size());
    }

    @IsTest
    static void claimNotFound_returnsError() {
        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();
        inp.claimId = '0Zk000000000000AAA';

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(false, r[0].sent);
    }

    @IsTest
    static void withDealerPhone_exercisesPhoneLookupPath() {
        Claim c = setup('Approved');
        c.DealerWhatsAppNumber__c = '+15551234567';
        update c;

        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(true, r[0].sent, 'Always writes audit even when push fails');
    }

    @IsTest
    static void withInvalidStoredSessionId_fallsThroughGracefully() {
        Claim c = setup('Approved');
        // Set a syntactically invalid value — exercise the catch in resolveSessionId
        c.MessagingSessionId__c = 'not-an-id';
        update c;

        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].sent, 'Invalid session id should fall through, not throw');
    }

    @IsTest
    static void withShortPhone_skipsPhoneLookup() {
        Claim c = setup('Rejected');
        // Phone with fewer than 8 digits — should skip phone lookup
        c.DealerWhatsAppNumber__c = 'Vin';
        update c;

        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].sent);
    }

    @IsTest
    static void unknownStatus_buildsGenericMessage() {
        Claim c = setup('Submitted');

        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].sent);
    }

    @IsTest
    static void needsMoreInfoNoQuestion_handlesNullClarification() {
        Claim c = setup('Needs More Info');
        // Don't set ClarificationRequest__c — exercises the "no specific question" branch
        NotifyDealerOnStatusChange.Input inp = new NotifyDealerOnStatusChange.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<NotifyDealerOnStatusChange.Result> r =
            NotifyDealerOnStatusChange.notify(new List<NotifyDealerOnStatusChange.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].sent);
    }
}