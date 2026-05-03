// Inspect a claim by claim number
String claimName = 'WC-HFCAU';
// Note: also pulling ApprovedAmount, ActualAmount, TotalAdjustedAmount,
// TotalClaimedAmount to check for partial-approval handling
List<Claim> rows = [
    SELECT Id, Name, Status, Status__c,
           AccountId, Account.Name, Account.DealerTrustScore__c,
           Vehicle__c, Vehicle__r.Name,
           PartCategory__c, Symptom__c, Diagnosis__c,
           Odometer__c, EstimatedCost__c, EstimatedAmount,
           ApprovedAmount, ActualAmount, TotalAdjustedAmount, TotalClaimedAmount,
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
           CreatedDate, LastModifiedDate, CreatedBy.Name
    FROM Claim WHERE Name = :claimName LIMIT 1
];
if (rows.isEmpty()) { System.debug('NOT FOUND: ' + claimName); } else {
    Claim c = rows[0];
    System.debug('========== ' + c.Name + ' (' + c.Id + ') ==========');
    System.debug('CreatedDate: ' + c.CreatedDate + ' | CreatedBy: ' + c.CreatedBy.Name);
    System.debug('LastModifiedDate: ' + c.LastModifiedDate);

    System.debug('--- INTAKE (set by ARIA / Action_Create_Warranty_Claim flow) ---');
    System.debug('Status: ' + c.Status + '   Status__c: ' + c.Status__c);
    System.debug('AccountId / Dealer: ' + c.AccountId + ' / ' + (c.Account != null ? c.Account.Name : 'null'));
    System.debug('Dealer Trust Score: ' + (c.Account != null ? c.Account.DealerTrustScore__c : null));
    System.debug('Vehicle__c (Asset Id): ' + c.Vehicle__c);
    System.debug('PartCategory__c: ' + c.PartCategory__c);
    System.debug('Symptom__c: ' + c.Symptom__c);
    System.debug('Diagnosis__c: ' + c.Diagnosis__c);
    System.debug('Odometer__c: ' + c.Odometer__c);
    System.debug('EstimatedCost__c: ' + c.EstimatedCost__c);
    System.debug('EstimatedAmount: ' + c.EstimatedAmount);
    System.debug('ApprovedAmount: ' + c.ApprovedAmount);
    System.debug('ActualAmount: ' + c.ActualAmount);
    System.debug('TotalClaimedAmount: ' + c.TotalClaimedAmount);
    System.debug('TotalAdjustedAmount: ' + c.TotalAdjustedAmount);
    System.debug('Authorization_Type__c: ' + c.Authorization_Type__c);
    System.debug('SubmissionChannel__c: ' + c.SubmissionChannel__c);
    System.debug('DealerWhatsAppNumber__c: ' + c.DealerWhatsAppNumber__c);
    System.debug('Priority__c: ' + c.Priority__c);
    System.debug('SLA_Due_Date__c: ' + c.SLA_Due_Date__c);
    System.debug('MessagingSessionId__c: ' + c.MessagingSessionId__c);
    System.debug('OwnerId: ' + c.OwnerId);
    System.debug('ApproverQueue__c: ' + c.ApproverQueue__c);

    System.debug('--- COVERAGE ENGINE ---');
    System.debug('Eligibility__c: ' + c.Eligibility__c);
    System.debug('EligibilityRationale__c: ' + c.EligibilityRationale__c);

    System.debug('--- AI VERDICT (Prompt Builder via InvokeClaimVerdictPrompt) ---');
    System.debug('AI_Recommendation__c: ' + c.AI_Recommendation__c);
    System.debug('AI_Confidence__c: ' + c.AI_Confidence__c);
    System.debug('AI_Summary__c: ' + c.AI_Summary__c);

    System.debug('--- ENRICHMENT ---');
    System.debug('AI_Image_Analysis__c: ' + c.AI_Image_Analysis__c);
    System.debug('TelemetrySignal__c: ' + c.TelemetrySignal__c);

    System.debug('--- DECISION ---');
    System.debug('Auto_Approved__c: ' + c.Auto_Approved__c);
    System.debug('ApprovalDate__c: ' + c.ApprovalDate__c);
    System.debug('RejectionDate__c: ' + c.RejectionDate__c);
    System.debug('DecisionRationale__c: ' + c.DecisionRationale__c);
    System.debug('ReasonCode__c: ' + c.ReasonCode__c);
    System.debug('ApproverSlackRef__c: ' + c.ApproverSlackRef__c);
    System.debug('ClarificationRequest__c: ' + c.ClarificationRequest__c);
    System.debug('RequiresFollowUp__c: ' + c.RequiresFollowUp__c);

    // Chatter audit
    List<FeedItem> feed = [
        SELECT Body, CreatedDate, CreatedBy.Name FROM FeedItem
        WHERE ParentId = :c.Id ORDER BY CreatedDate ASC
    ];
    System.debug('--- CHATTER AUDIT (' + feed.size() + ' posts) ---');
    for (FeedItem fi : feed) {
        System.debug('  [' + fi.CreatedDate + '] ' + fi.CreatedBy.Name + ' → '
            + (fi.Body != null ? fi.Body.left(140) : '(null)'));
    }

    // Files
    List<ContentDocumentLink> links = [
        SELECT ContentDocument.Title, ContentDocument.FileType
        FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id
    ];
    System.debug('--- FILES (' + links.size() + ') ---');
    for (ContentDocumentLink l : links)
        System.debug('  ' + l.ContentDocument.Title + ' (' + l.ContentDocument.FileType + ')');

    // Anomalies
    System.debug('========== ANOMALY CHECK ==========');
    List<String> issues = new List<String>();
    if (c.AccountId == null) issues.add('No dealer Account linked');
    if (c.Vehicle__c == null) issues.add('No Vehicle linked');
    if (String.isBlank(c.PartCategory__c)) issues.add('PartCategory empty');
    if (String.isBlank(c.Symptom__c)) issues.add('Symptom empty');
    if (c.EstimatedCost__c == null) issues.add('EstimatedCost empty');
    if (String.isBlank(c.AI_Recommendation__c)) issues.add('AI_Recommendation not populated');
    if (String.isNotBlank(c.DealerWhatsAppNumber__c)) {
        Integer digits = 0;
        for (Integer i = 0; i < c.DealerWhatsAppNumber__c.length(); i++) {
            String ch = c.DealerWhatsAppNumber__c.substring(i, i+1);
            if (ch >= '0' && ch <= '9') digits++;
        }
        if (digits < 8) issues.add('DealerWhatsAppNumber__c is suspicious: "' + c.DealerWhatsAppNumber__c + '" (only ' + digits + ' digits)');
    }
    if (c.Status == 'Approved' && c.ApprovalDate__c == null) issues.add('Approved with no ApprovalDate');
    if ((c.Status == 'Approved' || c.Status == 'Rejected') && String.isBlank(c.DecisionRationale__c))
        issues.add('Decided but no DecisionRationale');
    if (issues.isEmpty()) System.debug('  No anomalies detected.');
    else for (String s : issues) System.debug('  ⚠ ' + s);
}
