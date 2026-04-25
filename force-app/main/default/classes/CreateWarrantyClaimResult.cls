public with sharing class CreateWarrantyClaimResult {
    @InvocableVariable(label='Claim Id' description='Salesforce Id of the newly created Claim record.')
    public Id claimId;

    @InvocableVariable(label='Claim Number' description='Human-readable Claim number.')
    public String claimNumber;

    @InvocableVariable(label='Status' description='Initial status of the created Claim.')
    public String status;

    @InvocableVariable(label='Eligibility' description='Coverage eligibility result.')
    public String eligibility;

    @InvocableVariable(label='Rationale' description='Explanation for the coverage decision.')
    public String rationale;

    @InvocableVariable(label='SLA Due' description='Calculated SLA deadline.')
    public DateTime slaDue;

    @InvocableVariable(label='Claim Item Id' description='Id of the first ClaimItem created.')
    public Id claimItemId;

    @InvocableVariable(label='Claim Coverage Id' description='Id of the ClaimCoverage record.')
    public Id claimCoverageId;

    @InvocableVariable(label='Payment Detail Id' description='Id of the PaymentDetail record.')
    public Id paymentDetailId;

    @InvocableVariable(label='Vehicle Id' description='Id of the associated Vehicle (Asset).')
    public Id vehicleId;

    @InvocableVariable(label='Asset Warranty Id' description='Id of the associated AssetWarranty.')
    public Id assetWarrantyId;

    @InvocableVariable(label='Message' description='Success or error message.')
    public String message;

    @InvocableVariable(label='Slack Notification Sent' description='True if the Slack notification request was successfully issued.')
    public Boolean slackNotificationSent;
}