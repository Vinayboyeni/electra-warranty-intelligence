/**
 * ComposeDealerRejectionMessage
 *
 * Generates a personalized, empathetic WhatsApp rejection message for the
 * dealer via the "Compose_Dealer_Rejection_Message" Prompt Builder template.
 *
 * Falls back to a rule-based template if the LLM call is unavailable, the
 * Prompt Template isn't configured, or the response is malformed. The caller
 * always gets a usable message — degradation is transparent via the `source`
 * field.
 *
 * Invoked from SendWhatsAppClaimDecision.cls when decision == REJECTED.
 */
public without sharing class ComposeDealerRejectionMessage {

    private static final String TEMPLATE_DEV_NAME = 'Compose_Dealer_Rejection_Message';

    public class Input {
        @InvocableVariable(required=true label='Claim Id')
        public Id claimId;
        @InvocableVariable(label='Reason Code' description='Rejection reason code (e.g., Coverage Expired, Wear & Tear).')
        public String reasonCode;
        @InvocableVariable(label='Adjuster Rationale' description='Free-text rationale from the adjuster.')
        public String adjusterRationale;
    }

    public class Output {
        @InvocableVariable(label='Message Body' description='Formatted rejection message ready for WhatsApp delivery.')
        public String messageBody;
        @InvocableVariable(label='Source' description='PromptTemplate or Fallback — tells you which path produced the output.')
        public String source;
    }

    /**
     * Non-invocable entry point for use from other Apex classes
     * (e.g., SendWhatsAppClaimDecision). Always returns a usable string.
     */
    public static String compose(Id claimId, String reasonCode, String rationale) {
        if (claimId == null) return buildFallback(null, reasonCode, rationale);
        Claim c = queryClaim(claimId);
        if (c == null) return buildFallback(null, reasonCode, rationale);

        String body = tryPromptTemplate(c, reasonCode, rationale);
        if (String.isNotBlank(body)) return body;
        return buildFallback(c, reasonCode, rationale);
    }

    @InvocableMethod(
        label='Compose Dealer Rejection Message'
        description='Generates a personalized rejection WhatsApp message via Prompt Builder template. Falls back to rule-based template if unavailable.'
    )
    public static List<Output> run(List<Input> inputs) {
        List<Output> out = new List<Output>();
        if (inputs == null) return out;
        for (Input i : inputs) {
            Output o = new Output();
            if (i == null || i.claimId == null) {
                o.messageBody = buildFallback(null, i == null ? null : i.reasonCode,
                    i == null ? null : i.adjusterRationale);
                o.source = 'Fallback';
                out.add(o);
                continue;
            }
            Claim c = queryClaim(i.claimId);
            String templateBody = (c != null) ? tryPromptTemplate(c, i.reasonCode, i.adjusterRationale) : null;
            if (String.isNotBlank(templateBody)) {
                o.messageBody = templateBody;
                o.source = 'PromptTemplate';
            } else {
                o.messageBody = buildFallback(c, i.reasonCode, i.adjusterRationale);
                o.source = 'Fallback';
            }
            out.add(o);
        }
        return out;
    }

    // ─────────────────────────────────────────────────────────────────

    private static Claim queryClaim(Id claimId) {
        List<Claim> claims = [
            SELECT Id, Name, Status, PartCategory__c, Symptom__c, Odometer__c,
                   EstimatedCost__c, Eligibility__c, ReasonCode__c,
                   Account.Name, Account.DealerTrustScore__c,
                   Vehicle__r.Name
            FROM Claim WHERE Id = :claimId LIMIT 1
        ];
        return claims.isEmpty() ? null : claims[0];
    }

    /**
     * Attempts to call the Compose_Dealer_Rejection_Message Prompt Template.
     * Returns null on any failure so the caller can use the rule-based fallback.
     * Wrapped in try/catch so the class deploys cleanly even in orgs without
     * the standard action or without the template configured.
     */
    private static String tryPromptTemplate(Claim c, String reasonCode, String rationale) {
        try {
            Map<String, Object> inputRecord = new Map<String, Object>{
                'Id'                => c.Id,
                'Name'              => c.Name,
                'PartCategory__c'   => c.PartCategory__c,
                'Symptom__c'        => c.Symptom__c,
                'EstimatedCost__c'  => c.EstimatedCost__c,
                'Eligibility__c'    => c.Eligibility__c,
                'DealerName'        => c.Account != null ? c.Account.Name : '',
                'ReasonCode'        => String.isNotBlank(reasonCode) ? reasonCode : '',
                'AdjusterRationale' => String.isNotBlank(rationale) ? rationale : ''
            };

            Invocable.Action a = Invocable.Action.createStandardAction(
                'generativeAi:generatePromptTemplateResponse');
            a.setInvocationParameter('promptTemplateDevName', TEMPLATE_DEV_NAME);
            a.setInvocationParameter('inputRecord', inputRecord);
            a.setInvocationParameter('reasonCode', reasonCode);
            a.setInvocationParameter('adjusterRationale', rationale);

            List<Invocable.Action.Result> results = a.invoke();
            if (results == null || results.isEmpty() || !results[0].isSuccess()) {
                return null;
            }
            Object resp = results[0].getOutputParameters().get('promptResponse');
            if (resp == null) return null;
            String text = String.valueOf(resp).trim();
            // Strip any accidental code fences the model might wrap around the reply
            if (text.startsWith('```')) {
                text = text.replaceFirst('^```[a-zA-Z]*\\s*', '');
                if (text.endsWith('```')) text = text.substring(0, text.length() - 3).trim();
            }
            return text.length() > 10 ? text : null;
        } catch (Exception e) {
            System.debug('ComposeDealerRejectionMessage template call failed: '
                + e.getMessage() + '\n' + e.getStackTraceString());
            return null;
        }
    }

    /**
     * Rule-based empathetic rejection message. Used when the Prompt Template
     * is unavailable. Same shape / channel as the Prompt Template output so
     * downstream handling is identical.
     */
    private static String buildFallback(Claim c, String reasonCode, String rationale) {
        String claimName = (c != null && c.Name != null) ? c.Name : 'your claim';
        String dealerName = (c != null && c.Account != null && c.Account.Name != null)
            ? c.Account.Name : 'there';

        String body = '❌ *Claim ' + claimName + ' — REJECTED*\n\n';
        body += 'Hi ' + dealerName + ' team,\n\n';
        body += 'Thank you for your warranty prior-authorization request. '
            + 'After careful review, we are unable to approve this claim.\n\n';
        if (String.isNotBlank(reasonCode)) {
            body += '*Reason:* ' + reasonCode + '\n';
        }
        if (String.isNotBlank(rationale)) {
            body += '*Approver note:* ' + rationale + '\n';
        }
        body += '\nWe appreciate your continued partnership. If you believe this '
            + 'decision warrants reconsideration, please reply *GOODWILL* to '
            + 'request a policy exception, or reply *AGENT* to speak with an '
            + 'Electra Service specialist directly.';
        return body;
    }
}
