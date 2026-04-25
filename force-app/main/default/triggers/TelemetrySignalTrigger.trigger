/**
 * TelemetrySignalTrigger
 *
 * Subscribes to the TelemetrySignal__e Platform Event fired by the Data
 * Cloud Data Action (Telemetry_Risk_Rollup_cio → Salesforce Platform Event).
 *
 * For each event:
 *   1. Look up the Vehicle by VIN
 *   2. Find any Claims linked to that Vehicle (Claim.Vehicle__c stores the
 *      Asset Id, which equals Vehicle.AssetId)
 *   3. Write a human-readable rolled-up string to Claim.TelemetrySignal__c
 *
 * The string is consumed by GetWarrantyClaimApprovalContext and surfaced
 * on the approver Slack card.
 */
trigger TelemetrySignalTrigger on TelemetrySignal__e (after insert) {
    Set<String> vinsInBatch = new Set<String>();
    Map<String, TelemetrySignal__e> signalByVin = new Map<String, TelemetrySignal__e>();

    for (TelemetrySignal__e evt : Trigger.new) {
        if (String.isBlank(evt.VIN__c)) continue;
        vinsInBatch.add(evt.VIN__c);
        signalByVin.put(evt.VIN__c, evt);
    }
    if (vinsInBatch.isEmpty()) return;

    // VIN → Asset Id (Claim.Vehicle__c stores Asset Id, per project convention)
    Map<Id, String> assetIdToVin = new Map<Id, String>();
    for (Vehicle v : [
        SELECT Id, AssetId, VehicleIdentificationNumber
        FROM Vehicle
        WHERE VehicleIdentificationNumber IN :vinsInBatch
    ]) {
        if (v.AssetId != null) assetIdToVin.put(v.AssetId, v.VehicleIdentificationNumber);
    }
    if (assetIdToVin.isEmpty()) return;

    List<Claim> updates = new List<Claim>();
    for (Claim c : [
        SELECT Id, Vehicle__c
        FROM Claim
        WHERE Vehicle__c IN :assetIdToVin.keySet()
    ]) {
        String vin = assetIdToVin.get(c.Vehicle__c);
        TelemetrySignal__e sig = signalByVin.get(vin);
        if (sig == null) continue;

        Integer faults  = (sig.FaultCount30d__c != null) ? sig.FaultCount30d__c.intValue() : 0;
        Integer offnet  = (sig.OffNetworkCharges30d__c != null) ? sig.OffNetworkCharges30d__c.intValue() : 0;

        String label = faults + ' fault codes, ' + offnet + ' off-network charges (last 30d)';
        if (sig.LastEventDate__c != null) {
            label += '. Last event: ' + sig.LastEventDate__c.format('MMM d, yyyy');
        }
        c.TelemetrySignal__c = label;
        updates.add(c);
    }

    if (!updates.isEmpty()) {
        try {
            update updates;
        } catch (Exception e) {
            System.debug('TelemetrySignalTrigger update failed: ' + e.getMessage());
        }
    }
}
