/**
 * GetPendingClaimsQueue
 *
 * Returns a compact summary of claims currently awaiting approver decision.
 * Invoked from the Warranty Approver Agent's QueueOverview subagent when the
 * adjuster asks "what's pending" / "show me the queue" / etc.
 *
 * Includes claims with Status in ('Pending Approver Review', 'Needs More Info').
 * Ordered by SLA deadline ascending so most urgent appear first.
 */
public with sharing class GetPendingClaimsQueue {

    public class Input {
        @InvocableVariable(label='Max Records' description='Upper limit on rows returned. Default 10.')
        public Integer maxRecords;
    }

    public class Result {
        @InvocableVariable(label='Queue Summary' description='Formatted markdown list of pending claims.')
        public String queueSummary;

        @InvocableVariable(label='Count' description='Number of pending claims returned.')
        public Integer count;

        @InvocableVariable(label='Has More' description='True if the queue contains more claims than returned.')
        public Boolean hasMore;
    }

    @InvocableMethod(
        label='Get Pending Claims Queue'
        description='Returns a formatted markdown summary of the claims awaiting approver decision. Sorted by SLA deadline ascending.'
    )
    public static List<Result> fetch(List<Input> inputs) {
        List<Result> out = new List<Result>();
        Integer rowLimit = 10;
        if (inputs != null && !inputs.isEmpty() && inputs[0] != null && inputs[0].maxRecords != null) {
            rowLimit = Math.min(Math.max(inputs[0].maxRecords, 1), 50);
        }

        List<Claim> claims = [
            SELECT Id, Name, Status, Account.Name, PartCategory__c, EstimatedCost__c,
                   Eligibility__c, SLA_Due_Date__c, Priority__c
            FROM Claim
            WHERE Status IN ('Pending Approver Review', 'Needs More Info')
            ORDER BY SLA_Due_Date__c ASC NULLS LAST, CreatedDate ASC
            LIMIT :(rowLimit + 1)
        ];

        Integer totalCount = claims.size();
        Boolean hasMore = totalCount > rowLimit;
        if (hasMore) {
            claims.remove(claims.size() - 1);
        }

        Result r = new Result();
        r.count = claims.size();
        r.hasMore = hasMore;

        if (claims.isEmpty()) {
            r.queueSummary = '*No claims pending approval right now.* Queue is clear.';
            out.add(r);
            return out;
        }

        String body = '*Pending claims (' + claims.size() + (hasMore ? '+' : '') + '):*\n';
        for (Claim c : claims) {
            String dueLabel = c.SLA_Due_Date__c != null
                ? c.SLA_Due_Date__c.format('MMM d, h:mm a')
                : 'no SLA set';
            String priority = String.isNotBlank(c.Priority__c) && c.Priority__c != 'Medium'
                ? ' [' + c.Priority__c + ']' : '';
            String dealer = (c.Account != null && c.Account.Name != null) ? c.Account.Name : 'Unknown dealer';
            String part = String.isNotBlank(c.PartCategory__c) ? c.PartCategory__c : 'N/A';
            String cost = c.EstimatedCost__c != null ? '$' + c.EstimatedCost__c.setScale(0) : 'N/A';
            String status = c.Status == 'Needs More Info' ? ' *(Needs More Info)*' : '';
            body += '• *' + c.Name + '*' + priority + ' — ' + dealer
                + ' | ' + part + ' | ' + cost
                + ' | ' + (c.Eligibility__c != null ? c.Eligibility__c : 'N/A')
                + ' | SLA: ' + dueLabel
                + status + '\n';
        }
        if (hasMore) {
            body += '\n_Showing first ' + rowLimit + '. Say "show more" or narrow by VIN/claim number._';
        }
        body += '\nSay *Review WC-XXXXX* to load full context and adjudicate.';

        r.queueSummary = body;
        out.add(r);
        return out;
    }
}
