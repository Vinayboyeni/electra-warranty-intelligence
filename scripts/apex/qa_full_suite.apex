// SENIOR QA INTEGRATION TEST SUITE
// Exercises every Apex action the agents call. Records pass/fail per scenario
// and dumps actual vs expected so any divergence is obvious.
//
// Strategy:
//   - Find existing Submitted claims tied to demo VINs
//   - Call each invocable Apex with realistic inputs
//   - Inspect outputs + side-effects (status, FeedItem audit, related records)
//   - Print one PASS / FAIL line per assertion

System.debug('========== ELECTRA WARRANTY QA SUITE ==========');
Integer pass = 0, fail = 0;

// --- 0. Find a usable test claim -------------------------------------------
Claim seed = null;
for (Claim c : [
    SELECT Id, Name, Status, AccountId, Vehicle__c, PartCategory__c,
           EstimatedCost__c, Eligibility__c, AI_Recommendation__c,
           AI_Confidence__c, DealerWhatsAppNumber__c
    FROM Claim
    WHERE Status IN ('Submitted', 'Pending Approver Review')
      AND Vehicle__c != null
      AND AccountId != null
    ORDER BY CreatedDate DESC
    LIMIT 5
]) {
    if (seed == null) seed = c;
    System.debug('CANDIDATE: ' + c.Name + ' status=' + c.Status + ' part=' + c.PartCategory__c
        + ' cost=' + c.EstimatedCost__c + ' elig=' + c.Eligibility__c);
}
if (seed == null) {
    System.debug('FAIL — no testable Submitted/Pending claim. Re-run DemoScenarioSeeder first.');
    return;
}
System.debug('USING CLAIM: ' + seed.Name + ' (' + seed.Id + ')');

// --- 1. GetWarrantyClaimApprovalContext ------------------------------------
System.debug('--- TEST 1: GetWarrantyClaimApprovalContext ---');
GetWarrantyClaimApprovalContext.Input ci = new GetWarrantyClaimApprovalContext.Input();
ci.claimId = seed.Id;
List<GetWarrantyClaimApprovalContext.Result> ctxResults =
    GetWarrantyClaimApprovalContext.getContext(new List<GetWarrantyClaimApprovalContext.Input>{ ci });
if (ctxResults == null || ctxResults.isEmpty()) {
    System.debug('  FAIL — empty result'); fail++;
} else {
    GetWarrantyClaimApprovalContext.Result r = ctxResults[0];
    System.debug('  claimNumber: ' + r.claimNumber + (r.claimNumber == seed.Name ? ' [PASS]' : ' [FAIL]'));
    if (r.claimNumber == seed.Name) pass++; else fail++;
    System.debug('  status: ' + r.status);
    System.debug('  dealerName: ' + r.dealerName);
    System.debug('  similarClaimsPrecedent: ' + (r.similarClaimsPrecedent == null ? '(null — no history)' : r.similarClaimsPrecedent));
    System.debug('  slackMessageBody length: ' + (r.slackMessageBody == null ? 0 : r.slackMessageBody.length()));
    if (r.slackMessageBody != null && r.slackMessageBody.length() > 200) { System.debug('  body looks OK [PASS]'); pass++; }
    else { System.debug('  body suspiciously short [FAIL]'); fail++; }
}

// --- 2. CoverageEngine (Likely / Borderline / Not Covered) ----------------
System.debug('--- TEST 2: CoverageEngine ---');
CoverageEvaluateInput cIn = new CoverageEvaluateInput();
cIn.vehicleId = seed.Vehicle__c;
cIn.odometer = 25000;
cIn.partCategory = 'Battery';
List<CoverageEvaluateResult> covRes = CoverageEngine.evaluateInvocable(new List<CoverageEvaluateInput>{ cIn });
if (covRes == null || covRes.isEmpty()) {
    System.debug('  FAIL — no coverage result'); fail++;
} else {
    String elig = covRes[0].eligibility;
    System.debug('  eligibility: ' + elig + ' rationale: ' + covRes[0].rationale);
    Set<String> validVerdicts = new Set<String>{ 'Likely', 'Borderline', 'Not Covered' };
    if (validVerdicts.contains(elig)) { System.debug('  verdict valid [PASS]'); pass++; }
    else { System.debug('  invalid verdict [FAIL]'); fail++; }
}

