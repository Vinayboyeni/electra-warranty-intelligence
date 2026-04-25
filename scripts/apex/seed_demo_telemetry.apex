// Pre-seeds TelemetrySignal__c on all Claims for demo VINs.
// Run this 30 seconds before the demo.
// Publishes one Platform Event per demo VIN; the trigger updates all matching Claims.

List<TelemetrySignal__e> events = new List<TelemetrySignal__e>{
    // Fraud scenario — the "flagged" narrative
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOFRD0800000',
        FaultCount30d__c = 3,
        OffNetworkCharges30d__c = 1,
        LastEventDate__c = Datetime.newInstance(2026, 4, 19, 19, 8, 0)
    ),
    // Big-ticket scenario — moderate risk
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOBIG0300000',
        FaultCount30d__c = 2,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 22, 7, 11, 0)
    ),
    // SRT scenario — clean
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOSRT1000000',
        FaultCount30d__c = 0,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 20, 16, 45, 0)
    ),
    // Happy path — clean
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOHAPY010000',
        FaultCount30d__c = 0,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 22, 9, 0, 0)
    ),
    // Add additional VINs as needed — copy the blocks above
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOSAFE090000',
        FaultCount30d__c = 0,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 23, 10, 0, 0)
    ),
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOREJ0500000',
        FaultCount30d__c = 1,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 21, 15, 30, 0)
    ),
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOGDWL060000',
        FaultCount30d__c = 0,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 22, 11, 0, 0)
    ),
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMODUP0700000',
        FaultCount30d__c = 0,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 22, 14, 0, 0)
    ),
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOBORD040000',
        FaultCount30d__c = 1,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 22, 13, 0, 0)
    )
};

List<Database.SaveResult> results = EventBus.publish(events);
Integer ok = 0;
for (Database.SaveResult sr : results) if (sr.isSuccess()) ok++;
System.debug('Seeded telemetry events: ' + ok + '/' + results.size());
System.debug('TelemetrySignal__c will populate on any Claim linked to these VINs within 2-5 seconds.');
