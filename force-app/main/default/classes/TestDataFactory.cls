@IsTest
public class TestDataFactory {
    public static Account createDealer() {
        Account a = new Account(Name = 'Elite dealership', DealerTrustScore__c = 95);
        insert a;
        return a;
    }

    public static Contact createCustomer(Id accountId) {
        Contact c = new Contact(LastName = 'Smith', AccountId = accountId);
        insert c;
        return c;
    }

    public static Vehicle createVehicle() {
        Product2 p = new Product2(Name = 'Electra X5 Model', IsActive = true);
        insert p;

        VehicleDefinition vd = new VehicleDefinition(
            Name = 'Electra X5 Definition',
            ProductId = p.Id
        );
        insert vd;

        Account owner = new Account(Name = 'Test Owner');
        insert owner;

        Asset ast = new Asset(
            Name = 'Electra X5 Asset',
            AccountId = owner.Id,
            Product2Id = p.Id
        );
        insert ast;

        Vehicle v = new Vehicle(
            Name = '2023 Electra X5', 
            VehicleIdentificationNumber = 'VIN' + String.valueOf(DateTime.now().getTime()).substring(5),
            AssetId = ast.Id,
            VehicleDefinitionId = vd.Id
        );
        insert v;
        return [SELECT Id, Name, AssetId, VehicleDefinitionId, VehicleIdentificationNumber FROM Vehicle WHERE Id = :v.Id];
    }

    public static AssetWarranty createWarranty(Id assetId) {
        AssetWarranty aw = new AssetWarranty(
            AssetId = assetId,
            Vehicle__c = assetId, // Legacy custom field
            StartDate = Date.today().addDays(-30),
            EndDate = Date.today().addDays(335),
            MileageCap__c = 50000,
            CoveredCategories__c = 'Battery,Drive Motor,Electronics',
            LaborPolicy__c = 'Standard'
        );
        insert aw;
        return aw;
    }

    public static Claim createClaim(Id dealerId, Id assetId) {
        Claim c = new Claim(
            Name = 'CLM-TEST-' + DateTime.now().getTime(),
            AccountId = dealerId,
            Vehicle__c = assetId,
            Status = 'Draft',
            Symptom__c = 'Vibration at high speeds',
            Odometer__c = 15000,
            Authorization_Type__c = 'Prior Authorization',
            Priority__c = 'Medium'
        );
        insert c;
        return c;
    }
}