/**
 * GetPendingClarification - Agentforce Invocable Action
 *
 * Returns the OEM approver's clarification question for a claim that is in
 * "Needs More Info" status. Used by the dealer agent right after GetClaimStatus
 * so the dealer sees the actual question and can reply in the same chat —
 * no inbound push needed. Pairs with SubmitDealerClarificationResponse.
 *
 * Lookup mirrors GetClaimStatus: claim number first (with the same WC- suffix
 * fallback), then VIN.
 */
public without sharing class GetPendingClarification {

    public class Input {
        @InvocableVariable(label='Claim Number' description='Claim number to look up (e.g., WC-00042). Either claimNumber or vin is required.' required=false)
        public String claimNumber;

        @InvocableVariable(label='VIN' description='17-character VIN. Used to find the most recent claim if no claim number is provided.' required=false)
        public String vin;
    }

    public class Result {
        @InvocableVariable(label='Claim Number' description='Confirmed claim number.')
        public String claimNumber;

        @InvocableVariable(label='Has Pending Clarification' description='True when the claim is in Needs More Info and a question is on file.')
        public Boolean hasPendingClarification;

        @InvocableVariable(label='Clarification Question' description='The OEM approver clarification question for the dealer to answer.')
        public String clarificationQuestion;

        @InvocableVariable(label='Claim Status' description='Current status of the claim.')
        public String claimStatus;

        @InvocableVariable(label='Message' description='Result message for the agent to relay.')
        public String message;
    }

    @InvocableMethod(
        label='Get Pending Clarification'
        description='Returns the OEM approver clarification question for a claim in Needs More Info status, so the dealer can reply in chat.'
    )
    public static List<Result> getClarification(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        for (Input inp : inputs) {
            Result res = new Result();
            res.hasPendingClarification = false;

            Claim matched = findClaim(inp);

            if (matched == null) {
                res.message = 'No claim found. Please verify your claim number or VIN.';
                results.add(res);
                continue;
            }

            res.claimNumber = matched.Name;
            res.claimStatus = matched.Status;

            Boolean isPending = 'Needs More Info'.equalsIgnoreCase(matched.Status)
                && String.isNotBlank(matched.ClarificationRequest__c);

            if (isPending) {
                res.hasPendingClarification = true;
                res.clarificationQuestion = matched.ClarificationRequest__c;
                res.message = 'The OEM approver has asked: ' + matched.ClarificationRequest__c;
            } else if ('Needs More Info'.equalsIgnoreCase(matched.Status)) {
                res.message = 'Claim is awaiting more info but no specific question is on file. Reply AGENT to reach a specialist.';
            } else {
                res.message = 'No pending clarification. Current status: ' + matched.Status + '.';
            }

            results.add(res);
        }
        return results;
    }

    private static Claim findClaim(Input inp) {
        if (inp == null) return null;

        if (String.isNotBlank(inp.claimNumber)) {
            List<Claim> byNumber = [
                SELECT Id, Name, Status, ClarificationRequest__c
                FROM Claim WHERE Name = :inp.claimNumber LIMIT 1
            ];
            if (!byNumber.isEmpty()) return byNumber[0];

            // WC-XXXXX suffix fallback (matches GetClaimStatus pattern)
            if (inp.claimNumber.startsWithIgnoreCase('WC-') && inp.claimNumber.length() == 8) {
                String suffix = inp.claimNumber.substring(3).toUpperCase();
                for (Claim c : [
                    SELECT Id, Name, Status, ClarificationRequest__c
                    FROM Claim ORDER BY CreatedDate DESC LIMIT 200
                ]) {
                    if (String.valueOf(c.Id).right(5).toUpperCase() == suffix) return c;
                }
            }
        }

        if (String.isNotBlank(inp.vin)) {
            List<Vehicle> vehicles = [
                SELECT AssetId FROM Vehicle WHERE VehicleIdentificationNumber = :inp.vin LIMIT 1
            ];
            if (!vehicles.isEmpty() && vehicles[0].AssetId != null) {
                Id assetId = vehicles[0].AssetId;
                List<Claim> byVin = [
                    SELECT Id, Name, Status, ClarificationRequest__c
                    FROM Claim WHERE Vehicle__c = :assetId
                    ORDER BY CreatedDate DESC LIMIT 1
                ];
                if (!byVin.isEmpty()) return byVin[0];
            }
        }
        return null;
    }
}