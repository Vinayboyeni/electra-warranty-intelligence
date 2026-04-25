// Diagnoses why Claim.TelemetrySignal__c is empty.
// Checks each link in the chain: VINs → Vehicles → Assets → Claims.

System.debug('=== TELEMETRY SIGNAL DIAGNOSTIC ===');

// 1. What VINs do we have in the Vehicle object?
System.debug('--- Vehicles in org ---');
List<Vehicle> allVehicles = [
    SELECT Id, Name, VehicleIdentificationNumber, AssetId
    FROM Vehicle
    LIMIT 20
];
System.debug('Found ' + allVehicles.size() + ' vehicles.');
for (Vehicle v : allVehicles) {
    System.debug('  VIN: ' + v.VehicleIdentificationNumber
        + ' | Name: ' + v.Name
        + ' | AssetId: ' + v.AssetId);
}

// 2. How many Claims have a Vehicle link?
System.debug('--- Claims with Vehicle link ---');
List<Claim> claims = [
    SELECT Id, Name, Vehicle__c, TelemetrySignal__c
    FROM Claim
    WHERE Vehicle__c != null
    LIMIT 20
];
System.debug('Found ' + claims.size() + ' claims with Vehicle__c populated.');
for (Claim c : claims) {
    System.debug('  Claim: ' + c.Name
        + ' | Vehicle__c (AssetId): ' + c.Vehicle__c
        + ' | Signal: ' + c.TelemetrySignal__c);
}

// 3. Does any Vehicle VIN match our CSV VINs?
System.debug('--- CSV VIN match check ---');
Set<String> csvVins = new Set<String>{
    'ELXDEMOFRD0800000',
    'ELXDEMOHAPY010000',
    'ELXDEMOSRT1000000',
    'ELXDEMOBIG0300000'
};
List<Vehicle> matched = [
    SELECT Id, VehicleIdentificationNumber, AssetId
    FROM Vehicle
    WHERE VehicleIdentificationNumber IN :csvVins
];
System.debug('CSV VINs matched in org: ' + matched.size());
for (Vehicle v : matched) {
    System.debug('  MATCH: ' + v.VehicleIdentificationNumber + ' → AssetId ' + v.AssetId);
}
if (matched.isEmpty()) {
    System.debug('*** NO MATCHES. The CSV has placeholder VINs that do not exist in your org. ***');
    System.debug('*** Fix: update the CSV with VINs from the "Vehicles in org" list above,');
    System.debug('*** re-upload to the Data Stream, re-run the CI, and re-trigger the Data Action. ***');
}
