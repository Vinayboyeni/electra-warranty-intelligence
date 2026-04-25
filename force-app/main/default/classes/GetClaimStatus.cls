/**
 * GetClaimStatus - Agentforce Invocable Action
 *
 * Powers the "Claim Status Inquiry" topic of the Dealer Intake Agent.
 * Retrieves the current status, assigned approver, SLA deadline, and latest
 * approver comment for a previously submitted warranty claim.
 *
 * Accepts either:
 *   - A claim number (e.g., CLM-00042) — precise lookup
 *   - A VIN — returns the most recent claim for that vehicle
 *
 * This eliminates the most common dealer repeat contact reason:
 * "Where is my claim?" — reducing inbound call volume significantly.
 */
public with sharing class GetClaimStatus {

    public class Input {
        @InvocableVariable(label='Claim Number' description='Human-readable claim number (e.g., CLM-00042). Used when dealer knows their specific claim number.' required=false)
        public String claimNumber;

        @InvocableVariable(label='VIN' description='17-character VIN. Used to find the most recent claim if no claim number is provided.' required=false)
        public String vin;
    }

    public class Result {
        @InvocableVariable(label='Claim Number' description='Human-readable claim reference number.')
        public String claimNumber;

        @InvocableVariable(label='Claim Status' description='Current status of the claim: Pending, Under Review, Approved, Rejected.')
        public String claimStatus;

        @InvocableVariable(label='Assigned Approver' description='Full name of the OEM approver currently handling the claim.')
        public String assignedApprover;

        @InvocableVariable(label='SLA Due Date' description='SLA deadline by which the OEM must respond to this claim.')
        public DateTime slaDueDate;

        @InvocableVariable(label='Approver Comment' description='Most recent comment or feedback from the OEM approver.')
        public String approverComment;

        @InvocableVariable(label='Next Step' description='Recommended next action for the dealer based on current claim status.')
        public String nextStep;

        @InvocableVariable(label='Claim Found' description='True if a matching claim was found.')
        public Boolean claimFound;
    }

    @InvocableMethod(
        label='Get Claim Status'
        description='Returns the current status, approver, SLA deadline, and latest comment for an existing warranty claim. Used by dealers to self-serve claim follow-ups via WhatsApp.'
    )
    public static List<Result> getStatus(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        for (Input inp : inputs) {
            Result res = new Result();
            res.claimFound = false;

            Claim matchedClaim = null;

            // Strategy 1: Lookup by claim number (Name field in Salesforce)
            if (String.isNotBlank(inp.claimNumber)) {
                List<Claim> byNumber = [
                    SELECT Id, Name, Status, OwnerId, Owner.Name, CreatedDate,
                           EligibilityRationale__c, SLA_Due_Date__c
                    FROM Claim
                    WHERE Name = :inp.claimNumber
                    LIMIT 1
                ];
                if (!byNumber.isEmpty()) {
                    matchedClaim = byNumber[0];
                }

                // Strategy 1b: Fallback — match WC-XXXXX against the last 5 chars of the Salesforce Id.
                // The Flow generates claim numbers as "WC-" + UPPER(RIGHT(Id, 5)); Salesforce Ids are
                // case-sensitive, so iterate recent Claims and compare case-insensitively on the suffix.
                if (matchedClaim == null && inp.claimNumber.startsWithIgnoreCase('WC-') && inp.claimNumber.length() == 8) {
                    String suffix = inp.claimNumber.substring(3).toUpperCase();
                    List<Claim> recent = [
                        SELECT Id, Name, Status, OwnerId, Owner.Name, CreatedDate,
                               EligibilityRationale__c, SLA_Due_Date__c
                        FROM Claim
                        ORDER BY CreatedDate DESC
                        LIMIT 200
                    ];
                    for (Claim c : recent) {
                        String cid = String.valueOf(c.Id);
                        if (cid.right(5).toUpperCase() == suffix) {
                            matchedClaim = c;
                            break;
                        }
                    }
                }
            }

            // Strategy 2: Lookup by VIN (most recent claim)
            if (matchedClaim == null && String.isNotBlank(inp.vin)) {
                List<Vehicle> vehicles = [
                    SELECT Id, AssetId FROM Vehicle
                    WHERE VehicleIdentificationNumber = :inp.vin
                    LIMIT 1
                ];
                if (!vehicles.isEmpty() && vehicles[0].AssetId != null) {
                    Id vehicleAssetId = vehicles[0].AssetId;
                    List<Claim> byVin = [
                        SELECT Id, Name, Status, OwnerId, Owner.Name, CreatedDate,
                               EligibilityRationale__c, SLA_Due_Date__c
                        FROM Claim
                        WHERE Vehicle__c = :vehicleAssetId
                        ORDER BY CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!byVin.isEmpty()) {
                        matchedClaim = byVin[0];
                    }
                }
            }

            if (matchedClaim == null) {
                res.claimFound = false;
                res.nextStep = 'No claim found. Please verify your Claim Number or VIN and try again.';
                results.add(res);
                continue;
            }

            res.claimFound = true;
            res.claimNumber = matchedClaim.Name;
            res.claimStatus = matchedClaim.Status;
            res.assignedApprover = matchedClaim.Owner.Name;
            res.slaDueDate = matchedClaim.SLA_Due_Date__c != null
                ? matchedClaim.SLA_Due_Date__c
                : matchedClaim.CreatedDate.addHours(24);
            res.approverComment = String.isNotBlank(matchedClaim.EligibilityRationale__c)
                ? matchedClaim.EligibilityRationale__c
                : 'No comments yet from the approver.';
            res.nextStep = deriveNextStep(matchedClaim.Status);

            results.add(res);
        }

        return results;
    }

    private static String deriveNextStep(String status) {
        if (String.isBlank(status)) return 'Contact your OEM claim representative for an update.';
        switch on status {
            when 'Submitted', 'Pending Approver Review' {
                return 'Your claim is queued for review. No action needed — you will be notified within 24 business hours.';
            }
            when 'Under Review' {
                return 'An OEM adjuster is reviewing your claim. They may reach out for clarification.';
            }
            when 'Approved' {
                return 'Claim approved! Proceed with the repair and submit your invoice to Electra for reimbursement.';
            }
            when 'Rejected' {
                return 'Claim was rejected. Review the approver comment for the reason, or reply AGENT to speak with a specialist.';
            }
            when 'Clarification Needed' {
                return 'The approver has requested additional information. Please reply to their WhatsApp message or contact them directly.';
            }
            when else {
                return 'Please contact your Electra OEM representative for the latest update on this claim.';
            }
        }
    }
}