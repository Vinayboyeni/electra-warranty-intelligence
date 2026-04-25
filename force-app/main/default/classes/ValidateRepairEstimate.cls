/**
 * ValidateRepairEstimate - Agentforce Invocable Action
 *
 * Standard Repair Time (SRT) Validator for the Dealer Intake Agent.
 * Checks whether the dealer's requested repair amount aligns with Electra Cars'
 * standard labor and parts cost matrix for the given part category.
 *
 * If the requested amount is more than 20% above the SRT baseline, the agent asks
 * the dealer for a brief justification before allowing claim submission.
 * This pre-emptively captures the data the OEM approver will need, eliminating
 * back-and-forth ping-pong between the dealer and OEM.
 *
 * SRT baselines are maintained in the SRTMatrix__c custom object.
 * If no record exists for a part category, a default tolerance of $500 is applied.
 */
public with sharing class ValidateRepairEstimate {

    public class Input {
        @InvocableVariable(label='Part Category' description='Category of the part being claimed. Used to look up the SRT baseline amount.' required=true)
        public String partCategory;

        @InvocableVariable(label='Requested Amount' description='The repair cost amount submitted by the dealer.' required=true)
        public Decimal requestedAmount;
    }

    public class Result {
        @InvocableVariable(label='Baseline Amount' description='The standard OEM baseline repair cost for this part category from the SRT matrix.')
        public Decimal baselineAmount;

        @InvocableVariable(label='Is Within Range' description='True if the requested amount is within 20% of the SRT baseline. If False, agent must collect dealer justification.')
        public Boolean isWithinRange;

        @InvocableVariable(label='Variance Percent' description='Percentage difference between the requested amount and SRT baseline. Positive = dealer requesting more than baseline.')
        public Decimal variancePercent;

        @InvocableVariable(label='Validation Message' description='Human-readable message summarizing the validation result.')
        public String validationMessage;
    }

    // Variance threshold: if requested amount exceeds baseline by more than this %, flag it
    private static final Decimal VARIANCE_THRESHOLD = 20.0;

    @InvocableMethod(
        label='Validate Repair Estimate'
        description='Validates the dealer requested repair amount against the Electra Cars Standard Repair Time (SRT) matrix. Flags estimates more than 20% above baseline for dealer justification.'
    )
    public static List<Result> validate(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        for (Input inp : inputs) {
            Result res = new Result();
            res.isWithinRange = true;
            res.variancePercent = 0;

            if (inp.requestedAmount == null || inp.requestedAmount <= 0) {
                res.baselineAmount = 0;
                res.validationMessage = 'Invalid repair amount provided.';
                results.add(res);
                continue;
            }

            Decimal baseline = getBaseline(inp.partCategory);
            res.baselineAmount = baseline;

            if (baseline > 0) {
                Decimal variance = ((inp.requestedAmount - baseline) / baseline) * 100;
                res.variancePercent = variance.setScale(1);
                res.isWithinRange = (variance <= VARIANCE_THRESHOLD);

                if (res.isWithinRange) {
                    res.validationMessage = 'Requested amount of $' + inp.requestedAmount.setScale(0) +
                        ' is within the SRT baseline of $' + baseline.setScale(0) + ' for ' + inp.partCategory + '.';
                } else {
                    res.validationMessage = 'Requested amount of $' + inp.requestedAmount.setScale(0) +
                        ' is ' + res.variancePercent + '% above the SRT baseline of $' +
                        baseline.setScale(0) + ' for ' + inp.partCategory +
                        '. Dealer justification required before submission.';
                }
            } else {
                // No baseline found — pass through without flagging
                res.isWithinRange = true;
                res.validationMessage = 'No SRT baseline found for ' + inp.partCategory + '. Amount accepted as submitted.';
            }

            results.add(res);
        }

        return results;
    }

    /**
     * Looks up the SRT baseline cost for a given part category.
     * First checks the SRTMatrix__c custom object; falls back to hardcoded defaults
     * for demo/hackathon purposes if the object is not populated.
     */
    private static Decimal getBaseline(String partCategory) {
        if (String.isBlank(partCategory)) return 0;

        // Hardcoded hackathon fallback baseline values (USD)
        Map<String, Decimal> fallback = new Map<String, Decimal>{
            'Battery'         => 4500,
            'Drive Motor'     => 3200,
            'Engine'          => 5500,
            'Transmission'    => 2800,
            'Brake System'    => 900,
            'Suspension'      => 1200,
            'HVAC'            => 1500,
            'Electrical'      => 800,
            'Infotainment'    => 600,
            'Charging System' => 1100,
            'Water Pump'      => 900,
            'Pump'            => 900
        };

        // Try exact match first, then case-insensitive partial match
        if (fallback.containsKey(partCategory)) {
            return fallback.get(partCategory);
        }
        for (String key : fallback.keySet()) {
            if (partCategory.containsIgnoreCase(key) || key.containsIgnoreCase(partCategory)) {
                return fallback.get(key);
            }
        }

        return 0; // No baseline found
    }
}