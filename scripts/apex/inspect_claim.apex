// Deep inspection of a single claim — every field the system writes to.
// Reports anomalies (missing values, unexpected states, audit gaps).

Id targetId = '0Zkbm0000004We1CAE';

// 1. Pull the claim with every relevant field
List<Claim> rows = [
    SELECT Id, Name, Status, Status__c,
           AccountId, Account.Name, Account.DealerTrustScore__c,
           Vehicle__c, Vehicle__r.Name,
           PartCategory__c, Symptom__c, Diagnosis__c,
           Odometer__c, EstimatedCost__c, EstimatedAmount,
           Authorization_Type__c,
           DealerWhatsAppNumber__c, DealerResponseSummary__c,
           Eligibility__c, EligibilityRationale__c,
           AI_Recommendation__c, AI_Confidence__c, AI_Summary__c,
           AI_Image_Analysis__c,
           ApproverQueue__c, ApproverSlackRef__c, OwnerId,
           Priority__c, SLA_Due_Date__c,
           SubmissionChannel__c, MessagingSessionId__c,
           ApprovalDate__c, RejectionDate__c, Auto_Approved__c,
           DecisionRationale__c, ReasonCode__c,
           ClarificationRequest__c, RequiresFollowUp__c,
           TelemetrySignal__c,
           CreatedDate, LastModifiedDate, CreatedById, LastModifiedById
    FROM Claim
    WHERE Id = :targetId
    LIMIT 1
];