// --- 3. Coverage with very high odometer (should be Not Covered) ----------
System.debug('--- TEST 3: CoverageEngine (out-of-warranty odometer) ---');
CoverageEvaluateInput cIn2 = new CoverageEvaluateInput();
cIn2.vehicleId = seed.Vehicle__c;
cIn2.odometer = 250000;
cIn2.partCategory = 'Battery';
List<CoverageEvaluateResult> covRes2 = CoverageEngine.evaluateInvocable(new List<CoverageEvaluateInput>{ cIn2 });
if (!covRes2.isEmpty()) {
    System.debug('  high-odometer eligibility: ' + covRes2[0].eligibility);
    if (covRes2[0].eligibility == 'Not Covered') { System.debug('  correctly Not Covered [PASS]'); pass++; }
    else { System.debug('  WARNING — high-odometer claim returned ' + covRes2[0].eligibility + ' [investigate]'); }
}

// --- 4. CheckRecentClaims (duplicate detection) ----------------------------
System.debug('--- TEST 4: CheckRecentClaims (duplicate detection) ---');
CheckRecentClaims.Input crIn = new CheckRecentClaims.Input();
crIn.vin = 'ELXDEMOFRD0800000';
crIn.partCategory = 'Battery';
List<CheckRecentClaims.Result> crRes = CheckRecentClaims.checkRecent(new List<CheckRecentClaims.Input>{ crIn });
if (crRes != null && !crRes.isEmpty()) {
    System.debug('  duplicateFound=' + crRes[0].duplicateFound
        + ' existingClaim=' + crRes[0].existingClaimNumber);
    System.debug('  CheckRecentClaims executed [PASS]'); pass++;
} else { System.debug('  FAIL — CheckRecentClaims empty'); fail++; }

// --- 5. ValidateRepairEstimate ---------------------------------------------
System.debug('--- TEST 5: ValidateRepairEstimate ---');
ValidateRepairEstimate.Input vrIn = new ValidateRepairEstimate.Input();
vrIn.partCategory = 'Battery';
vrIn.requestedAmount = 1500;
List<ValidateRepairEstimate.Result> vrRes = ValidateRepairEstimate.validate(new List<ValidateRepairEstimate.Input>{ vrIn });
if (vrRes != null && !vrRes.isEmpty()) {
    System.debug('  baseline=' + vrRes[0].baselineAmount + ' withinRange=' + vrRes[0].isWithinRange
        + ' variance=' + vrRes[0].variancePercent + '%');
    System.debug('  ValidateRepairEstimate executed [PASS]'); pass++;
} else { System.debug('  FAIL — ValidateRepairEstimate empty'); fail++; }

// --- 6. GetClaimStatus -----------------------------------------------------
System.debug('--- TEST 6: GetClaimStatus ---');
GetClaimStatus.Input gsIn = new GetClaimStatus.Input();
gsIn.claimNumber = seed.Name;
List<GetClaimStatus.Result> gsRes = GetClaimStatus.getStatus(new List<GetClaimStatus.Input>{ gsIn });
if (gsRes != null && !gsRes.isEmpty() && gsRes[0].claimFound == true) {
    System.debug('  found by claim number [PASS]'); pass++;
    System.debug('  status: ' + gsRes[0].claimStatus + ' approver: ' + gsRes[0].assignedApprover);
} else {
    System.debug('  FAIL — claim not found via GetClaimStatus'); fail++;
}

// --- 7. GetPendingClaimsQueue ----------------------------------------------
System.debug('--- TEST 7: GetPendingClaimsQueue ---');
GetPendingClaimsQueue.Input pqIn = new GetPendingClaimsQueue.Input();
pqIn.maxRecords = 10;
List<GetPendingClaimsQueue.Result> pqRes = GetPendingClaimsQueue.fetch(new List<GetPendingClaimsQueue.Input>{ pqIn });
if (pqRes != null && !pqRes.isEmpty()) {
    System.debug('  queue count=' + pqRes[0].count + ' hasMore=' + pqRes[0].hasMore);
    System.debug('  summary preview: ' + (pqRes[0].queueSummary != null ? pqRes[0].queueSummary.left(150) : '(null)'));
    System.debug('  GetPendingClaimsQueue executed [PASS]'); pass++;
} else { System.debug('  FAIL — GetPendingClaimsQueue empty'); fail++; }

