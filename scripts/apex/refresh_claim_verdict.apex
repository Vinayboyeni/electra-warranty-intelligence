// Re-run InvokeClaimVerdictPrompt on this one claim with the new fallback
// guard deployed, so AI_Recommendation/Confidence/Summary reflect a sane
// verdict on the existing claim.

Id targetId = '0Zkbm0000004We1CAE';
InvokeClaimVerdictPrompt.InvocableInput inp = new InvokeClaimVerdictPrompt.InvocableInput();
inp.claimId = targetId;
List<InvokeClaimVerdictPrompt.InvocableResult> results =
    InvokeClaimVerdictPrompt.run(new List<InvokeClaimVerdictPrompt.InvocableInput>{ inp });

if (!results.isEmpty()) {
    System.debug('After re-run:');
    System.debug('  recommendation: ' + results[0].recommendation);
    System.debug('  confidence: ' + results[0].confidence);
    System.debug('  source: ' + results[0].source);
    System.debug('  summary: ' + results[0].summary);
}

List<Claim> after = [
    SELECT AI_Recommendation__c, AI_Confidence__c, AI_Summary__c
    FROM Claim WHERE Id = :targetId
];
System.debug('Stored on claim:');
System.debug('  AI_Recommendation__c: ' + after[0].AI_Recommendation__c);
System.debug('  AI_Confidence__c: ' + after[0].AI_Confidence__c);
System.debug('  AI_Summary__c: ' + after[0].AI_Summary__c);
