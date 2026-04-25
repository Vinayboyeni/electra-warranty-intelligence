/**
 * ClaimStatusTrigger
 *
 * Watches for Claims transitioning into a decided state (Approved or Rejected)
 * and fires a dealer trust-score recalculation for affected Accounts.
 *
 * Kept intentionally thin: detect the transition, collect Account Ids,
 * hand off to the service class.
 */
trigger ClaimStatusTrigger on Claim (after update) {
    Set<Id> dealerIdsToRecalc = new Set<Id>();

    for (Claim newClaim : Trigger.new) {
        Claim oldClaim = Trigger.oldMap.get(newClaim.Id);
        if (oldClaim == null) continue;

        Boolean statusChanged = newClaim.Status != oldClaim.Status;
        Boolean nowDecided    = newClaim.Status == 'Approved'
                             || newClaim.Status == 'Rejected';

        if (statusChanged && nowDecided && newClaim.AccountId != null) {
            dealerIdsToRecalc.add(newClaim.AccountId);
        }
    }

    if (!dealerIdsToRecalc.isEmpty()) {
        DealerTrustScoreService.recalculate(dealerIdsToRecalc);
    }
}
