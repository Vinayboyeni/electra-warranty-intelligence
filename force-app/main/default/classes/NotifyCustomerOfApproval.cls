/**
 * NotifyCustomerOfApproval
 *
 * Sends the end customer (vehicle owner) a WhatsApp message with their
 * warranty approval + a link to the authorization PDF.
 *
 * Called from ApproveWarrantyClaim after the dealer WhatsApp fires, so
 * the customer gets notified at the very end of the happy path.
 *
 * Uses the same three-tier delivery pattern as SendWhatsAppClaimDecision:
 *   Tier 1: push through an active MessagingSession to the customer
 *   Tier 2: Chatter FeedItem audit on the Claim (always writes)
 *
 * Never throws — any failure is swallowed so approval cannot roll back.
 *
 * Customer relationship resolves via:
 *   Claim.Vehicle__c (Asset Id) → Asset.Contact → Contact.MobilePhone
 */
public without sharing class NotifyCustomerOfApproval {

    public static void send(Id claimId, String pdfUrl) {
        if (claimId == null) return;

        try {
            List<Claim> claims = [
                SELECT Id, Name, ApprovalDate__c, PartCategory__c,
                       AuthorizationPdfUrl__c,
                       Vehicle__c, Vehicle__r.Name,
                       Account.Name
                FROM Claim
                WHERE Id = :claimId
                LIMIT 1
            ];
            if (claims.isEmpty()) return;
            Claim c = claims[0];

            // Prefer the stored PDF URL; fall back to what the caller passed.
            String pdfLink = String.isNotBlank(c.AuthorizationPdfUrl__c)
                ? c.AuthorizationPdfUrl__c
                : pdfUrl;

            // Resolve customer Contact + phone via Vehicle → Asset chain.
            String customerName  = null;
            String customerPhone = null;
            String vin = null;
            if (c.Vehicle__c != null) {
                List<Vehicle> vList = [
                    SELECT Id, VehicleIdentificationNumber,
                           Asset.ContactId,
                           Asset.Contact.Name,
                           Asset.Contact.MobilePhone,
                           Asset.Contact.Phone
                    FROM Vehicle
                    WHERE AssetId = :c.Vehicle__c
                    LIMIT 1
                ];
                if (!vList.isEmpty()) {
                    vin = vList[0].VehicleIdentificationNumber;
                    if (vList[0].Asset != null && vList[0].Asset.Contact != null) {
                        customerName  = vList[0].Asset.Contact.Name;
                        customerPhone = !String.isBlank(vList[0].Asset.Contact.MobilePhone)
                            ? vList[0].Asset.Contact.MobilePhone
                            : vList[0].Asset.Contact.Phone;
                    }
                }
            }

            String body = buildBody(c, customerName, vin, pdfLink);

            // Tier 1: try pushing to an active MessagingSession for this phone.
            Boolean pushed = false;
            Id sessionId = findActiveSession(customerPhone);
            if (sessionId != null && !Test.isRunningTest()) {
                pushed = tryStandardSendMessage(sessionId, body);
            }

            // Tier 2: always write a Chatter audit so the demo shows what
            // would have been sent even if the customer doesn't have an
            // active messaging session.
            FeedItem fi = new FeedItem(
                ParentId = c.Id,
                Body = (pushed
                    ? '📱 WhatsApp sent to customer (' + (customerPhone != null ? customerPhone : 'no phone') + '):\n'
                    : '📱 Customer WhatsApp audit (will deliver once customer opens chat'
                        + (customerPhone != null ? ', phone: ' + customerPhone : ', no phone on Contact')
                        + '):\n'
                ) + body
            );
            insert fi;
        } catch (Exception e) {
            System.debug('NotifyCustomerOfApproval swallowed: '
                + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    private static String buildBody(Claim c, String customerName, String vin, String pdfLink) {
        String name = String.isNotBlank(customerName) ? customerName : 'there';
        String vehicle = (c.Vehicle__r != null && c.Vehicle__r.Name != null)
            ? c.Vehicle__r.Name : 'your Electra vehicle';
        String dealer = (c.Account != null && c.Account.Name != null)
            ? c.Account.Name : 'your authorized Electra dealer';

        String body = '✅ *Warranty claim approved*\n\n'
            + 'Hi ' + name + ', good news — the warranty request for your ' + vehicle
            + (String.isNotBlank(vin) ? ' (VIN ' + vin + ')' : '') + ' has been approved.\n\n'
            + '*Claim:* ' + c.Name + '\n'
            + '*Repair category:* ' + (c.PartCategory__c != null ? c.PartCategory__c : '—') + '\n'
            + '*Servicing dealer:* ' + dealer + '\n';
        if (String.isNotBlank(pdfLink)) {
            body += '\n📄 *Authorization document:* ' + pdfLink
                + '\n(Valid 30 days. Share with your dealer when scheduling.)';
        }
        body += '\n\nYour dealer will contact you to schedule the repair. '
            + 'Questions? Reply here or call 1-800-ELECTRA and quote claim ' + c.Name + '.';
        return body;
    }

    private static Id findActiveSession(String phone) {
        if (String.isBlank(phone)) return null;
        try {
            List<MessagingEndUser> endUsers = [
                SELECT Id FROM MessagingEndUser WHERE Name = :phone LIMIT 1
            ];
            if (endUsers.isEmpty()) return null;
            List<MessagingSession> sessions = [
                SELECT Id FROM MessagingSession
                WHERE MessagingEndUserId = :endUsers[0].Id AND Status = 'Active'
                ORDER BY LastModifiedDate DESC LIMIT 1
            ];
            return sessions.isEmpty() ? null : sessions[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static Boolean tryStandardSendMessage(Id sessionId, String body) {
        try {
            Invocable.Action action = Invocable.Action.createStandardAction('messaging:sendMessage');
            action.setInvocationParameter('MessagingSessionId', sessionId);
            action.setInvocationParameter('Message', body);
            action.setInvocationParameter('MessageType', 'Text');
            List<Invocable.Action.Result> results = action.invoke();
            return !results.isEmpty() && results[0].isSuccess();
        } catch (Exception e) {
            return false;
        }
    }
}
