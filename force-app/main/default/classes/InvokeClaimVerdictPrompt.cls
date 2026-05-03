/**
 * InvokeClaimVerdictPrompt
 *
 * Evaluates a claim's risk profile via the Prompt Builder template
 * "Claim_Risk_Verdict" and writes AI_Recommendation__c, AI_Confidence__c,
 * and AI_Summary__c back to the Claim record.
 *
 * Degrades gracefully — if the Prompt Template is not configured, the
 * Einstein API throws, or the response isn't parseable JSON, falls back
 * to the existing rule-based verdict so the system keeps working.
 *
 * Exposed as an InvocableMethod so the flow can call it after the claim
 * record is created (between Create_Claim_Rec and Route_Claim_Apex).
 */
public without sharing class InvokeClaimVerdictPrompt {

    private static final String TEMPLATE_DEV_NAME = 'Claim_Risk_Verdict';

    public class InvocableInput {
        @InvocableVariable(required=true label='Claim Id')
        public Id claimId;
    }

    public class InvocableResult {
        @InvocableVariable(label='Recommendation')   public String recommendation;
        @InvocableVariable(label='Confidence')       public Integer confidence;
        @InvocableVariable(label='Summary')          public String summary;
        @InvocableVariable(label='Source')           public String source; // 'PromptTemplate' or 'Fallback'
    }

    @InvocableMethod(
        label='Evaluate Claim Verdict (Prompt Builder)'
        description='Invokes the Claim_Risk_Verdict Prompt Template to produce an AI-backed verdict. Falls back to rule-based logic if the template call fails.'
    )
    public static List<InvocableResult> run(List<InvocableInput> inputs) {
        List<InvocableResult> out = new List<InvocableResult>();
        if (inputs == null) return out;

        for (InvocableInput i : inputs) {
            InvocableResult r = new InvocableResult();
            if (i == null || i.claimId == null) {
                r.recommendation = 'Needs Clarification';
                r.confidence = 50;
                r.summary = 'No claim id supplied.';
                r.source = 'Fallback';
                out.add(r);
                continue;
            }

            Claim c = queryClaim(i.claimId);
            if (c == null) {
                r.recommendation = 'Needs Clarification';
                r.confidence = 50;
                r.summary = 'Claim not found for id ' + i.claimId + '.';
                r.source = 'Fallback';
                out.add(r);
                continue;
            }

            // Try Prompt Template first; fall back on any failure
            Map<String, Object> verdict = tryPromptTemplate(c);
            String src = 'PromptTemplate';
            if (verdict == null) {
                verdict = buildFallback(c);
                src = 'Fallback';
            }

            r.recommendation = (String) verdict.get('recommendation');
            Object conf = verdict.get('confidence');
            r.confidence = conf instanceof Integer ? (Integer) conf
                : conf instanceof Decimal ? ((Decimal) conf).intValue()
                : 50;
            r.summary = (String) verdict.get('summary');
            r.source = src;

            writeBackToClaim(c.Id, r);
            out.add(r);
        }
        return out;
    }

    private static Claim queryClaim(Id claimId) {
        List<Claim> claims = [
            SELECT Id, Name, PartCategory__c, Symptom__c, Odometer__c,
                   EstimatedCost__c, Eligibility__c,
                   Account.Name, Account.DealerTrustScore__c,
                   Vehicle__c, Vehicle__r.Name
            FROM Claim WHERE Id = :claimId LIMIT 1
        ];
        return claims.isEmpty() ? null : claims[0];
    }

    /**
     * Attempts to call the Claim_Risk_Verdict prompt template via Einstein.
     * Returns null on any failure so the caller can fall back.
     *
     * Uses dynamic Type lookup for ConnectApi.EinsteinLLM so this class
     * deploys cleanly even in orgs where the Einstein LLM API isn't
     * available yet (the call then returns null and fallback fires).
     */
    private static Map<String, Object> tryPromptTemplate(Claim c) {
        // Primary path — modern ConnectApi.EinsteinLLM. Returns null on any
        // failure or when the template returns no generations, so the caller
        // can fall back to the rule-based verdict.
        String rawText = invokeViaConnectApi(c);
        if (String.isBlank(rawText)) return null;
        try {
            String cleaned = stripCodeFences(rawText);
            Object parsed = JSON.deserializeUntyped(cleaned);
            if (!(parsed instanceof Map<String, Object>)) return null;
            Map<String, Object> asMap = (Map<String, Object>) parsed;
            if (!asMap.containsKey('recommendation') || !asMap.containsKey('confidence')) {
                return null;
            }
            // Template-binding sanity check: if the LLM claims required fields
            // are missing/insufficient but they ARE populated on the claim,
            // the template's variable resolution failed. Fall back to
            // rule-based so we don't surface a misleading verdict.
            Object summaryObj = asMap.get('summary');
            String summary = (summaryObj instanceof String) ? (String) summaryObj : '';
            String summaryLower = summary.toLowerCase();

            // Catches: "missing details", "insufficient claim details",
            // "not provided", "please provide", "request part category", etc.
            Boolean claimsMissing = (
                    summaryLower.contains('missing')
                 || summaryLower.contains('insufficient')
                 || summaryLower.contains('not provided')
                 || summaryLower.contains('please provide')
                 || summaryLower.contains('request part')
                 || summaryLower.contains('request symptom')
                 || summaryLower.contains('request coverage')
                 || summaryLower.contains('request odometer')
            ) && (
                    summaryLower.contains('details')
                 || summaryLower.contains('information')
                 || summaryLower.contains('part')
                 || summaryLower.contains('symptom')
                 || summaryLower.contains('odometer')
                 || summaryLower.contains('cost')
                 || summaryLower.contains('verdict')
            );
            Boolean fieldsActuallyPopulated = String.isNotBlank(c.PartCategory__c)
                && String.isNotBlank(c.Symptom__c)
                && c.EstimatedCost__c != null
                && c.Odometer__c != null;
            if (claimsMissing && fieldsActuallyPopulated) {
                System.debug('Template reported missing/insufficient fields but they ARE populated. Falling back to rule-based.');
                return null;
            }
            return asMap;
        } catch (Exception e) {
            System.debug('InvokeClaimVerdictPrompt: parse failed — ' + e.getMessage());
            return null;
        }
    }

    /**
     * Calls the Prompt Template via ConnectApi.EinsteinLLM. This is the
     * modern, Apex-native invocation path. Requires the template to be
     * configured AND ACTIVATED in Prompt Builder.
     *
     * Returns the LLM response text, or null on any failure/empty response.
     */
    private static String invokeViaConnectApi(Claim c) {
        try {
            ConnectApi.EinsteinPromptTemplateGenerationsInput inp =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();

            ConnectApi.EinsteinLlmAdditionalConfigInput addCfg =
                new ConnectApi.EinsteinLlmAdditionalConfigInput();
            addCfg.applicationName = 'PromptBuilderPreview';
            inp.additionalConfig = addCfg;
            inp.isPreview = false;

            // Send the actual Claim SObject (not a Map). The template's input
            // is declared as SOBJECT://Claim, so the merge fields like
            // {!$Input:Claim.PartCategory__c} only resolve when the wrapped
            // value is a real Claim record. Passing a Map<String,Object>
            // caused the merges to render empty — the LLM saw a blank
            // prompt and replied with generic "insufficient details" text.
            ConnectApi.WrappedValue claimWv = new ConnectApi.WrappedValue();
            claimWv.value = c;

            // Also send the pre-rendered text context as a redundant fallback
            // for templates that prefer a single Text input.
            String claimContext = renderClaimContext(c);
            ConnectApi.WrappedValue contextWv = new ConnectApi.WrappedValue();
            contextWv.value = claimContext;

            inp.inputParams = new Map<String, ConnectApi.WrappedValue>{
                'Input:Claim'        => claimWv,
                'Input:ClaimContext' => contextWv
            };

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    TEMPLATE_DEV_NAME, inp);

            if (result == null || result.generations == null || result.generations.isEmpty()) {
                if (result != null && result.generationErrors != null && !result.generationErrors.isEmpty()) {
                    System.debug('Template generation error: ' + result.generationErrors[0].errorMessage);
                }
                return null;
            }
            String text = result.generations[0].text;
            return String.isBlank(text) ? null : text;
        } catch (Exception e) {
            System.debug('InvokeClaimVerdictPrompt ConnectApi call failed: '
                + e.getMessage());
            return null;
        }
    }

    /**
     * Rule-based fallback that mirrors the existing flow formula logic.
     * Shape matches the Prompt Template's expected JSON so the caller
     * can treat both paths identically.
     */
    private static Map<String, Object> buildFallback(Claim c) {
        Map<String, Object> v = new Map<String, Object>();
        String eligibility = c.Eligibility__c != null ? c.Eligibility__c : '';
        if (eligibility == 'Likely') {
            v.put('recommendation', 'Approve');
            v.put('confidence', 90);
            v.put('summary', 'Coverage active; part, mileage, and dates within warranty terms.');
        } else if (eligibility == 'Not Covered') {
            v.put('recommendation', 'Reject');
            v.put('confidence', 95);
            v.put('summary', 'Claim falls outside warranty coverage terms.');
        } else {
            v.put('recommendation', 'Needs Clarification');
            v.put('confidence', 50);
            v.put('summary', 'Borderline eligibility — adjuster review recommended.');
        }
        v.put('risk_factors', new List<String>());
        return v;
    }

    /**
     * Persist the verdict to the Claim. Writes to AI_Recommendation__c,
     * AI_Confidence__c, and AI_Summary__c.
     */
    private static void writeBackToClaim(Id claimId, InvocableResult r) {
        try {
            Claim c = new Claim(Id = claimId);
            c.AI_Recommendation__c = r.recommendation;
            c.AI_Confidence__c = r.confidence;
            if (String.isNotBlank(r.summary)) {
                c.AI_Summary__c = r.summary.abbreviate(255);
            }
            update c;
        } catch (Exception e) {
            System.debug('InvokeClaimVerdictPrompt write-back failed: ' + e.getMessage());
        }
    }

    /**
     * Renders the claim's relevant fields as a single Text blob that the
     * Prompt Builder template can consume via a single {!$Input:ClaimContext}
     * placeholder. Avoids the Map<->Object resolution problem entirely.
     */
    private static String renderClaimContext(Claim c) {
        List<String> lines = new List<String>{ 'Claim details:' };
        lines.add('- Claim number: ' + (c.Name != null ? c.Name : 'N/A'));
        lines.add('- Part category: ' + (c.PartCategory__c != null ? c.PartCategory__c : 'N/A'));
        lines.add('- Reported symptom: ' + (c.Symptom__c != null ? c.Symptom__c : 'N/A'));
        lines.add('- Odometer: ' + (c.Odometer__c != null ? String.valueOf(c.Odometer__c.intValue()) + ' miles' : 'N/A'));
        lines.add('- Estimated cost: ' + (c.EstimatedCost__c != null ? '$' + c.EstimatedCost__c.setScale(2) : 'N/A'));
        lines.add('- Coverage engine verdict: ' + (c.Eligibility__c != null ? c.Eligibility__c : 'N/A'));
        if (c.Account != null && c.Account.Name != null) {
            lines.add('- Servicing dealer: ' + c.Account.Name);
        }
        return String.join(lines, '\n');
    }

    private static String stripCodeFences(String raw) {
        if (String.isBlank(raw)) return raw;
        String s = raw.trim();
        if (s.startsWith('```')) {
            s = s.replaceFirst('^```[a-zA-Z]*\\s*', '');
            if (s.endsWith('```')) {
                s = s.substring(0, s.length() - 3).trim();
            }
        }
        return s;
    }
}