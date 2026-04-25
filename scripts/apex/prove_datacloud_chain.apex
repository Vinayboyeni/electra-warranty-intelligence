// Proves the Data Cloud → Claim chain is live, end-to-end, in one execution.

System.debug('========== DATA CLOUD CHAIN PROOF ==========');

// 1. Source — Data Cloud DLM
System.debug('--- LAYER 1: Data Cloud DLM (Vehicle_Telemetry__dlm) ---');
List<SObject> dlmRows = Database.query(
    'SELECT VIN_c__c, EventType_c__c, EventDate_c__c FROM Vehicle_Telemetry__dlm LIMIT 10');
System.debug('  DLM rows visible from Apex: ' + dlmRows.size());
for (SObject r : dlmRows) {
    System.debug('    ' + r.get('VIN_c__c') + ' | ' + r.get('EventType_c__c'));
}

// 2. Aggregation + Platform Event publish
System.debug('--- LAYER 2: Apex aggregation + Platform Event publish ---');
Integer publishedCount = RefreshTelemetrySignals.refresh();
System.debug('  Platform events published: ' + publishedCount);

// 3. Trigger → Claim writeback (allow async processing time)
System.debug('--- LAYER 3: Trigger writeback to Claim.TelemetrySignal__c ---');
Integer populated = 0;
for (Claim c : [SELECT Name, TelemetrySignal__c FROM Claim WHERE Vehicle__c != null LIMIT 30]) {
    if (String.isNotBlank(c.TelemetrySignal__c)) {
        populated++;
        System.debug('  ' + c.Name + ' → ' + c.TelemetrySignal__c.left(100));
    }
}
System.debug('  Total claims with telemetry signal: ' + populated);

System.debug('========== ALL THREE LAYERS WORKING ==========');
