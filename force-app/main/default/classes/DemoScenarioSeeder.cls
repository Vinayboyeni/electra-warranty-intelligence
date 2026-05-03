/**
 * DemoScenarioSeeder
 *
 * Produces a curated set of Accounts, Vehicles, Assets, Contacts, and
 * AssetWarranty records covering every happy and fault path the agents can take.
 *
 * Run from Dev Console Execute Anonymous:
 *   DemoScenarioSeeder.seedAll();
 *
 * Or to tear down and reseed fresh (idempotent):
 *   DemoScenarioSeeder.reset();
 *   DemoScenarioSeeder.seedAll();
 *
 * Every record created has 'DEMO-' in its Name or VIN for easy identification
 * and cleanup. Prints the demo script to the debug log at the end.
 */
public with sharing class DemoScenarioSeeder {

    private static final String DEMO_VIN_PREFIX = 'ELXDEMO';

    public static void seedAll() {
        Map<String, Account> dealers = seedDealers();
        Contact customer = seedCustomer(dealers.get('ELITE').Id);

        System.debug('===============================================');
        System.debug('DEMO SCENARIOS SEEDED');
        System.debug('===============================================');

        logScenario(seedScenarioA(dealers.get('ELITE'), customer));
        logScenario(seedScenarioB(dealers.get('ELITE'), customer));
        logScenario(seedScenarioC(dealers.get('ELITE'), customer));
        logScenario(seedScenarioD(dealers.get('METRO'), customer));
        logScenario(seedScenarioE(dealers.get('AVERAGE'), customer));
        logScenario(seedScenarioF(dealers.get('METRO'), customer));
        logScenario(seedScenarioG(dealers.get('ELITE'), customer));
        logScenario(seedScenarioH(dealers.get('WATCHLIST'), customer));
        logScenario(seedScenarioI(dealers.get('ELITE'), customer));
        logScenario(seedScenarioJ(dealers.get('ELITE'), customer));

        System.debug('===============================================');
        System.debug('Primary demo VIN (Scenario B): use this for the 5-min demo.');
    }

    public static void reset() {
        List<Claim> oldClaims = [
            SELECT Id FROM Claim
            WHERE Name LIKE 'WC-DEMO%' OR Vehicle__r.Name LIKE :(DEMO_VIN_PREFIX + '%')
            LIMIT 1000
        ];
        if (!oldClaims.isEmpty()) delete oldClaims;

        List<AssetWarranty> oldWarranties = [
            SELECT Id FROM AssetWarranty
            WHERE Asset.Name LIKE :(DEMO_VIN_PREFIX + '%') LIMIT 1000
        ];
        if (!oldWarranties.isEmpty()) delete oldWarranties;

        List<Vehicle> oldVehicles = [
            SELECT Id FROM Vehicle
            WHERE VehicleIdentificationNumber LIKE :(DEMO_VIN_PREFIX + '%') LIMIT 1000
        ];
        if (!oldVehicles.isEmpty()) delete oldVehicles;

        List<Asset> oldAssets = [
            SELECT Id FROM Asset WHERE Name LIKE :(DEMO_VIN_PREFIX + '%') LIMIT 1000
        ];
        if (!oldAssets.isEmpty()) delete oldAssets;

        List<Account> oldDealers = [
            SELECT Id FROM Account WHERE Name LIKE 'DEMO-%' LIMIT 100
        ];
        if (!oldDealers.isEmpty()) delete oldDealers;

        System.debug('Demo data reset complete.');
    }

    private static Map<String, Account> seedDealers() {
        Account elite = new Account(
            Name = 'DEMO-Elite Electra Motors',
            AccountNumber = 'ELX-DLR-DEMO-ELITE',
            DealerTrustScore__c = 90
        );
        Account metro = new Account(
            Name = 'DEMO-Metro Electra Dealership',
            AccountNumber = 'ELX-DLR-DEMO-METRO',
            DealerTrustScore__c = 78
        );
        Account avg = new Account(
            Name = 'DEMO-Average Performance Motors',
            AccountNumber = 'ELX-DLR-DEMO-AVG',
            DealerTrustScore__c = 60
        );
        Account watch = new Account(
            Name = 'DEMO-Watchlist Auto Mall',
            AccountNumber = 'ELX-DLR-DEMO-WATCH',
            DealerTrustScore__c = 35
        );
        insert new List<Account>{ elite, metro, avg, watch };

        Map<String, Account> out = new Map<String, Account>();
        out.put('ELITE', elite);
        out.put('METRO', metro);
        out.put('AVERAGE', avg);
        out.put('WATCHLIST', watch);
        return out;
    }

    private static Contact seedCustomer(Id accountId) {
        Contact c = new Contact(
            FirstName = 'Priya',
            LastName = 'Demo-Customer',
            Email = 'priya.demo@electra.test',
            Phone = '+919999200001',
            AccountId = accountId
        );
        insert c;
        return c;
    }

    // SCENARIO A - Auto-approve: Likely + low cost + trusted dealer -> skip Slack
    private static String[] seedScenarioA(Account dealer, Contact customer) {
        String vin = pad17(DEMO_VIN_PREFIX + 'HAPY01');
        Vehicle v = makeVehicle(vin, '2024 Electra X5 Sport', 8000, dealer.Id, customer.Id);
        makeWarranty(v, 'Battery,Engine,Drive Motor,HVAC', Date.today().addYears(3), 50000);
        return new String[]{
            'A - Auto-approve (happy)',
            vin, dealer.Name,
            'Likely, cost<=500, conf 90, trust 90 -> AUTO-APPROVED (no Slack)',
            'WhatsApp VIN=' + vin + ', odometer=8000, part=Battery, symptom="capacity warning", amount=450'
        };
    }

    // SCENARIO B - Standard approval: Likely, medium cost
    private static String[] seedScenarioB(Account dealer, Contact customer) {
        String vin = pad17(DEMO_VIN_PREFIX + 'HAPY02');
        Vehicle v = makeVehicle(vin, '2023 Electra X5 Long Range', 15000, dealer.Id, customer.Id);
        makeWarranty(v, 'Battery,Engine,Drive Motor,HVAC,Charging System', Date.today().addYears(2), 60000);
        return new String[]{
            'B - Standard approval (happy) [PRIMARY DEMO]',
            vin, dealer.Name,
            'Likely, $1,800 -> Pending Approver Review -> SLACK -> adjuster approves',
            'WhatsApp VIN=' + vin + ', odometer=15000, part=Battery, amount=1800. Slack: "approve WC-... test rationale"'
        };
    }

    // SCENARIO C - $2k gate: Likely but above $2000
    private static String[] seedScenarioC(Account dealer, Contact customer) {
        String vin = pad17(DEMO_VIN_PREFIX + 'BIG03');
        Vehicle v = makeVehicle(vin, '2023 Electra Model Z Premium', 22000, dealer.Id, customer.Id);
        makeWarranty(v, 'Engine,Drive Motor,Transmission', Date.today().addYears(3), 60000);
        return new String[]{
            'C - $2k gate (happy)',
            vin, dealer.Name,
            'Likely, $3,500 > $2000 -> adjuster must explicitly confirm',
            'WhatsApp VIN=' + vin + ', odometer=22000, part=Drive Motor, amount=3500'
        };
    }

    // SCENARIO D - RFI round-trip: Borderline
    private static String[] seedScenarioD(Account dealer, Contact customer) {
        String vin = pad17(DEMO_VIN_PREFIX + 'BORD04');
        Vehicle v = makeVehicle(vin, '2022 Electra X5', 48500, dealer.Id, customer.Id);
        makeWarranty(v, 'Battery,Engine,Drive Motor,HVAC,Brake System', Date.today().addMonths(6), 50000);
        return new String[]{
            'D - RFI round-trip (happy)',
            vin, dealer.Name,
            'Borderline (48500 of 50000 mi) -> approver clarifies -> dealer replies -> approve',
            'WhatsApp VIN=' + vin + ', odometer=48500, part=Brake System, amount=950'
        };
    }

    // SCENARIO E - Auto-reject: warranty expired
    private static String[] seedScenarioE(Account dealer, Contact customer) {
        String vin = pad17(DEMO_VIN_PREFIX + 'REJ05');
        Vehicle v = makeVehicle(vin, '2019 Electra X5 Classic', 62000, dealer.Id, customer.Id);
        makeWarranty(v, 'Battery,Engine', Date.today().addYears(-1), 50000);
        return new String[]{
            'E - Auto-reject (fault)',
            vin, dealer.Name,
            'Not Covered (warranty expired) -> AUTO-REJECTED -> dealer notified',
            'WhatsApp VIN=' + vin + ', odometer=62000, part=Engine, amount=2500'
        };
    }

    // SCENARIO F - Goodwill path: just outside cap
    private static String[] seedScenarioF(Account dealer, Contact customer) {
        String vin = pad17(DEMO_VIN_PREFIX + 'GDWL06');
        Vehicle v = makeVehicle(vin, '2021 Electra X5 Long Range', 51200, dealer.Id, customer.Id);
        makeWarranty(v, 'Battery,Engine,Drive Motor,HVAC', Date.today().addYears(1), 50000);
        return new String[]{
            'F - Goodwill exception (fault)',
            vin, dealer.Name,
            'Not Covered (51200 > 50000 cap) -> dealer replies GOODWILL',
            'WhatsApp VIN=' + vin + ', odometer=51200, part=Battery, amount=4500, then reply GOODWILL'
        };
    }

    // SCENARIO G - Duplicate guard (demo pattern: submit the claim TWICE via ARIA)
    // We intentionally do NOT pre-seed an existing claim here — the org's Claim
    // object requires an InsurancePolicyAsset reference (not a plain Asset) which
    // would pull in FSC policy schema. For the demo, ARIA creates the first claim
    // on first submission; the second submission trips CheckRecentClaims.
    private static String[] seedScenarioG(Account dealer, Contact customer) {
        String vin = pad17(DEMO_VIN_PREFIX + 'DUP07');
        Vehicle v = makeVehicle(vin, '2024 Electra X5', 12000, dealer.Id, customer.Id);
        makeWarranty(v, 'Battery,Engine,Drive Motor,HVAC,Charging System', Date.today().addYears(3), 50000);

        return new String[]{
            'G - Duplicate guard (fault)',
            vin, dealer.Name,
            'Two submissions for VIN+Battery in 30d -> second hits CheckRecentClaims warning',
            'Submit ARIA claim for VIN=' + vin + ', part=Battery. Then submit AGAIN for same VIN+Battery — ARIA should warn of duplicate.'
        };
    }

    // SCENARIO H - Fraud flag dealer
    private static String[] seedScenarioH(Account dealer, Contact customer) {
        String vin = pad17(DEMO_VIN_PREFIX + 'FRD08');
        Vehicle v = makeVehicle(vin, '2023 Electra X5', 28000, dealer.Id, customer.Id);
        makeWarranty(v, 'Battery,Engine,Drive Motor,HVAC', Date.today().addYears(2), 50000);
        return new String[]{
            'H - Low-trust dealer (fault)',
            vin, dealer.Name + ' (trust 35)',
            'Likely eligibility but dealer trust 35 -> Slack card shows risk flag',
            'WhatsApp VIN=' + vin + ', odometer=28000, part=Battery, amount=2100'
        };
    }

    // SCENARIO I - Safety halt
    private static String[] seedScenarioI(Account dealer, Contact customer) {
        String vin = pad17(DEMO_VIN_PREFIX + 'SAFE09');
        Vehicle v = makeVehicle(vin, '2024 Electra X5 Performance', 5000, dealer.Id, customer.Id);
        makeWarranty(v, 'Battery,Engine,Drive Motor,Brake System', Date.today().addYears(3), 50000);
        return new String[]{
            'I - Safety halt (fault)',
            vin, dealer.Name,
            'Dealer mentions fire/smoke/brake -> ARIA halts + Electra Safety Hotline',
            'WhatsApp VIN=' + vin + ', odometer=5000, part=Battery, symptom="battery SMOKING"'
        };
    }

    // SCENARIO J - SRT justification triggered
    private static String[] seedScenarioJ(Account dealer, Contact customer) {
        String vin = pad17(DEMO_VIN_PREFIX + 'SRT10');
        Vehicle v = makeVehicle(vin, '2023 Electra X5 Premium', 18000, dealer.Id, customer.Id);
        makeWarranty(v, 'Battery,Engine,Drive Motor,HVAC', Date.today().addYears(3), 50000);
        return new String[]{
            'J - SRT variance (fault)',
            vin, dealer.Name,
            'Battery baseline $4500; dealer quotes $9000 -> 100% over -> dealer justifies',
            'WhatsApp VIN=' + vin + ', odometer=18000, part=Battery, amount=9000'
        };
    }

    private static Id cachedDefinitionId;
    // Keyed by Vehicle Id -> Asset Id. Populated in makeVehicle(), consumed
    // wherever Claim.AssetId or AssetWarranty.Vehicle__c needs the Asset reference.
    // This bypasses any org-specific oddity where Vehicle.AssetId is not
    // reliably retrievable on the in-memory SObject instance after insert.
    private static Map<Id, Id> vehicleAssetMap = new Map<Id, Id>();

    private static Id assetIdOf(Vehicle v) {
        return vehicleAssetMap.get(v.Id);
    }

    private static Id findOrCreateVehicleDefinition() {
        if (cachedDefinitionId != null) return cachedDefinitionId;

        // Try to find any existing VehicleDefinition in the org first
        List<VehicleDefinition> existing = [
            SELECT Id FROM VehicleDefinition LIMIT 1
        ];
        if (!existing.isEmpty()) {
            cachedDefinitionId = existing[0].Id;
            return cachedDefinitionId;
        }

        // None exist — create a minimal demo definition using dynamic put() so the
        // class compiles even if some optional fields are not writable in this org.
        SObject def = Schema.getGlobalDescribe().get('VehicleDefinition').newSObject();
        def.put('Name', 'DEMO-Electra-X5-2023');
        safePut(def, 'Make', 'Electra');
        safePut(def, 'ModelName', 'X5');
        safePut(def, 'Model', 'X5');
        safePut(def, 'ModelYear', 2023);
        safePut(def, 'Year', 2023);
        insert def;
        cachedDefinitionId = (Id) def.get('Id');
        return cachedDefinitionId;
    }

    private static void safePut(SObject rec, String fieldName, Object value) {
        try {
            Schema.SObjectField f = rec.getSObjectType().getDescribe().fields.getMap().get(fieldName);
            if (f != null && f.getDescribe().isCreateable()) {
                rec.put(fieldName, value);
            }
        } catch (Exception e) {
            // ignore — field not available in this org
        }
    }

    private static Vehicle makeVehicle(String vin, String modelName, Integer odometer, Id dealerId, Id customerId) {
        Asset a = new Asset(
            Name = vin,
            AccountId = dealerId,
            ContactId = customerId
        );
        insert a;

        Vehicle v = new Vehicle(
            Name = modelName + ' ' + vin.right(5),
            VehicleIdentificationNumber = vin,
            Current_Mileage__c = odometer,
            AssetId = a.Id,
            VehicleDefinitionId = findOrCreateVehicleDefinition()
        );
        insert v;
        vehicleAssetMap.put(v.Id, a.Id);
        return v;
    }

    private static void makeWarranty(Vehicle v, String coveredCats, Date endDate, Integer mileageCap) {
        Id aid = assetIdOf(v);
        AssetWarranty w = new AssetWarranty();
        w.AssetId = aid;                    // required standard asset link
        w.Vehicle__c = aid;                 // custom hybrid lookup (also Asset)
        w.CoveredCategories__c = coveredCats;
        w.MileageCap__c = mileageCap;
        w.EndDate = endDate;
        w.StartDate = endDate.addYears(-4);
        w.WarrantyType = 'Full Warranty';
        insert w;
    }

    private static String pad17(String base) {
        String core = base.replaceAll('[^A-Z0-9]', '');
        if (core.length() >= 17) return core.substring(0, 17);
        return core + '0'.repeat(17 - core.length());
    }

    private static void logScenario(String[] info) {
        System.debug('');
        System.debug('>> ' + info[0]);
        System.debug('   VIN:      ' + info[1]);
        System.debug('   Dealer:   ' + info[2]);
        System.debug('   Expected: ' + info[3]);
        System.debug('   Demo:     ' + info[4]);
    }
}