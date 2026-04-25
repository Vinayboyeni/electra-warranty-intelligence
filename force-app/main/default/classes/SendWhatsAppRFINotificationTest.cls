@IsTest
private class SendWhatsAppRFINotificationTest {

    @IsTest
    static void testNullInput() {
        List<SendWhatsAppRFINotification.Result> results = SendWhatsAppRFINotification.send(null);
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testNullClaimId() {
        SendWhatsAppRFINotification.Input inp = new SendWhatsAppRFINotification.Input();
        inp.claimId = null;
        Test.startTest();
        List<SendWhatsAppRFINotification.Result> results = SendWhatsAppRFINotification.send(
            new List<SendWhatsAppRFINotification.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].sent);
        System.assertEquals('Error', results[0].channel);
    }

    @IsTest
    static void testClaimNotFound() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        Id deletedId = c.Id;
        delete c;

        SendWhatsAppRFINotification.Input inp = new SendWhatsAppRFINotification.Input();
        inp.claimId = deletedId;
        Test.startTest();
        List<SendWhatsAppRFINotification.Result> results = SendWhatsAppRFINotification.send(
            new List<SendWhatsAppRFINotification.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(false, results[0].sent);
        System.assertEquals('Error', results[0].channel);
    }

    @IsTest
    static void testNoMessageBody() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        // ClarificationRequest__c left blank, no messageBody override

        SendWhatsAppRFINotification.Input inp = new SendWhatsAppRFINotification.Input();
        inp.claimId = c.Id;
        Test.startTest();
        List<SendWhatsAppRFINotification.Result> results = SendWhatsAppRFINotification.send(
            new List<SendWhatsAppRFINotification.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(false, results[0].sent);
        System.assertEquals('Error', results[0].channel);
    }

    @IsTest
    static void testSuccessChatterFallback() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        c.ClarificationRequest__c = 'Please provide repair photos.';
        update c;

        SendWhatsAppRFINotification.Input inp = new SendWhatsAppRFINotification.Input();
        inp.claimId = c.Id;
        Test.startTest();
        List<SendWhatsAppRFINotification.Result> results = SendWhatsAppRFINotification.send(
            new List<SendWhatsAppRFINotification.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(true, results[0].sent);
        System.assert(results[0].channel.contains('Chatter'), 'Expected Chatter fallback, got: ' + results[0].channel);
    }

    @IsTest
    static void testSuccessWithOverrideBody() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        c.DealerWhatsAppNumber__c = '+15551234567';
        update c;

        SendWhatsAppRFINotification.Input inp = new SendWhatsAppRFINotification.Input();
        inp.claimId = c.Id;
        inp.messageBody = 'Please send the OBD-II diagnostic report.';
        Test.startTest();
        List<SendWhatsAppRFINotification.Result> results = SendWhatsAppRFINotification.send(
            new List<SendWhatsAppRFINotification.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(true, results[0].sent);
        // No active MessagingSession in test context — falls back to Chatter
        System.assert(results[0].channel.contains('Chatter'), 'Expected Chatter fallback, got: ' + results[0].channel);
    }
}