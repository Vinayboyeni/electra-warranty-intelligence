public with sharing class CoverageEvaluateResult {
    @InvocableVariable(label='Eligibility' description='Coverage eligibility verdict: Likely (covered), Borderline (needs review), or Not Covered.')
    public String eligibility; // Likely | Borderline | Not Covered

    @InvocableVariable(label='Risk Flags' description='List of risk factors that may disqualify or complicate the claim (e.g. Outside coverage dates, Mileage exceeded).')
    public List<String> riskFlags;

    @InvocableVariable(label='Rationale' description='Human-readable explanation of the coverage decision, including coverage dates and odometer context.')
    public String rationale;

    @InvocableVariable(label='Coverage Id' description='Salesforce Id of the matched AssetWarranty record used for the evaluation.')
    public Id coverageId;
}