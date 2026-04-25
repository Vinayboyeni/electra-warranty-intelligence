@IsTest
private class CoverageEngineTest {
    @TestSetup
    static void setupData() {
        Vehicle v = TestDataFactory.createVehicle();
        TestDataFactory.createWarranty(v.AssetId);
    }

    @IsTest
    static void testLikelyCoverage() {
        Vehicle v = [SELECT Id FROM Vehicle LIMIT 1];
        
        CoverageEvaluateInput req = new CoverageEvaluateInput();
        req.vehicleId = v.Id;
        req.odometer = 10000;
        req.partCategory = 'Battery';
        
        Test.startTest();
        List<CoverageEvaluateResult> results = CoverageEngine.evaluateInvocable(new List<CoverageEvaluateInput>{ req });
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assertEquals('Likely', results[0].eligibility);
        System.assert(results[0].rationale.contains('Eligibility: Likely'), 'Expected Likely rationale, got: ' + results[0].rationale);
    }

    @IsTest
    static void testNotCoveredMileage() {
        Vehicle v = [SELECT Id FROM Vehicle LIMIT 1];
        
        CoverageEvaluateInput req = new CoverageEvaluateInput();
        req.vehicleId = v.Id;
        req.odometer = 60000; // Over cap
        req.partCategory = 'Battery';
        
        Test.startTest();
        List<CoverageEvaluateResult> results = CoverageEngine.evaluateInvocable(new List<CoverageEvaluateInput>{ req });
        Test.stopTest();
        
        System.assertEquals('Not Covered', results[0].eligibility);
    }
}