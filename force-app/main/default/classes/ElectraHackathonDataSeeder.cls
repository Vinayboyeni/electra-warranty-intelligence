public with sharing class ElectraHackathonDataSeeder {
    public class SeedDataException extends Exception {}

    private class VehiclePoolResult {
        List<Vehicle> vehicles = new List<Vehicle>();
        Integer addedAssets = 0;
        Integer addedVehicles = 0;
    }

    public class SeedSummary {
        @AuraEnabled public String runKey;
        @AuraEnabled public Integer requestedCount;
        @AuraEnabled public Integer usedVehicleCount;
        @AuraEnabled public Integer addedAssets;
        @AuraEnabled public Integer addedVehicles;
        @AuraEnabled public Integer createdAccounts;
        @AuraEnabled public Integer createdContacts;
        @AuraEnabled public Integer insertedAssetWarranties;
        @AuraEnabled public Integer createdClaims;
        @AuraEnabled public Integer queuedClaims;
        @AuraEnabled public Integer clarificationUpdates;
        @AuraEnabled public List<String> warnings;
    }

    public static SeedSummary seed(Integer requestedCount) {
        Integer target = normalizeTargetCount(requestedCount);
        String runKey = Datetime.now().formatGMT('yyyyMMddHHmmss');
        List<String> warnings = new List<String>();

        VehiclePoolResult vehiclePool = ensureVehiclePool(target, runKey, warnings);
        List<Vehicle> vehicles = vehiclePool.vehicles;

        if (vehicles.size() < 20) {
            throw new SeedDataException(
                'Need at least 20 Vehicle records with VIN and AssetId. Found ' + vehicles.size() + '.'
            );
        }

        Integer count = Math.min(target, vehicles.size());

        List<Account> insertedDealerAccounts = insertDealerAccounts(
            buildDealerAccounts(runKey, count),
            warnings
        );
        Integer createdAccountCount = insertedDealerAccounts.size();

        List<Account> dealerAccounts = new List<Account>();
        dealerAccounts.addAll(insertedDealerAccounts);

        if (dealerAccounts.size() < count) {
            Integer additionalNeeded = count - dealerAccounts.size();
            Set<Id> usedAccountIds = new Set<Id>();
            for (Account a : dealerAccounts) {
                usedAccountIds.add(a.Id);
            }

            List<Account> fallbackAccounts;
            if (usedAccountIds.isEmpty()) {
                fallbackAccounts = [SELECT Id FROM Account ORDER BY LastModifiedDate DESC LIMIT :additionalNeeded];
            } else {
                fallbackAccounts = [
                    SELECT Id
                    FROM Account
                    WHERE Id NOT IN :usedAccountIds
                    ORDER BY LastModifiedDate DESC
                    LIMIT :additionalNeeded
                ];
            }
            dealerAccounts.addAll(fallbackAccounts);
            warnings.add(
                'Used ' + fallbackAccounts.size() + ' existing Account records because duplicate rules blocked some inserts.'
            );
        }

        if (dealerAccounts.isEmpty()) {
            throw new SeedDataException('No dealer accounts available for seeding. Check Account data in org.');
        }

        Integer effectiveCount = Math.min(count, dealerAccounts.size());
        if (effectiveCount < count) {
            warnings.add('Account inserts were partially successful. Continuing with ' + effectiveCount + ' records.');
        }

        List<Contact> dealerContacts = insertDealerContacts(
            buildDealerContacts(runKey, dealerAccounts),
            warnings
        );

        Integer warrantyInsertCount = insertAssetWarranties(runKey, vehicles, effectiveCount, warnings);

        List<CreatePriorAuthorizationClaim.Request> claimRequests =
            buildClaimRequests(runKey, dealerAccounts, vehicles, effectiveCount);
        List<CreatePriorAuthorizationClaim.Response> claimResponses =
            CreatePriorAuthorizationClaim.createClaims(claimRequests);

        List<Id> createdClaimIds = new List<Id>();
        for (CreatePriorAuthorizationClaim.Response response : claimResponses) {
            if (response != null && response.claimId != null && response.status == 'Created') {
                createdClaimIds.add(response.claimId);
            } else if (response != null && String.isNotBlank(response.message)) {
                warnings.add('Claim create warning: ' + response.message);
            }
        }

        // Queue routing is already handled by Claim_Queue_Routing_Flow on record create.
        Integer queuedCount = 0;
        Integer clarificationCount = requestClarifications(runKey, createdClaimIds, warnings);

        SeedSummary summary = new SeedSummary();
        summary.runKey = runKey;
        summary.requestedCount = target;
        summary.usedVehicleCount = effectiveCount;
        summary.addedAssets = vehiclePool.addedAssets;
        summary.addedVehicles = vehiclePool.addedVehicles;
        summary.createdAccounts = createdAccountCount;
        summary.createdContacts = dealerContacts.size();
        summary.insertedAssetWarranties = warrantyInsertCount;
        summary.createdClaims = createdClaimIds.size();
        summary.queuedClaims = queuedCount;
        summary.clarificationUpdates = clarificationCount;
        summary.warnings = warnings;
        return summary;
    }

    public static Map<String, Integer> collectRunCounts(String runKey) {
        String repairOrderPrefix = 'ELX-RO-' + runKey + '-%';

        List<Claim> claims = [
            SELECT Id
            FROM Claim
            WHERE Repair_Order_Number__c LIKE :repairOrderPrefix
        ];
        Set<Id> claimIds = new Set<Id>();
        for (Claim claimRecord : claims) {
            claimIds.add(claimRecord.Id);
        }

        Map<String, Integer> counts = new Map<String, Integer>();
        counts.put('Claims', claimIds.size());
        counts.put('ClaimItems', claimIds.isEmpty() ? 0 : [SELECT COUNT() FROM ClaimItem WHERE ClaimId IN :claimIds]);
        counts.put('ClaimCoverage', claimIds.isEmpty() ? 0 : [SELECT COUNT() FROM ClaimCoverage WHERE ClaimId IN :claimIds]);

        Set<Id> coverageIds = new Set<Id>();
        if (!claimIds.isEmpty()) {
            for (ClaimCoverage c : [SELECT Id FROM ClaimCoverage WHERE ClaimId IN :claimIds]) {
                coverageIds.add(c.Id);
            }
        }
        counts.put(
            'ClaimCoveragePaymentDetail',
            coverageIds.isEmpty() ? 0 : [SELECT COUNT() FROM ClaimCoveragePaymentDetail WHERE ClaimCoverageId IN :coverageIds]
        );

        counts.put('Accounts', [SELECT COUNT() FROM Account WHERE AccountNumber LIKE :('ELX-DLR-' + runKey + '-%')]);
        counts.put('Contacts', [SELECT COUNT() FROM Contact WHERE Email LIKE :('dealer.%.' + runKey + '@electracars.example')]);
        counts.put('SeedVehicles', [SELECT COUNT() FROM Vehicle WHERE Name LIKE :('Electra Seed Vehicle ' + runKey + '%')]);
        counts.put('SeedAssets', [SELECT COUNT() FROM Asset WHERE Name LIKE :('Electra Seed Asset ' + runKey + '%')]);

        Integer runAssetWarrantyCount = 0;
        for (AssetWarranty w : [SELECT Coverage_Notes__c FROM AssetWarranty LIMIT 50000]) {
            String notes = (String) w.get('Coverage_Notes__c');
            if (notes != null && notes.contains(runKey)) {
                runAssetWarrantyCount++;
            }
        }
        counts.put('AssetWarranties', runAssetWarrantyCount);
        return counts;
    }

    private static Integer normalizeTargetCount(Integer requestedCount) {
        Integer target = requestedCount == null ? 25 : requestedCount;
        if (target < 20) {
            return 20;
        }
        if (target > 25) {
            return 25;
        }
        return target;
    }

    private static VehiclePoolResult ensureVehiclePool(Integer target, String runKey, List<String> warnings) {
        VehiclePoolResult result = new VehiclePoolResult();
        result.vehicles = [
            SELECT Id, Name, VehicleIdentificationNumber, AssetId, VehicleDefinitionId, Asset.Product2Id
            FROM Vehicle
            WHERE VehicleIdentificationNumber != null
                AND AssetId != null
                AND VehicleDefinitionId != null
            ORDER BY LastModifiedDate DESC
            LIMIT :target
        ];

        if (result.vehicles.size() >= target) {
            return result;
        }

        Integer additionalNeeded = target - result.vehicles.size();
        Vehicle templateVehicle = [
            SELECT Id, VehicleDefinitionId, Asset.Product2Id
            FROM Vehicle
            WHERE VehicleIdentificationNumber != null
                AND AssetId != null
                AND VehicleDefinitionId != null
                AND Asset.Product2Id != null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (templateVehicle == null || templateVehicle.VehicleDefinitionId == null || templateVehicle.Asset.Product2Id == null) {
            warnings.add('Could not create additional vehicles because template VehicleDefinition/Product is missing.');
            return result;
        }

        List<Account> ownerAccounts = [SELECT Id FROM Account ORDER BY LastModifiedDate DESC LIMIT 10];
        if (ownerAccounts.isEmpty()) {
            warnings.add('Could not create additional vehicles because no Account exists for asset ownership.');
            return result;
        }

        List<Asset> assetsToInsert = new List<Asset>();
        for (Integer i = 0; i < additionalNeeded; i++) {
            Asset a = new Asset();
            a.Name = 'Electra Seed Asset ' + runKey + ' ' + pad3(i + 1);
            a.Product2Id = templateVehicle.Asset.Product2Id;
            a.AccountId = ownerAccounts[Math.mod(i, ownerAccounts.size())].Id;
            a.SerialNumber = 'ELX-ASSET-' + runKey + '-' + pad3(i + 1);
            assetsToInsert.add(a);
        }

        Database.SaveResult[] assetResults = Database.insert(assetsToInsert, false);
        List<Asset> insertedAssets = new List<Asset>();
        for (Integer i = 0; i < assetResults.size(); i++) {
            if (assetResults[i].isSuccess()) {
                insertedAssets.add(assetsToInsert[i]);
            } else if (assetResults[i].getErrors().size() > 0) {
                warnings.add('Asset create warning: ' + assetResults[i].getErrors()[0].getMessage());
            }
        }
        result.addedAssets = insertedAssets.size();

        if (insertedAssets.isEmpty()) {
            return result;
        }

        Set<String> existingVins = new Set<String>();
        for (Vehicle v : result.vehicles) {
            existingVins.add(v.VehicleIdentificationNumber);
        }

        List<Vehicle> vehiclesToInsert = new List<Vehicle>();
        Integer vinCounter = 1;
        for (Integer i = 0; i < insertedAssets.size(); i++) {
            String candidateVin = buildSeedVin(runKey, vinCounter);
            while (existingVins.contains(candidateVin)) {
                vinCounter++;
                candidateVin = buildSeedVin(runKey, vinCounter);
            }
            existingVins.add(candidateVin);
            vinCounter++;

            Vehicle v = new Vehicle();
            v.Name = 'Electra Seed Vehicle ' + runKey + ' ' + pad3(i + 1);
            v.AssetId = insertedAssets[i].Id;
            v.VehicleDefinitionId = templateVehicle.VehicleDefinitionId;
            v.VehicleIdentificationNumber = candidateVin;
            vehiclesToInsert.add(v);
        }

        Database.SaveResult[] vehicleResults = Database.insert(vehiclesToInsert, false);
        for (Integer i = 0; i < vehicleResults.size(); i++) {
            if (vehicleResults[i].isSuccess()) {
                result.vehicles.add(vehiclesToInsert[i]);
                result.addedVehicles++;
            } else if (vehicleResults[i].getErrors().size() > 0) {
                warnings.add('Vehicle create warning: ' + vehicleResults[i].getErrors()[0].getMessage());
            }
        }

        if (result.vehicles.size() > target) {
            while (result.vehicles.size() > target) {
                result.vehicles.remove(result.vehicles.size() - 1);
            }
        }

        return result;
    }

    private static List<Account> insertDealerAccounts(List<Account> accountsToInsert, List<String> warnings) {
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        for (Account accountRecord : accountsToInsert) {
            accountRecord.setOptions(options);
        }

        Database.SaveResult[] results = Database.insert(accountsToInsert, false);
        List<Account> inserted = new List<Account>();
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                inserted.add(accountsToInsert[i]);
            } else if (results[i].getErrors().size() > 0) {
                warnings.add('Account create warning: ' + results[i].getErrors()[0].getMessage());
            }
        }
        return inserted;
    }

    private static List<Contact> insertDealerContacts(List<Contact> contactsToInsert, List<String> warnings) {
        if (contactsToInsert.isEmpty()) {
            return contactsToInsert;
        }

        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        for (Contact contactRecord : contactsToInsert) {
            contactRecord.setOptions(options);
        }

        Database.SaveResult[] results = Database.insert(contactsToInsert, false);
        List<Contact> inserted = new List<Contact>();
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                inserted.add(contactsToInsert[i]);
            } else if (results[i].getErrors().size() > 0) {
                warnings.add('Contact create warning: ' + results[i].getErrors()[0].getMessage());
            }
        }
        return inserted;
    }

    private static List<Account> buildDealerAccounts(String runKey, Integer count) {
        List<String> dealerBrands = new List<String>{
            'Aurora EV Mobility', 'BluePeak Auto Works', 'Cobalt Drive Center', 'Delta Motion Garage',
            'Eon Circuit Motors', 'Flux Highway Hub', 'GlideTorque Service', 'Helix Mobility Yard',
            'Ionline Auto Point', 'JouleTrack Motors', 'Kinetic Road Labs', 'Lumina EV Workshop',
            'Matrix Drive Depot', 'NovaTorque Mobility', 'OrbitAuto Service', 'PulseDrive Garage',
            'Quantum Road Studio', 'RapidVolt Motors', 'Sparkline EV Hub', 'TorqueTrail Workshop',
            'UrbanAmp Auto Care', 'VectorDrive Garage', 'WaveCharge Motors', 'XpressEV Works',
            'YieldRoad Mobility', 'ZenDrive Auto Hub', 'AstraMotion Center', 'Boltway Service Point',
            'CoreShift Motors', 'Driftline EV Care'
        };
        List<String> cities = new List<String>{
            'Bengaluru', 'Hyderabad', 'Pune', 'Ahmedabad', 'Chennai',
            'Mumbai', 'Delhi', 'Jaipur', 'Kolkata', 'Surat'
        };
        List<String> states = new List<String>{
            'Karnataka', 'Telangana', 'Maharashtra', 'Gujarat', 'Tamil Nadu',
            'Maharashtra', 'Delhi', 'Rajasthan', 'West Bengal', 'Gujarat'
        };

        List<Account> accounts = new List<Account>();
        String runTail = runKey.right(4);
        for (Integer i = 0; i < count; i++) {
            Integer cityIndex = Math.mod(i, cities.size());
            Account accountRecord = new Account();
            accountRecord.Name = dealerBrands[Math.mod(i, dealerBrands.size())] + ' ' + runKey.right(6) + ' ' + pad3(i + 1);
            accountRecord.Phone = '+91-80-' + runTail + '-' + pad4(1000 + i);
            accountRecord.Website = 'https://dealer' + pad3(i + 1) + '-' + runKey + '.electracars.example';
            accountRecord.Industry = 'Automotive';
            accountRecord.BillingStreet = (10 + i) + ', EV Service Park, Sector ' + String.valueOf(1 + Math.mod(i, 12));
            accountRecord.BillingCity = cities[cityIndex];
            accountRecord.BillingState = states[cityIndex];
            accountRecord.BillingPostalCode = String.valueOf(560000 + i);
            accountRecord.BillingCountry = 'India';
            accountRecord.AccountNumber = 'ELX-DLR-' + runKey + '-' + pad3(i + 1);
            accounts.add(accountRecord);
        }
        return accounts;
    }

    private static List<Contact> buildDealerContacts(String runKey, List<Account> dealerAccounts) {
        List<String> firstNames = new List<String>{
            'Aarav', 'Ishaan', 'Riya', 'Anaya', 'Kabir', 'Diya', 'Arjun', 'Meera',
            'Vihaan', 'Sara', 'Rohan', 'Nisha', 'Aditya', 'Kavya', 'Rahul', 'Tara',
            'Manav', 'Ira', 'Neel', 'Aisha', 'Varun', 'Pooja', 'Dev', 'Myra', 'Kiran',
            'Naina', 'Samar', 'Leena', 'Pranav', 'Saanvi'
        };
        List<String> lastNames = new List<String>{
            'Verma', 'Reddy', 'Sharma', 'Kapoor', 'Iyer', 'Menon', 'Patel', 'Rana',
            'Das', 'Bose', 'Gupta', 'Khan', 'Sinha', 'Nair', 'Mishra', 'Arora',
            'Kulkarni', 'Yadav', 'Malhotra', 'Chawla', 'Bhat', 'Singh', 'Banerjee', 'Joshi',
            'Goel', 'Pillai', 'Saxena', 'Dutta', 'Thakur', 'Prasad'
        };
        List<String> titles = new List<String>{
            'Service Advisor', 'Warranty Coordinator', 'Workshop Manager', 'Parts Manager'
        };

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < dealerAccounts.size(); i++) {
            Contact contactRecord = new Contact();
            contactRecord.AccountId = dealerAccounts[i].Id;
            contactRecord.FirstName = firstNames[Math.mod(i, firstNames.size())];
            contactRecord.LastName = lastNames[Math.mod(i, lastNames.size())] + ' ' + runKey.right(4) + pad3(i + 1);
            contactRecord.Title = titles[Math.mod(i, titles.size())];
            contactRecord.Email = 'dealer.' + pad3(i + 1) + '.' + runKey + '@electracars.example';
            contactRecord.Phone = '+91-98' + pad6(700000 + i);
            contacts.add(contactRecord);
        }
        return contacts;
    }

    private static Integer insertAssetWarranties(
        String runKey,
        List<Vehicle> vehicles,
        Integer count,
        List<String> warnings
    ) {
        List<AssetWarranty> warranties = new List<AssetWarranty>();
        for (Integer i = 0; i < count; i++) {
            Vehicle vehicleRecord = vehicles[i];
            AssetWarranty warranty = new AssetWarranty();
            warranty.AssetId = vehicleRecord.AssetId;
            warranty.StartDate = Date.today().addMonths(-1 * (12 + Math.mod(i, 6)));
            warranty.EndDate = Date.today().addMonths(24 + Math.mod(i, 12));
            warranty.WarrantyType = Math.mod(i, 5) == 0 ? 'Repair' : 'Standard';
            warranty.put('Mileage_Limit__c', Decimal.valueOf(60000 + (i * 1250)));
            warranty.put('Months_Limit__c', Decimal.valueOf(36 + (Math.mod(i, 3) * 12)));
            warranty.put('Extension_Flag__c', Math.mod(i, 7) == 0);
            warranty.put('Exclusion_Flag__c', false);
            warranty.put(
                'Coverage_Notes__c',
                'Electra Cars seeded warranty for VIN ' + vehicleRecord.VehicleIdentificationNumber + ' (' + runKey + ').'
            );
            warranties.add(warranty);
        }

        Database.SaveResult[] results = Database.insert(warranties, false);
        Integer inserted = 0;
        for (Database.SaveResult result : results) {
            if (result.isSuccess()) {
                inserted++;
            } else if (result.getErrors().size() > 0) {
                warnings.add('AssetWarranty warning: ' + result.getErrors()[0].getMessage());
            }
        }
        return inserted;
    }

    private static List<CreatePriorAuthorizationClaim.Request> buildClaimRequests(
        String runKey,
        List<Account> dealerAccounts,
        List<Vehicle> vehicles,
        Integer count
    ) {
        List<String> issues = new List<String>{
            'Battery cooling module replacement',
            'Drive inverter control board replacement',
            'HV cable harness replacement',
            'E-axle sensor replacement',
            'Thermal pump assembly replacement',
            'Charging port actuator replacement'
        };

        List<String> diagnosticCodes = new List<String>{
            'P0A7C', 'P0AA6', 'P1A10', 'P0C73', 'P0A94', 'P1A45'
        };

        List<CreatePriorAuthorizationClaim.Request> requests = new List<CreatePriorAuthorizationClaim.Request>();
        for (Integer i = 0; i < count; i++) {
            Vehicle vehicleRecord = vehicles[i];
            String issue = issues[Math.mod(i, issues.size())];
            String diagnosticCode = diagnosticCodes[Math.mod(i, diagnosticCodes.size())];

            CreatePriorAuthorizationClaim.Request request = new CreatePriorAuthorizationClaim.Request();
            request.vin = vehicleRecord.VehicleIdentificationNumber;
            request.dealerAccountId = dealerAccounts[i].Id;
            request.summary = issue + ' requested for ' + vehicleRecord.Name + '.';
            request.symptomText = 'Dealer observed warning alert and confirmed failure during standard diagnostics.';
            request.diagnosticCodeText = diagnosticCode;
            request.faultDate = Datetime.now().addDays(-1 * (4 + Math.mod(i, 15)));
            request.repairDate = Datetime.now().addDays(-1 * Math.mod(i, 3));
            request.mileageAtFailure = Decimal.valueOf(9500 + (i * 1350));
            request.submissionChannel = Math.mod(i, 2) == 0 ? 'Web Chat' : 'WhatsApp';
            request.authorizationType = 'Prior Authorization';
            request.priority = Math.mod(i, 4) == 0 ? 'Critical' : 'Medium';
            request.repairOrderNumber = 'ELX-RO-' + runKey + '-' + pad3(i + 1);
            request.dealerWhatsAppNumber = '+91-99' + pad6(300000 + i);
            request.externalDmsReference = 'ELX-DMS-' + runKey + '-' + pad3(i + 1);
            request.requestedAmount = Decimal.valueOf(1200 + (Math.mod(i, 7) * 185));
            request.requestedQuantity = 1;
            request.chargeType = 'Replaced Part';
            requests.add(request);
        }
        return requests;
    }

    private static Integer requestClarifications(String runKey, List<Id> claimIds, List<String> warnings) {
        if (claimIds.isEmpty()) {
            return 0;
        }

        List<RequestDealerClarification.Input> clarificationRequests = new List<RequestDealerClarification.Input>();
        for (Integer i = 0; i < claimIds.size(); i++) {
            if (Math.mod(i, 3) != 0) {
                continue;
            }
            RequestDealerClarification.Input request = new RequestDealerClarification.Input();
            request.claimId = claimIds[i];
            request.clarificationRequest =
                'Please provide invoice image and confirm failure timestamp for seeded run ' + runKey + '.';
            clarificationRequests.add(request);
        }

        List<RequestDealerClarification.Result> clarificationResponses =
            RequestDealerClarification.requestClarification(clarificationRequests);
        Integer updatedCount = 0;
        for (RequestDealerClarification.Result response : clarificationResponses) {
            if (response != null && response.status == 'Success') {
                updatedCount++;
            } else if (response != null && String.isNotBlank(response.message)) {
                warnings.add('Clarification warning: ' + response.message);
            }
        }
        return updatedCount;
    }

    private static String pad3(Integer value) {
        return String.valueOf(value).leftPad(3, '0');
    }

    private static String pad4(Integer value) {
        return String.valueOf(value).leftPad(4, '0');
    }

    private static String pad6(Integer value) {
        return String.valueOf(value).leftPad(6, '0');
    }

    private static String buildSeedVin(String runKey, Integer counter) {
        String compactRunKey = runKey.substring(2); // keep VIN concise and unique per run
        return 'ELX' + compactRunKey + pad3(counter);
    }
}