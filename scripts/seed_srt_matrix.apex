// Seed SRT Matrix baseline amounts for all covered part categories.
// Idempotent: upserts by Part_Category__c (External ID) so you can re-run safely.
//
// Baselines match the hardcoded fallback in ValidateRepairEstimate.cls
// so behavior stays consistent whether the query hits the DMO or falls back.

List<SRTMatrix__c> baselines = new List<SRTMatrix__c>{
    new SRTMatrix__c(Part_Category__c = 'Battery',          Baseline_Amount__c = 4500, IsActive__c = true),
    new SRTMatrix__c(Part_Category__c = 'Drive Motor',      Baseline_Amount__c = 3200, IsActive__c = true),
    new SRTMatrix__c(Part_Category__c = 'Engine',           Baseline_Amount__c = 5500, IsActive__c = true),
    new SRTMatrix__c(Part_Category__c = 'Transmission',     Baseline_Amount__c = 2800, IsActive__c = true),
    new SRTMatrix__c(Part_Category__c = 'Brake System',     Baseline_Amount__c = 900,  IsActive__c = true),
    new SRTMatrix__c(Part_Category__c = 'Suspension',       Baseline_Amount__c = 1200, IsActive__c = true),
    new SRTMatrix__c(Part_Category__c = 'HVAC',             Baseline_Amount__c = 1500, IsActive__c = true),
    new SRTMatrix__c(Part_Category__c = 'Electrical System',Baseline_Amount__c = 800,  IsActive__c = true),
    new SRTMatrix__c(Part_Category__c = 'Infotainment',     Baseline_Amount__c = 600,  IsActive__c = true),
    new SRTMatrix__c(Part_Category__c = 'Charging System',  Baseline_Amount__c = 1100, IsActive__c = true)
};

// Set Name too (required on custom objects)
for (SRTMatrix__c r : baselines) {
    r.Name = r.Part_Category__c;
}

// Upsert by external id
Schema.SObjectField extIdField = SRTMatrix__c.Part_Category__c;
Database.UpsertResult[] results = Database.upsert(baselines, extIdField, false);

Integer created = 0, updated = 0, failed = 0;
for (Integer i = 0; i < results.size(); i++) {
    Database.UpsertResult r = results[i];
    if (r.isSuccess()) {
        if (r.isCreated()) created++;
        else updated++;
    } else {
        failed++;
        System.debug('FAILED: ' + baselines[i].Part_Category__c + ' — '
            + r.getErrors()[0].getMessage());
    }
}

System.debug('===============================================');
System.debug('SRT Matrix seed complete');
System.debug('  Created: ' + created);
System.debug('  Updated: ' + updated);
System.debug('  Failed:  ' + failed);
System.debug('===============================================');

// Verify
for (SRTMatrix__c r : [
    SELECT Name, Part_Category__c, Baseline_Amount__c, IsActive__c
    FROM SRTMatrix__c
    ORDER BY Part_Category__c
]) {
    System.debug('  ' + r.Part_Category__c + ': $' + r.Baseline_Amount__c
        + (r.IsActive__c ? ' (active)' : ' (inactive)'));
}
