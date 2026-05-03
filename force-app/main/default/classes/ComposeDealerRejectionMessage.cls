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
            ConnectApi.EinsteinPromptTemplateGenerationsInput inp =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();

            ConnectApi.EinsteinLlmAdditionalConfigInput addCfg =
                new ConnectApi.EinsteinLlmAdditionalConfigInput();
            addCfg.applicationName = 'PromptBuilderPreview';
            inp.additionalConfig = addCfg;
            inp.isPreview = false;

            // Pre-render claim context as a text blob (Map/Object resolution
            // unreliable for nested {!$Input:Claim.X} references). Plus
            // ReasonCode + AdjusterRationale as separate Text inputs so the
            // template can interpolate them individually for empathy.
            String contextBlob = 'Claim details:'
                + '\n- Claim number: ' + (c.Name != null ? c.Name : 'N/A')
                + '\n- Dealer: ' + (c.Account != null && c.Account.Name != null ? c.Account.Name : 'N/A')
                + '\n- Part category: ' + (c.PartCategory__c != null ? c.PartCategory__c : 'N/A')
                + '\n- Reported symptom: ' + (c.Symptom__c != null ? c.Symptom__c : 'N/A')
                + '\n- Estimated cost: ' + (c.EstimatedCost__c != null ? '$' + c.EstimatedCost__c.setScale(2) : 'N/A')
                + '\n- Coverage verdict: ' + (c.Eligibility__c != null ? c.Eligibility__c : 'N/A');
            ConnectApi.WrappedValue ctxWv = new ConnectApi.WrappedValue();
            ctxWv.value = contextBlob;

            // Legacy Object input — kept so older templates still work.
            Map<String, Object> claimMap = new Map<String, Object>{
                'Id'                => c.Id,
                'Name'              => c.Name,
                'PartCategory__c'   => c.PartCategory__c,
                'Symptom__c'        => c.Symptom__c,
                'EstimatedCost__c'  => c.EstimatedCost__c,
                'Eligibility__c'    => c.Eligibility__c
            };
            ConnectApi.WrappedValue claimWv = new ConnectApi.WrappedValue();
            claimWv.value = claimMap;
            ConnectApi.WrappedValue reasonWv = new ConnectApi.WrappedValue();
            reasonWv.value = String.isNotBlank(reasonCode) ? reasonCode : '';
            ConnectApi.WrappedValue rationaleWv = new ConnectApi.WrappedValue();
            rationaleWv.value = String.isNotBlank(rationale) ? rationale : '';

            inp.inputParams = new Map<String, ConnectApi.WrappedValue>{
                'Input:ClaimContext'      => ctxWv,
                'Input:Claim'             => claimWv,
                'Input:ReasonCode'        => reasonWv,
                'Input:AdjusterRationale' => rationaleWv
            };

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    TEMPLATE_DEV_NAME, inp);

            if (result == null || result.generations == null || result.generations.isEmpty()) {
                return null;
            }
            String text = result.generations[0].text;
            if (String.isBlank(text)) return null;
            text = text.trim();
            if (text.startsWith('```')) {
                text = text.replaceFirst('^```[a-zA-Z]*\\s*', '');
                if (text.endsWith('```')) text = text.substring(0, text.length() - 3).trim();
            }
            // Template-binding sanity check (same as in ComposeRepairGuidance).
            String lower = text.toLowerCase();
            Boolean saysEmpty = lower.contains('missing')
                || lower.contains('not provided')
                || lower.contains('please provide')
                || lower.contains('no information');
            Boolean fieldsPresent = String.isNotBlank(c.PartCategory__c)
                && String.isNotBlank(c.Symptom__c);
            if (saysEmpty && fieldsPresent) {
                System.debug('ComposeDealerRejectionMessage template reported missing fields incorrectly. Falling back.');
                return null;
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