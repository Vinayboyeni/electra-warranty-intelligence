System.debug('=== VINs in your org ===');
List<Vehicle> vs = [
    SELECT VehicleIdentificationNumber, Name, AssetId
    FROM Vehicle
    WHERE VehicleIdentificationNumber != null
    ORDER BY CreatedDate DESC
    LIMIT 20
];
System.debug('Total vehicles with VIN: ' + vs.size());
for (Vehicle v : vs) {
    System.debug('VIN: ' + v.VehicleIdentificationNumber + ' | Vehicle: ' + v.Name);
}
