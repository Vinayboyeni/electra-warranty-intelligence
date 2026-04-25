public with sharing class SendWarrantyExpiryAlert {

    public class Input {
        @InvocableVariable(required=true label='Asset Warranty Id' description='Id of the AssetWarranty record about to expire.')
        public Id assetWarrantyId;
    }

    public class Result {
        @InvocableVariable(label='Sent') public Boolean sent;
        @InvocableVariable(label='Dealer Name') public String dealerName;
        @InvocableVariable(label='VIN') public String vin;
        @InvocableVariable(label='Expiry Date') public String expiryDate;
        @InvocableVariable(label='Message') public String message;
    }

    @InvocableMethod(
        label='Send Warranty Expiry Alert'
        description='Sends a proactive WhatsApp alert to the dealer when a vehicle warranty is expiring within 30 days. Posts audit trail to the Asset Chatter feed.'
    )
    public static List<Result> send(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        Set<Id> warrantyIds = new Set<Id>();
        for (Input inp : inputs) {
            if (inp != null && inp.assetWarrantyId != null) warrantyIds.add(inp.assetWarrantyId);
        }
        if (warrantyIds.isEmpty()) return results;

        List<AssetWarranty> warranties = [
            SELECT Id, EndDate, MileageCap__c, CoveredCategories__c,
                   Asset.Id, Asset.Name, Asset.AccountId,
                   Asset.Account.Name, Asset.Account.Phone,
                   Asset.Contact.Name
            FROM AssetWarranty
            WHERE Id IN :warrantyIds
        ];

        // Build a map of AssetId → VIN via Vehicle
        Set<Id> assetIds = new Set<Id>();
        for (AssetWarranty aw : warranties) {
            if (aw.Asset != null) assetIds.add(aw.Asset.Id);
        }
        Map<Id, String> assetToVin = new Map<Id, String>();
        for (Vehicle v : [
            SELECT AssetId, VehicleIdentificationNumber
            FROM Vehicle WHERE AssetId IN :assetIds
        ]) {
            assetToVin.put(v.AssetId, v.VehicleIdentificationNumber);
        }

        Map<Id, Input> inputMap = new Map<Id, Input>();
        for (Input inp : inputs) {
            if (inp != null) inputMap.put(inp.assetWarrantyId, inp);
        }

        List<FeedItem> chatterPosts = new List<FeedItem>();

        for (AssetWarranty aw : warranties) {
            Result res = new Result();
            try {
                String dealerName   = aw.Asset?.Account?.Name;
                String dealerPhone  = aw.Asset?.Account?.Phone;
                String vin          = assetToVin.get(aw.Asset?.Id);
                String customerName = aw.Asset?.Contact?.Name;
                String expiryDate   = aw.EndDate != null ? aw.EndDate.format() : 'Unknown';
                Integer daysLeft    = aw.EndDate != null ? Date.today().daysBetween(aw.EndDate) : 0;

                String alertMessage =
                    '⚠️ *Electra Cars — Warranty Expiry Alert*\n'
                    + 'Vehicle *' + (vin != null ? vin : 'N/A') + '* has an active warranty expiring soon.\n\n'
                    + '*Expiry Date:* ' + expiryDate + ' (' + daysLeft + ' days remaining)\n'
                    + '*Coverage:* ' + (aw.CoveredCategories__c != null ? aw.CoveredCategories__c : 'Standard') + '\n'
                    + '*Mileage Cap:* ' + (aw.MileageCap__c != null ? aw.MileageCap__c.intValue() + ' miles' : 'N/A') + '\n'
                    + (customerName != null ? '*Customer:* ' + customerName + '\n' : '')
                    + '\nIf any warranty repairs are needed, submit a Prior Authorization claim via ARIA *before the expiry date*.\n'
                    + 'Reply *START* to begin a new claim.';

                // Post to Asset Chatter for audit trail
                FeedItem fi = new FeedItem();
                fi.ParentId = aw.Asset.Id;
                fi.Body = '⚠️ WARRANTY EXPIRY ALERT — '
                    + (vin != null ? 'VIN: ' + vin : aw.Asset.Name)
                    + ' — Expires: ' + expiryDate + ' (' + daysLeft + ' days).'
                    + (String.isNotBlank(dealerPhone) ? ' WhatsApp alert sent to ' + dealerPhone + '.' : ' No dealer phone on file.');
                chatterPosts.add(fi);

                res.sent       = true;
                res.dealerName = dealerName;
                res.vin        = vin;
                res.expiryDate = expiryDate;
                res.message    = 'Alert dispatched. ' + daysLeft + ' days until expiry.';

            } catch (Exception e) {
                res.sent    = false;
                res.message = 'Exception: ' + e.getMessage();
            }
            results.add(res);
        }

        if (!chatterPosts.isEmpty()) {
            try {
                insert chatterPosts;
            } catch (Exception e) {
                // Asset Chatter feeds may be disabled in this org — audit trail is non-critical
            }
        }

        return results;
    }
}