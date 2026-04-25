@IsTest
private class LinkUploadedEvidenceToClaimTest {
    @IsTest
    static void testLink() {
        Account a = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(a.Id, v.AssetId);
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDocument.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        LinkUploadedEvidenceToClaim.Input req = new LinkUploadedEvidenceToClaim.Input();
        req.claimId = c.Id;
        req.attachmentIdCollection = new List<String>{ conDocId };
        
        Test.startTest();
        List<LinkUploadedEvidenceToClaim.Result> res = LinkUploadedEvidenceToClaim.linkEvidence(new List<LinkUploadedEvidenceToClaim.Input>{ req });
        Test.stopTest();
        
        System.assertNotEquals(null, res);
        System.assertEquals(1, res[0].linkedCount);
    }
}