public with sharing class CoverageEvaluateInput {
    @InvocableVariable(required=true label='Vehicle Id' description='Salesforce Id of the Vehicle record to evaluate warranty coverage for.')
    public Id vehicleId;

    @InvocableVariable(required=true label='Odometer' description='Current odometer reading in miles from the dealer. Used to check mileage-based warranty limits.')
    public Integer odometer;

    @InvocableVariable(label='Part Category' description='Category of the part being claimed (e.g. Battery, Drive Motor, Pump). Used to check if the category is covered.')
    public String partCategory;
}