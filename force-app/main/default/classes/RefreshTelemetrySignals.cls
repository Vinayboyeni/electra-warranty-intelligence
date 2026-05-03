/**
 * RefreshTelemetrySignals
 *
 * Reads vehicle telemetry events directly from the Data Cloud DLM,
 * aggregates per VIN over the last 30 days, and publishes
 * TelemetrySignal__e Platform Events. The TelemetrySignalTrigger
 * subscriber then writes the rolled-up signal to matching Claim records.
 *
 * This class replaces the CI → Data Action → Platform Event UI chain
 * which is brittle to set up. The data source is still Data Cloud
 * (Vehicle_Telemetry__dlm) — only the orchestration moved into Apex
 * for reliability.
 *
 * Three callable surfaces:
 *   1. refresh()             — fire-and-forget, processes all VINs
 *   2. refreshForVins(set)   — targeted refresh for specific VINs
 *   3. execute(SchedulableContext) — schedulable for periodic refresh
 *
 * Schedule example:
 *   System.schedule('Telemetry refresh hourly', '0 0 * * * ?',
 *       new RefreshTelemetrySignals());
 */
public without sharing class RefreshTelemetrySignals implements Schedulable {

    private static final Integer WINDOW_DAYS = 30;

    /**
     * Schedulable entry point. Fires a full refresh when the cron triggers.
     */
    public void execute(SchedulableContext sc) {
        refresh();
    }

    /**
     * Process ALL VINs in the DLM. Returns the count of events published.
     */
    public static Integer refresh() {
        return refreshInternal(null);
    }

    /**
     * Process only specific VINs. Useful for live demos and ad-hoc triggers.
     */
    public static Integer refreshForVins(Set<String> vins) {
        return refreshInternal(vins);
    }

    private static Integer refreshInternal(Set<String> vinFilter) {
        // 1. Pull the telemetry events from the Data Cloud DLM.
        // Vehicle_Telemetry__dlm is queryable as a regular SObject.
        // Field names follow the Data Cloud convention: source-column__c plus
        // the appended __c (so vin → VIN_c__c, event_type → EventType_c__c).
        Datetime cutoff = System.now().addDays(-WINDOW_DAYS);
        String soql =
            'SELECT VIN_c__c, EventType_c__c, EventDate_c__c, Location_c__c '
            + 'FROM Vehicle_Telemetry__dlm '
            + 'WHERE EventDate_c__c >= :cutoff';
        if (vinFilter != null && !vinFilter.isEmpty()) {
            soql += ' AND VIN_c__c IN :vinFilter';
        }
        soql += ' LIMIT 5000';

        List<SObject> rows;
        try {
            rows = Database.query(soql);
        } catch (Exception e) {
            System.debug('RefreshTelemetrySignals DLM query failed: ' + e.getMessage());
            return 0;
        }
        if (rows.isEmpty()) {
            System.debug('No telemetry rows in window — nothing to publish.');
            return 0;
        }

        // 2. Aggregate per VIN: count Fault events, count off-network charges,
        //    track the most recent event date.
        Map<String, Integer> faultCounts  = new Map<String, Integer>();
        Map<String, Integer> offNetCounts = new Map<String, Integer>();
        Map<String, Datetime> lastEvent   = new Map<String, Datetime>();

        for (SObject r : rows) {
            String vin = (String) r.get('VIN_c__c');
            if (String.isBlank(vin)) continue;
            String etype = (String) r.get('EventType_c__c');
            String loc   = (String) r.get('Location_c__c');
            Datetime ed  = (Datetime) r.get('EventDate_c__c');

            if (!faultCounts.containsKey(vin))  faultCounts.put(vin, 0);
            if (!offNetCounts.containsKey(vin)) offNetCounts.put(vin, 0);

            if ('Fault'.equalsIgnoreCase(etype)) {
                faultCounts.put(vin, faultCounts.get(vin) + 1);
            } else if ('Charge'.equalsIgnoreCase(etype)
                       && String.isNotBlank(loc)
                       && loc.startsWithIgnoreCase('NonNetwork')) {
                offNetCounts.put(vin, offNetCounts.get(vin) + 1);
            }
            if (ed != null) {
                Datetime prev = lastEvent.get(vin);
                if (prev == null || ed > prev) lastEvent.put(vin, ed);
            }
        }

        // 3. Build + publish Platform Events. Trigger handles the writeback
        //    to Claim.TelemetrySignal__c.
        List<TelemetrySignal__e> events = new List<TelemetrySignal__e>();
        for (String vin : faultCounts.keySet()) {
            events.add(new TelemetrySignal__e(
                VIN__c                  = vin,
                FaultCount30d__c        = faultCounts.get(vin),
                OffNetworkCharges30d__c = offNetCounts.get(vin),
                LastEventDate__c        = lastEvent.get(vin)
            ));
        }
        if (events.isEmpty()) return 0;

        Integer ok = 0;
        for (Database.SaveResult sr : EventBus.publish(events)) {
            if (sr.isSuccess()) ok++;
        }
        System.debug('Published ' + ok + ' / ' + events.size() + ' telemetry events.');
        return ok;
    }
}