if (rows.isEmpty()) {
    System.debug('NO CLAIM FOUND for Id ' + targetId);
} else {
    Claim c = rows[0];
    System.debug('========== CLAIM DEEP INSPECTION ==========');
    System.debug('Id: ' + c.Id);
    System.debug('Name: ' + c.Name);
    System.debug('CreatedDate: ' + c.CreatedDate);
    System.debug('LastModifiedDate: ' + c.LastModifiedDate);

    System.debug('--- IDENTITY / RELATIONSHIPS ---');
    System.debug('Status (standard): ' + c.Status);
    System.debug('Status__c (custom): ' + c.Status__c);
    System.debug('AccountId / Dealer: ' + c.AccountId + ' / ' + (c.Account != null ? c.Account.Name : 'null'));
    System.debug('Dealer Trust Score: ' + (c.Account != null ? c.Account.DealerTrustScore__c : null));
    System.debug('Vehicle__c (Asset): ' + c.Vehicle__c + ' / ' + (c.Vehicle__r != null ? c.Vehicle__r.Name : 'null'));
    System.debug('OwnerId: ' + c.OwnerId);
    System.debug('ApproverQueue__c: ' + c.ApproverQueue__c);

    System.debug('--- INTAKE FIELDS (from ARIA / flow) ---');
    System.debug('PartCategory__c: ' + c.PartCategory__c);
    System.debug('Symptom__c: ' + c.Symptom__c);
    System.debug('Diagnosis__c: ' + c.Diagnosis__c);
    System.debug('Odometer__c: ' + c.Odometer__c);
    System.debug('EstimatedCost__c: ' + c.EstimatedCost__c);
    System.debug('EstimatedAmount: ' + c.EstimatedAmount);
    System.debug('Authorization_Type__c: ' + c.Authorization_Type__c);
    System.debug('SubmissionChannel__c: ' + c.SubmissionChannel__c);
    System.debug('DealerWhatsAppNumber__c: ' + c.DealerWhatsAppNumber__c);
    System.debug('Priority__c: ' + c.Priority__c);
    System.debug('SLA_Due_Date__c: ' + c.SLA_Due_Date__c);
    System.debug('MessagingSessionId__c: ' + c.MessagingSessionId__c);

    System.debug('--- COVERAGE ENGINE OUTPUT ---');
    System.debug('Eligibility__c: ' + c.Eligibility__c);
    System.debug('EligibilityRationale__c: ' + c.EligibilityRationale__c);

    System.debug('--- AI VERDICT (Prompt Builder + InvokeClaimVerdictPrompt) ---');
    System.debug('AI_Recommendation__c: ' + c.AI_Recommendation__c);
    System.debug('AI_Confidence__c: ' + c.AI_Confidence__c);
    System.debug('AI_Summary__c: ' + c.AI_Summary__c);

    System.debug('--- IMAGE / TELEMETRY ENRICHMENT ---');
    System.debug('AI_Image_Analysis__c: ' + c.AI_Image_Analysis__c);
    System.debug('TelemetrySignal__c: ' + c.TelemetrySignal__c);

    System.debug('--- DECISION FIELDS (Approve / Reject / Clarify / Auto-route) ---');
    System.debug('Auto_Approved__c: ' + c.Auto_Approved__c);
    System.debug('ApprovalDate__c: ' + c.ApprovalDate__c);
    System.debug('RejectionDate__c: ' + c.RejectionDate__c);
    System.debug('DecisionRationale__c: ' + c.DecisionRationale__c);
    System.debug('ReasonCode__c: ' + c.ReasonCode__c);
    System.debug('ApproverSlackRef__c: ' + c.ApproverSlackRef__c);

    System.debug('--- CLARIFICATION (RFI) ---');
    System.debug('ClarificationRequest__c: ' + c.ClarificationRequest__c);
    System.debug('RequiresFollowUp__c: ' + c.RequiresFollowUp__c);
    System.debug('DealerResponseSummary__c: ' + c.DealerResponseSummary__c);

    // 2. Chatter audit (FeedItems)
    List<FeedItem> feed = [
        SELECT Id, Body, CreatedDate, CreatedBy.Name
        FROM FeedItem WHERE ParentId = :c.Id
        ORDER BY CreatedDate ASC
    ];
    System.debug('--- CHATTER AUDIT (' + feed.size() + ' posts) ---');
    for (FeedItem fi : feed) {
        System.debug('  [' + fi.CreatedDate + '] ' + fi.CreatedBy.Name + ' → '
            + (fi.Body != null ? fi.Body.left(150) : '(null body)'));
    }

    // 3. Files attached
    List<ContentDocumentLink> links = [
        SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType
        FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id
    ];
    System.debug('--- FILES ATTACHED (' + links.size() + ') ---');
    for (ContentDocumentLink l : links) {
        System.debug('  ' + l.ContentDocument.Title + ' (' + l.ContentDocument.FileType + ')');
    }

    // 4. Anomaly detection
    System.debug('========== ANOMALY CHECK ==========');
    List<String> issues = new List<String>();
    if (String.isBlank(c.Status)) issues.add('Status (standard) is blank');
    if (c.Status != null && c.Status__c != null && c.Status != c.Status__c) {
        issues.add('Status mismatch: standard=' + c.Status + ' custom=' + c.Status__c);
    }
    if (c.Vehicle__c == null) issues.add('No Vehicle linked');
    if (c.AccountId == null) issues.add('No Account/dealer linked');
    if (String.isBlank(c.PartCategory__c)) issues.add('PartCategory empty');
    if (c.Status == 'Approved' && c.ApprovalDate__c == null) issues.add('Approved but no ApprovalDate');
    if (c.Status == 'Rejected' && c.RejectionDate__c == null && c.ApprovalDate__c == null) {
        issues.add('Rejected but no RejectionDate or ApprovalDate');
    }
    if ((c.Status == 'Approved' || c.Status == 'Rejected') && String.isBlank(c.DecisionRationale__c)) {
        issues.add('Decided but no DecisionRationale');
    }
    if (c.Status == 'Rejected' && String.isBlank(c.ReasonCode__c)) {
        issues.add('Rejected but no ReasonCode');
    }
    if (c.Eligibility__c == 'Not Covered' && c.Status == 'Pending Approver Review') {
        issues.add('Not Covered but still in Pending queue (legacy data — auto-reject would have caught new ones)');
    }
    if (c.Auto_Approved__c == true && c.Status != 'Approved') {
        issues.add('Auto_Approved=true but Status=' + c.Status);
    }
    if (String.isBlank(c.AI_Recommendation__c)) issues.add('AI_Recommendation not populated');
    if (c.Status == 'Needs More Info' && String.isBlank(c.ClarificationRequest__c)) {
        issues.add('Needs More Info but no ClarificationRequest captured');
    }
    if (issues.isEmpty()) {
        System.debug('  No anomalies detected.');
    } else {
        for (String issue : issues) System.debug('  ⚠ ' + issue);
    }
}
