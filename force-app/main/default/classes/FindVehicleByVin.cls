public with sharing class FindVehicleByVin {
    public class CoverageSnapshot {
        @AuraEnabled public Id coverageId;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Integer mileageCap;
        @AuraEnabled public String coveredCategories;
        @AuraEnabled public String laborPolicy;
    }
    public class LastClaimSummary {
        @AuraEnabled public Id claimId;
        @AuraEnabled public String claimNumber;
        @AuraEnabled public String status;
        @AuraEnabled public DateTime submittedDate;
        @AuraEnabled public String partCategory;
        @AuraEnabled public Id partId;
    }
    public class Result {
        @AuraEnabled public Id vehicleId;
        @AuraEnabled public String vin;
        @AuraEnabled public String model;
        @AuraEnabled public Integer year;
        @AuraEnabled public Id customerId;
        @AuraEnabled public Id dealerId;
        @AuraEnabled public CoverageSnapshot coverage;
        @AuraEnabled public LastClaimSummary lastClaim;
    }

    @InvocableMethod(label='Find Vehicle Warranty By Vin' description='Lookup Vehicle and active warranty details by VIN.')
    public static List<FindVehicleByVinResult> findByVin(List<FindVehicleByVinInput> inputs) {
        List<FindVehicleByVinResult> out = new List<FindVehicleByVinResult>();
        if (inputs == null) return out;
        for (FindVehicleByVinInput i : inputs) {
            Result r = byVin(i == null ? null : i.vin);
            FindVehicleByVinResult ir = new FindVehicleByVinResult();
            if (r != null) {
                ir.vehicleId = r.vehicleId;
                ir.vin = r.vin;
                ir.vehicleModel = r.model;
                ir.year = r.year;
                ir.customerId = r.customerId;
                ir.dealerId = r.dealerId;
                if (r.coverage != null) {
                    ir.coverageId = r.coverage.coverageId;
                    ir.coverageStartDate = r.coverage.startDate;
                    ir.coverageEndDate = r.coverage.endDate;
                    ir.coverageMileageCap = r.coverage.mileageCap;
                    ir.coverageCategories = r.coverage.coveredCategories;
                }
                if (r.lastClaim != null) {
                    ir.lastClaimId = r.lastClaim.claimId;
                    ir.lastClaimNumber = r.lastClaim.claimNumber;
                    ir.lastClaimStatus = r.lastClaim.status;
                    ir.lastClaimSubmittedDate = r.lastClaim.submittedDate;
                    ir.lastClaimPartCategory = r.lastClaim.partCategory;
                    ir.lastClaimPartId = r.lastClaim.partId;
                }
                ir.vehicleFound = true;
                ir.activeWarrantyFound = (r.coverage != null);
                ir.assetWarrantyId = r.coverage != null ? r.coverage.coverageId : null;
                ir.message = 'Vehicle located.';
            } else {
                ir.vehicleFound = false;
                ir.activeWarrantyFound = false;
                ir.message = 'No vehicle found for the provided VIN.';
            }
            out.add(ir);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static Result byVin(String vin) {
        if (String.isBlank(vin)) {
            throw new AuraHandledException('VIN is required');
        }

        List<Vehicle> vehicles = [
            SELECT Id, VehicleIdentificationNumber, Name, AssetId, Asset.AccountId, Asset.ContactId
            FROM Vehicle
            WHERE VehicleIdentificationNumber = :vin
            LIMIT 1
        ];
        if (vehicles.isEmpty()) {
            return null;
        }
        Vehicle v = vehicles[0];

        Result res = new Result();
        res.vehicleId = v.Id;
        res.vin = v.VehicleIdentificationNumber;
        res.model = v.Name;
        res.dealerId = v.Asset.AccountId;
        res.customerId = v.Asset.ContactId;

        AssetWarranty cov = null;
        try {
            cov = [
                SELECT Id, StartDate, EndDate, MileageCap__c, CoveredCategories__c, LaborPolicy__c
                FROM AssetWarranty
                WHERE Vehicle__c = :v.AssetId
                ORDER BY EndDate DESC
                LIMIT 1
            ];
        } catch (Exception e) {}

        if (cov != null) {
            res.coverage = new CoverageSnapshot();
            res.coverage.coverageId = cov.Id;
            res.coverage.startDate = cov.StartDate;
            res.coverage.endDate = cov.EndDate;
            res.coverage.mileageCap = cov.MileageCap__c == null ? null : Integer.valueOf(cov.MileageCap__c);
            res.coverage.coveredCategories = cov.CoveredCategories__c;
            res.coverage.laborPolicy = cov.LaborPolicy__c;
        }

        Claim last = null;
        try {
            last = [
                SELECT Id, Name, Status, CreatedDate, PartCategory__c, Part__c
                FROM Claim
                WHERE Vehicle__c = :v.AssetId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        } catch (Exception e) {}

        if (last != null) {
            res.lastClaim = new LastClaimSummary();
            res.lastClaim.claimId = last.Id;
            res.lastClaim.claimNumber = last.Name;
            res.lastClaim.status = last.Status;
            res.lastClaim.submittedDate = last.CreatedDate;
            res.lastClaim.partCategory = last.PartCategory__c;
            res.lastClaim.partId = last.Part__c;
        }

        return res;
    }
}