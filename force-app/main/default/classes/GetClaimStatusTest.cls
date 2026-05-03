@IsTest
private class GetClaimStatusTest {

    private static Claim setupClaim(String status) {
        Account dealer = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(dealer.Id, v.AssetId);
        c.Status = status;
        c.PartCategory__c = 'Battery';
        c.SLA_Due_Date__c = Datetime.now().addHours(24);
        c.EligibilityRationale__c = 'Coverage active';
        update c;
        return c;
    }

    @IsTest
    static void lookupByName_findsClaim() {
        Claim c = setupClaim('Pending Approver Review');
        GetClaimStatus.Input inp = new GetClaimStatus.Input();
        inp.claimNumber = c.Name;

        Test.startTest();
        List<GetClaimStatus.Result> r = GetClaimStatus.getStatus(new List<GetClaimStatus.Input>{inp});
        Test.stopTest();

        System.assertEquals(1, r.size());
        System.assertEquals(true, r[0].claimFound);
        System.assertEquals('Pending Approver Review', r[0].claimStatus);
    }

    @IsTest
    static void lookupByVin_findsClaim() {
        Claim c = setupClaim('Pending Approver Review');
        Vehicle v = [SELECT VehicleIdentificationNumber FROM Vehicle WHERE AssetId = :c.Vehicle__c LIMIT 1];

        GetClaimStatus.Input inp = new GetClaimStatus.Input();
        inp.vin = v.VehicleIdentificationNumber;

        Test.startTest();
        List<GetClaimStatus.Result> r = GetClaimStatus.getStatus(new List<GetClaimStatus.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].claimFound, 'Should find by VIN');
    }

    @IsTest
    static void lookupNotFound_returnsClaimFoundFalse() {
        GetClaimStatus.Input inp = new GetClaimStatus.Input();
        inp.claimNumber = 'WC-FAKE9';

        Test.startTest();
        List<GetClaimStatus.Result> r = GetClaimStatus.getStatus(new List<GetClaimStatus.Input>{inp});
        Test.stopTest();

        System.assertEquals(false, r[0].claimFound);
        System.assertNotEquals(null, r[0].nextStep);
    }

    @IsTest
    static void lookupNullInputs_handlesGracefully() {
        GetClaimStatus.Input inp = new GetClaimStatus.Input();

        Test.startTest();
        List<GetClaimStatus.Result> r = GetClaimStatus.getStatus(new List<GetClaimStatus.Input>{inp});
        Test.stopTest();

        System.assertEquals(false, r[0].claimFound);
    }

    @IsTest
    static void lookupNullList_returnsEmpty() {
        Test.startTest();
        List<GetClaimStatus.Result> r = GetClaimStatus.getStatus(null);
        Test.stopTest();

        System.assertEquals(0, r.size());
    }

    @IsTest
    static void lookupNeedsMoreInfo_populatesClarificationQuestion() {
        Claim c = setupClaim('Needs More Info');
        c.ClarificationRequest__c = 'Please send invoice';
        update c;

        GetClaimStatus.Input inp = new GetClaimStatus.Input();
        inp.claimNumber = c.Name;

        Test.startTest();
        List<GetClaimStatus.Result> r = GetClaimStatus.getStatus(new List<GetClaimStatus.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].claimFound);
        System.assertEquals('Please send invoice', r[0].clarificationQuestion);
    }

    @IsTest
    static void lookupApproved_returnsApprovalNextStep() {
        Claim c = setupClaim('Approved');
        c.ApprovalDate__c = Datetime.now();
        update c;

        GetClaimStatus.Input inp = new GetClaimStatus.Input();
        inp.claimNumber = c.Name;

        Test.startTest();
        List<GetClaimStatus.Result> r = GetClaimStatus.getStatus(new List<GetClaimStatus.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].claimFound);
        System.assertEquals('Approved', r[0].claimStatus);
    }

    @IsTest
    static void lookupRejected_returnsRejectionNextStep() {
        Claim c = setupClaim('Rejected');
        c.RejectionDate__c = Datetime.now();
        update c;

        GetClaimStatus.Input inp = new GetClaimStatus.Input();
        inp.claimNumber = c.Name;

        Test.startTest();
        List<GetClaimStatus.Result> r = GetClaimStatus.getStatus(new List<GetClaimStatus.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].claimFound);
        System.assertEquals('Rejected', r[0].claimStatus);
    }

    @IsTest
    static void lookupVinNotFound_returnsClaimFoundFalse() {
        GetClaimStatus.Input inp = new GetClaimStatus.Input();
        inp.vin = 'NOSUCHVIN12345678';

        Test.startTest();
        List<GetClaimStatus.Result> r = GetClaimStatus.getStatus(new List<GetClaimStatus.Input>{inp});
        Test.stopTest();

        System.assertEquals(false, r[0].claimFound);
    }

    @IsTest
    static void lookupSubmittedStatus_returnsRoutingMessage() {
        Claim c = setupClaim('Submitted');
        GetClaimStatus.Input inp = new GetClaimStatus.Input();
        inp.claimNumber = c.Name;

        Test.startTest();
        List<GetClaimStatus.Result> r = GetClaimStatus.getStatus(new List<GetClaimStatus.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].claimFound);
        System.assertNotEquals(null, r[0].nextStep);
    }
}