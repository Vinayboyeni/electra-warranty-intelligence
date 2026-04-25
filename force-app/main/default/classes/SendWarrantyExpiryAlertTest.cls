@IsTest
private class SendWarrantyExpiryAlertTest {

    @IsTest
    static void testNullInput() {
        List<SendWarrantyExpiryAlert.Result> results = SendWarrantyExpiryAlert.send(null);
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testNullWarrantyId() {
        SendWarrantyExpiryAlert.Input inp = new SendWarrantyExpiryAlert.Input();
        inp.assetWarrantyId = null;
        Test.startTest();
        List<SendWarrantyExpiryAlert.Result> results = SendWarrantyExpiryAlert.send(
            new List<SendWarrantyExpiryAlert.Input>{ inp }
        );
        Test.stopTest();
        // Null id filtered out → warrantyIds empty → returns empty list
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testSuccessWithVin() {
        Vehicle v = TestDataFactory.createVehicle();
        AssetWarranty aw = TestDataFactory.createWarranty(v.AssetId);

        SendWarrantyExpiryAlert.Input inp = new SendWarrantyExpiryAlert.Input();
        inp.assetWarrantyId = aw.Id;
        Test.startTest();
        List<SendWarrantyExpiryAlert.Result> results = SendWarrantyExpiryAlert.send(
            new List<SendWarrantyExpiryAlert.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].sent);
        System.assertEquals(v.VehicleIdentificationNumber, results[0].vin);
        System.assertNotEquals(null, results[0].expiryDate);
    }

    @IsTest
    static void testSuccessNoVin() {
        // Asset without a linked Vehicle — VIN resolves to null
        Product2 p = new Product2(Name = 'Test Product No VIN', IsActive = true);
        insert p;
        Account owner = new Account(Name = 'Test Owner No VIN');
        insert owner;
        Asset ast = new Asset(Name = 'Test Asset No VIN', AccountId = owner.Id, Product2Id = p.Id);
        insert ast;

        AssetWarranty aw = new AssetWarranty(
            AssetId  = ast.Id,
            Vehicle__c = ast.Id,
            StartDate  = Date.today().addDays(-10),
            EndDate    = Date.today().addDays(20),
            MileageCap__c = 50000,
            CoveredCategories__c = 'Battery',
            LaborPolicy__c = 'Standard'
        );
        insert aw;

        SendWarrantyExpiryAlert.Input inp = new SendWarrantyExpiryAlert.Input();
        inp.assetWarrantyId = aw.Id;
        Test.startTest();
        List<SendWarrantyExpiryAlert.Result> results = SendWarrantyExpiryAlert.send(
            new List<SendWarrantyExpiryAlert.Input>{ inp }
        );
        Test.stopTest();
        System.assertEquals(true, results[0].sent);
        System.assertEquals(null, results[0].vin);
    }

    @IsTest
    static void testBulkInvocation() {
        Vehicle v1 = TestDataFactory.createVehicle();
        Vehicle v2 = TestDataFactory.createVehicle();
        AssetWarranty aw1 = TestDataFactory.createWarranty(v1.AssetId);
        AssetWarranty aw2 = TestDataFactory.createWarranty(v2.AssetId);

        SendWarrantyExpiryAlert.Input inp1 = new SendWarrantyExpiryAlert.Input();
        inp1.assetWarrantyId = aw1.Id;
        SendWarrantyExpiryAlert.Input inp2 = new SendWarrantyExpiryAlert.Input();
        inp2.assetWarrantyId = aw2.Id;

        Test.startTest();
        List<SendWarrantyExpiryAlert.Result> results = SendWarrantyExpiryAlert.send(
            new List<SendWarrantyExpiryAlert.Input>{ inp1, inp2 }
        );
        Test.stopTest();
        System.assertEquals(2, results.size());
        System.assertEquals(true, results[0].sent);
        System.assertEquals(true, results[1].sent);
    }
}