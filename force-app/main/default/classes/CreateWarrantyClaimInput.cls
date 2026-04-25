public with sharing class CreateWarrantyClaimInput {
    @InvocableVariable(required=true label='VIN' description='17-character Vehicle Identification Number.')
    public String vin;

    @InvocableVariable(label='Dealer Id' description='Salesforce Account Id of the dealership.')
    public Id dealerId;

    @InvocableVariable(label='Dealer Account Id' description='Alias for dealerId.')
    public Id dealerAccountId;

    @InvocableVariable(label='Customer Id' description='Salesforce Contact Id of the vehicle owner.')
    public Id customerId;

    @InvocableVariable(label='Odometer' description='Current odometer reading.')
    public Integer odometer;

    @InvocableVariable(label='Mileage At Failure' description='Alias for odometer at time of failure.')
    public Integer mileageAtFailure;

    @InvocableVariable(label='Part Id' description='Salesforce Id of a specific Part record.')
    public Id partId;

    @InvocableVariable(label='Causal Part Id' description='Alias for partId.')
    public Id causalPartId;

    @InvocableVariable(label='Part Category' description='Category of the part being claimed.')
    public String partCategory;

    @InvocableVariable(label='Symptom' description='Dealer-described fault or symptom.')
    public String symptom;

    @InvocableVariable(label='Symptom Text' description='Alias for symptom.')
    public String symptomText;

    @InvocableVariable(label='Summary' description='Brief summary of the claim.')
    public String summary;

    @InvocableVariable(label='Channel' description='WhatsApp | Web | SMS | Other.')
    public String channel;

    @InvocableVariable(label='Submission Channel' description='Alias for channel.')
    public String submissionChannel;

    @InvocableVariable(label='Dealer WhatsApp Number' description='WhatsApp number provided by the dealer.')
    public String dealerWhatsAppNumber;

    @InvocableVariable(label='Authorization Type' description='Type of warranty event.')
    public String authorizationType;

    @InvocableVariable(label='Priority' description='Claim priority: Normal or High.')
    public String priority;

    @InvocableVariable(label='Repair Order Number' description='Dealer DMS Repair Order number.')
    public String repairOrderNumber;

    @InvocableVariable(label='External DMS Reference' description='Optional external system reference number.')
    public String externalDmsReference;

    @InvocableVariable(label='Diagnostic Code Text' description='Direct text of a diagnostic code.')
    public String diagnosticCodeText;

    @InvocableVariable(label='Fault Code Id' description='Id of a specific CodeSet or FaultCode.')
    public Id faultCodeId;

    @InvocableVariable(label='Fault Date' description='The date the fault occurred.')
    public DateTime faultDate;

    @InvocableVariable(label='Repair Date' description='The date the repair was initiated.')
    public DateTime repairDate;

    @InvocableVariable(label='Requested Amount' description='Amount requested for reimbursement.')
    public Decimal requestedAmount;

    @InvocableVariable(label='Requested Quantity' description='Quantity being claimed.')
    public Decimal requestedQuantity;

    @InvocableVariable(label='Charge Type' description='Type of claim charge.')
    public String chargeType;

    @InvocableVariable(label='Approver Queue' description='Name of the Salesforce Queue.')
    public String approverQueue;

    @InvocableVariable(label='SRT Justification' description='Dealer provided justification for repair costs above SRT baseline.')
    public String srtJustification;
}