public with sharing class FindVehicleByVinInput {
    @InvocableVariable(required=true label='VIN' description='17-character Vehicle Identification Number used to locate the Vehicle record in Salesforce.')
    public String vin;
}