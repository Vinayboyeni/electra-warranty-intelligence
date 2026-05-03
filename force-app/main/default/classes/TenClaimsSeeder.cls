/**
 * Seeds 10 Electra Cars vehicles (each a distinct model) and 10 warranty claims.
 *
 * Creates for each model:
 *   Product2 → VehicleDefinition → Asset → Vehicle (unique 17-char VIN)
 *   → AssetWarranty → Claim (via CreatePriorAuthorizationClaim)
 *
 * Safe to run multiple times — keys off Product2.StockKeepingUnit and Vehicle VIN.
 * Reuses an existing "Electra Flagship Dealer" Account if present; otherwise creates one.
 *
 * Anonymous Apex:
 *   TenClaimsSeeder.Summary s = TenClaimsSeeder.run();
 *   System.debug(JSON.serializePretty(s));
 */
public without sharing class TenClaimsSeeder {

    private static final String DEALER_NAME = 'Electra Flagship Dealer';

    public class Summary {
        public Id dealerAccountId;
        public Id customerContactId;
        public Integer vehiclesCreated = 0;
        public Integer vehiclesReused = 0;
        public Integer warrantiesCreated = 0;
        public Integer claimsCreated = 0;
        public List<Row> rows = new List<Row>();
        public List<String> warnings = new List<String>();
    }

    public class Row {
        public String vin;
        public String model;
        public Integer modelYear;
        public Id vehicleId;
        public Id assetId;
        public Id claimId;
        public String claimStatus;
        public String issue;
        public String diagnosticCode;
        public Decimal requestedAmount;
    }

    private class ModelSpec {
        String modelName;        // e.g. "Electra X5 Sport"
        String sku;              // Product SKU
        Integer modelYear;
        String vin;              // 17-char VIN
        String issue;
        String diagnosticCode;
        String partCategory;     // Matches CoveredCategories__c tokens
        Decimal mileageAtFailure;
        Decimal requestedAmount;
        String priority;
        String submissionChannel;
        Integer faultDaysAgo;
    }

    public static Summary run() {
        Summary summary = new Summary();

        Account dealer = ensureDealer();
        summary.dealerAccountId = dealer.Id;

        Contact customer = ensureCustomer(dealer.Id);
        summary.customerContactId = customer.Id;

        List<ModelSpec> specs = buildSpecs();

        // Load existing vehicles by VIN so we don't re-insert
        Set<String> vins = new Set<String>();
        for (ModelSpec spec : specs) {
            vins.add(spec.vin);
        }
        Map<String, Vehicle> existingByVin = new Map<String, Vehicle>();
        for (Vehicle v : [
            SELECT Id, AssetId, VehicleIdentificationNumber, VehicleDefinitionId
            FROM Vehicle
            WHERE VehicleIdentificationNumber IN :vins
        ]) {
            existingByVin.put(v.VehicleIdentificationNumber, v);
        }

        // Existing products by SKU
        Set<String> skus = new Set<String>();
        for (ModelSpec spec : specs) {
            skus.add(spec.sku);
        }
        Map<String, Product2> productBySku = new Map<String, Product2>();
        for (Product2 p : [SELECT Id, StockKeepingUnit FROM Product2 WHERE StockKeepingUnit IN :skus]) {
            productBySku.put(p.StockKeepingUnit, p);
        }

        // Existing vehicle definitions by product
        Map<Id, VehicleDefinition> vdByProduct = new Map<Id, VehicleDefinition>();
        if (!productBySku.isEmpty()) {
            for (VehicleDefinition vd : [
                SELECT Id, ProductId FROM VehicleDefinition WHERE ProductId IN :productBySku.values()
            ]) {
                vdByProduct.put(vd.ProductId, vd);
            }
        }

        // Step 1 — Products
        List<Product2> newProducts = new List<Product2>();
        for (ModelSpec spec : specs) {
            if (productBySku.containsKey(spec.sku)) continue;
            newProducts.add(new Product2(
                Name = spec.modelName + ' ' + spec.modelYear,
                StockKeepingUnit = spec.sku,
                ProductCode = spec.sku,
                IsActive = true
            ));
        }
        if (!newProducts.isEmpty()) {
            insert newProducts;
            for (Product2 p : newProducts) {
                productBySku.put(p.StockKeepingUnit, p);
            }
        }

        // Step 2 — VehicleDefinitions
        List<VehicleDefinition> newDefs = new List<VehicleDefinition>();
        for (ModelSpec spec : specs) {
            Product2 p = productBySku.get(spec.sku);
            if (p == null || vdByProduct.containsKey(p.Id)) continue;
            newDefs.add(new VehicleDefinition(
                Name = spec.modelYear + ' ' + spec.modelName,
                ProductId = p.Id
            ));
        }
        if (!newDefs.isEmpty()) {
            insert newDefs;
            for (VehicleDefinition vd : newDefs) {
                vdByProduct.put(vd.ProductId, vd);
            }
        }

        // Step 3 — Assets + Vehicles (only for VINs not already present)
        List<ModelSpec> specsNeedingVehicle = new List<ModelSpec>();
        for (ModelSpec spec : specs) {
            if (!existingByVin.containsKey(spec.vin)) {
                specsNeedingVehicle.add(spec);
            } else {
                summary.vehiclesReused++;
            }
        }

        if (!specsNeedingVehicle.isEmpty()) {
            List<Asset> newAssets = new List<Asset>();
            for (ModelSpec spec : specsNeedingVehicle) {
                Product2 p = productBySku.get(spec.sku);
                newAssets.add(new Asset(
                    Name = spec.modelYear + ' ' + spec.modelName + ' — ' + spec.vin,
                    AccountId = dealer.Id,
                    ContactId = customer.Id,
                    Product2Id = p.Id,
                    SerialNumber = spec.vin,
                    Status = 'Purchased'
                ));
            }
            insert newAssets;

            List<Vehicle> newVehicles = new List<Vehicle>();
            for (Integer i = 0; i < specsNeedingVehicle.size(); i++) {
                ModelSpec spec = specsNeedingVehicle[i];
                Product2 p = productBySku.get(spec.sku);
                VehicleDefinition vd = vdByProduct.get(p.Id);
                newVehicles.add(new Vehicle(
                    Name = spec.modelYear + ' ' + spec.modelName,
                    VehicleIdentificationNumber = spec.vin,
                    AssetId = newAssets[i].Id,
                    VehicleDefinitionId = vd.Id
                ));
            }
            insert newVehicles;
            for (Vehicle v : newVehicles) {
                existingByVin.put(v.VehicleIdentificationNumber, v);
                summary.vehiclesCreated++;
            }
        }

        // Step 4 — AssetWarranty per vehicle (skip if one already exists for the asset)
        Set<Id> assetIds = new Set<Id>();
        for (ModelSpec spec : specs) {
            Vehicle v = existingByVin.get(spec.vin);
            if (v != null && v.AssetId != null) assetIds.add(v.AssetId);
        }
        Set<Id> assetsWithWarranty = new Set<Id>();
        for (AssetWarranty aw : [SELECT AssetId FROM AssetWarranty WHERE AssetId IN :assetIds]) {
            assetsWithWarranty.add(aw.AssetId);
        }

        List<AssetWarranty> newWarranties = new List<AssetWarranty>();
        for (ModelSpec spec : specs) {
            Vehicle v = existingByVin.get(spec.vin);
            if (v == null || v.AssetId == null || assetsWithWarranty.contains(v.AssetId)) continue;
            AssetWarranty w = new AssetWarranty();
            w.AssetId = v.AssetId;
            w.put('Vehicle__c', v.AssetId);
            w.StartDate = Date.today().addDays(-400);
            w.EndDate = Date.today().addDays(1095);
            w.put('MileageCap__c', Decimal.valueOf(80000));
            w.put(
                'CoveredCategories__c',
                'Engine,Transmission,Drive Motor,HVAC,Suspension,Brake System,Electrical System,Charging System,Infotainment,Battery'
            );
            w.put('LaborPolicy__c', 'Full Coverage');
            newWarranties.add(w);
        }
        if (!newWarranties.isEmpty()) {
            Database.SaveResult[] wResults = Database.insert(newWarranties, false);
            for (Integer i = 0; i < wResults.size(); i++) {
                if (wResults[i].isSuccess()) {
                    summary.warrantiesCreated++;
                } else {
                    summary.warnings.add('AssetWarranty: ' + wResults[i].getErrors()[0].getMessage());
                }
            }
        }

        // Step 5 — Claims via CreatePriorAuthorizationClaim
        String runKey = Datetime.now().formatGMT('yyyyMMddHHmmss');
        List<CreatePriorAuthorizationClaim.Request> requests = new List<CreatePriorAuthorizationClaim.Request>();
        for (Integer i = 0; i < specs.size(); i++) {
            ModelSpec spec = specs[i];
            CreatePriorAuthorizationClaim.Request req = new CreatePriorAuthorizationClaim.Request();
            req.vin = spec.vin;
            req.dealerAccountId = dealer.Id;
            req.summary = spec.issue + ' on ' + spec.modelYear + ' ' + spec.modelName + '.';
            req.symptomText = 'Dealer observed fault indicator; ' + spec.partCategory.toLowerCase()
                + ' diagnostics confirm failure.';
            req.diagnosticCodeText = spec.diagnosticCode;
            req.faultDate = Datetime.now().addDays(-spec.faultDaysAgo);
            req.repairDate = Datetime.now().addDays(-Math.max(0, spec.faultDaysAgo - 2));
            req.mileageAtFailure = spec.mileageAtFailure;
            req.submissionChannel = spec.submissionChannel;
            req.authorizationType = 'Prior Authorization';
            req.priority = spec.priority;
            req.repairOrderNumber = 'ELX-RO-' + runKey + '-' + String.valueOf(i + 1).leftPad(3, '0');
            req.dealerWhatsAppNumber = '+91-98765-0' + String.valueOf(1000 + i).leftPad(4, '0');
            req.externalDmsReference = 'ELX-DMS-' + runKey + '-' + String.valueOf(i + 1).leftPad(3, '0');
            req.requestedAmount = spec.requestedAmount;
            req.requestedQuantity = 1;
            req.chargeType = 'Replaced Part';
            requests.add(req);
        }

        List<CreatePriorAuthorizationClaim.Response> responses =
            CreatePriorAuthorizationClaim.createClaims(requests);

        for (Integer i = 0; i < specs.size(); i++) {
            ModelSpec spec = specs[i];
            CreatePriorAuthorizationClaim.Response resp = responses[i];
            Row row = new Row();
            row.vin = spec.vin;
            row.model = spec.modelYear + ' ' + spec.modelName;
            row.modelYear = spec.modelYear;
            row.issue = spec.issue;
            row.diagnosticCode = spec.diagnosticCode;
            row.requestedAmount = spec.requestedAmount;
            Vehicle v = existingByVin.get(spec.vin);
            if (v != null) {
                row.vehicleId = v.Id;
                row.assetId = v.AssetId;
            }
            if (resp != null) {
                row.claimId = resp.claimId;
                row.claimStatus = resp.status;
                if (resp.claimId != null && resp.status == 'Created') {
                    summary.claimsCreated++;
                } else if (String.isNotBlank(resp.message)) {
                    summary.warnings.add('Claim (' + spec.vin + '): ' + resp.message);
                }
            }
            summary.rows.add(row);
        }

        logSummary(summary);
        return summary;
    }

    private static Account ensureDealer() {
        List<Account> existing = [
            SELECT Id FROM Account WHERE Name = :DEALER_NAME ORDER BY CreatedDate ASC LIMIT 1
        ];
        if (!existing.isEmpty()) return existing[0];

        Account dealer = new Account(
            Name = DEALER_NAME,
            Phone = '+91-80-4155-0100',
            Industry = 'Automotive',
            BillingStreet = '12 EV Service Park, Sector 4',
            BillingCity = 'Bengaluru',
            BillingState = 'Karnataka',
            BillingPostalCode = '560001',
            BillingCountry = 'India'
        );
        try {
            dealer.put('DealerTrustScore__c', 85);
        } catch (Exception e) { /* field may not exist in some orgs */ }
        insert dealer;
        return dealer;
    }

    private static Contact ensureCustomer(Id dealerAccountId) {
        List<Contact> existing = [
            SELECT Id FROM Contact
            WHERE AccountId = :dealerAccountId AND Email = 'priya.sharma@electracustomer.demo'
            LIMIT 1
        ];
        if (!existing.isEmpty()) return existing[0];
        Contact c = new Contact(
            FirstName = 'Priya',
            LastName = 'Sharma',
            Email = 'priya.sharma@electracustomer.demo',
            Phone = '+91-98760-00001',
            AccountId = dealerAccountId
        );
        insert c;
        return c;
    }

    private static List<ModelSpec> buildSpecs() {
        List<ModelSpec> result = new List<ModelSpec>();

        result.add(makeSpec('Electra X3 Eco',        'EX3-ECO-2023',   2023, 'ELXX3E23000000001',
            'Battery cooling module replacement',       'P0A7C', 'Battery',            12500,  1450, 'Medium',   'WhatsApp',  5));
        result.add(makeSpec('Electra X5 Sport',      'EX5-SPT-2024',   2024, 'ELXX5S24000000002',
            'Drive inverter control board replacement', 'P0AA6', 'Drive Motor',        8750,   1820, 'Critical', 'Web Chat',  3));
        result.add(makeSpec('Electra X7 Premium',    'EX7-PRM-2024',   2024, 'ELXX7P24000000003',
            'HV cable harness replacement',             'P1A10', 'Electrical System',  15200,  2150, 'High',     'WhatsApp',  7));
        result.add(makeSpec('Electra Urban Mini',    'EUM-STD-2023',   2023, 'ELXUMS23000000004',
            'E-axle sensor replacement',                'P0C73', 'Drive Motor',        21400,  480,  'Low',      'WhatsApp',  14));
        result.add(makeSpec('Electra Bolt Compact',  'EBC-STD-2024',   2024, 'ELXBCS24000000005',
            'Thermal pump assembly replacement',        'P0A94', 'HVAC',               5200,   920,  'Medium',   'Web Chat',  2));
        result.add(makeSpec('Electra Nova Crossover','ENC-STD-2024',   2024, 'ELXNCS24000000006',
            'Charging port actuator replacement',       'P1A45', 'Charging System',    9800,   340,  'Medium',   'WhatsApp',  6));
        result.add(makeSpec('Electra Pulse Sedan',   'EPS-STD-2023',   2023, 'ELXPSS23000000007',
            'Brake-by-wire module fault',               'C1A10', 'Brake System',       18600,  1560, 'High',     'WhatsApp',  9));
        result.add(makeSpec('Electra Titan Pickup',  'ETP-STD-2024',   2024, 'ELXTPS24000000008',
            'Regenerative brake controller fault',      'C2A20', 'Brake System',       4300,   1190, 'Critical', 'Web Chat',  1));
        result.add(makeSpec('Electra Vega Coupe',    'EVC-STD-2023',   2023, 'ELXVCS23000000009',
            'DC-DC converter failure',                  'P0C10', 'Electrical System',  24100,  2410, 'High',     'WhatsApp',  11));
        result.add(makeSpec('Electra Zephyr GT',     'EZG-STD-2024',   2024, 'ELXZGS24000000010',
            'Infotainment head unit malfunction',       'B1B01', 'Infotainment',       6900,   410,  'Low',      'Web Chat',  4));

        return result;
    }

    private static ModelSpec makeSpec(
        String modelName, String sku, Integer modelYear, String vin,
        String issue, String dtc, String partCategory,
        Decimal mileage, Decimal amount, String priority, String channel, Integer faultDaysAgo
    ) {
        ModelSpec s = new ModelSpec();
        s.modelName = modelName;
        s.sku = sku;
        s.modelYear = modelYear;
        s.vin = vin;
        s.issue = issue;
        s.diagnosticCode = dtc;
        s.partCategory = partCategory;
        s.mileageAtFailure = mileage;
        s.requestedAmount = amount;
        s.priority = priority;
        s.submissionChannel = channel;
        s.faultDaysAgo = faultDaysAgo;
        return s;
    }

    private static void logSummary(Summary s) {
        System.debug('=== TenClaimsSeeder complete ===');
        System.debug('Dealer: ' + s.dealerAccountId + ' | Customer: ' + s.customerContactId);
        System.debug('Vehicles created: ' + s.vehiclesCreated + ' | reused: ' + s.vehiclesReused);
        System.debug('Warranties created: ' + s.warrantiesCreated);
        System.debug('Claims created: ' + s.claimsCreated);
        System.debug('--- VIN | Model | Issue | DTC | Amount | Claim ---');
        for (Row r : s.rows) {
            System.debug(
                r.vin + ' | ' + r.model + ' | ' + r.issue + ' | ' + r.diagnosticCode
                + ' | $' + r.requestedAmount + ' | ' + r.claimId + ' (' + r.claimStatus + ')'
            );
        }
        if (!s.warnings.isEmpty()) {
            System.debug('Warnings:');
            for (String w : s.warnings) System.debug(' - ' + w);
        }
    }
}