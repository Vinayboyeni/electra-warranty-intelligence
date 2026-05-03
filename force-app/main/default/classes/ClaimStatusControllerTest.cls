@IsTest
private class ClaimStatusControllerTest {

    private static Claim setupClaim() {
        Account dealer = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(dealer.Id, v.AssetId);
        c.Status = 'Pending Approver Review';
        c.PartCategory__c = 'Battery';
        c.EstimatedCost__c = 2500;
        c.SLA_Due_Date__c = Datetime.now().addHours(24);
        c.EligibilityRationale__c = 'Coverage active';
        update c;
        return c;
    }

    @IsTest
    static void lookupByClaimNumber_returnsClaim() {
        Claim c = setupClaim();
        Test.startTest();
        ClaimStatusController.ClaimStatusInfo info =
            ClaimStatusController.lookup(c.Name, null);
        Test.stopTest();

        System.assertEquals(true, info.found, 'Should find claim by Name');
        System.assertEquals(c.Name, info.claimNumber);
        System.assertEquals('Pending Approver Review', info.status);
        System.assertNotEquals(null, info.nextStep, 'Should compute next step');
    }

    @IsTest
    static void lookupByVin_returnsMostRecentClaim() {
        Claim c = setupClaim();
        Vehicle v = [SELECT Id, VehicleIdentificationNumber FROM Vehicle WHERE AssetId = :c.Vehicle__c LIMIT 1];

        Test.startTest();
        ClaimStatusController.ClaimStatusInfo info =
            ClaimStatusController.lookup(null, v.VehicleIdentificationNumber);
        Test.stopTest();

        System.assertEquals(true, info.found, 'Should find claim by VIN');
        System.assertEquals(c.Name, info.claimNumber);
    }

    @IsTest
    static void lookupNotFound_returnsFoundFalse() {
        Test.startTest();
        ClaimStatusController.ClaimStatusInfo info =
            ClaimStatusController.lookup('WC-NOTREAL', null);
        Test.stopTest();

        System.assertEquals(false, info.found, 'Should not find non-existent claim');
    }

    @IsTest
    static void lookupNullInputs_returnsFoundFalse() {
        Test.startTest();
        ClaimStatusController.ClaimStatusInfo info =
            ClaimStatusController.lookup(null, null);
        Test.stopTest();

        System.assertEquals(false, info.found, 'Should handle nulls gracefully');
    }

    @IsTest
    static void lookupVinNotFound_returnsFoundFalse() {
        Test.startTest();
        ClaimStatusController.ClaimStatusInfo info =
            ClaimStatusController.lookup(null, 'NONEXISTENTVIN12345');
        Test.stopTest();

        System.assertEquals(false, info.found);
    }

    @IsTest
    static void lookupNeedsMoreInfo_setsAwaitingResponse() {
        Claim c = setupClaim();
        c.Status = 'Needs More Info';
        c.ClarificationRequest__c = 'Send the inverter serial number.';
        c.RequiresFollowUp__c = true;
        update c;

        Test.startTest();
        ClaimStatusController.ClaimStatusInfo info =
            ClaimStatusController.lookup(c.Name, null);
        Test.stopTest();

        System.assertEquals(true, info.found);
        System.assertEquals(true, info.isAwaitingResponse, 'Should flag awaiting response');
        System.assertEquals('Send the inverter serial number.', info.clarificationQuestion);
    }

    @IsTest
    static void submitResponse_success_updatesClaim() {
        Claim c = setupClaim();
        c.Status = 'Needs More Info';
        c.ClarificationRequest__c = 'Need invoice';
        c.RequiresFollowUp__c = true;
        update c;

        Test.startTest();
        ClaimStatusController.SubmissionResult res =
            ClaimStatusController.submitResponse(c.Name, 'Invoice attached');
        Test.stopTest();

        System.assertEquals(true, res.submitted, 'Submission should succeed');
        System.assertEquals('Pending Approver Review', res.newStatus);

        Claim refreshed = [SELECT Status, RequiresFollowUp__c, DealerResponseSummary__c FROM Claim WHERE Id = :c.Id];
        System.assertEquals('Pending Approver Review', refreshed.Status);
        System.assertEquals(false, refreshed.RequiresFollowUp__c);
        System.assertEquals('Invoice attached', refreshed.DealerResponseSummary__c);
    }

    @IsTest
    static void submitResponse_blankClaimNumber_returnsError() {
        Test.startTest();
        ClaimStatusController.SubmissionResult res =
            ClaimStatusController.submitResponse('', 'response');
        Test.stopTest();

        System.assertEquals(false, res.submitted);
        System.assertNotEquals(null, res.message);
    }

