public with sharing class HackathonDataPrep {
    public static void prepareDemoData() {
        // 1. Dealer Account — trust score 85 qualifies for auto-approval path
        Account dealer = new Account(
            Name = 'Electra Flagship Store',
            DealerTrustScore__c = 85,
            Phone = '+14155550100'
        );
        insert dealer;

        // 2. Customer Contact linked to dealer
        Contact customer = new Contact(
            FirstName = 'Demo',
            LastName = 'Customer',
            Email = 'demo.customer@electra.demo',
            AccountId = dealer.Id
        );
        insert customer;

        // 3. Product + VehicleDefinition
        Product2 p = new Product2(
            Name = 'Electra X5 Sport',
            IsActive = true,
            StockKeepingUnit = 'EX5-2024'
        );
        insert p;

        VehicleDefinition vd = new VehicleDefinition(
            Name = '2024 Electra X5 Sport',
            ProductId = p.Id
        );
        insert vd;

        // 4. Asset — bridge between Vehicle and AssetWarranty
        Asset ast = new Asset(
            Name = '2024 Electra X5 Sport — ELX10000000000001',
            AccountId = dealer.Id,
            ContactId = customer.Id,
            Product2Id = p.Id,
            Status = 'Purchased'
        );
        insert ast;

        // 5. Vehicle with a valid 17-char VIN
        Vehicle v = new Vehicle(
            Name = '2024 Electra X5 Sport',
            VehicleIdentificationNumber = 'ELX10000000000001',
            AssetId = ast.Id,
            VehicleDefinitionId = vd.Id
        );
        insert v;

        // 6. Standard warranty (4yr / 50k miles) — expires in ~3 years
        //    Vehicle__c must be the Asset Id (AssetWarranty.Vehicle__c is a Lookup to Asset)
        AssetWarranty standardWarranty = new AssetWarranty(
            AssetId = ast.Id,
            Vehicle__c = ast.Id,
            StartDate = Date.today().addDays(-365),
            EndDate = Date.today().addDays(1095),
            MileageCap__c = 50000,
            CoveredCategories__c = 'Engine,Transmission,Drive Motor,HVAC,Suspension,Brake System,Electrical System,Charging System,Infotainment',
            LaborPolicy__c = 'Full Coverage'
        );
        insert standardWarranty;

        // 7. Battery extended warranty (8yr / 100k miles)
        AssetWarranty batteryWarranty = new AssetWarranty(
            AssetId = ast.Id,
            Vehicle__c = ast.Id,
            StartDate = Date.today().addDays(-365),
            EndDate = Date.today().addDays(2555),
            MileageCap__c = 100000,
            CoveredCategories__c = 'Battery',
            LaborPolicy__c = 'Full Coverage'
        );
        insert batteryWarranty;

        // 8. Near-expiry warranty for proactive alert demo (expires in 28 days)
        AssetWarranty expiringWarranty = new AssetWarranty(
            AssetId = ast.Id,
            Vehicle__c = ast.Id,
            StartDate = Date.today().addDays(-700),
            EndDate = Date.today().addDays(28),
            MileageCap__c = 36000,
            CoveredCategories__c = 'Engine,Transmission',
            LaborPolicy__c = 'Parts Only'
        );
        insert expiringWarranty;

        System.debug('=== HACKATHON DEMO DATA READY ===');
        System.debug('VIN: ELX10000000000001');
        System.debug('Dealer: Electra Flagship Store | Trust Score: 85/100');
        System.debug('Customer: Demo Customer');
        System.debug('Warranties: Standard (3yr left), Battery (7yr left), Expiring (28 days)');
        System.debug('Run in ARIA: Share VIN ELX10000000000001 to start a claim');
    }
}