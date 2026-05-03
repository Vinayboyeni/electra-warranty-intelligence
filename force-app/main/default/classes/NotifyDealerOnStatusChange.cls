/**
 * Pushes a status-change message into the dealer's WhatsApp session
 * after the OEM approver acts. Triggered by Notify_Dealer_On_Status_Change_Flow.
 *
 * Resolution order for the target session:
 *   1. Claim.MessagingSessionId__c (stored at intake — most reliable)
 *   2. Active MessagingSession for Claim.DealerWhatsAppNumber__c (WhatsApp path)
 *   3. Most recent Active MessagingSession in the last 6 hours (portal/embedded
 *      web chat fallback — works for demo where a single dealer chat is open)
 * Always writes a Chatter FeedItem audit so every status change is visible
 * on the Claim record even when no live session exists.
 *
 * Never throws — a messaging failure must not roll back the Status update DML.
 */
public without sharing class NotifyDealerOnStatusChange {

    public class Input {
        @InvocableVariable(required=true label='Claim Id')
        public Id claimId;
    }

    public class Result {
        @InvocableVariable public Boolean sent;
        @InvocableVariable public String channel;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='Notify Dealer On Claim Status Change'
        description='Sends a WhatsApp message to the dealer summarising the latest claim decision (Approved / Rejected / Needs More Info).'
    )
    public static List<Result> notify(List<Input> inputs) {
        List<Result> results = new List<Result>();
        if (inputs == null) return results;

        for (Input inp : inputs) {
            Result res = new Result();
            res.sent = false;
            try {
                if (inp == null || inp.claimId == null) {
                    res.channel = 'Error';
                    res.message = 'claimId is required.';
                    results.add(res);
                    continue;
                }

                List<Claim> claims = [
                    SELECT Id, Name, Status, DealerWhatsAppNumber__c,
                           MessagingSessionId__c, ClarificationRequest__c,
                           DecisionRationale__c, ReasonCode__c
                    FROM Claim WHERE Id = :inp.claimId LIMIT 1
                ];
                if (claims.isEmpty()) {
                    res.channel = 'Error';
                    res.message = 'Claim not found.';
                    results.add(res);
                    continue;
                }
                Claim c = claims[0];

                String body = buildBody(c);

                // 1) Try the session stored on the Claim
                Id sessionId = resolveSessionId(c.MessagingSessionId__c);

                // 2) Fall back to active session lookup by phone (WhatsApp path)
                if (sessionId == null) {
                    sessionId = findActiveSessionByPhone(c.DealerWhatsAppNumber__c);
                }

                // 3) Last-resort fallback: most recent active MessagingSession.
                //    Covers Embedded Service / portal chat where the session ID
                //    is never written back to the Claim.
                if (sessionId == null) {
                    sessionId = findMostRecentActiveSession();
                }

                Boolean pushed = false;
                if (sessionId != null) {
                    pushed = trySend(sessionId, body);
                }

                FeedItem fi = new FeedItem();
                fi.ParentId = c.Id;
                fi.Body = (pushed
                    ? '📨 Status update sent to dealer in WhatsApp:\n'
                    : '📨 Status update queued (no active session). Dealer will see it on next ARIA reply:\n'
                ) + body;
                insert fi;

                res.sent = true;
                res.channel = pushed ? 'WhatsApp' : 'Chatter (deferred)';
                res.message = pushed
                    ? 'Status update dispatched.'
                    : 'No active session; logged on Claim feed.';
            } catch (Exception e) {
                res.channel = 'Error';
                res.message = 'Exception: ' + e.getMessage();
            }
            results.add(res);
        }
        return results;
    }

    private static String buildBody(Claim c) {
        String header;
        String line;
        String statusLabel = c.Status;
        if ('Approved'.equalsIgnoreCase(c.Status)) {
            header = '✅ *Claim ' + c.Name + ' — APPROVED*';
            line = 'Message: Claim approved successfully. You may proceed with the repair.';
        } else if ('Rejected'.equalsIgnoreCase(c.Status)) {
            header = '❌ *Claim ' + c.Name + ' — REJECTED*';
            String reason = String.isNotBlank(c.ReasonCode__c) ? c.ReasonCode__c : 'Not covered';
            line = 'Message: Claim rejected. Reason: ' + reason + '.';
        } else if ('Needs More Info'.equalsIgnoreCase(c.Status)) {
            header = 'ℹ️ *Claim ' + c.Name + ' — NEEDS MORE INFO*';
            String q = String.isNotBlank(c.ClarificationRequest__c)
                ? c.ClarificationRequest__c
                : 'Our adjuster needs additional information before continuing.';
            line = 'Message: ' + q;
        } else {
            header = '🔔 *Claim ' + c.Name + ' — status updated*';
            line = 'Message: Claim status changed to ' + c.Status + '.';
        }

        String rationale = String.isNotBlank(c.DecisionRationale__c)
            ? '\n\n*Approver note:* ' + c.DecisionRationale__c : '';

        return header + '\n\nHere are the results:\n' + line
            + '\nStatus: ' + statusLabel + rationale;
    }

    private static Id resolveSessionId(String stored) {
        if (String.isBlank(stored)) return null;
        try {
            Id sid = (Id) stored;
            List<MessagingSession> rows = [
                SELECT Id FROM MessagingSession WHERE Id = :sid LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static Id findActiveSessionByPhone(String phone) {
        if (String.isBlank(phone)) return null;
        Integer digits = 0;
        for (Integer i = 0; i < phone.length(); i++) {
            String ch = phone.substring(i, i + 1);
            if (ch >= '0' && ch <= '9') digits++;
        }
        if (digits < 8) return null;
        try {
            List<MessagingEndUser> users = [
                SELECT Id FROM MessagingEndUser WHERE Name = :phone LIMIT 1
            ];
            if (users.isEmpty()) return null;
            List<MessagingSession> rows = [
                SELECT Id FROM MessagingSession
                WHERE MessagingEndUserId = :users[0].Id AND Status = 'Active'
                ORDER BY LastModifiedDate DESC LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static Id findMostRecentActiveSession() {
        // Look for any session that is NOT in a terminal state (Ended/Closed/Completed/Failed).
        // Wider net than just "Active" — embedded chat sessions often sit in
        // "In Progress", "Waiting", or "New" while the dealer is reading.
        try {
            Datetime cutoff = Datetime.now().addHours(-6);
            List<MessagingSession> rows = [
                SELECT Id, Status FROM MessagingSession
                WHERE CreatedDate >= :cutoff
                  AND Status NOT IN ('Ended', 'Closed', 'Completed', 'Failed')
                ORDER BY LastModifiedDate DESC LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static Boolean trySend(Id sessionId, String body) {
        try {
            Invocable.Action a = Invocable.Action.createStandardAction('messaging:sendMessage');
            a.setInvocationParameter('MessagingSessionId', sessionId);
            a.setInvocationParameter('Message', body);
            a.setInvocationParameter('MessageType', 'Text');
            List<Invocable.Action.Result> r = a.invoke();
            return !r.isEmpty() && r[0].isSuccess();
        } catch (Exception e) {
            return false;
        }
    }
}