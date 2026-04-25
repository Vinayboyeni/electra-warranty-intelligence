public with sharing class FindVehicleByVinResult {
    @InvocableVariable(label='Vehicle Id' description='Salesforce Id of the matched Vehicle record.')
    public Id vehicleId;

    @InvocableVariable(label='Asset Warranty Id' description='Alias for coverageId.')
    public Id assetWarrantyId;

    @InvocableVariable(label='VIN' description='Confirmed VIN.')
    public String vin;

    @InvocableVariable(label='Vehicle Model' description='Vehicle model name.')
    public String vehicleModel;

    @InvocableVariable(label='Year' description='Model year.')
    public Integer year;

    @InvocableVariable(label='Customer Id' description='Salesforce Contact Id of the owner.')
    public Id customerId;

    @InvocableVariable(label='Dealer Id' description='Salesforce Account Id.')
    public Id dealerId;

    @InvocableVariable(label='Coverage Id' description='Id of the active AssetWarranty.')
    public Id coverageId;

    @InvocableVariable(label='Vehicle Found' description='True if a vehicle was located for the provided VIN.')
    public Boolean vehicleFound;

    @InvocableVariable(label='Active Warranty Found' description='True if an active warranty was found.')
    public Boolean activeWarrantyFound;

    @InvocableVariable(label='Message' description='Success or error message.')
    public String message;

    @InvocableVariable(label='Coverage Start Date' description='Start date of coverage.')
    public Date coverageStartDate;

    @InvocableVariable(label='Coverage End Date' description='Expiration date.')
    public Date coverageEndDate;

    @InvocableVariable(label='Coverage Mileage Cap' description='Maximum mileage.')
    public Integer coverageMileageCap;

    @InvocableVariable(label='Coverage Categories' description='Covered part categories.')
    public String coverageCategories;

    @InvocableVariable(label='Last Claim Id' description='Id of the most recent Claim.')
    public Id lastClaimId;

    @InvocableVariable(label='Last Claim Number' description='Human-readable number.')
    public String lastClaimNumber;

    @InvocableVariable(label='Last Claim Status' description='Status of the most recent Claim.')
    public String lastClaimStatus;

    @InvocableVariable(label='Last Claim Submitted Date' description='Submission date.')
    public DateTime lastClaimSubmittedDate;

    @InvocableVariable(label='Last Claim Part Category' description='Part category.')
    public String lastClaimPartCategory;

    @InvocableVariable(label='Last Claim Part Id' description='Part record Id.')
    public Id lastClaimPartId;
}