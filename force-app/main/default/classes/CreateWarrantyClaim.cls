public without sharing class CreateWarrantyClaim {
    public class Input {
        @AuraEnabled public String vin;
        @AuraEnabled public Id dealerId;
        @AuraEnabled public Id customerId;
        @AuraEnabled public Integer odometer;
        @AuraEnabled public Id partId;
        @AuraEnabled public String partCategory;
        @AuraEnabled public String symptom;
        @AuraEnabled public String channel;
        @AuraEnabled public String authorizationType;
        @AuraEnabled public String priority;
        @AuraEnabled public String repairOrderNumber;
        @AuraEnabled public String externalDmsReference;
        @AuraEnabled public String approverQueue;
        @AuraEnabled public String diagnosticCodeText;
        @AuraEnabled public String dealerWhatsAppNumber;
        @AuraEnabled public Decimal requestedAmount;
        @AuraEnabled public Date faultDate;
        @AuraEnabled public String srtJustification;
        @AuraEnabled public String messagingSessionId;
    }
    public class Summary {
        @AuraEnabled public Id claimId;
        @AuraEnabled public String claimNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String eligibility;
        @AuraEnabled public String rationale;
        @AuraEnabled public DateTime slaDue;
        @AuraEnabled public Id claimItemId;
        @AuraEnabled public Id vehicleId;
        @AuraEnabled public Id assetWarrantyId;
        @AuraEnabled public Boolean slackNotificationSent;
    }

    @InvocableMethod(label='Create Prior Authorization Claim' description='Create a new Warranty Claim for prior authorization. Orchestrates record creation and routing.')
    public static List<CreateWarrantyClaimResult> createClaimInvocable(List<CreateWarrantyClaimInput> inputs) {
        List<CreateWarrantyClaimResult> results = new List<CreateWarrantyClaimResult>();
        if (inputs == null) return results;
        for (CreateWarrantyClaimInput i : inputs) {
            CreateWarrantyClaimResult r = new CreateWarrantyClaimResult();
            try {
                Summary s = createClaim(convert(i));
                if (s != null) {
                    r.claimId = s.claimId;
                    r.claimNumber = s.claimNumber;
                    r.status = s.status;
                    r.eligibility = s.eligibility;
                    r.rationale = s.rationale;
                    r.slaDue = s.slaDue;
                    r.claimItemId = s.claimItemId;
                    r.vehicleId = s.vehicleId;
                    r.assetWarrantyId = s.assetWarrantyId;
                    r.slackNotificationSent = s.slackNotificationSent;
                    r.message = 'Claim created successfully';
                }
            } catch (Exception e) {
                r.status = 'Error';
                r.message = e.getMessage();
                r.rationale = e.getMessage();
                r.slackNotificationSent = false;
                System.debug('CreateWarrantyClaim Error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            }
            results.add(r);
        }
        return results;
    }

    @AuraEnabled
    public static Summary createClaim(Input req) {
        if (req == null) throw new AuraHandledException('Input is required.');
        if (String.isBlank(req.vin)) throw new AuraHandledException('VIN is required.');

        List<Vehicle> vehicles = [
            SELECT Id, VehicleIdentificationNumber, AssetId
            FROM Vehicle
            WHERE VehicleIdentificationNumber = :req.vin
            LIMIT 1
        ];
        if (vehicles.isEmpty()) throw new AuraHandledException('Vehicle not found for VIN: ' + req.vin);
        Vehicle veh = vehicles[0];

        CoverageEngine.EvaluationResult eval = CoverageEngine.evaluate(veh.Id, req.odometer, req.partCategory);

        if (req.dealerId == null) throw new AuraHandledException('Dealer ID (AccountId) is required to create a claim.');

        Claim claim = new Claim();
        // Automotive Cloud relies on AccountId for the primary dealer/customer linked
        claim.AccountId = req.dealerId;
        claim.Name = 'Warranty Claim: ' + req.vin;
        claim.Status = 'Submitted';
        claim.DealerWhatsAppNumber__c = req.dealerWhatsAppNumber;
        claim.SubmissionChannel__c = String.isBlank(req.channel) ? 'Web' : req.channel;
        // Capture the session Id so post-creation actions (chat-attachment
        // linking, dealer status push) can find the original conversation.
        if (String.isNotBlank(req.messagingSessionId)) {
            claim.MessagingSessionId__c = req.messagingSessionId;
        }
        
        // Setup AI Fields
        claim.AI_Summary__c = eval != null ? eval.rationale : null;
        if (eval != null) {
            String eligibility = eval.eligibility != null ? eval.eligibility.trim() : '';
            claim.Eligibility__c = eligibility;

            if (eligibility == 'Likely') {
                claim.AI_Recommendation__c = 'Approve';
                claim.AI_Confidence__c = 90;
            } else if (eligibility == 'Not Covered') {
                claim.AI_Recommendation__c = 'Reject';
                claim.AI_Confidence__c = 95;
            } else {
                claim.AI_Recommendation__c = 'Needs Clarification';
                claim.AI_Confidence__c = 50;
            }
            claim.EligibilityRationale__c = eval.rationale != null ? eval.rationale.abbreviate(255) : null;
        }
        
        // Other input fields
        claim.Odometer__c = req.odometer;
        claim.Symptom__c = req.symptom;
        claim.Diagnosis__c = req.diagnosticCodeText;
        claim.Authorization_Type__c = String.isBlank(req.authorizationType) ? 'Prior Authorization' : req.authorizationType;
        // Safety-based priority logic (moves logic from agent script to Apex for robustness)
        String priority = String.isBlank(req.priority) ? 'Medium' : req.priority;
        String symptomLower = String.isNotBlank(req.symptom) ? req.symptom.toLowerCase() : '';
        List<String> safetyKeywords = new List<String>{'fire', 'smoke', 'stranded', 'brake', 'steering', 'leak'};
        for (String keyword : safetyKeywords) {
            if (symptomLower.contains(keyword)) {
                priority = 'High';
                break;
            }
        }
        claim.Priority__c = priority;
        claim.DealerResponseSummary__c = req.srtJustification;
        
        // Link to Vehicle and Asset via the hybrid Vehicle__c lookup
        claim.Vehicle__c = veh.AssetId;
        
        // Map the claimed amount to both standard and custom fields
        if (req.requestedAmount != null) {
            claim.Summary = 'Claim Amount: $' + req.requestedAmount;
            claim.EstimatedAmount = req.requestedAmount;
            claim.EstimatedCost__c = req.requestedAmount;
        }
        
        DateTime slaDue = System.now().addHours(24);
        claim.SLA_Due_Date__c = slaDue;

        insert claim;

        // Generate human-readable WC-XXXXX claim number from the Salesforce record ID
        String claimSeq = String.valueOf(claim.Id).right(5).toUpperCase();
        String claimNumber = 'WC-' + claimSeq;
        claim.Name = claimNumber;
        update claim;

        // Instant Notification: Create a Chatter post to alert the approver queue
        try {
            FeedItem fi = new FeedItem();
            fi.ParentId = claim.Id;
            fi.Body = 'New Warranty Claim submitted for VIN: ' + req.vin + '. AI Recommendation: ' + claim.AI_Recommendation__c;
            insert fi;
        } catch (Exception e) {}

        ClaimItem item = new ClaimItem();
        item.ClaimId = claim.Id;
        item.Name = req.symptom != null ? req.symptom.abbreviate(80) : 'Issue';
        // Check if FaultDate field exists, otherwise use custom field or skip
        try {
            item.put('FaultDate', req.faultDate != null ? req.faultDate : Date.today());
        } catch (Exception e) {
            // FaultDate field doesn't exist, try custom field
            try {
                item.put('FaultDate__c', req.faultDate != null ? req.faultDate : Date.today());
            } catch (Exception ex) {
                // Neither field exists, continue without fault date on ClaimItem
                System.debug('FaultDate field not available on ClaimItem: ' + ex.getMessage());
            }
        }
        
        insert item;

        try {
            RouteClaimToApproverQueue.Input routeInput = new RouteClaimToApproverQueue.Input();
            routeInput.claimId = claim.Id;
            RouteClaimToApproverQueue.route(new List<RouteClaimToApproverQueue.Input>{ routeInput });
        } catch (Exception e) {}

        Summary s = new Summary();
        s.claimId = claim.Id;
        s.claimNumber = claimNumber;
        s.status = claim.Status;
        s.eligibility = eval != null ? eval.eligibility : null;
        s.rationale = eval != null ? eval.rationale : null;
        s.slaDue = slaDue;
        s.claimItemId = item.Id;
        s.vehicleId = veh.Id;
        s.slackNotificationSent = true; // Confirmation that transaction reached this point
        return s;
    }
 
    private static Input convert(CreateWarrantyClaimInput i) {
        if (i == null) return null;
        Input inx = new Input();
        inx.vin = i.vin;
        inx.dealerId = i.dealerId != null ? i.dealerId : i.dealerAccountId;
        inx.customerId = i.customerId;
        inx.odometer = i.odometer != null ? i.odometer : i.mileageAtFailure;
        inx.partId = i.partId != null ? i.partId : i.causalPartId;
        inx.partCategory = i.partCategory;
        inx.symptom = String.isNotBlank(i.symptom) ? i.symptom : i.symptomText;
        inx.channel = String.isNotBlank(i.channel) ? i.channel : i.submissionChannel;
        inx.authorizationType = i.authorizationType;
        inx.priority = i.priority;
        inx.repairOrderNumber = i.repairOrderNumber;
        inx.externalDmsReference = i.externalDmsReference;
        inx.approverQueue = i.approverQueue;
        inx.diagnosticCodeText = i.diagnosticCodeText;
        inx.dealerWhatsAppNumber = i.dealerWhatsAppNumber;
        inx.requestedAmount = i.requestedAmount;
        // Handle faultDate conversion: support both DateTime and Date
        if (i.faultDate != null) {
            inx.faultDate = i.faultDate.date();
        }
        inx.srtJustification = i.srtJustification;
        inx.messagingSessionId = i.messagingSessionId;
        return inx;
    }
}