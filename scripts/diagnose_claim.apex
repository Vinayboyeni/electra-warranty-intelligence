// Full field dump for a specific claim to diagnose routing/approval state
String targetClaimName = 'WC-PVCA2';

List<Claim> claims = [
    SELECT Id, Name, Status, OwnerId, Owner.Name,
           AccountId, Account.Name, Account.DealerTrustScore__c,
           Vehicle__c, Vehicle__r.Name,
           Odometer__c, PartCategory__c, Symptom__c,
           EstimatedCost__c, EstimatedAmount, Eligibility__c, EligibilityRationale__c,
           AI_Recommendation__c, AI_Confidence__c, AI_Summary__c,
           Auto_Approved__c, ApprovalDate__c, DecisionRationale__c,
           SLA_Due_Date__c, SubmissionChannel__c, DealerWhatsAppNumber__c,
           Priority__c, CreatedDate, LastModifiedDate,
           InsuredAssetId
    FROM Claim
    WHERE Name = :targetClaimName
    LIMIT 1
];

if (claims.isEmpty()) {
    System.debug('❌ CLAIM NOT FOUND: ' + targetClaimName);
    return;
}

Claim c = claims[0];
System.debug('═══════════════════════════════════════════════');
System.debug('CLAIM ' + c.Name + ' (' + c.Id + ')');
System.debug('═══════════════════════════════════════════════');
System.debug('▶ STATUS & OWNER');
System.debug('  Status:             ' + c.Status);
System.debug('  Owner:              ' + c.Owner.Name + ' (' + c.OwnerId + ')');
System.debug('  Auto_Approved__c:   ' + c.Auto_Approved__c);
System.debug('  ApprovalDate:       ' + c.ApprovalDate__c);
System.debug('  DecisionRationale:  ' + c.DecisionRationale__c);
System.debug('');

System.debug('▶ DEALER & VEHICLE');
System.debug('  Dealer:             ' + c.Account.Name);
System.debug('  Dealer Trust:       ' + c.Account.DealerTrustScore__c);
System.debug('  Vehicle:            ' + (c.Vehicle__r != null ? c.Vehicle__r.Name : 'NULL'));
System.debug('  Vehicle__c (Asset): ' + c.Vehicle__c);
System.debug('  InsuredAssetId:     ' + c.InsuredAssetId);
System.debug('');

System.debug('▶ CLAIM DETAILS');
System.debug('  Part:               ' + c.PartCategory__c);
System.debug('  Symptom:            ' + c.Symptom__c);
System.debug('  Odometer:           ' + c.Odometer__c);
System.debug('  EstimatedCost__c:   ' + c.EstimatedCost__c);
System.debug('  EstimatedAmount:    ' + c.EstimatedAmount);
System.debug('  SubmissionChannel:  ' + c.SubmissionChannel__c);
System.debug('  DealerWhatsApp:     ' + c.DealerWhatsAppNumber__c);
System.debug('');

System.debug('▶ ELIGIBILITY & AI');
System.debug('  Eligibility:        ' + c.Eligibility__c);
System.debug('  EligibilityRationale: ' + c.EligibilityRationale__c);
System.debug('  AI_Recommendation:  ' + c.AI_Recommendation__c);
System.debug('  AI_Confidence:      ' + c.AI_Confidence__c);
System.debug('  AI_Summary:         ' + c.AI_Summary__c);
System.debug('');

System.debug('▶ TIMING');
System.debug('  Created:            ' + c.CreatedDate);
System.debug('  LastModified:       ' + c.LastModifiedDate);
System.debug('  SLA_Due_Date:       ' + c.SLA_Due_Date__c);
System.debug('  Priority:           ' + c.Priority__c);
System.debug('');

// Diagnose auto-approve eligibility per RouteClaimToApproverQueue.cls rules
System.debug('▶ AUTO-APPROVE CRITERIA CHECK (rules in RouteClaimToApproverQueue.cls)');
Decimal confidence = c.AI_Confidence__c != null ? c.AI_Confidence__c : 0;
Decimal cost       = c.EstimatedCost__c != null ? c.EstimatedCost__c : 999999;
Decimal trust      = (c.Account != null && c.Account.DealerTrustScore__c != null)
                        ? c.Account.DealerTrustScore__c : 0;
String elig        = c.Eligibility__c != null ? c.Eligibility__c : '';

Boolean eligibleOK    = (elig == 'Likely');
Boolean confOK        = (confidence >= 90);
Boolean costOK        = (cost <= 500);
Boolean trustOK       = (trust >= 75);

System.debug('  Eligibility == "Likely"?    ' + eligibleOK + '  (got: "' + elig + '")');
System.debug('  AI Confidence >= 90?        ' + confOK    + '  (got: ' + confidence + ')');
System.debug('  Cost <= 500?                ' + costOK    + '  (got: ' + cost + ')');
System.debug('  Dealer Trust >= 75?         ' + trustOK   + '  (got: ' + trust + ')');
System.debug('  ALL 4 MET? AUTO-APPROVE =   ' + (eligibleOK && confOK && costOK && trustOK));
System.debug('');

System.debug('▶ EXPECTED vs ACTUAL STATUS');
if (eligibleOK && confOK && costOK && trustOK) {
    System.debug('  Expected: Approved (auto) — NO Slack notification');
    System.debug('  Actual:   ' + c.Status);
    System.debug(c.Status == 'Approved' ? '  ✅ AUTO-APPROVE FIRED CORRECTLY' : '  ❌ AUTO-APPROVE DID NOT FIRE');
} else if (elig == 'Not Covered') {
    System.debug('  Expected: Rejected (auto)');
    System.debug('  Actual:   ' + c.Status);
} else {
    System.debug('  Expected: Pending Approver Review (Slack notification should fire)');
    System.debug('  Actual:   ' + c.Status);
    System.debug(c.Status == 'Pending Approver Review' ? '  ✅ ROUTING CORRECT' : '  ❌ ROUTING BROKEN');
}
System.debug('═══════════════════════════════════════════════');

// Check if any FeedItems were posted (indicates notification flow fired)
List<FeedItem> feed = [
    SELECT Id, Body, CreatedDate FROM FeedItem
    WHERE ParentId = :c.Id ORDER BY CreatedDate DESC LIMIT 5
];
System.debug('▶ CHATTER FEED (last 5 posts — shows notification + approval activity)');
for (FeedItem fi : feed) {
    String snippet = fi.Body != null ? fi.Body.abbreviate(120) : 'NULL';
    System.debug('  ' + fi.CreatedDate.format('HH:mm:ss') + ' | ' + snippet);
}
