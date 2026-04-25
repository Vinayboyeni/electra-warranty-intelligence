// Backfills AuthorizationPdfUrl__c on approved claims that are missing it.
// Calls GenerateApprovalAuthorization.generate for each; it handles PDF + writeback.
// Skip if you already like the current audit state.

List<Claim> approved = [
    SELECT Id, Name, AuthorizationPdfUrl__c
    FROM Claim
    WHERE Status = 'Approved'
      AND AuthorizationPdfUrl__c = null
    LIMIT 50
];
System.debug('Backfilling ' + approved.size() + ' approved claim(s) without PDF URL.');

Integer ok = 0, skipped = 0;
for (Claim c : approved) {
    try {
        String url = GenerateApprovalAuthorization.generate(c.Id);
        if (String.isNotBlank(url)) {
            ok++;
            System.debug('  ✓ ' + c.Name + ' → ' + url.left(60) + '...');
        } else {
            skipped++;
            System.debug('  · ' + c.Name + ' → generator returned null');
        }
    } catch (Exception e) {
        skipped++;
        System.debug('  ✗ ' + c.Name + ' → ' + e.getMessage());
    }
}
System.debug('Done. Populated: ' + ok + ', Skipped: ' + skipped);
