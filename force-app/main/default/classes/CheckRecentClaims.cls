/**
 * CheckRecentClaims - Agentforce Invocable Action
 *
 * Duplicate claim guard for the Dealer Intake Agent.
 * Checks whether an open or recent warranty claim exists for the same VIN
 * and Part Category within the last 30 days. Prevents data pollution in the
 * Automotive Cloud pipeline and surfaces the duplicate to the agent before
 * allowing a new claim to be submitted.
 */
public with sharing class CheckRecentClaims {

    public class Input {
        @InvocableVariable(label='VIN' description='17-character VIN to search for recent claims.' required=true)
        public String vin;

        @InvocableVariable(label='Part Category' description='Part category to match against recent claims. If blank, matches on VIN alone.' required=false)
        public String partCategory;
    }

    public class Result {
        @InvocableVariable(label='Duplicate Found' description='True if an open claim for this VIN (and part category) was submitted in the last 30 days.')
        public Boolean duplicateFound;

        @InvocableVariable(label='Existing Claim Number' description='Human-readable number of the existing open claim.')
        public String existingClaimNumber;

        @InvocableVariable(label='Existing Claim Id' description='Salesforce Id of the existing open claim.')
        public Id existingClaimId;

        @InvocableVariable(label='Existing Claim Status' description='Current status of the existing claim.')
        public String existingClaimStatus;

        @InvocableVariable(label='Days Since Submission' description='Number of days since the existing claim was submitted.')
        public Integer daysSinceSubmission;
    }

    @InvocableMethod(
        label='Check Recent Claims'
        description='Checks for duplicate open warranty claims for this VIN in the last 30 days. Used as a data quality gate before submitting a new claim.'
    )
    public static List<Result> checkRecent(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        for (Input inp : inputs) {
            Result res = new Result();
            res.duplicateFound = false;
            res.daysSinceSubmission = 0;

            if (String.isBlank(inp.vin)) {
                results.add(res);
                continue;
            }

            DateTime cutoff = DateTime.now().addDays(-30);

            // Look up the Vehicle first
            List<Vehicle> vehicles = [
                SELECT Id, AssetId
                FROM Vehicle
                WHERE VehicleIdentificationNumber = :inp.vin
                LIMIT 1
            ];

            if (vehicles.isEmpty()) {
                results.add(res);
                continue;
            }

            // Claim.Vehicle__c stores the Asset Id (not the Vehicle record Id)
            Id vehicleId = vehicles[0].AssetId;

            // Query for open claims in the last 30 days
            String statusFilter = 'Pending Approver Review';
            List<Claim> openClaims;

            if (String.isNotBlank(inp.partCategory)) {
                openClaims = [
                    SELECT Id, Name, Status, CreatedDate, PartCategory__c
                    FROM Claim
                    WHERE Vehicle__c = :vehicleId
                      AND PartCategory__c = :inp.partCategory
                      AND CreatedDate >= :cutoff
                      AND Status IN ('Submitted', 'Pending Approver Review', 'Under Review')
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
            } else {
                openClaims = [
                    SELECT Id, Name, Status, CreatedDate, PartCategory__c
                    FROM Claim
                    WHERE Vehicle__c = :vehicleId
                      AND CreatedDate >= :cutoff
                      AND Status IN ('Submitted', 'Pending Approver Review', 'Under Review')
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
            }

            if (!openClaims.isEmpty()) {
                Claim c = openClaims[0];
                res.duplicateFound = true;
                res.existingClaimId = c.Id;
                res.existingClaimNumber = c.Name;
                res.existingClaimStatus = c.Status;
                res.daysSinceSubmission = Integer.valueOf(
                    (DateTime.now().getTime() - c.CreatedDate.getTime()) / 86400000L
                );
            }

            results.add(res);
        }

        return results;
    }
}