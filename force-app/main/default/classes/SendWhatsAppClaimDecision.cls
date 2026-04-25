/**
 * SendWhatsAppClaimDecision
 *
 * Posts an approval/rejection outcome back to the dealer in the same WhatsApp
 * thread that ARIA used for intake. Called directly from ApproveWarrantyClaim
 * and RejectWarrantyClaim after the DML commit — NOT as a separate flow,
 * because the notification must not fail the parent approve/reject transaction
 * and must run synchronously so the judge sees the message appear.
 *
 * Same three-tier pattern as SendWhatsAppRFINotification:
 *   Tier 1: Standard messaging:sendMessage invocable (works if active session)
 *   Tier 2: Chatter FeedItem audit (always writes)
 */
public with sharing class SendWhatsAppClaimDecision {

    public static final String APPROVED = 'APPROVED';
    public static final String REJECTED = 'REJECTED';

    /**
     * Fire-and-forget notification. Never throws — swallows exceptions so a
     * downstream messaging failure cannot roll back the approve/reject DML.
     * decision must be 'APPROVED' or 'REJECTED' (use the constants above).
     *
     * For REJECTED: calls ComposeDealerRejectionMessage to get a personalized
     * empathetic WhatsApp body from the Prompt Builder template. Falls back
     * to rule-based buildBody() if the composer returns null.
     */
    public static void notify(Id claimId, String decision, String rationale) {
        notify(claimId, decision, null, rationale, null);
    }

    public static void notify(Id claimId, String decision, String reasonCode, String rationale) {
        notify(claimId, decision, reasonCode, rationale, null);
    }

    public static void notify(Id claimId, String decision, String reasonCode, String rationale, String authorizationPdfUrl) {
        if (claimId == null) return;
        try {
            List<Claim> claims = [
                SELECT Id, Name, DealerWhatsAppNumber__c
                FROM Claim WHERE Id = :claimId LIMIT 1
            ];
            if (claims.isEmpty()) return;

            Claim c = claims[0];

            // For REJECTED, try Prompt Builder template first (empathetic, personalized).
            // Falls through to the rule-based buildBody() if template unavailable.
            String body = null;
            String bodySource = 'Rule-based';
            if (REJECTED.equalsIgnoreCase(decision)) {
                try {
                    body = ComposeDealerRejectionMessage.compose(c.Id, reasonCode, rationale);
                    if (String.isNotBlank(body)) bodySource = 'PromptTemplate-or-Fallback';
                } catch (Exception ce) {
                    System.debug('Rejection composer failed: ' + ce.getMessage());
                }
            }
            if (String.isBlank(body)) {
                body = buildBody(c.Name, decision, rationale);
            }

            // For APPROVED, append the authorization PDF link if generated.
            if (APPROVED.equalsIgnoreCase(decision) && String.isNotBlank(authorizationPdfUrl)) {
                body += '\n\n📄 *Authorization document:* ' + authorizationPdfUrl
                    + '\n(Present at dealer service bay. Valid 30 days.)';
            }

            // For APPROVED, append AI-generated part-specific repair guidance.
            // Never blocks — if the composer returns null we just omit this block.
            if (APPROVED.equalsIgnoreCase(decision)) {
                try {
                    String guidance = ComposeRepairGuidance.compose(c.Id);
                    if (String.isNotBlank(guidance)) {
                        body += '\n\n' + guidance;
                    }
                } catch (Exception ge) {
                    System.debug('Repair guidance composer failed: ' + ge.getMessage());
                }
            }

            Id sessionId = findActiveSession(c.DealerWhatsAppNumber__c);
            Boolean pushed = false;
            if (sessionId != null) {
                pushed = tryStandardSendMessage(sessionId, body);
            }

            FeedItem fi = new FeedItem();
            fi.ParentId = c.Id;
            fi.Body = (pushed
                ? '📨 WhatsApp decision sent to dealer (' + bodySource + '):\n'
                : '📨 Decision audit (dealer sees on next ARIA interaction, ' + bodySource + '):\n'
            ) + body;
            insert fi;
        } catch (Exception e) {
            System.debug('SendWhatsAppClaimDecision swallowed: ' + e.getMessage());
        }
    }

    private static String buildBody(String claimNumber, String decision, String rationale) {
        Boolean isApproved = (APPROVED.equalsIgnoreCase(decision));
        String header = isApproved
            ? '✅ *Claim ' + claimNumber + ' — APPROVED*'
            : '❌ *Claim ' + claimNumber + ' — REJECTED*';
        String bodyLine = isApproved
            ? 'Great news! Your warranty prior-authorization is approved. You may proceed with the repair.'
            : 'Your warranty prior-authorization has been declined.';
        String rationaleLine = String.isNotBlank(rationale)
            ? '\n\n*Approver note:* ' + rationale : '';
        String footer = isApproved
            ? '\n\nReply STATUS ' + claimNumber + ' anytime for the latest.'
            : '\n\nReply GOODWILL to request a policy exception, or AGENT to reach a specialist.';
        return header + '\n\n' + bodyLine + rationaleLine + footer;
    }

    private static Id findActiveSession(String dealerPhone) {
        if (String.isBlank(dealerPhone)) return null;
        // Sanity check: the dealer-side agent occasionally hallucinates the
        // DealerWhatsAppNumber__c when its input isn't bound. Reject anything
        // that doesn't look like a phone (digit-heavy, optional + prefix).
        // A real phone has at least 8 digits; "Vin" / random text has none.
        Integer digitCount = 0;
        for (Integer i = 0; i < dealerPhone.length(); i++) {
            String ch = dealerPhone.substring(i, i + 1);
            if (ch >= '0' && ch <= '9') digitCount++;
        }
        if (digitCount < 8) {
            System.debug('findActiveSession: rejecting non-phone value "' + dealerPhone + '"');
            return null;
        }
        try {
            List<MessagingEndUser> endUsers = [
                SELECT Id FROM MessagingEndUser WHERE Name = :dealerPhone LIMIT 1
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
            List<Invocable.Action.Result> invocResults = action.invoke();
            return !invocResults.isEmpty() && invocResults[0].isSuccess();
        } catch (Exception e) {
            return false;
        }
    }
}
