public with sharing class FindVehicleWarrantyByVin {
    public class Request {
        @InvocableVariable(required=true)
        public String vin;
    }

    public class Response {
        @InvocableVariable
        public Id vehicleId;

        @InvocableVariable
        public Id assetId;

        @InvocableVariable
        public Id assetWarrantyId;

        @InvocableVariable
        public Id ownerAccountId;

        @InvocableVariable
        public Boolean vehicleFound;

        @InvocableVariable
        public Boolean activeWarrantyFound;

        @InvocableVariable
        public String message;
    }

    @InvocableMethod(label='Find Vehicle and Warranty by VIN' description='Locates the Automotive Cloud vehicle, asset, and active asset warranty for a VIN.')
    public static List<Response> find(List<Request> requests) {
        Set<String> vins = new Set<String>();
        for (Request request : requests) {
            vins.add(WarrantyClaimFlowSupport.normalizeVin(request.vin));
        }

        Map<String, WarrantyClaimFlowSupport.VehicleWarrantyContext> contextsByVin =
            WarrantyClaimFlowSupport.findVehicleWarrantyByVin(vins);

        List<Response> responses = new List<Response>();
        for (Request request : requests) {
            String normalizedVin = WarrantyClaimFlowSupport.normalizeVin(request.vin);
            WarrantyClaimFlowSupport.VehicleWarrantyContext context = contextsByVin.get(normalizedVin);
            Response response = new Response();

            if (context == null || context.vehicle == null) {
                response.vehicleFound = false;
                response.activeWarrantyFound = false;
                response.message = 'No vehicle was found for VIN ' + normalizedVin + '.';
            } else {
                response.vehicleId = context.vehicle.Id;
                response.assetId = context.vehicle.AssetId;
                response.ownerAccountId = context.vehicle.CurrentOwnerId != null
                    ? context.vehicle.CurrentOwnerId
                    : (context.asset != null ? context.asset.AccountId : null);
                response.assetWarrantyId = context.activeWarranty != null ? context.activeWarranty.Id : null;
                response.vehicleFound = true;
                response.activeWarrantyFound = context.activeWarranty != null;
                response.message = context.activeWarranty != null
                    ? 'Vehicle and active warranty found.'
                    : 'Vehicle found, but no active asset warranty matched the current date.';
            }

            responses.add(response);
        }

        return responses;
    }
}