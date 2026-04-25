@IsTest
private class FindVehicleByVinTest {
    @TestSetup
    static void setupData() {
        Account dealer = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        TestDataFactory.createWarranty(v.AssetId);
        TestDataFactory.createClaim(dealer.Id, v.AssetId);
    }

    @IsTest
    static void testFindByVinSuccess() {
        Vehicle v = [SELECT VehicleIdentificationNumber FROM Vehicle LIMIT 1];
        FindVehicleByVinInput req = new FindVehicleByVinInput();
        req.vin = v.VehicleIdentificationNumber;
        
        Test.startTest();
        List<FindVehicleByVinResult> results = FindVehicleByVin.findByVin(new List<FindVehicleByVinInput>{ req });
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assertEquals(v.VehicleIdentificationNumber, results[0].vin);
    }

    @IsTest
    static void testFindByVinNotFound() {
        FindVehicleByVinInput req = new FindVehicleByVinInput();
        req.vin = 'NON-EXISTENT';
        
        Test.startTest();
        List<FindVehicleByVinResult> results = FindVehicleByVin.findByVin(new List<FindVehicleByVinInput>{ req });
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assertEquals(null, results[0].vehicleId);
    }
}