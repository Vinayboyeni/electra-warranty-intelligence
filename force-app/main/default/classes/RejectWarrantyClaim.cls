public with sharing class RejectWarrantyClaim {
    public class Input {
        @InvocableVariable(label='Claim Id' description='Id of the Claim to reject.')
        public Id claimId;

        @InvocableVariable(label='Reason Code' description='Reason code associated with the rejection.')
        public String reasonCode;

        @InvocableVariable(label='Decision Rationale' description='Optional rejection rationale stored on the claim.')
        public String decisionRationale;

        @InvocableVariable(label='Approver Slack Reference' description='Slack thread or message reference for the rejection action.')
        public String approverSlackRef;
    }

    public class Result {
        @InvocableVariable(label='Claim Id' description='Id of the processed claim.') public Id claimId;
        @InvocableVariable(label='Status' description='Status of the rejection operation (Success/Error).') public String status;
        @InvocableVariable(label='Message' description='Detailed message regarding the operation.') public String message;
    }

    @InvocableMethod(label='Reject Warranty Claim' description='Mark a Warranty Claim as Rejected. Required inputs include the Claim Id, a standardized Reason Code (e.g. Not Covered), and a decision rationale outlining the rejection logic.')
    public static List<Result> reject(List<Input> inputs) {
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
            SELECT Id, Status, DecisionRationale__c, ReasonCode__c
            FROM Claim
            WHERE Id IN :inputMap.keySet()
        ]) {
            Input request = inputMap.get(claim.Id);
            if (request == null) {
                continue;
            }

            // Defense-in-depth: skip if already decided. Prevents an Approved
            // claim being silently flipped to Rejected by a downstream misfire.
            if (claim.Status == 'Approved' || claim.Status == 'Rejected') {
                alreadyDecided.add(claim.Id);
                continue;
            }

            claim.Status = 'Rejected';
            claim.Status__c = 'Rejected';
            claim.RejectionDate__c = System.now();
            if (String.isNotBlank(request.reasonCode)) {
                claim.ReasonCode__c = request.reasonCode;
            }
            if (String.isNotBlank(request.decisionRationale)) {
                claim.DecisionRationale__c = request.decisionRationale;
            }
            if (String.isNotBlank(request.approverSlackRef)) {
                claim.ApproverSlackRef__c = request.approverSlackRef;
            }
            updates.add(claim);
        }

        if (!updates.isEmpty()) {
            update updates;
            // Notify each dealer on WhatsApp. ComposeDealerRejectionMessage
            // (called inside notify for REJECTED) uses reasonCode and rationale
            // as separate inputs to the Prompt Builder template for empathetic,
            // personalized output.
            for (Claim claim : updates) {
                Input req = inputMap.get(claim.Id);
                String reasonCode = (req != null) ? req.reasonCode : null;
                String rationale = (req != null) ? req.decisionRationale : null;
                SendWhatsAppClaimDecision.notify(
                    claim.Id,
                    SendWhatsAppClaimDecision.REJECTED,
                    reasonCode,
                    rationale
                );
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
                    result.message = 'Claim rejected successfully. Dealer notified on WhatsApp.';
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