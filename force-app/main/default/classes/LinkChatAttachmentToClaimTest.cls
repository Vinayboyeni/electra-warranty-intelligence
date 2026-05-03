@IsTest
private class LinkChatAttachmentToClaimTest {

    /** Build a Claim record we can link chat attachments to. */
    private static Claim setupClaim() {
        Account dealer = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        return TestDataFactory.createClaim(dealer.Id, v.AssetId);
    }

    /**
     * Insert a ContentVersion + ContentDocumentLink against a stub
     * "session" record. We can't insert a real MessagingSession in tests
     * (license-restricted), so we use the Account/Claim Id as a stand-in
     * for LinkedEntityId — the link helper only cares that there's a
     * ContentDocumentLink to find.
     */
    private static Id createSessionAttachment(Id sessionLikeId, String fileName) {
        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName + '.png',
            VersionData = Blob.valueOf('test-image-bytes'),
            IsMajorVersion = true
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = sessionLikeId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        return cv.Id;
    }

    @IsTest
    static void link_copiesSessionAttachmentToClaim_andReturnsSuccess() {
        Claim c = setupClaim();
        // Use the dealer Account Id as a session stand-in (any record that
        // accepts ContentDocumentLink will do — MessagingSession isn't
        // insertable in unit tests).
        Id sessionStand = c.AccountId;
        createSessionAttachment(sessionStand, 'damage-photo');

        LinkChatAttachmentToClaim.Input inp = new LinkChatAttachmentToClaim.Input();
        inp.claimId = c.Id;
        inp.messagingSessionId = String.valueOf(sessionStand);

        Test.startTest();
        List<LinkChatAttachmentToClaim.Result> out =
            LinkChatAttachmentToClaim.link(new List<LinkChatAttachmentToClaim.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, out.size(), 'one result per input');
        System.assertEquals(true, out[0].success, 'should report success');
        System.assertEquals(1, out[0].filesLinked, 'one file linked');
        System.assert(out[0].fileTitle != null && out[0].fileTitle.contains('damage-photo'),
            'fileTitle should contain the uploaded filename');

        // Verify the link actually landed on the Claim
        Integer linksOnClaim = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, linksOnClaim, 'ContentDocumentLink to Claim was created');
    }

    @IsTest
    static void link_isIdempotent_doesNotDoubleLink() {
        Claim c = setupClaim();
        Id sessionStand = c.AccountId;
        createSessionAttachment(sessionStand, 'invoice');

        LinkChatAttachmentToClaim.Input inp = new LinkChatAttachmentToClaim.Input();
        inp.claimId = c.Id;
        inp.messagingSessionId = String.valueOf(sessionStand);

        Test.startTest();
        // First call: links file
        LinkChatAttachmentToClaim.link(new List<LinkChatAttachmentToClaim.Input>{inp});
        // Second call: should NOT create a duplicate
        List<LinkChatAttachmentToClaim.Result> out2 =
            LinkChatAttachmentToClaim.link(new List<LinkChatAttachmentToClaim.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, out2[0].success, 'second call still succeeds');
        System.assertEquals(0, out2[0].filesLinked, 'no new links on second call');

        Integer linksOnClaim = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, linksOnClaim, 'still only one link after duplicate call');
    }

    @IsTest
    static void link_fallsBackToClaimMessagingSessionId_whenInputBlank() {
        Claim c = setupClaim();
        Id sessionStand = c.AccountId;
        createSessionAttachment(sessionStand, 'fallback-photo');

        // Stamp the session Id on the Claim so the action falls back to it
        c.MessagingSessionId__c = String.valueOf(sessionStand);
        update c;

        LinkChatAttachmentToClaim.Input inp = new LinkChatAttachmentToClaim.Input();
        inp.claimId = c.Id;
        // intentionally omit messagingSessionId — should fall back

        Test.startTest();
        List<LinkChatAttachmentToClaim.Result> out =
            LinkChatAttachmentToClaim.link(new List<LinkChatAttachmentToClaim.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, out[0].success);
        System.assertEquals(1, out[0].filesLinked);
    }

    @IsTest
    static void link_returnsFalse_whenNoSessionFound() {
        Claim c = setupClaim();
        // No MessagingSessionId__c on the Claim, and no input session id

        LinkChatAttachmentToClaim.Input inp = new LinkChatAttachmentToClaim.Input();
        inp.claimId = c.Id;

        Test.startTest();
        List<LinkChatAttachmentToClaim.Result> out =
            LinkChatAttachmentToClaim.link(new List<LinkChatAttachmentToClaim.Input>{inp});
        Test.stopTest();

        System.assertEquals(false, out[0].success, 'should not report success');
        System.assert(out[0].message != null && out[0].message.toLowerCase().contains('session'),
            'message should explain the missing session');
    }

    @IsTest
    static void link_returnsFalse_whenSessionHasNoAttachments() {
        Claim c = setupClaim();
        Id emptySession = c.AccountId;
        // No createSessionAttachment call — session has zero files

        LinkChatAttachmentToClaim.Input inp = new LinkChatAttachmentToClaim.Input();
        inp.claimId = c.Id;
        inp.messagingSessionId = String.valueOf(emptySession);

        Test.startTest();
        List<LinkChatAttachmentToClaim.Result> out =
            LinkChatAttachmentToClaim.link(new List<LinkChatAttachmentToClaim.Input>{inp});
        Test.stopTest();

        System.assertEquals(false, out[0].success);
        System.assert(out[0].message != null && out[0].message.toLowerCase().contains('no files'),
            'message should explain no files: ' + out[0].message);
    }

    @IsTest
    static void link_handlesNullClaimId_gracefully() {
        LinkChatAttachmentToClaim.Input inp = new LinkChatAttachmentToClaim.Input();
        // claimId left null

        Test.startTest();
        List<LinkChatAttachmentToClaim.Result> out =
            LinkChatAttachmentToClaim.link(new List<LinkChatAttachmentToClaim.Input>{inp});
        Test.stopTest();

        System.assertEquals(false, out[0].success);
        System.assert(out[0].message != null && out[0].message.toLowerCase().contains('claim'),
            'should report missing claim id');
    }

    @IsTest
    static void link_handlesNullInputList_gracefully() {
        Test.startTest();
        List<LinkChatAttachmentToClaim.Result> out =
            LinkChatAttachmentToClaim.link(null);
        Test.stopTest();

        System.assertEquals(0, out.size(), 'null input list returns empty result list');
    }
}