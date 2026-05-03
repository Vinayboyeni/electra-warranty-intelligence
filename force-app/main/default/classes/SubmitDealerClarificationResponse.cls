public without sharing class SubmitDealerClarificationResponse {
    public class Input {
        @InvocableVariable(label='Claim Number' description='The claim number (Name) of the record being responded to.')
        public String claimNumber;

        @InvocableVariable(label='Dealer Response' description='The text answer from the dealership.')
        public String dealerResponse;
    }

    public class Result {
        @InvocableVariable(label='Submitted' description='True if the response was successfully recorded.')
        public Boolean submitted;
        @InvocableVariable(label='Message' description='Result message.')
        public String message;
        @InvocableVariable(label='New Status' description='The Claim status after the response was recorded. Will be Pending Approver Review on success.')
        public String newStatus;
        @InvocableVariable(label='Claim Number Out' description='Echoed claim number for the agent to display.')
        public String claimNumberOut;
    }

    @InvocableMethod(label='Submit Dealer Response' description='Submits the dealer written response to the OEM adjuster clarification request. Moves the claim back to the Pending Approver Review state and triggers Slack re-notification via the existing Slack_Notify_Approver_Flow.')
    public static List<Result> submitResponse(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        Map<String, String> responseMap = new Map<String, String>();
        for (Input i : inputs) {
            if (String.isNotBlank(i.claimNumber)) {
                responseMap.put(i.claimNumber.trim(), i.dealerResponse);
            }
        }

        Map<String, Claim> claimByName = new Map<String, Claim>();
        if (!responseMap.isEmpty()) {
            for (Claim c : [
                SELECT Id, Name, Status, Status__c, DealerResponseSummary__c, RequiresFollowUp__c
                FROM Claim
                WHERE Name IN :responseMap.keySet()
            ]) {
                claimByName.put(c.Name, c);
            }
        }

        Set<String> updatedNames = new Set<String>();
        String dmlError = null;
        if (!claimByName.isEmpty()) {
            for (Claim c : claimByName.values()) {
                c.DealerResponseSummary__c = responseMap.get(c.Name);
                c.Status = 'Pending Approver Review';
                c.RequiresFollowUp__c = false;
            }
            try {
                update claimByName.values();
                updatedNames.addAll(claimByName.keySet());
            } catch (DmlException e) {
                dmlError = e.getMessage();
                System.debug('SubmitDealerClarificationResponse DML failed: ' + dmlError);
            }
        }

        for (Input i : inputs) {
            Result r = new Result();
            String key = String.isNotBlank(i.claimNumber) ? i.claimNumber.trim() : null;
            r.claimNumberOut = key;
            if (key == null) {
                r.submitted = false;
                r.message = 'Claim number is required.';
            } else if (!claimByName.containsKey(key)) {
                r.submitted = false;
                r.message = 'No claim found with that number.';
            } else if (dmlError != null) {
                r.submitted = false;
                r.message = 'Failed to update claim: ' + dmlError;
            } else if (updatedNames.contains(key)) {
                r.submitted = true;
                r.newStatus = 'Pending Approver Review';
                r.message = 'Response submitted successfully. Claim is now in Pending Approver Review.';
            } else {
                r.submitted = false;
                r.message = 'Unknown error.';
            }
            results.add(r);
        }

        return results;
    }
}