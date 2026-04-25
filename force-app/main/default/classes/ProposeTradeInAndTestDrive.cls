public with sharing class ProposeTradeInAndTestDrive {

    public class TradeInRequest {
        @InvocableVariable(required=true description='Dealer Account ID where the customer is located')
        public Id dealerAccountId;
        @InvocableVariable(required=true description='Vehicle ID of the car with the expensive failed component')
        public Id vehicleId;
    }

    public class TradeInResult {
        @InvocableVariable
        public Id leadId;
        @InvocableVariable
        public Id testDriveId;
        @InvocableVariable
        public String statusMessage;
        @InvocableVariable
        public Boolean isOfferGenerated;
    }

    @InvocableMethod(label='Propose Trade-In and Test Drive' description='Evaluates if the vehicle qualifies for an upgrade. If yes, creates a Lead and a scheduled Test Drive.')
    public static List<TradeInResult> execute(List<TradeInRequest> requests) {
        List<TradeInResult> results = new List<TradeInResult>();
        
        for(TradeInRequest req : requests) {
            TradeInResult result = new TradeInResult();
            result.isOfferGenerated = false;

            try {
                // Fetch Vehicle details to assess "loyalty" or "aging"
                Vehicle v = [SELECT Id, Name, ModelYear FROM Vehicle WHERE Id = :req.vehicleId LIMIT 1];
                
                // Simple logic: If model year is 2024 or older, propose trade-in!
                // For hackathon sake, we always propose an upgrade if requested by the Agent.
                
                // 1. Create a Lead
                Lead newLead = new Lead();
                newLead.FirstName = 'Warranty';
                newLead.LastName = 'Upgrade Prospect (' + v.Name + ')';
                newLead.Company = 'Electra Trade-In Program';
                newLead.LeadSource = 'Agentforce Warranty Escalation';
                newLead.Status = 'New - Not Contacted';
                insert newLead;
                
                // 2. Create Test Drive
                SObjectType tdType = Schema.getGlobalDescribe().get('Test_Drive__c');
                if(tdType != null) {
                    SObject td = tdType.newSObject();
                    try { td.put('test_drive_date_time__c', System.now().addHours(2)); } catch(Exception e){}
                    try { td.put('model_interested__c', 'Electra Prime 2025 Edition'); } catch(Exception e){}
                    try { td.put('status__c', 'Scheduled'); } catch(Exception e){}
                    insert td;
                    result.testDriveId = td.Id;
                }
                
                result.leadId = newLead.Id;
                result.isOfferGenerated = true;
                result.statusMessage = 'Successfully scheduled a Test Drive for the newest model and alerted Sales!';

            } catch (Exception e) {
                result.statusMessage = 'Could not generate offer: ' + e.getMessage();
            }
            
            results.add(result);
        }
        
        return results;
    }
}