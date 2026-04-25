public with sharing class SubmitGoodwillReview {

    public class Input {
        @InvocableVariable(label='Claim Id' description='Salesforce Id of the existing Claim to flag for goodwill review. Either claimId or vin must be provided.')
        public Id claimId;

        @InvocableVariable(label='VIN' description='17-character VIN. Used when no claim exists yet — creates a goodwill claim automatically.')
        public String vin;

        @InvocableVariable(label='Dealer Id' description='Account Id of the dealer. Required when creating a new goodwill claim from VIN.')
        public Id dealerId;

        @InvocableVariable(label='Goodwill Reason' description='Dealer reason for requesting a goodwill policy exception.')
        public String goodwillReason;

        @InvocableVariable(label='Part Category' description='Part category involved. Used when creating a new goodwill claim.')
        public String partCategory;
    }

    public class Result {
        @InvocableVariable(label='Status') public String status;
        @InvocableVariable(label='Claim Id' description='Id of the updated or newly created Claim.') public Id claimId;
        @InvocableVariable(label='Claim Number') public String claimNumber;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(label='Submit Goodwill Review' description='Flags a Warranty Claim for goodwill policy exception. If no claimId is provided but a VIN is given, creates a minimal Goodwill claim first.')
    public static List<Result> submit(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        for (Input i : inputs) {
            Result r = new Result();
            try {
                Id targetClaimId = i.claimId;

                // No claim yet — create a minimal Goodwill claim from VIN
                if (targetClaimId == null && String.isNotBlank(i.vin)) {
                    List<Vehicle> vehicles = [
                        SELECT Id, AssetId FROM Vehicle
                        WHERE VehicleIdentificationNumber = :i.vin LIMIT 1
                    ];
                    if (vehicles.isEmpty()) {
                        r.status = 'Error';
                        r.message = 'Vehicle not found for VIN: ' + i.vin;
                        results.add(r);
                        continue;
                    }

                    Id resolvedDealerId = i.dealerId;
                    if (resolvedDealerId == null && vehicles[0].AssetId != null) {
                        List<Asset> assets = [SELECT AccountId FROM Asset WHERE Id = :vehicles[0].AssetId LIMIT 1];
                        if (!assets.isEmpty()) resolvedDealerId = assets[0].AccountId;
                    }
                    if (resolvedDealerId == null) {
                        r.status = 'Error';
                        r.message = 'Dealer Id required to create a goodwill claim.';
                        results.add(r);
                        continue;
                    }

                    Claim newClaim = new Claim();
                    newClaim.AccountId      = resolvedDealerId;
                    newClaim.Name           = 'Goodwill Request: ' + i.vin;
                    newClaim.Status         = 'Submitted';
                    newClaim.Authorization_Type__c = 'Goodwill';
                    newClaim.Priority__c    = 'High';
                    newClaim.Vehicle__c     = vehicles[0].AssetId;
                    newClaim.PartCategory__c = String.isNotBlank(i.partCategory) ? i.partCategory : 'General';
                    newClaim.DealerResponseSummary__c = i.goodwillReason;
                    newClaim.SLA_Due_Date__c = System.now().addHours(72);
                    insert newClaim;
                    targetClaimId = newClaim.Id;
                }

                if (targetClaimId == null) {
                    r.status = 'Error';
                    r.message = 'Provide either claimId or a VIN to submit a goodwill review.';
                    results.add(r);
                    continue;
                }

                // Update the claim to Goodwill type and escalate priority
                Claim c = new Claim(Id = targetClaimId);
                c.Authorization_Type__c = 'Goodwill';
                c.Priority__c = 'High';
                if (String.isNotBlank(i.goodwillReason)) {
                    c.DealerResponseSummary__c = i.goodwillReason;
                }
                update c;

                List<Claim> updated = [SELECT Name FROM Claim WHERE Id = :targetClaimId LIMIT 1];
                r.status      = 'Success';
                r.claimId     = targetClaimId;
                r.claimNumber = updated.isEmpty() ? null : updated[0].Name;
                r.message     = 'Goodwill request submitted. Manager review within 48-72 business hours.';

            } catch (Exception e) {
                r.status  = 'Error';
                r.message = e.getMessage();
            }
            results.add(r);
        }
        return results;
    }
}