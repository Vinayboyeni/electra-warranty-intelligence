public with sharing class SubmitDealerClarificationResponse {
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
    }

    @InvocableMethod(label='Submit Dealer Response' description='Submits the dealer written response to the OEM adjuster clarification request. Moves the claim back to the Pending Approver Review state.')
    public static List<Result> submitResponse(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        Map<String, String> responseMap = new Map<String, String>();
        for (Input i : inputs) {
            if (String.isNotBlank(i.claimNumber)) {
                responseMap.put(i.claimNumber, i.dealerResponse);
            }
        }

        if (responseMap.isEmpty()) return results;

        List<Claim> claims = [
            SELECT Id, Name, Status, Status__c, DealerResponseSummary__c, RequiresFollowUp__c
            FROM Claim
            WHERE Name IN :responseMap.keySet()
        ];

        for (Claim c : claims) {
            c.DealerResponseSummary__c = responseMap.get(c.Name);
            c.Status = 'Pending Approver Review';
            c.RequiresFollowUp__c = false;
        }

        if (!claims.isEmpty()) {
            update claims;
        }

        for (Input i : inputs) {
            Result r = new Result();
            r.submitted = String.isNotBlank(i.claimNumber) && responseMap.containsKey(i.claimNumber);
            r.message = r.submitted ? 'Response submitted successfully.' : 'Invalid claim number.';
            results.add(r);
        }

        return results;
    }
}