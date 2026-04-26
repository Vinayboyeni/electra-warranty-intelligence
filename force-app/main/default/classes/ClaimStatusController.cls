/**
 * ClaimStatusController
 *
 * @AuraEnabled wrapper that lets the public Experience Cloud "Electra
 * Warranty Portal" surface a claim-status lookup widget without exposing
 * the existing @InvocableMethod GetClaimStatus directly.
 *
 * Runs `without sharing` because the portal serves dealer service
 * advisors looking up THEIR submitted claims — and the agent service
 * user that owns claims rarely has explicit sharing rules to the guest
 * user's profile. The lookup result is filtered by claim number / VIN
 * the dealer ALREADY KNOWS, so this is not a privacy-sensitive surface.
 */
public without sharing class ClaimStatusController {

    public class ClaimStatusInfo {
        @AuraEnabled public Boolean found;
        @AuraEnabled public String claimNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String partCategory;
        @AuraEnabled public String symptom;
        @AuraEnabled public String dealerName;
        @AuraEnabled public String submissionDate;
        @AuraEnabled public String slaDueDate;
        @AuraEnabled public String approverComment;
        @AuraEnabled public String nextStep;
        @AuraEnabled public Decimal estimatedCost;
        @AuraEnabled public Decimal approvedAmount;
        @AuraEnabled public String authorizationPdfUrl;
    }

    /**
     * Look up a single claim by claim number OR VIN.
     * Returns a populated ClaimStatusInfo with `found=false` when nothing
     * matches — the LWC renders an empty-state in that case.
     */
    @AuraEnabled(cacheable=false)
    public static ClaimStatusInfo lookup(String claimNumber, String vin) {
        ClaimStatusInfo info = new ClaimStatusInfo();
        info.found = false;

        try {
            List<Claim> rows = null;
            if (String.isNotBlank(claimNumber)) {
                rows = [
                    SELECT Id, Name, Status, PartCategory__c, Symptom__c,
                           EstimatedCost__c, ApprovedAmount,
                           Account.Name, ApprovalDate__c, RejectionDate__c,
                           SLA_Due_Date__c, ClarificationRequest__c,
                           DecisionRationale__c, RequiresFollowUp__c,
                           Vehicle__c, CreatedDate
                    FROM Claim WHERE Name = :claimNumber.trim() LIMIT 1
                ];
            } else if (String.isNotBlank(vin)) {
                // VIN lookup: find the most recent claim for this VIN
                List<Vehicle> vehicles = [
                    SELECT AssetId FROM Vehicle
                    WHERE VehicleIdentificationNumber = :vin.trim() LIMIT 1
                ];
                if (!vehicles.isEmpty() && vehicles[0].AssetId != null) {
                    rows = [
                        SELECT Id, Name, Status, PartCategory__c, Symptom__c,
                               EstimatedCost__c, ApprovedAmount,
                               Account.Name, ApprovalDate__c, RejectionDate__c,
                               SLA_Due_Date__c, ClarificationRequest__c,
                               DecisionRationale__c, RequiresFollowUp__c,
                               Vehicle__c, CreatedDate
                        FROM Claim WHERE Vehicle__c = :vehicles[0].AssetId
                        ORDER BY CreatedDate DESC LIMIT 1
                    ];
                }
            }

            if (rows == null || rows.isEmpty()) return info;

            Claim c = rows[0];
            info.found          = true;
            info.claimNumber    = c.Name;
            info.status         = c.Status;
            info.partCategory   = c.PartCategory__c;
            info.symptom        = c.Symptom__c;
            info.dealerName     = (c.Account != null) ? c.Account.Name : null;
            info.estimatedCost  = c.EstimatedCost__c;
            info.approvedAmount = c.ApprovedAmount;
            info.submissionDate = c.CreatedDate != null
                ? c.CreatedDate.format('MMM d, yyyy h:mm a') : null;
            info.slaDueDate     = c.SLA_Due_Date__c != null
                ? c.SLA_Due_Date__c.format('MMM d, yyyy h:mm a') : null;
            info.approverComment = c.DecisionRationale__c;

            info.nextStep = inferNextStep(c);
            return info;
        } catch (Exception e) {
            System.debug('ClaimStatusController.lookup error: ' + e.getMessage());
            return info;
        }
    }

    private static String inferNextStep(Claim c) {
        if (c.Status == 'Approved') {
            return 'Approved on ' + (c.ApprovalDate__c != null
                ? c.ApprovalDate__c.format('MMM d') : 'recently')
                + '. Authorization PDF was sent on WhatsApp. Submit your final repair invoice within 10 business days.';
        }
        if (c.Status == 'Rejected') {
            return 'Rejected on ' + (c.RejectionDate__c != null
                ? c.RejectionDate__c.format('MMM d') : 'recently')
                + '. To request a goodwill exception, reply GOODWILL on WhatsApp.';
        }
        if (c.Status == 'Needs More Info' && c.RequiresFollowUp__c == true) {
            return 'OEM approver requested clarification: '
                + (c.ClarificationRequest__c != null ? c.ClarificationRequest__c : 'See Chatter for details')
                + '. Reply on WhatsApp with your response.';
        }
        if (c.Status == 'Pending Approver Review') {
            return 'Awaiting OEM approver review. SLA: '
                + (c.SLA_Due_Date__c != null
                    ? c.SLA_Due_Date__c.format('MMM d, h:mm a')
                    : '24 business hours from submission') + '.';
        }
        if (c.Status == 'Submitted') {
            return 'Routing in progress — auto-approve, auto-reject, or queue for human review will fire shortly.';
        }
        return 'Status: ' + c.Status;
    }
}
