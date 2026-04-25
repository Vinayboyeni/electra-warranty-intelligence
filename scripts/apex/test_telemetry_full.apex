// Publish events for ALL 4 demo VINs, then query Claims to see which populated.
List<TelemetrySignal__e> events = new List<TelemetrySignal__e>{
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOFRD0800000',
        FaultCount30d__c = 3,
        OffNetworkCharges30d__c = 1,
        LastEventDate__c = Datetime.newInstance(2026, 4, 19, 19, 8, 0)
    ),
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOHAPY010000',
        FaultCount30d__c = 0,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 22, 9, 0, 0)
    ),
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOSRT1000000',
        FaultCount30d__c = 0,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 20, 16, 45, 0)
    ),
    new TelemetrySignal__e(
        VIN__c = 'ELXDEMOBIG0300000',
        FaultCount30d__c = 2,
        OffNetworkCharges30d__c = 0,
        LastEventDate__c = Datetime.newInstance(2026, 4, 22, 7, 11, 0)
    )
};

List<Database.SaveResult> results = EventBus.publish(events);
Integer ok = 0;
for (Database.SaveResult sr : results) if (sr.isSuccess()) ok++;
System.debug('Events published: ' + ok + '/' + results.size());
System.debug('Trigger will process async — wait 2-3 seconds then re-run diagnose_telemetry.');
