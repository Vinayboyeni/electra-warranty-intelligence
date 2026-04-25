// Publishes a fake TelemetrySignal__e for the fraud-scenario VIN.
// If the trigger works, Claims linked to that VIN will show TelemetrySignal__c populated.

TelemetrySignal__e evt = new TelemetrySignal__e(
    VIN__c = 'ELXDEMOFRD0800000',
    FaultCount30d__c = 3,
    OffNetworkCharges30d__c = 1,
    LastEventDate__c = Datetime.newInstance(2026, 4, 19, 19, 8, 0)
);
Database.SaveResult sr = EventBus.publish(evt);
System.debug('Publish success: ' + sr.isSuccess());
if (!sr.isSuccess()) {
    for (Database.Error err : sr.getErrors()) {
        System.debug('Publish error: ' + err.getMessage());
    }
}

// Wait a moment, then check if Claims were updated
// (Platform events are async; we can't check immediately, but the publish result tells us if the event was accepted)
System.debug('Event published. Check Claim.TelemetrySignal__c in 5 seconds.');
