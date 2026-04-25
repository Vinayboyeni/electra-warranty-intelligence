public with sharing class RequestDealerClarification {
    public class Input {
        @InvocableVariable(label='Claim Id' description='Id of the Claim that requires clarification.')
        public Id claimId;

        @InvocableVariable(label='Clarification Request' description='Text of the clarification request to send back to the dealer.')
        public String clarificationRequest;

        @InvocableVariable(label='Approver Slack Reference' description='Slack thread or message reference for the clarification request.')
        public String approverSlackRef;

        @InvocableVariable(label='Requires Follow Up' description='Flag indicating this claim needs follow-up from the dealer.')
        public Boolean requiresFollowUp;
    }

    public class Result {
        @InvocableVariable(label='Claim Id' description='Id of the processed claim.') public Id claimId;
        @InvocableVariable(label='Status' description='Status of the clarification request operation.') public String status;
        @InvocableVariable(label='Message' description='Detailed message regarding the operation.') public String message;
        @InvocableVariable(label='Dealer WhatsApp Number' description='WhatsApp number from the claim.') public String dealerWhatsAppNumber;
        @InvocableVariable(label='Submission Channel' description='The channel used for submission.') public String submissionChannel;
    }

    @InvocableMethod(label='Request Dealer Clarification' description='Push a Claim back to the Dealer requesting additional information or evidence. This changes the status to Needs More Info and sends a notification to the Dealer.')
    public static List<Result> requestClarification(List<Input> inputs) {
        List<Result> output = new List<Result>();
        if (inputs == null) {
            return output;
        }

        Map<Id, Input> inputMap = new Map<Id, Input>();
        for (Input input : inputs) {
            if (input != null && input.claimId != null) {
                inputMap.put(input.claimId, input);
            }
        }
        if (inputMap.isEmpty()) {
            return output;
        }

        List<Claim> claims = [
            SELECT Id, Status, ClarificationRequest__c, RequiresFollowUp__c, ApproverSlackRef__c, DealerWhatsAppNumber__c, SubmissionChannel__c
            FROM Claim
            WHERE Id IN :inputMap.keySet()
        ];

        List<Claim> updates = new List<Claim>();
        for (Claim claim : claims) {
            Input request = inputMap.get(claim.Id);
            if (request == null) {
                continue;
            }

            claim.Status = 'Needs More Info';
            claim.Status__c = 'Needs More Info';
            if (String.isNotBlank(request.clarificationRequest)) {
                claim.ClarificationRequest__c = request.clarificationRequest;
            }
            claim.RequiresFollowUp__c = request.requiresFollowUp == null ? true : request.requiresFollowUp;
            if (String.isNotBlank(request.approverSlackRef)) {
                claim.ApproverSlackRef__c = request.approverSlackRef;
            }
            updates.add(claim);
        }

        if (!updates.isEmpty()) {
            update updates;
        }

        for (Input request : inputs) {
            Result result = new Result();
            result.claimId = request == null ? null : request.claimId;
            if (request != null && request.claimId != null && inputMap.containsKey(request.claimId)) {
                Claim c = null;
                for(Claim clm : claims) if(clm.Id == request.claimId) c = clm;
                
                result.status = 'Success';
                result.message = 'Clarification request recorded.';
                if (c != null) {
                    result.dealerWhatsAppNumber = c.DealerWhatsAppNumber__c;
                    result.submissionChannel = c.SubmissionChannel__c;
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