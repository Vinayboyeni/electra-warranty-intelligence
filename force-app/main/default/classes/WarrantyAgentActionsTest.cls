/**
 * @description  Comprehensive test class for all 8 Agentforce action classes.
 *               Covers: FindVehicleByVin, CoverageEngine, CreateWarrantyClaim,
 *               GetWarrantyClaimApprovalContext, ApproveWarrantyClaim, RejectWarrantyClaim,
 *               RequestDealerClarification, RouteClaimToApproverQueue, ImageDamageAnalyzer.
 */
@IsTest
private class WarrantyAgentActionsTest {

    // ─────────────────────────────────────────────────────────────────────────
    // SETUP HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static Vehicle createVehicle(String vin) {
        Product2 p = new Product2(Name = 'Test Product', IsActive = true);
        insert p;

        VehicleDefinition vd = new VehicleDefinition(Name = 'Test Def', ProductId = p.Id);
        insert vd;

        Account a = new Account(Name = 'Owner');
        insert a;

        Asset ast = new Asset(Name = 'Test Asset', AccountId = a.Id, Product2Id = p.Id);
        insert ast;

        Vehicle v = new Vehicle(
            Name = 'Test ' + vin, 
            VehicleIdentificationNumber = vin,
            AssetId = ast.Id,
            VehicleDefinitionId = vd.Id
        );
        insert v;
        return v;
    }

    private static Account createDealer(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Contact createCustomer(Id accountId, String firstName) {
        Contact c = new Contact(FirstName = firstName, LastName = 'TestCustomer', AccountId = accountId);
        insert c;
        return c;
    }

    private static Claim createClaim(Id accountId, String status) {
        Claim c = new Claim(
            AccountId = accountId,
            Name      = 'Test Claim ' + Datetime.now().getTime(),
            ClaimType = 'Warranty',
            Status    = status
        );
        insert c;
        return c;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. FindVehicleByVin
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testFindVehicleByVin_found() {
        createVehicle('1HGCM82633A123456');
        Test.startTest();
        FindVehicleByVinInput inp = new FindVehicleByVinInput();
        inp.vin = '1HGCM82633A123456';
        List<FindVehicleByVinResult> results = FindVehicleByVin.findByVin(new List<FindVehicleByVinInput>{ inp });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].vehicleId != null, 'Vehicle ID should be populated');
        System.assertEquals('1HGCM82633A123456', results[0].vin);
    }

    @IsTest
    static void testFindVehicleByVin_notFound() {
        Test.startTest();
        FindVehicleByVinInput inp = new FindVehicleByVinInput();
        inp.vin = 'XXXXXXXXXXXX99999';
        List<FindVehicleByVinResult> results = FindVehicleByVin.findByVin(new List<FindVehicleByVinInput>{ inp });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].vehicleId == null, 'Vehicle ID should be null for missing VIN');
    }

    @IsTest
    static void testFindVehicleByVin_nullInputs() {
        Test.startTest();
        List<FindVehicleByVinResult> results = FindVehicleByVin.findByVin(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testFindVehicleByVin_byVinBlank() {
        Test.startTest();
        try {
            FindVehicleByVin.byVin(null);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. CoverageEngine
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCoverageEngine_invocable() {
        Test.startTest();
        CoverageEvaluateInput inp = new CoverageEvaluateInput();
        inp.vehicleId = '001000000000001AAA';
        inp.odometer  = 30000;
        inp.partCategory = 'Battery';
        List<CoverageEvaluateResult> results = CoverageEngine.evaluateInvocable(new List<CoverageEvaluateInput>{ inp });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(String.isNotBlank(results[0].eligibility), 'Eligibility should be set');
    }

    @IsTest
    static void testCoverageEngine_nullVehicleId() {
        Test.startTest();
        try {
            CoverageEngine.evaluate(null, 10000, 'Battery');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testCoverageEngine_nullInputList() {
        Test.startTest();
        List<CoverageEvaluateResult> results = CoverageEngine.evaluateInvocable(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. CreateWarrantyClaim
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateWarrantyClaim_success() {
        Account dealer = createDealer('Dealer Beta');
        Contact customer = createCustomer(dealer.Id, 'Bob');
        createVehicle('2HGCM82633A999001');

        Test.startTest();
        CreateWarrantyClaimInput inp = new CreateWarrantyClaimInput();
        inp.vin            = '2HGCM82633A999001';
        inp.dealerId       = dealer.Id;
        inp.customerId     = customer.Id;
        inp.odometer       = 45000;
        inp.symptom        = 'Battery not charging';
        inp.partCategory   = 'Battery';
        inp.channel        = 'WhatsApp';
        inp.authorizationType = 'Prior Authorization';
        inp.priority       = 'Normal';
        inp.repairOrderNumber = 'RO-2024-001';
        inp.approverQueue  = 'Warranty Claim Approvers';
        List<CreateWarrantyClaimResult> results = CreateWarrantyClaim.createClaimInvocable(
            new List<CreateWarrantyClaimInput>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].claimId != null, 'Claim should be created');
        System.assertEquals('Submitted', results[0].status);
    }

    @IsTest
    static void testCreateWarrantyClaim_vehicleNotFound() {
        Account dealer = createDealer('Dealer Gamma');
        Contact customer = createCustomer(dealer.Id, 'Charlie');

        Test.startTest();
        CreateWarrantyClaimInput inp = new CreateWarrantyClaimInput();
        inp.vin        = 'BADVIN00000000001';
        inp.dealerId   = dealer.Id;
        inp.customerId = customer.Id;
        inp.odometer   = 10000;
        inp.symptom    = 'Drive motor failure';
        List<CreateWarrantyClaimResult> results = CreateWarrantyClaim.createClaimInvocable(
            new List<CreateWarrantyClaimInput>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Error', results[0].status);
    }

    @IsTest
    static void testCreateWarrantyClaim_nullInput() {
        Test.startTest();
        List<CreateWarrantyClaimResult> results = CreateWarrantyClaim.createClaimInvocable(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testCreateWarrantyClaim_submissionChannelAlias() {
        Account dealer = createDealer('Dealer Delta');
        Contact customer = createCustomer(dealer.Id, 'Dave');
        createVehicle('3HGCM82633A777001');

        Test.startTest();
        CreateWarrantyClaimInput inp = new CreateWarrantyClaimInput();
        inp.vin               = '3HGCM82633A777001';
        inp.dealerId          = dealer.Id;
        inp.customerId        = customer.Id;
        inp.odometer          = 20000;
        inp.symptom           = 'Pump noise';
        inp.submissionChannel = 'Web'; // use alias
        List<CreateWarrantyClaimResult> results = CreateWarrantyClaim.createClaimInvocable(
            new List<CreateWarrantyClaimInput>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].claimId != null, 'Claim should be created via alias channel');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. ApproveWarrantyClaim
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testApproveWarrantyClaim_success() {
        Account dealer = createDealer('Dealer Epsilon');
        Claim c = createClaim(dealer.Id, 'Submitted');

        Test.startTest();
        ApproveWarrantyClaim.Input inp = new ApproveWarrantyClaim.Input();
        inp.claimId           = c.Id;
        inp.decisionRationale = 'Covered under 5-year motor warranty.';
        inp.approverSlackRef  = 'T12345678/P1234567890';
        List<ApproveWarrantyClaim.Result> results = ApproveWarrantyClaim.approve(
            new List<ApproveWarrantyClaim.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Success', results[0].status);
        System.assertEquals('Approved', [SELECT Status FROM Claim WHERE Id = :c.Id].Status);
    }

    @IsTest
    static void testApproveWarrantyClaim_nullClaimId() {
        Test.startTest();
        ApproveWarrantyClaim.Input inp = new ApproveWarrantyClaim.Input();
        inp.claimId = null;
        List<ApproveWarrantyClaim.Result> results = ApproveWarrantyClaim.approve(
            new List<ApproveWarrantyClaim.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testApproveWarrantyClaim_nullList() {
        Test.startTest();
        List<ApproveWarrantyClaim.Result> results = ApproveWarrantyClaim.approve(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. RejectWarrantyClaim
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testRejectWarrantyClaim_success() {
        Account dealer = createDealer('Dealer Zeta');
        Claim c = createClaim(dealer.Id, 'Submitted');

        Test.startTest();
        RejectWarrantyClaim.Input inp = new RejectWarrantyClaim.Input();
        inp.claimId           = c.Id;
        inp.reasonCode        = 'NotCovered';
        inp.decisionRationale = 'Vehicle is outside warranty period.';
        inp.approverSlackRef  = 'T11111111/P9999999999';
        List<RejectWarrantyClaim.Result> results = RejectWarrantyClaim.reject(
            new List<RejectWarrantyClaim.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Success', results[0].status);
        System.assertEquals('Rejected', [SELECT Status FROM Claim WHERE Id = :c.Id].Status);
    }

    @IsTest
    static void testRejectWarrantyClaim_nullClaimId() {
        Test.startTest();
        RejectWarrantyClaim.Input inp = new RejectWarrantyClaim.Input();
        inp.claimId = null;
        List<RejectWarrantyClaim.Result> results = RejectWarrantyClaim.reject(
            new List<RejectWarrantyClaim.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testRejectWarrantyClaim_nullList() {
        Test.startTest();
        List<RejectWarrantyClaim.Result> results = RejectWarrantyClaim.reject(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. RequestDealerClarification
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testRequestDealerClarification_success() {
        Account dealer = createDealer('Dealer Eta');
        Claim c = createClaim(dealer.Id, 'Submitted');

        Test.startTest();
        RequestDealerClarification.Input inp = new RequestDealerClarification.Input();
        inp.claimId              = c.Id;
        inp.clarificationRequest = 'Please provide RO attachment and mileage documentation.';
        inp.approverSlackRef     = 'T22222222/P8888888888';
        inp.requiresFollowUp     = true;
        List<RequestDealerClarification.Result> results = RequestDealerClarification.requestClarification(
            new List<RequestDealerClarification.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Success', results[0].status);
        Claim updated = [SELECT Status, RequiresFollowUp__c FROM Claim WHERE Id = :c.Id];
        System.assertEquals('Needs More Info', updated.Status);
        System.assertEquals(true, updated.RequiresFollowUp__c);
    }

    @IsTest
    static void testRequestDealerClarification_defaultFollowUp() {
        Account dealer = createDealer('Dealer Theta');
        Claim c = createClaim(dealer.Id, 'Submitted');

        Test.startTest();
        RequestDealerClarification.Input inp = new RequestDealerClarification.Input();
        inp.claimId              = c.Id;
        inp.clarificationRequest = 'Missing odometer photo.';
        // requiresFollowUp left null — should default to true
        List<RequestDealerClarification.Result> results = RequestDealerClarification.requestClarification(
            new List<RequestDealerClarification.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, [SELECT RequiresFollowUp__c FROM Claim WHERE Id = :c.Id].RequiresFollowUp__c);
    }

    @IsTest
    static void testRequestDealerClarification_nullList() {
        Test.startTest();
        List<RequestDealerClarification.Result> results = RequestDealerClarification.requestClarification(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. GetWarrantyClaimApprovalContext
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testGetApprovalContext_byClaimId() {
        Account dealer = createDealer('Dealer Iota');
        Claim c = createClaim(dealer.Id, 'Submitted');

        Test.startTest();
        GetWarrantyClaimApprovalContext.Input inp = new GetWarrantyClaimApprovalContext.Input();
        inp.claimId = c.Id;
        List<GetWarrantyClaimApprovalContext.Result> results = GetWarrantyClaimApprovalContext.getContext(
            new List<GetWarrantyClaimApprovalContext.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(c.Id, results[0].claimId);
        System.assertEquals('Pending Approver Review', results[0].status);
        System.assert(String.isNotBlank(results[0].slackMessageBody), 'Slack body should be built');
    }

    @IsTest
    static void testGetApprovalContext_byClaimNumber() {
        Account dealer = createDealer('Dealer Kappa');
        Claim c = createClaim(dealer.Id, 'Submitted');
        String claimName = [SELECT Name FROM Claim WHERE Id = :c.Id].Name;

        Test.startTest();
        GetWarrantyClaimApprovalContext.Input inp = new GetWarrantyClaimApprovalContext.Input();
        inp.claimNumber = claimName;
        List<GetWarrantyClaimApprovalContext.Result> results = GetWarrantyClaimApprovalContext.getContext(
            new List<GetWarrantyClaimApprovalContext.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(c.Id, results[0].claimId);
    }

    @IsTest
    static void testGetApprovalContext_nullInput() {
        Test.startTest();
        List<GetWarrantyClaimApprovalContext.Result> results = GetWarrantyClaimApprovalContext.getContext(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testGetApprovalContext_notFound() {
        Test.startTest();
        GetWarrantyClaimApprovalContext.Input inp = new GetWarrantyClaimApprovalContext.Input();
        inp.claimNumber = 'CLM-DOESNOTEXIST-9999';
        List<GetWarrantyClaimApprovalContext.Result> results = GetWarrantyClaimApprovalContext.getContext(
            new List<GetWarrantyClaimApprovalContext.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. RouteClaimToApproverQueue
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testRouteClaimToApproverQueue_noQueue() {
        Account dealer = createDealer('Dealer Lambda');
        Claim c = createClaim(dealer.Id, 'Submitted');

        Test.startTest();
        RouteClaimToApproverQueue.Input inp = new RouteClaimToApproverQueue.Input();
        inp.claimId = c.Id;
        List<RouteClaimToApproverQueue.Result> results = RouteClaimToApproverQueue.route(
            new List<RouteClaimToApproverQueue.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(String.isNotBlank(results[0].status), 'Status should be set');
    }

    @IsTest
    static void testRouteClaimToApproverQueue_nullClaimId() {
        Test.startTest();
        RouteClaimToApproverQueue.Input inp = new RouteClaimToApproverQueue.Input();
        inp.claimId = null;
        List<RouteClaimToApproverQueue.Result> results = RouteClaimToApproverQueue.route(
            new List<RouteClaimToApproverQueue.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testRouteClaimToApproverQueue_nullList() {
        Test.startTest();
        List<RouteClaimToApproverQueue.Result> results = RouteClaimToApproverQueue.route(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. ImageDamageAnalyzer
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testImageDamageAnalyzer_pump() {
        Account dealer = createDealer('Dealer Mu');
        Claim c = createClaim(dealer.Id, 'Submitted');

        Test.startTest();
        ImageDamageAnalyzer.Input inp = new ImageDamageAnalyzer.Input();
        inp.claimId  = c.Id;
        inp.partName = 'Coolant Pump';
        List<ImageDamageAnalyzer.Result> results = ImageDamageAnalyzer.analyze(
            new List<ImageDamageAnalyzer.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isDamaged);
        System.assert(String.isNotBlank(results[0].analysisResult));
        System.assert(String.isNotBlank([SELECT AI_Image_Analysis__c FROM Claim WHERE Id = :c.Id].AI_Image_Analysis__c));
    }

    @IsTest
    static void testImageDamageAnalyzer_battery() {
        Account dealer = createDealer('Dealer Nu');
        Claim c = createClaim(dealer.Id, 'Submitted');

        Test.startTest();
        ImageDamageAnalyzer.Input inp = new ImageDamageAnalyzer.Input();
        inp.claimId  = c.Id;
        inp.partName = 'Battery Pack';
        List<ImageDamageAnalyzer.Result> results = ImageDamageAnalyzer.analyze(
            new List<ImageDamageAnalyzer.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isDamaged);
    }

    @IsTest
    static void testImageDamageAnalyzer_generic() {
        Account dealer = createDealer('Dealer Xi');
        Claim c = createClaim(dealer.Id, 'Submitted');

        Test.startTest();
        ImageDamageAnalyzer.Input inp = new ImageDamageAnalyzer.Input();
        inp.claimId  = c.Id;
        inp.partName = 'Drive Motor';
        List<ImageDamageAnalyzer.Result> results = ImageDamageAnalyzer.analyze(
            new List<ImageDamageAnalyzer.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isDamaged);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. LinkUploadedEvidenceToClaim
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testLinkUploadedEvidence_emptyInput() {
        Account dealer = createDealer('Dealer Omicron');
        Claim c = createClaim(dealer.Id, 'Submitted');

        Test.startTest();
        LinkUploadedEvidenceToClaim.Input inp = new LinkUploadedEvidenceToClaim.Input();
        inp.claimId       = c.Id;
        inp.attachmentIds = '';
        List<LinkUploadedEvidenceToClaim.Result> results = LinkUploadedEvidenceToClaim.linkEvidence(
            new List<LinkUploadedEvidenceToClaim.Input>{ inp }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(0, results[0].linkedCount);
    }

    @IsTest
    static void testLinkUploadedEvidence_nullInput() {
        Test.startTest();
        List<LinkUploadedEvidenceToClaim.Result> results = LinkUploadedEvidenceToClaim.linkEvidence(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }
}