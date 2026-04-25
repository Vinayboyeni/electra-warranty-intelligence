// without sharing — runs during claim creation flow as the agent service user
// and must update every claim record regardless of sharing.
public without sharing class RouteClaimToApproverQueue {
    public class Input {
        @InvocableVariable(label='Claim Id' description='The Claim Id to route.')
        public Id claimId;
        @InvocableVariable(label='Priority' description='Priority for routing.')
        public String priority;
        @InvocableVariable(label='Preferred Queue Developer Name' description='Developer name of the preferred queue to route to.')
        public String preferredQueueDeveloperName;
    }

    public class Result {
        @InvocableVariable(label='Claim Id' description='Id of the processed claim.') public Id claimId;
        @InvocableVariable(label='Queue Name' description='Name of the queue the claim was routed to.') public String queueName;
        @InvocableVariable(label='Status' description='Status of the routing operation (Success/Error).') public String status;
        @InvocableVariable(label='Message' description='Detailed message regarding the routing.') public String message;
    }

    private static final String DEFAULT_QUEUE_NAME = 'Warranty Claim Approvers';
    private static final Decimal AUTO_APPROVE_COST_CAP = 500;
    private static final Decimal AUTO_APPROVE_CONFIDENCE_MIN = 90;
    private static final Decimal AUTO_APPROVE_TRUST_MIN = 75;

    @InvocableMethod(label='Route Claim to Approver Queue' description='Escalates or formally routes a Submitted Claim to the designated human Approver Queue (e.g., Warranty Claim Approvers) for manual review.')
    public static List<Result> route(List<Input> inputs) {
        List<Result> output = new List<Result>();
        if (inputs == null) {
            return output;
        }

        Set<Id> claimIds = new Set<Id>();
        for (Input input : inputs) {
            if (input != null && input.claimId != null) {
                claimIds.add(input.claimId);
            }
        }
        if (claimIds.isEmpty()) {
            return output;
        }

        Map<Id, Claim> claims = new Map<Id, Claim>([
            SELECT Id, Status, Eligibility__c, EstimatedCost__c, AI_Confidence__c,
                   ApproverQueue__c, Account.DealerTrustScore__c
            FROM Claim
            WHERE Id IN :claimIds
        ]);

        Set<String> queueNames = new Set<String>{ DEFAULT_QUEUE_NAME };
        for (Claim claim : claims.values()) {
            if (!String.isBlank(claim.ApproverQueue__c)) {
                queueNames.add(claim.ApproverQueue__c);
            }
        }

        Map<String, Group> queueByName = new Map<String, Group>();
        for (Group q : [
            SELECT Id, Name
            FROM Group
            WHERE Type = 'Queue' AND Name IN :queueNames
        ]) {
            queueByName.put(q.Name, q);
        }

        List<Claim> updates = new List<Claim>();

        for (Input input : inputs) {
            Result result = new Result();
            result.claimId = input == null ? null : input.claimId;
            if (input == null || input.claimId == null) {
                result.status = 'Error';
                result.message = 'Invalid claim input.';
                output.add(result);
                continue;
            }

            Claim claim = claims.get(input.claimId);
            if (claim == null) {
                result.status = 'Error';
                result.message = 'Claim not found.';
                output.add(result);
                continue;
            }

            Decimal confidence = claim.AI_Confidence__c != null ? claim.AI_Confidence__c : 0;
            Decimal cost = claim.EstimatedCost__c != null ? claim.EstimatedCost__c : 999999;
            Decimal trustScore = (claim.Account != null && claim.Account.DealerTrustScore__c != null)
                ? claim.Account.DealerTrustScore__c : 0;
            String eligibility = claim.Eligibility__c != null ? claim.Eligibility__c : '';

            Boolean canAutoApprove = eligibility == 'Likely'
                && confidence >= AUTO_APPROVE_CONFIDENCE_MIN
                && cost <= AUTO_APPROVE_COST_CAP
                && trustScore >= AUTO_APPROVE_TRUST_MIN;

            String targetStatus;
            if (eligibility == 'Not Covered') {
                // High confidence rejection — auto-reject, no human needed
                targetStatus = 'Rejected';
                claim.Status = targetStatus;
                claim.DecisionRationale__c = 'Auto-rejected: Coverage engine determined part/vehicle is not covered.';
                result.message = 'Auto-rejected: not covered.';
            } else if (canAutoApprove) {
                // Low cost + high confidence + trusted dealer — auto-approve
                targetStatus = 'Approved';
                claim.Status = targetStatus;
                claim.Auto_Approved__c = true;
                claim.ApprovalDate__c = System.now();
                claim.DecisionRationale__c = 'Auto-approved: Likely covered, cost within threshold ($'
                    + cost + '), dealer trust score ' + trustScore.intValue() + '/100.';
                result.message = 'Auto-approved.';
            } else {
                // Needs human review
                targetStatus = 'Pending Approver Review';
                claim.Status = targetStatus;
                String targetQueueName = String.isBlank(claim.ApproverQueue__c)
                    ? DEFAULT_QUEUE_NAME : claim.ApproverQueue__c;
                Group targetQueue = queueByName.get(targetQueueName);
                if (targetQueue != null) {
                    claim.OwnerId = targetQueue.Id;
                    result.queueName = targetQueue.Name;
                }
                result.message = 'Routed to approver queue.';
            }

            updates.add(claim);
            result.status = claim.Status;
            output.add(result);
        }

        if (!updates.isEmpty()) {
            update updates;
        }

        return output;
    }
}