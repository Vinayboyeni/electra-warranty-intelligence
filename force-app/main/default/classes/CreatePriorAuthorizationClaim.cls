public with sharing class CreatePriorAuthorizationClaim {
    public class Request {
        @InvocableVariable(required=true)
        public String vin;

        @InvocableVariable
        public String dealerAccountId;

        @InvocableVariable
        public String summary;

        @InvocableVariable
        public String symptomText;

        @InvocableVariable
        public String diagnosticCodeText;

        @InvocableVariable
        public Datetime faultDate;

        @InvocableVariable
        public Datetime repairDate;

        @InvocableVariable
        public Decimal mileageAtFailure;

        @InvocableVariable
        public String submissionChannel;

        @InvocableVariable
        public String authorizationType;

        @InvocableVariable
        public String priority;

        @InvocableVariable
        public String repairOrderNumber;

        @InvocableVariable
        public String dealerWhatsAppNumber;

        @InvocableVariable
        public String externalDmsReference;

        @InvocableVariable
        public String causalPartId;

        @InvocableVariable
        public String faultCodeId;

        @InvocableVariable
        public Decimal requestedAmount;

        @InvocableVariable
        public Decimal requestedQuantity;

        @InvocableVariable
        public String chargeType;
    }

    public class Response {
        @InvocableVariable
        public Id claimId;

        @InvocableVariable
        public Id claimItemId;

        @InvocableVariable
        public Id claimCoverageId;

        @InvocableVariable
        public Id paymentDetailId;

        @InvocableVariable
        public Id vehicleId;

        @InvocableVariable
        public Id assetWarrantyId;

        @InvocableVariable
        public String status;

        @InvocableVariable
        public String message;
    }

    @InvocableMethod(label='Create Prior Authorization Claim' description='Creates a Claim, Claim Item, Claim Coverage, and optional payment detail for a warranty prior authorization request.')
    public static List<Response> createClaims(List<Request> requests) {
        List<Response> responses = new List<Response>();
        Set<String> vins = new Set<String>();
        for (Request request : requests) {
            vins.add(WarrantyClaimFlowSupport.normalizeVin(request.vin));
        }

        Map<String, WarrantyClaimFlowSupport.VehicleWarrantyContext> contextsByVin =
            WarrantyClaimFlowSupport.findVehicleWarrantyByVin(vins);

        Id priorAuthorizationRecordTypeId =
            WarrantyClaimFlowSupport.getRecordTypeId(Claim.SObjectType, 'Prior_Authorization');

        String claimStatus = WarrantyClaimFlowSupport.choosePicklistValue(
            Schema.SObjectType.Claim.fields.Status,
            new List<String>{ 'Draft', 'Submitted', 'Open', 'New' }
        );
        String claimType = WarrantyClaimFlowSupport.choosePicklistValue(
            Schema.SObjectType.Claim.fields.ClaimType,
            new List<String>{ 'Warranty', 'Claim', 'Service' }
        );
        String claimPriorityDefault = WarrantyClaimFlowSupport.choosePicklistValue(
            Schema.SObjectType.Claim.fields.Priority__c,
            new List<String>{ 'Medium', 'High', 'Low' }
        );
        String claimItemUom = WarrantyClaimFlowSupport.choosePicklistValue(
            Schema.SObjectType.ClaimItem.fields.AssetUsageUnitOfMeasure,
            new List<String>{ 'Kilometers', 'Miles' }
        );
        String claimCoverageStatus = WarrantyClaimFlowSupport.choosePicklistValue(
            Schema.SObjectType.ClaimCoverage.fields.Status,
            new List<String>{ 'Submitted', 'Open', 'Draft' }
        );
        String claimCoverageReserveMode = WarrantyClaimFlowSupport.choosePicklistValue(
            Schema.SObjectType.ClaimCoverage.fields.InternalReserveMode,
            new List<String>{ 'CoverageReserve', 'ReserveWorksheet' }
        );
        String coverageType = WarrantyClaimFlowSupport.choosePicklistValue(
            Schema.SObjectType.ClaimCoverage.fields.CoverageType,
            new List<String>{ 'Parts', 'Labor', 'Expense' }
        );
        String paymentStatus = WarrantyClaimFlowSupport.choosePicklistValue(
            Schema.SObjectType.ClaimCoveragePaymentDetail.fields.Status,
            new List<String>{ 'Submitted', 'Open', 'Draft' }
        );
        String paymentChargeTypeDefault = WarrantyClaimFlowSupport.choosePicklistValue(
            Schema.SObjectType.ClaimCoveragePaymentDetail.fields.ChargeType,
            new List<String>{ 'Replaced Part', 'Labor', 'Other' }
        );

        for (Request request : requests) {
            Response response = new Response();
            String normalizedVin = WarrantyClaimFlowSupport.normalizeVin(request.vin);
            WarrantyClaimFlowSupport.VehicleWarrantyContext context = contextsByVin.get(normalizedVin);
            Id dealerAccountId = String.isNotBlank(request.dealerAccountId) ? Id.valueOf(request.dealerAccountId) : null;
            Id causalPartId = String.isNotBlank(request.causalPartId) ? Id.valueOf(request.causalPartId) : null;
            Id faultCodeId = String.isNotBlank(request.faultCodeId) ? Id.valueOf(request.faultCodeId) : null;

            if (context == null || context.vehicle == null) {
                response.status = 'Failed';
                response.message = 'Unable to create claim because no vehicle was found for VIN ' + normalizedVin + '.';
                responses.add(response);
                continue;
            }

            Claim claim = new Claim();
            claim.Name = WarrantyClaimFlowSupport.buildClaimName(
                String.isBlank(request.authorizationType) ? 'Prior Authorization' : request.authorizationType,
                normalizedVin
            );
            claim.RecordTypeId = priorAuthorizationRecordTypeId;
            claim.AccountId = dealerAccountId;
            claim.ProductId = context.asset != null ? context.asset.Product2Id : null;
            claim.ReportDate = System.now();
            claim.InitiationDate = System.now();
            claim.ClaimLossDate = request.faultDate != null ? request.faultDate.date() : null;
            claim.Summary = request.summary;
            claim.ClaimReason = String.isNotBlank(request.summary) ? request.summary : 'Warranty prior authorization request';
            claim.ClaimType = claimType;
            claim.Status = claimStatus;
            claim.Submission_Channel__c = WarrantyClaimFlowSupport.choosePicklistValue(
                Schema.SObjectType.Claim.fields.Submission_Channel__c,
                new List<String>{ request.submissionChannel, 'Web Chat' }
            );
            claim.Authorization_Type__c = WarrantyClaimFlowSupport.choosePicklistValue(
                Schema.SObjectType.Claim.fields.Authorization_Type__c,
                new List<String>{ request.authorizationType, 'Prior Authorization' }
            );
            claim.Priority__c = WarrantyClaimFlowSupport.choosePicklistValue(
                Schema.SObjectType.Claim.fields.Priority__c,
                new List<String>{ request.priority, claimPriorityDefault }
            );
            claim.Repair_Order_Number__c = request.repairOrderNumber;
            claim.Dealer_WhatsApp_Number__c = request.dealerWhatsAppNumber;
            claim.External_DMS_Reference__c = request.externalDmsReference;
            claim.AI_Recommendation__c = WarrantyClaimFlowSupport.choosePicklistValue(
                Schema.SObjectType.Claim.fields.AI_Recommendation__c,
                new List<String>{ 'Needs Clarification' }
            );
            claim.Missing_Info_Flag__c = String.isBlank(request.summary) || request.faultDate == null;
            claim.Requires_Follow_Up__c = claim.Missing_Info_Flag__c;

            insert claim;

            ClaimItem claimItem = new ClaimItem();
            claimItem.Name = 'Primary Failure';
            claimItem.ClaimId = claim.Id;
            claimItem.VehicleId = context.vehicle.Id;
            claimItem.AssetId = context.vehicle.AssetId;
            claimItem.ProductId = causalPartId;
            claimItem.FaultDate = request.faultDate;
            claimItem.RepairDate = request.repairDate;
            claimItem.Description = request.summary;
            claimItem.Symptom_Text__c = request.symptomText;
            claimItem.Diagnostic_Code_Text__c = request.diagnosticCodeText;
            claimItem.Mileage_At_Failure__c = request.mileageAtFailure;
            if (request.mileageAtFailure != null) {
                claimItem.AssetUsageValue = request.mileageAtFailure.intValue();
                claimItem.AssetUsageUnitOfMeasure = claimItemUom;
            }

            insert claimItem;

            ClaimCoverage claimCoverage = new ClaimCoverage();
            claimCoverage.Name = 'Primary Coverage';
            claimCoverage.ClaimId = claim.Id;
            claimCoverage.ClaimItemId = claimItem.Id;
            claimCoverage.AssetWarrantyId = context.activeWarranty != null ? context.activeWarranty.Id : null;
            claimCoverage.CausalPartId = causalPartId;
            claimCoverage.FaultCodeId = faultCodeId;
            claimCoverage.Description = request.summary;
            claimCoverage.CoverageType = coverageType;
            claimCoverage.InternalReserveMode = claimCoverageReserveMode;
            claimCoverage.Status = claimCoverageStatus;
            claimCoverage.Coverage_Decision__c = WarrantyClaimFlowSupport.choosePicklistValue(
                Schema.SObjectType.ClaimCoverage.fields.Coverage_Decision__c,
                new List<String>{ context.activeWarranty != null ? 'Needs Review' : 'Not Covered' }
            );
            claimCoverage.Policy_Match_Type__c = WarrantyClaimFlowSupport.choosePicklistValue(
                Schema.SObjectType.ClaimCoverage.fields.Policy_Match_Type__c,
                new List<String>{ context.activeWarranty != null ? 'Rule Based Match' : 'No Match' }
            );
            claimCoverage.Coverage_Decision_Reason__c = context.activeWarranty != null
                ? 'Active asset warranty found. Awaiting approver review.'
                : 'No active asset warranty matched the current date.';

            insert claimCoverage;

            Id paymentDetailId;
            if (request.requestedAmount != null || request.requestedQuantity != null || causalPartId != null) {
                String requestedChargeType = request.chargeType;
                if (requestedChargeType == 'Parts' || requestedChargeType == 'Part') {
                    requestedChargeType = 'Replaced Part';
                }

                ClaimCoveragePaymentDetail paymentDetail = new ClaimCoveragePaymentDetail();
                paymentDetail.Name = 'Requested Charge';
                paymentDetail.ClaimCoverageId = claimCoverage.Id;
                paymentDetail.ClaimedAmount = request.requestedAmount;
                paymentDetail.Requested_Amount__c = request.requestedAmount;
                paymentDetail.Quantity = request.requestedQuantity != null ? request.requestedQuantity.intValue() : null;
                paymentDetail.Requested_Qty__c = request.requestedQuantity;
                paymentDetail.Status = paymentStatus;
                paymentDetail.ChargeType = WarrantyClaimFlowSupport.choosePicklistValue(
                    Schema.SObjectType.ClaimCoveragePaymentDetail.fields.ChargeType,
                    new List<String>{ requestedChargeType, paymentChargeTypeDefault }
                );
                paymentDetail.ReplacementPartId = causalPartId;
                paymentDetail.Description = request.summary;
                insert paymentDetail;
                paymentDetailId = paymentDetail.Id;
            }

            response.claimId = claim.Id;
            response.claimItemId = claimItem.Id;
            response.claimCoverageId = claimCoverage.Id;
            response.paymentDetailId = paymentDetailId;
            response.vehicleId = context.vehicle.Id;
            response.assetWarrantyId = context.activeWarranty != null ? context.activeWarranty.Id : null;
            response.status = 'Created';
            response.message = 'Prior authorization claim created successfully.';
            responses.add(response);
        }

        return responses;
    }
}