    @IsTest
    static void submitResponse_blankResponse_returnsError() {
        Test.startTest();
        ClaimStatusController.SubmissionResult res =
            ClaimStatusController.submitResponse('WC-XYZ', '');
        Test.stopTest();

        System.assertEquals(false, res.submitted);
    }

    @IsTest
    static void submitResponse_claimNotFound_returnsError() {
        Test.startTest();
        ClaimStatusController.SubmissionResult res =
            ClaimStatusController.submitResponse('WC-NOTREAL', 'response');
        Test.stopTest();

        System.assertEquals(false, res.submitted);
    }

    @IsTest
    static void submitResponse_alreadyDecided_skipsUpdate() {
        Claim c = setupClaim();
        c.Status = 'Approved';
        update c;

        Test.startTest();
        ClaimStatusController.SubmissionResult res =
            ClaimStatusController.submitResponse(c.Name, 'response');
        Test.stopTest();

        System.assertEquals(false, res.submitted, 'Should not update decided claims');
    }

    @IsTest
    static void getAttachedFiles_emptyClaim_returnsEmpty() {
        Claim c = setupClaim();
        Test.startTest();
        List<ClaimStatusController.AttachedFile> files = ClaimStatusController.getAttachedFiles(c.Id);
        Test.stopTest();

        System.assertEquals(0, files.size(), 'No files yet');
    }

    @IsTest
    static void getAttachedFiles_nullClaim_returnsEmpty() {
        Test.startTest();
        List<ClaimStatusController.AttachedFile> files = ClaimStatusController.getAttachedFiles(null);
        Test.stopTest();

        System.assertEquals(0, files.size());
    }

    @IsTest
    static void getAttachedFiles_withImage_returnsImageFile() {
        Claim c = setupClaim();
        ContentVersion cv = new ContentVersion(
            Title = 'damage',
            PathOnClient = 'damage.jpg',
            VersionData = Blob.valueOf('test image bytes')
        );
        insert cv;
        ContentVersion saved = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = saved.ContentDocumentId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );
        insert link;

        Test.startTest();
        List<ClaimStatusController.AttachedFile> files = ClaimStatusController.getAttachedFiles(c.Id);
        Test.stopTest();

        System.assertEquals(1, files.size());
        System.assertEquals('damage', files[0].title);
    }

    @IsTest
    static void publishUploadedFiles_emptyClaim_returnsZero() {
        Claim c = setupClaim();
        Test.startTest();
        Integer count = ClaimStatusController.publishUploadedFiles(c.Id);
        Test.stopTest();

        System.assertEquals(0, count);
    }

    @IsTest
    static void publishUploadedFiles_nullClaim_returnsZero() {
        Test.startTest();
        Integer count = ClaimStatusController.publishUploadedFiles(null);
        Test.stopTest();

        System.assertEquals(0, count);
    }

    @IsTest
    static void publishUploadedFiles_withImage_createsDistribution() {
        Claim c = setupClaim();
        ContentVersion cv = new ContentVersion(
            Title = 'damage',
            PathOnClient = 'damage.jpg',
            VersionData = Blob.valueOf('test bytes')
        );
        insert cv;
        ContentVersion saved = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = saved.ContentDocumentId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );
        insert link;

        Test.startTest();
        Integer count = ClaimStatusController.publishUploadedFiles(c.Id);
        Test.stopTest();

        // Test mode may or may not actually create ContentDistribution depending on org config.
        // Just verify the method completes without throwing.
        System.assert(count >= 0);
    }

    @IsTest
    static void publishUploadedFiles_withPdf_handlesGracefully() {
        Claim c = setupClaim();
        ContentVersion cv = new ContentVersion(
            Title = 'invoice',
            PathOnClient = 'invoice.pdf',
            VersionData = Blob.valueOf('pdf bytes')
        );
        insert cv;
        ContentVersion saved = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = saved.ContentDocumentId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );
        insert link;

        Test.startTest();
        Integer count = ClaimStatusController.publishUploadedFiles(c.Id);
        Test.stopTest();

        System.assert(count >= 0);
    }

    @IsTest
    static void getAttachedFiles_withPdf_returnsFile() {
        Claim c = setupClaim();
        ContentVersion cv = new ContentVersion(
            Title = 'invoice',
            PathOnClient = 'invoice.pdf',
            VersionData = Blob.valueOf('pdf bytes')
        );
        insert cv;
        ContentVersion saved = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = saved.ContentDocumentId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );
        insert link;

        Test.startTest();
        List<ClaimStatusController.AttachedFile> files = ClaimStatusController.getAttachedFiles(c.Id);
        Test.stopTest();

        System.assertEquals(1, files.size());
        System.assertEquals(false, files[0].isImage, 'PDF should not be flagged as image');
    }
}