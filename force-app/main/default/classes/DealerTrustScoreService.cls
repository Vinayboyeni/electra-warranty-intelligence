/**
 * DealerTrustScoreService
 *
 * Recalculates Account.DealerTrustScore__c from each dealer's last-90-days
 * decision history. Called from ClaimStatusTrigger whenever a Claim flips
 * into Approved or Rejected.
 *
 * Scoring formula:
 *   score = round( approved / (approved + rejected) × 100 )
 *   minimum sample size: 3 decided claims in the window
 *
 * When a dealer has fewer than 3 decided claims we leave the existing score
 * alone (protects seeded demo values + avoids punishing new dealers on
 * their first-ever rejection).
 *
 * Runs synchronously. Updates only Account — no recursion risk with the
 * Claim trigger that invoked it.
 */
public without sharing class DealerTrustScoreService {

    private static final Integer WINDOW_DAYS     = 90;
    private static final Integer MIN_SAMPLE_SIZE = 3;

    public static void recalculate(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return;

        Datetime cutoff = System.now().addDays(-WINDOW_DAYS);

        Map<Id, Integer> approvedByAcct = new Map<Id, Integer>();
        Map<Id, Integer> rejectedByAcct = new Map<Id, Integer>();

        try {
            for (AggregateResult ar : [
                SELECT AccountId acctId, Status stat, COUNT(Id) total
                FROM Claim
                WHERE AccountId IN :accountIds
                  AND Status IN ('Approved', 'Rejected')
                  AND LastModifiedDate >= :cutoff
                GROUP BY AccountId, Status
            ]) {
                Id acctId = (Id) ar.get('acctId');
                String stat = (String) ar.get('stat');
                Integer total = (Integer) ar.get('total');
                if (acctId == null || stat == null || total == null) continue;
                if (stat == 'Approved') approvedByAcct.put(acctId, total);
                else if (stat == 'Rejected') rejectedByAcct.put(acctId, total);
            }
        } catch (Exception e) {
            System.debug('DealerTrustScoreService aggregate failed: ' + e.getMessage());
            return;
        }

        List<Account> updates = new List<Account>();
        for (Id acctId : accountIds) {
            Integer approved = approvedByAcct.containsKey(acctId) ? approvedByAcct.get(acctId) : 0;
            Integer rejected = rejectedByAcct.containsKey(acctId) ? rejectedByAcct.get(acctId) : 0;
            Integer total    = approved + rejected;
            if (total < MIN_SAMPLE_SIZE) continue;

            Integer score = (Integer) Math.round(((Decimal) approved / total) * 100);
            if (score < 0)   score = 0;
            if (score > 100) score = 100;

            updates.add(new Account(Id = acctId, DealerTrustScore__c = score));
        }

        if (updates.isEmpty()) return;
        try {
            update updates;
        } catch (Exception e) {
            System.debug('DealerTrustScoreService update failed: ' + e.getMessage()
                + '\n' + e.getStackTraceString());
        }
    }
}