public with sharing class ApproveWarrantyClaim {
    public class Input {
        @InvocableVariable(label='Claim Id' description='Id of the Claim to approve.')
        public Id claimId;

        @InvocableVariable(label='Decision Rationale' description='Optional approval rationale stored on the claim.')
        public String decisionRationale;

        @InvocableVariable(label='Approver Slack Reference' description='Slack thread or message reference for the approval action.')
        public String approverSlackRef;

        @InvocableVariable(label='Approved Amount' description='Optional. Specific dollar amount the approver is authorizing — pass when partial-approving below the dealer-estimated cost. When null or equal to the estimate, full estimated amount is approved.')
        public Decimal approvedAmount;
    }

    public class Result {
        @InvocableVariable(label='Claim Id' description='Id of the processed claim.') public Id claimId;
        @InvocableVariable(label='Status' description='Status of the approval operation (Success/Error).') public String status;
        @InvocableVariable(label='Message' description='Detailed message regarding the operation.') public String message;
    }

    @InvocableMethod(label='Approve Warranty Claim' description='Mark a Warranty Claim as Approved. Requires the Claim Id and a decision rationale explaining the approval. Automatically updates the underlying record.')
    public static List<Result> approve(List<Input> inputs) {
        List<Result> output = new List<Result>();
        if (inputs == null) {
            return output;
        }

        List<Claim> updates = new List<Claim>();
        Map<Id, Input> inputMap = new Map<Id, Input>();
        for (Input input : inputs) {
            if (input != null && input.claimId != null) {
                inputMap.put(input.claimId, input);
            }
        }
        if (inputMap.isEmpty()) {
            return output;
        }

        Set<Id> alreadyDecided = new Set<Id>();
        for (Claim claim : [
            SELECT Id, Status, DecisionRationale__c, EstimatedCost__c, ApprovedAmount
            FROM Claim
            WHERE Id IN :inputMap.keySet()
        ]) {
            Input request = inputMap.get(claim.Id);
            if (request == null) {
                continue;
            }

            // Defense-in-depth: skip claims already decided. Prevents an
            // approver from accidentally re-firing the PDF + WhatsApp +
            // trust-score recalc chain on a settled claim.
            if (claim.Status == 'Approved' || claim.Status == 'Rejected') {
                alreadyDecided.add(claim.Id);
                continue;
            }

            claim.Status = 'Approved';
            claim.Status__c = 'Approved';
            claim.ApprovalDate__c = System.now();
            if (String.isNotBlank(request.decisionRationale)) {
                claim.DecisionRationale__c = request.decisionRationale;
            }
            if (String.isNotBlank(request.approverSlackRef)) {
                claim.ApproverSlackRef__c = request.approverSlackRef;
            }
            // Partial-approval support: if the approver passed an explicit
            // approvedAmount, use it. Otherwise default to the estimated
            // cost so the dealer's authorization still has a hard ceiling.
            if (request.approvedAmount != null && request.approvedAmount > 0) {
                claim.ApprovedAmount = request.approvedAmount;
            } else if (claim.EstimatedCost__c != null) {
                claim.ApprovedAmount = claim.EstimatedCost__c;
            }
            updates.add(claim);
        }

        if (!updates.isEmpty()) {
            update updates;
            // For each approved claim:
            //   1) Generate a branded PDF authorization certificate
            //   2) Save it as a ContentVersion attached to the Claim
            //   3) Create a public ContentDistribution link
            //   4) Include that link in the dealer's WhatsApp approval message
            // All wrapped in try/catch so a PDF or messaging failure cannot
            // roll back the approval DML itself.
            for (Claim claim : updates) {
                Input req = inputMap.get(claim.Id);
                String rationale = (req != null) ? req.decisionRationale : null;
                Decimal approvedAmt = (req != null) ? req.approvedAmount : null;

                String pdfUrl = null;
                try {
                    pdfUrl = GenerateApprovalAuthorization.generate(claim.Id);
                } catch (Exception pdfErr) {
                    System.debug('PDF authorization generation swallowed: ' + pdfErr.getMessage());
                }

                SendWhatsAppClaimDecision.notify(
                    claim.Id,
                    SendWhatsAppClaimDecision.APPROVED,
                    null,
                    rationale,
                    pdfUrl,
                    approvedAmt
                );

                // Also email the end customer (vehicle owner) with the PDF link.
                // Wrapped in try/catch so an email failure cannot block approval.
                try {
                    NotifyCustomerOfApproval.send(claim.Id, pdfUrl);
                } catch (Exception custErr) {
                    System.debug('Customer email notification swallowed: ' + custErr.getMessage());
                }
            }
        }

        for (Input request : inputs) {
            Result result = new Result();
            result.claimId = request == null ? null : request.claimId;
            if (request != null && request.claimId != null) {
                if (alreadyDecided.contains(request.claimId)) {
                    result.status = 'Skipped';
                    result.message = 'Claim is already decided (Approved or Rejected). No action taken.';
                } else {
                    result.status = 'Success';
                    result.message = 'Claim approved successfully. Dealer notified on WhatsApp.';
                }
            } else {
                result.status = 'Error';
                result.message = 'Invalid claim input.';
            }
            output.add(result);
        }
        return output;
    }
}