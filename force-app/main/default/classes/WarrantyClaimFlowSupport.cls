public with sharing class WarrantyClaimFlowSupport {
    public class VehicleWarrantyContext {
        public Vehicle vehicle;
        public Asset asset;
        public AssetWarranty activeWarranty;
    }

    public static Map<String, VehicleWarrantyContext> findVehicleWarrantyByVin(Set<String> vins) {
        Map<String, VehicleWarrantyContext> results = new Map<String, VehicleWarrantyContext>();
        Set<String> normalizedVins = new Set<String>();

        for (String vin : vins) {
            String normalized = normalizeVin(vin);
            if (String.isNotBlank(normalized)) {
                normalizedVins.add(normalized);
            }
        }

        if (normalizedVins.isEmpty()) {
            return results;
        }

        Map<String, Vehicle> vehiclesByVin = new Map<String, Vehicle>();
        for (Vehicle vehicle : [
            SELECT Id,
                   AssetId,
                   CurrentOwnerId,
                   VehicleIdentificationNumber,
                   ManufacturerWarrantyStartDt,
                   ManufacturerWarrantyEndDate,
                   Current_Mileage__c,
                   Last_Known_Mileage__c,
                   ActiveWarrantyCount,
                   Asset.AccountId,
                   Asset.Product2Id,
                   Asset.SerialNumber
            FROM Vehicle
            WHERE VehicleIdentificationNumber IN :normalizedVins
        ]) {
            vehiclesByVin.put(normalizeVin(vehicle.VehicleIdentificationNumber), vehicle);
        }

        Set<Id> assetIds = new Set<Id>();
        for (Vehicle vehicle : vehiclesByVin.values()) {
            if (vehicle.AssetId != null) {
                assetIds.add(vehicle.AssetId);
            }
        }

        Map<Id, AssetWarranty> activeWarrantyByAssetId = new Map<Id, AssetWarranty>();
        if (!assetIds.isEmpty()) {
            for (AssetWarranty warranty : [
                SELECT Id,
                       AssetId,
                       StartDate,
                       EndDate,
                       WarrantyType,
                       WarrantyTermId,
                       Coverage_Notes__c,
                       Extension_Flag__c,
                       Exclusion_Flag__c,
                       Mileage_Limit__c,
                       Months_Limit__c
                FROM AssetWarranty
                WHERE AssetId IN :assetIds
                ORDER BY EndDate DESC NULLS LAST
            ]) {
                if (!activeWarrantyByAssetId.containsKey(warranty.AssetId) && isWarrantyCurrentlyActive(warranty)) {
                    activeWarrantyByAssetId.put(warranty.AssetId, warranty);
                }
            }
        }

        for (String vin : normalizedVins) {
            VehicleWarrantyContext context = new VehicleWarrantyContext();
            Vehicle vehicle = vehiclesByVin.get(vin);
            if (vehicle != null) {
                context.vehicle = vehicle;
                context.asset = vehicle.Asset;
                context.activeWarranty = activeWarrantyByAssetId.get(vehicle.AssetId);
            }
            results.put(vin, context);
        }

        return results;
    }

    public static Id getRecordTypeId(Schema.SObjectType sObjectTypeToken, String developerName) {
        Schema.DescribeSObjectResult describe = sObjectTypeToken.getDescribe();
        for (Schema.RecordTypeInfo info : describe.getRecordTypeInfos()) {
            if (info.getDeveloperName() == developerName) {
                return info.getRecordTypeId();
            }
        }
        return null;
    }

    public static String choosePicklistValue(Schema.SObjectField fieldToken, List<String> preferredValues) {
        if (fieldToken == null || preferredValues == null || preferredValues.isEmpty()) {
            return null;
        }

        return choosePicklistValue(fieldToken.getDescribe(), preferredValues);
    }

    public static String choosePicklistValue(Schema.DescribeFieldResult fieldDescribe, List<String> preferredValues) {
        if (fieldDescribe == null || preferredValues == null || preferredValues.isEmpty()) {
            return null;
        }

        Map<String, String> labelsToValues = new Map<String, String>();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            labelsToValues.put(entry.getLabel().toLowerCase(), entry.getValue());
            labelsToValues.put(entry.getValue().toLowerCase(), entry.getValue());
        }

        for (String preferred : preferredValues) {
            if (String.isBlank(preferred)) {
                continue;
            }
            String match = labelsToValues.get(preferred.toLowerCase());
            if (match != null) {
                return match;
            }
        }

        return null;
    }

    public static Group findQueueForClaim(String preferredQueueDeveloperName, String priority, Id recordTypeId) {
        Set<Id> candidateQueueIds = new Set<Id>();
        for (QueueSobject queueSobject : [
            SELECT QueueId
            FROM QueueSobject
            WHERE SobjectType = 'Claim'
        ]) {
            candidateQueueIds.add(queueSobject.QueueId);
        }

        if (candidateQueueIds.isEmpty()) {
            return null;
        }

        List<Group> queues = [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE Type = 'Queue'
            AND Id IN :candidateQueueIds
        ];

        if (queues.isEmpty()) {
            return null;
        }

        if (String.isNotBlank(preferredQueueDeveloperName)) {
            for (Group queue : queues) {
                if (queue.DeveloperName == preferredQueueDeveloperName || queue.Name == preferredQueueDeveloperName) {
                    return queue;
                }
            }
        }

        if (String.valueOf(priority).equalsIgnoreCase('Critical')) {
            for (Group queue : queues) {
                if (queue.DeveloperName != null && queue.DeveloperName.toLowerCase().contains('critical')) {
                    return queue;
                }
            }
        }

        for (Group queue : queues) {
            if (queue.DeveloperName != null && queue.DeveloperName.toLowerCase().contains('warranty')) {
                return queue;
            }
        }

        return queues[0];
    }

    public static String normalizeVin(String vin) {
        return String.isBlank(vin) ? null : vin.trim().toUpperCase();
    }

    public static String buildClaimName(String authorizationType, String vin) {
        String prefix = String.isBlank(authorizationType) ? 'Claim' : authorizationType;
        String shortVin = 'UNKNOWN';
        if (!String.isBlank(vin)) {
            shortVin = vin.length() > 6 ? vin.right(6) : vin;
        }
        return prefix + ' - ' + shortVin;
    }

    public static Boolean isWarrantyCurrentlyActive(AssetWarranty warranty) {
        if (warranty == null) {
            return false;
        }

        Date today = Date.today();
        Boolean startsOkay = warranty.StartDate == null || warranty.StartDate <= today;
        Boolean endsOkay = warranty.EndDate == null || warranty.EndDate >= today;
        return startsOkay && endsOkay;
    }
}