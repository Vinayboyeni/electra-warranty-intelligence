// NOTE: without sharing — the coverage engine must see every active AssetWarranty
// for the queried Vehicle regardless of the running user's record access. When
// the agent service user runs this via flow, it doesn't have row-level access
// to warranties owned by other users, so "with sharing" silently returns empty
// and every claim ends up marked "Not Covered".
public without sharing class CoverageEngine {
    public class EvaluationInput {
        public Id vehicleId;
        public Integer odometer;
        public String partCategory;
    }
    public class EvaluationResult {
        @AuraEnabled public String eligibility;
        @AuraEnabled public List<String> riskFlags;
        @AuraEnabled public String rationale;
        @AuraEnabled public Id coverageId;
    }

    @InvocableMethod(label='Evaluate Coverage' description='Evaluates whether a vehicle and part category are covered under an active AssetWarranty. Returns eligibility verdict (Likely/Borderline/Not Covered), rationale, risk flags, and the AssetWarranty Id used for evaluation. Used as Step 2 of the Dealer Intake Agent.')
    public static List<CoverageEvaluateResult> evaluateInvocable(List<CoverageEvaluateInput> inputs) {
        List<CoverageEvaluateResult> out = new List<CoverageEvaluateResult>();
        if (inputs == null) return out;
        for (CoverageEvaluateInput i : inputs) {
            EvaluationResult er = evaluate(i == null ? null : i.vehicleId, i == null ? null : i.odometer, i == null ? null : i.partCategory);
            CoverageEvaluateResult r = new CoverageEvaluateResult();
            if ( er != null ) {
                r.eligibility = er.eligibility;
                r.riskFlags = er.riskFlags;
                r.rationale = er.rationale;
                r.coverageId = er.coverageId;
            }
            out.add(r);
        }
        return out;
    }

    public static EvaluationResult evaluate(Id vehicleId, Integer odometer, String partCategory) {
        if (vehicleId == null) throw new AuraHandledException('vehicleId is required');

        // vehicleId is the Vehicle record Id — AssetWarranty.Vehicle__c is a Lookup to Asset,
        // so we need to resolve the AssetId first.
        List<Vehicle> vehicles = [SELECT AssetId FROM Vehicle WHERE Id = :vehicleId LIMIT 1];
        Id assetId = vehicles.isEmpty() ? null : vehicles[0].AssetId;

        List<AssetWarranty> coverage = assetId != null
            ? [SELECT Id, StartDate, EndDate, MileageCap__c, CoveredCategories__c
               FROM AssetWarranty
               WHERE Vehicle__c = :assetId
               ORDER BY EndDate DESC
               LIMIT 1]
            : new List<AssetWarranty>();
        AssetWarranty cov = coverage.isEmpty() ? null : coverage[0];

        EvaluationResult out = new EvaluationResult();
        out.riskFlags = new List<String>();
        out.coverageId = cov == null ? null : cov.Id;

        if (cov == null) {
            out.eligibility = 'Not Covered';
            out.rationale = 'Eligibility: Not Covered | No active warranty found for this vehicle.';
            out.riskFlags.add('No warranty record found');
            return out;
        }

        Date today = Date.today();
        Boolean dateInRange = cov.StartDate != null && cov.EndDate != null
            && today >= cov.StartDate && today <= cov.EndDate;

        Boolean mileageInRange = cov.MileageCap__c == null || odometer == null
            || odometer <= cov.MileageCap__c;

        // Check if the part category is listed in the covered categories
        Boolean partCovered = true;
        if (String.isNotBlank(partCategory) && String.isNotBlank(cov.CoveredCategories__c)) {
            String coveredLower = cov.CoveredCategories__c.toLowerCase();
            String partLower = partCategory.toLowerCase();
            partCovered = coveredLower.contains(partLower);
        }

        if (dateInRange && mileageInRange && partCovered) {
            out.eligibility = 'Likely';
            out.rationale = 'Eligibility: Likely | Coverage active until ' + cov.EndDate
                + ' | Odometer: ' + odometer + ' (cap: ' + cov.MileageCap__c + ')';
        } else if ((dateInRange || mileageInRange) && !partCovered) {
            out.eligibility = 'Borderline';
            out.riskFlags.add('Part category "' + partCategory + '" not listed in covered categories');
            out.rationale = 'Eligibility: Borderline | Part coverage unclear. Covered categories: '
                + cov.CoveredCategories__c;
        } else {
            out.eligibility = 'Not Covered';
            if (!dateInRange) out.riskFlags.add('Outside coverage dates (expired ' + cov.EndDate + ')');
            if (!mileageInRange) out.riskFlags.add('Mileage ' + odometer + ' exceeds cap of ' + cov.MileageCap__c);
            if (!partCovered) out.riskFlags.add('Part "' + partCategory + '" not in covered categories');
            out.rationale = 'Eligibility: Not Covered | Flags: ' + String.join(out.riskFlags, '; ');
        }
        return out;
    }
}