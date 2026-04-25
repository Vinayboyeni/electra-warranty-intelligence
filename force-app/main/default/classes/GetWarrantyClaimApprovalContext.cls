// NOTE: without sharing — this class builds notifications that must show the
// claim context to ALL users in the approver Slack channel/agent. Running
// "with sharing" fails when the caller isn't a direct record owner (most
// commonly: the flow fires from a queue-owned claim where the triggering user
// has no sharing entry, so SOQL returns empty and the Slack card is blank).
public without sharing class GetWarrantyClaimApprovalContext {
    public class Input {
        @InvocableVariable(label='Claim Id' description='The Claim Id to assemble.')
        public Id claimId;

        @InvocableVariable(label='Claim Number' description='The Claim Name/claim number to assemble.')
        public String claimNumber;
    }

    public class Result {
        @InvocableVariable(label='Claim Id' description='Salesforce Id of the retrieved Claim.') public Id claimId;
        @InvocableVariable(label='Claim Number' description='Auto-number of the Claim.') public String claimNumber;
        @InvocableVariable(label='Status' description='Current processing status of the claim.') public String status;
        @InvocableVariable(label='Dealer Name' description='Name of the dealership that submitted the claim.') public String dealerName;
        @InvocableVariable(label='Dealer Trust Score' description='Calculated trust score of the dealer (0-100%).') public Decimal dealerTrustScore;
        @InvocableVariable(label='VIN' description='17-character Vehicle Identification Number.') public String vin;
        @InvocableVariable(label='Vehicle Name' description='Make and model of the vehicle.') public String vehicleName;
        @InvocableVariable(label='Customer Name' description='Name of the vehicle owner.') public String customerName;
        @InvocableVariable(label='Symptom' description='Symptom reported by the dealership.') public String symptom;
        @InvocableVariable(label='Fault Codes/Diagnosis' description='Diagnostic codes or preliminary diagnosis provided.') public String faultCodes;
        @InvocableVariable(label='Part Number/Category' description='Category of the part requested for warranty service.') public String partNumber;
        @InvocableVariable(label='Odometer' description='Reported mileage of the vehicle.') public String odometer;
        @InvocableVariable(label='Eligibility' description='Automated coverage eligibility result.') public String eligibility;
        @InvocableVariable(label='AI Confidence' description='Confidence score of the AI assessment.') public String aiConfidence;
        @InvocableVariable(label='Estimated Cost' description='Estimated repair cost.') public String estimatedCost;
        @InvocableVariable(label='Submission Date' description='Date and time the claim was submitted.') public String submissionDate;
        @InvocableVariable(label='Warranty End Date' description='Expected expiration date of the warranty.') public String warrantyEndDate;
        @InvocableVariable(label='Risk Flags' description='Any identified risks like high labor hours or suspicious components.') public String riskFlags;
        @InvocableVariable(label='Previous Claims' description='Summary of previous claims on this vehicle.') public String previousClaims;
        @InvocableVariable(label='AI Summary' description='Generated summary of the warranty scenario.') public String aiSummary;
        @InvocableVariable(label='AI Recommendation' description='Suggested decision based on historical precedents.') public String aiRecommendation;
        @InvocableVariable(label='Slack Reference' description='Id of the Slack thread associated with this claim.') public String slackReference;
        @InvocableVariable(label='Clarification Request' description='Any pending clarification requested from the dealer.') public String clarificationRequest;
        @InvocableVariable(label='Requires Follow Up' description='True if human follow up is required.') public Boolean requiresFollowUp;
        @InvocableVariable(label='Dealer Response Summary' description='Summary of the dealer\'s response to clarification.') public String dealerResponseSummary;
        @InvocableVariable(label='Messaging Session Id' description='Id for the live agent chat session if applicable.') public String messagingSessionId;
        @InvocableVariable(label='Submission Channel' description='Channel used to submit the claim.') public String submissionChannel;
        @InvocableVariable(label='AI Image Analysis' description='Findings from multimodal analysis of uploaded photos.') public String aiImageAnalysis;
        @InvocableVariable(label='Similar Claims Precedent' description='One-line summary of approval history for similar claims in the last 90 days.') public String similarClaimsPrecedent;
        @InvocableVariable(label='Slack Message Body' description='Formatted markdown block summarizing all claim details for chat channels.') public String slackMessageBody;
    }

    @InvocableMethod(label='Get Warranty Claim Approval Context' description='Retrieve all relevant details for a Warranty Claim, including the Dealer info, Symptom, Coverage details, and AI Image Analysis. Always call this action first when summarizing a claim for human approval.')
    public static List<Result> getContext(List<Input> inputs) {
        List<Result> out = new List<Result>();
        if (inputs == null) return out;

        for (Input input : inputs) {
            if (input == null || (input.claimId == null && String.isBlank(input.claimNumber))) {
                Result errRes = new Result();
                errRes.slackMessageBody = '*Notification error:* claim lookup received empty Id and Name. Open the claim record in Salesforce directly.';
                out.add(errRes);
                continue;
            }
            try {
            String claimFilter = input.claimId != null ? 'Id' : 'Name';
            String claimValue  = input.claimId != null
                ? String.valueOf(input.claimId) : input.claimNumber;

            List<Claim> claimResults = input.claimId != null
                ? [SELECT Id, Name, Status,
                        Account.Name, Account.DealerTrustScore__c,
                        Vehicle__c, Vehicle__r.Name,
                        Odometer__c, Symptom__c, Diagnosis__c, PartCategory__c,
                        EstimatedCost__c, ApprovedAmount,
                        Eligibility__c, EligibilityRationale__c,
                        AI_Summary__c, AI_Recommendation__c, AI_Confidence__c,
                        AI_Image_Analysis__c, ApproverSlackRef__c,
                        ClarificationRequest__c, RequiresFollowUp__c,
                        DealerResponseSummary__c, MessagingSessionId__c,
                        SubmissionChannel__c, SLA_Due_Date__c, Priority__c,
                        TelemetrySignal__c, PhotoPublicUrl__c,
                        CreatedDate
                   FROM Claim WHERE Id = :input.claimId LIMIT 1]
                : [SELECT Id, Name, Status,
                        Account.Name, Account.DealerTrustScore__c,
                        Vehicle__c, Vehicle__r.Name,
                        Odometer__c, Symptom__c, Diagnosis__c, PartCategory__c,
                        EstimatedCost__c, ApprovedAmount,
                        Eligibility__c, EligibilityRationale__c,
                        AI_Summary__c, AI_Recommendation__c, AI_Confidence__c,
                        AI_Image_Analysis__c, ApproverSlackRef__c,
                        ClarificationRequest__c, RequiresFollowUp__c,
                        DealerResponseSummary__c, MessagingSessionId__c,
                        SubmissionChannel__c, SLA_Due_Date__c, Priority__c,
                        TelemetrySignal__c, PhotoPublicUrl__c,
                        CreatedDate
                   FROM Claim WHERE Name = :input.claimNumber LIMIT 1];

            if (claimResults.isEmpty()) {
                Result notFound = new Result();
                notFound.claimNumber = input.claimNumber;
                notFound.slackMessageBody = '*Claim not found:* ' + (input.claimNumber != null ? input.claimNumber : String.valueOf(input.claimId)) + '. Verify the claim exists in Salesforce.';
                out.add(notFound);
                continue;
            }
            Claim claim = claimResults[0];

            // Resolve VIN and customer name via Asset → Vehicle / Contact
            String resolvedVin = null;
            String resolvedVehicleName = claim.Vehicle__r != null ? claim.Vehicle__r.Name : null;
            String resolvedCustomerName = null;
            String resolvedWarrantyEndDate = null;

            if (claim.Vehicle__c != null) {
                // Vehicle__c on Claim stores the Asset Id
                List<Vehicle> vList = [
                    SELECT Id, VehicleIdentificationNumber, Name, AssetId,
                           Asset.Contact.Name
                    FROM Vehicle
                    WHERE AssetId = :claim.Vehicle__c
                    LIMIT 1
                ];
                if (!vList.isEmpty()) {
                    resolvedVin = vList[0].VehicleIdentificationNumber;
                    if (String.isBlank(resolvedVehicleName)) resolvedVehicleName = vList[0].Name;
                    resolvedCustomerName = vList[0].Asset?.Contact?.Name;

                    // Fetch active warranty end date
                    List<AssetWarranty> wList = [
                        SELECT EndDate FROM AssetWarranty
                        WHERE Vehicle__c = :claim.Vehicle__c
                        ORDER BY EndDate DESC LIMIT 1
                    ];
                    if (!wList.isEmpty() && wList[0].EndDate != null) {
                        resolvedWarrantyEndDate = String.valueOf(wList[0].EndDate);
                    }
                }
            }

            // Previous claims on same vehicle (last 3, excluding current)
            String previousClaimsSummary = null;
            if (claim.Vehicle__c != null) {
                List<Claim> prevClaims = [
                    SELECT Name, Status, PartCategory__c, CreatedDate
                    FROM Claim
                    WHERE Vehicle__c = :claim.Vehicle__c
                      AND Id != :claim.Id
                    ORDER BY CreatedDate DESC
                    LIMIT 3
                ];
                if (!prevClaims.isEmpty()) {
                    List<String> lines = new List<String>();
                    for (Claim pc : prevClaims) {
                        lines.add(pc.Name + ' | ' + pc.PartCategory__c + ' | ' + pc.Status
                            + ' | ' + pc.CreatedDate.format('MMM d, yyyy'));
                    }
                    previousClaimsSummary = String.join(lines, '\n');
                }
            }

            // Build risk flags from stored eligibility rationale and trust score
            List<String> flags = new List<String>();
            if (claim.Account != null && claim.Account.DealerTrustScore__c != null
                    && claim.Account.DealerTrustScore__c < 60) {
                flags.add('Low dealer trust score (' + claim.Account.DealerTrustScore__c + ')');
            }
            if (claim.Eligibility__c == 'Borderline') flags.add('Borderline coverage — manual review required');
            if (claim.RequiresFollowUp__c) flags.add('Pending dealer clarification');
            if (claim.AI_Image_Analysis__c != null
                    && claim.AI_Image_Analysis__c.toLowerCase().contains('damage')) {
                flags.add('Damage confirmed in photo analysis');
            }
            String riskFlagsSummary = flags.isEmpty() ? 'None' : String.join(flags, '; ');

            // Historical precedent for similar claims (same part category,
            // ±30% cost, decided within last 90 days). Used to anchor approver
            // judgement with objective base rates.
            String precedentSummary = buildSimilarClaimsPrecedent(claim);

            Result r = new Result();
            r.claimId        = claim.Id;
            r.claimNumber    = claim.Name;
            r.status         = claim.Status;
            r.dealerName     = claim.Account != null ? claim.Account.Name : null;
            r.dealerTrustScore = claim.Account != null ? claim.Account.DealerTrustScore__c : null;
            r.vin            = resolvedVin;
            r.vehicleName    = resolvedVehicleName;
            r.customerName   = resolvedCustomerName;
            r.warrantyEndDate = resolvedWarrantyEndDate;
            r.odometer       = claim.Odometer__c != null ? String.valueOf(claim.Odometer__c.intValue()) : null;
            r.symptom        = claim.Symptom__c;
            r.faultCodes     = claim.Diagnosis__c;
            r.partNumber     = claim.PartCategory__c;
            r.eligibility    = claim.Eligibility__c;
            r.estimatedCost  = claim.EstimatedCost__c != null ? '$' + claim.EstimatedCost__c.setScale(2) : null;
            r.submissionDate = claim.CreatedDate != null
                ? claim.CreatedDate.format('MMM d, yyyy h:mm a') : null;
            r.aiSummary          = claim.AI_Summary__c;
            r.aiRecommendation   = claim.AI_Recommendation__c;
            r.aiConfidence       = claim.AI_Confidence__c != null
                ? String.valueOf(claim.AI_Confidence__c.intValue()) + '%' : null;
            r.aiImageAnalysis    = claim.AI_Image_Analysis__c;
            r.slackReference     = claim.ApproverSlackRef__c;
            r.clarificationRequest  = claim.ClarificationRequest__c;
            r.requiresFollowUp      = claim.RequiresFollowUp__c;
            r.dealerResponseSummary = claim.DealerResponseSummary__c;
            r.messagingSessionId    = claim.MessagingSessionId__c;
            r.submissionChannel     = claim.SubmissionChannel__c;
            r.riskFlags             = riskFlagsSummary;
            r.previousClaims        = previousClaimsSummary;
            r.similarClaimsPrecedent = precedentSummary;

            // Build formatted Slack message body
            // <!here> pings everyone currently online in the channel (approver pod).
            // Note: Slack for Salesforce and Incoming Webhooks both respect this syntax.
            String body = '<!here> :bell: *New warranty claim needs review*\n';
            body += '*' + r.claimNumber + '*\n';
            body += '---\n';
            body += '*Vehicle:* ' + (r.vehicleName != null ? r.vehicleName : 'Unknown')
                + (r.vin != null ? ' | VIN: ' + r.vin : '') + '\n';
            body += '*Customer:* ' + (r.customerName != null ? r.customerName : 'N/A') + '\n';
            body += '*Dealer:* ' + (r.dealerName != null ? r.dealerName : 'N/A')
                + (r.dealerTrustScore != null ? ' (Trust: ' + r.dealerTrustScore.intValue() + '/100)' : '') + '\n';
            body += '*Part:* ' + (r.partNumber != null ? r.partNumber : 'N/A')
                + ' | *Symptom:* ' + (r.symptom != null ? r.symptom : 'N/A') + '\n';
            body += '*Estimated Cost:* ' + (r.estimatedCost != null ? r.estimatedCost : 'N/A')
                + ' | *Odometer:* ' + (r.odometer != null ? r.odometer + ' mi' : 'N/A') + '\n';
            body += '*Warranty Expires:* ' + (r.warrantyEndDate != null ? r.warrantyEndDate : 'N/A') + '\n';
            body += '---\n';
            body += '*AI Verdict:* ' + (r.aiRecommendation != null ? r.aiRecommendation : 'N/A')
                + (r.aiConfidence != null ? ' (' + r.aiConfidence + ' confidence)' : '') + '\n';
            body += '*Eligibility:* ' + (r.eligibility != null ? r.eligibility : 'N/A') + '\n';
            body += '*Risk Flags:* ' + r.riskFlags + '\n';
            if (String.isNotBlank(r.similarClaimsPrecedent)) {
                body += ':bar_chart: *Historical precedent:* ' + r.similarClaimsPrecedent + '\n';
            }
            if (String.isNotBlank(claim.TelemetrySignal__c)) {
                body += ':satellite_antenna: *Vehicle telemetry (Data Cloud):* ' + claim.TelemetrySignal__c + '\n';
            }
            if (r.aiImageAnalysis != null) body += '*Photo Analysis:* ' + r.aiImageAnalysis + '\n';
            if (String.isNotBlank(claim.PhotoPublicUrl__c)) {
                body += ':camera_with_flash: *View photo:* <' + claim.PhotoPublicUrl__c + '|click to open>\n';
            }
            if (r.previousClaims != null) body += '---\n*Previous Claims:*\n' + r.previousClaims + '\n';
            if (r.clarificationRequest != null) body += '---\n*Pending Clarification:* ' + r.clarificationRequest + '\n';

            // Footer: direct Salesforce link + agent shortcut commands
            String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
            String claimUrl = baseUrl + '/lightning/r/Claim/' + claim.Id + '/view';
            body += '---\n';
            body += ':white_check_mark: *Open in Salesforce:* <' + claimUrl + '|Review claim record>\n';
            body += ':speech_balloon: *Decide from here:* reply in this channel\n';
            body += '  • `@Electra Warranty Approver approve ' + r.claimNumber + ' <rationale>`\n';
            body += '  • `@Electra Warranty Approver reject ' + r.claimNumber + ' <reason code> <rationale>`\n';
            body += '  • `@Electra Warranty Approver clarify ' + r.claimNumber + ' <question>`\n';
            body += '  • `@Electra Warranty Approver goodwill ' + r.claimNumber + ' <reason>`\n';

            r.slackMessageBody = body;

            out.add(r);
            } catch (Exception e) {
                // Never let a field-level hiccup leave the Slack post empty.
                // Produce a minimal but useful notification so the approver
                // knows a claim came in and can open it directly.
                Result fallback = new Result();
                fallback.claimNumber = input.claimNumber;
                fallback.slackMessageBody =
                    '*New claim needs review* — ' +
                    (input.claimNumber != null ? input.claimNumber : 'unknown id') +
                    '. Open the claim record in Salesforce for full details.\n' +
                    '_Context builder note: ' + e.getMessage() + '_';
                System.debug('GetWarrantyClaimApprovalContext body-build error: ' + e.getMessage()
                    + '\n' + e.getStackTraceString());
                out.add(fallback);
            }
        }
        return out;
    }

    /**
     * Historical precedent helper.
     * Returns a one-line summary of how similar claims (same part category,
     * cost within ±30%, decided within the last 90 days) were ruled on.
     * Returns null when we don't have enough signal to say anything useful
     * (no part category, no cost, or no history) — caller must handle null.
     */
    private static String buildSimilarClaimsPrecedent(Claim claim) {
        if (String.isBlank(claim.PartCategory__c) || claim.EstimatedCost__c == null) {
            return null;
        }

        Decimal cost     = claim.EstimatedCost__c;
        Decimal costLow  = cost * 0.70;
        Decimal costHigh = cost * 1.30;
        Datetime cutoff  = System.now().addDays(-90);

        List<Claim> similar;
        try {
            similar = [
                SELECT Id, Status, CreatedDate, LastModifiedDate, ApprovalDate__c
                FROM Claim
                WHERE PartCategory__c = :claim.PartCategory__c
                  AND EstimatedCost__c >= :costLow
                  AND EstimatedCost__c <= :costHigh
                  AND Status IN ('Approved', 'Rejected')
                  AND CreatedDate >= :cutoff
                  AND Id != :claim.Id
                LIMIT 200
            ];
        } catch (Exception e) {
            System.debug('buildSimilarClaimsPrecedent SOQL error: ' + e.getMessage());
            return null;
        }

        if (similar == null || similar.isEmpty()) return null;

        Integer total = similar.size();
        Integer approved = 0;
        Long totalDecisionMinutes = 0;
        Integer decisionSamples = 0;

        for (Claim pc : similar) {
            if (pc.Status == 'Approved') approved++;
            // Decision time = DML decision timestamp minus creation timestamp.
            // Use ApprovalDate__c when available (approvals), otherwise
            // LastModifiedDate as a proxy for when the reject DML ran.
            Datetime decidedAt = pc.ApprovalDate__c != null
                ? pc.ApprovalDate__c
                : pc.LastModifiedDate;
            if (decidedAt != null && pc.CreatedDate != null) {
                Long diffMin = (decidedAt.getTime() - pc.CreatedDate.getTime()) / (1000 * 60);
                if (diffMin >= 0) {
                    totalDecisionMinutes += diffMin;
                    decisionSamples++;
                }
            }
        }

        Integer approvalRate = (approved * 100) / total;
        String line = 'Of ' + total + ' similar claim' + (total == 1 ? '' : 's')
            + ' in the last 90 days, ' + approved + ' ('
            + approvalRate + '%) ' + (approved == 1 ? 'was' : 'were') + ' approved';

        if (decisionSamples > 0) {
            Decimal avgHours = ((Decimal) totalDecisionMinutes / decisionSamples) / 60;
            line += '. Avg decision time: ' + avgHours.setScale(1) + ' hours';
        }
        return line + '.';
    }
}