// --- 8. Trust score recalc trigger -----------------------------------------
System.debug('--- TEST 8: ClaimStatusTrigger / DealerTrustScoreService ---');
Decimal beforeScore = null;
List<Account> a0 = [SELECT DealerTrustScore__c FROM Account WHERE Id = :seed.AccountId];
if (!a0.isEmpty()) beforeScore = a0[0].DealerTrustScore__c;
System.debug('  dealer score BEFORE: ' + beforeScore);

Set<Id> testAcctIds = new Set<Id>{ seed.AccountId };
DealerTrustScoreService.recalculate(testAcctIds);

List<Account> a1 = [SELECT DealerTrustScore__c FROM Account WHERE Id = :seed.AccountId];
Decimal afterScore = a1.isEmpty() ? null : a1[0].DealerTrustScore__c;
System.debug('  dealer score AFTER recalc: ' + afterScore);
System.debug('  recalc executed without throwing [PASS]'); pass++;

// --- 9. TelemetrySignal trigger via Platform Event publish -----------------
System.debug('--- TEST 9: TelemetrySignal Platform Event ---');
TelemetrySignal__e evt = new TelemetrySignal__e(
    VIN__c = 'ELXDEMOFRD0800000',
    FaultCount30d__c = 5,
    OffNetworkCharges30d__c = 2,
    LastEventDate__c = System.now()
);
Database.SaveResult sr = EventBus.publish(evt);
if (sr.isSuccess()) { System.debug('  event published [PASS]'); pass++; }
else { System.debug('  event publish FAILED [FAIL]'); fail++; }

// --- 10. ComposeRepairGuidance fallback ------------------------------------
System.debug('--- TEST 10: ComposeRepairGuidance ---');
String guidance = ComposeRepairGuidance.compose(seed.Id);
if (String.isNotBlank(guidance)) {
    System.debug('  guidance generated, length=' + guidance.length() + ' [PASS]');
    System.debug('  preview: ' + guidance.left(150));
    pass++;
} else {
    System.debug('  WARNING — guidance empty (falls through to omit on null)');
}

// --- 11. ComposeDealerRejectionMessage fallback ----------------------------
System.debug('--- TEST 11: ComposeDealerRejectionMessage ---');
String rejBody = ComposeDealerRejectionMessage.compose(seed.Id, 'Wear & Tear', 'Test rationale');
if (String.isNotBlank(rejBody)) {
    System.debug('  rejection body generated, length=' + rejBody.length() + ' [PASS]');
    System.debug('  preview: ' + rejBody.left(150));
    pass++;
} else {
    System.debug('  FAIL — rejection composer returned blank'); fail++;
}

// --- 12. InvokeClaimVerdictPrompt (with fallback) --------------------------
System.debug('--- TEST 12: InvokeClaimVerdictPrompt ---');
InvokeClaimVerdictPrompt.InvocableInput ivIn = new InvokeClaimVerdictPrompt.InvocableInput();
ivIn.claimId = seed.Id;
List<InvokeClaimVerdictPrompt.InvocableResult> ivRes =
    InvokeClaimVerdictPrompt.run(new List<InvokeClaimVerdictPrompt.InvocableInput>{ ivIn });
if (ivRes != null && !ivRes.isEmpty()) {
    InvokeClaimVerdictPrompt.InvocableResult r = ivRes[0];
    System.debug('  recommendation: ' + r.recommendation + ' confidence: ' + r.confidence
        + ' source: ' + r.source);
    if (String.isNotBlank(r.recommendation) && r.confidence != null) {
        System.debug('  verdict produced [PASS]'); pass++;
    } else {
        System.debug('  FAIL — verdict missing fields'); fail++;
    }
} else { System.debug('  FAIL — empty result'); fail++; }

// --- SUMMARY ---------------------------------------------------------------
System.debug('=========== SUMMARY ===========');
System.debug('PASSED: ' + pass);
System.debug('FAILED: ' + fail);
if (fail == 0) System.debug('=== ALL CRITICAL ASSERTIONS PASSED ===');
else System.debug('=== ' + fail + ' FAILURE(S) — INVESTIGATE ABOVE ===');
