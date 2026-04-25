/**
 * ComposeRepairGuidance
 *
 * Post-approval companion to ComposeDealerRejectionMessage. Invokes the
 * Prompt Builder template "Compose_Repair_Guidance_Message" to generate a
 * short, part-specific, actionable guidance block the dealer receives on
 * WhatsApp right after the approval + authorization PDF link.
 *
 * Expected template output shape: plain text, 2-4 bullet points ending
 * with an expected-timeline line. No JSON, no markdown headers.
 *
 * Returns null on any failure so the caller can fall through to a
 * minimal rule-based guidance or simply omit the section.
 */
public without sharing class ComposeRepairGuidance {

    private static final String TEMPLATE_DEV_NAME = 'Compose_Repair_Guidance_Message';

    public static String compose(Id claimId) {
        if (claimId == null) return null;
        if (Test.isRunningTest()) return null;

        Claim c = queryClaim(claimId);
        if (c == null) return null;

        String promptBody = tryPromptTemplate(c);
        if (String.isNotBlank(promptBody)) return promptBody;

        // Fallback: deterministic per-category tips so the dealer
        // always sees something useful even if the template is offline.
        return buildFallback(c);
    }

    private static Claim queryClaim(Id claimId) {
        List<Claim> claims = [
            SELECT Id, Name, PartCategory__c, Symptom__c, Diagnosis__c,
                   Odometer__c, EstimatedCost__c, Vehicle__r.Name
            FROM Claim WHERE Id = :claimId LIMIT 1
        ];
        return claims.isEmpty() ? null : claims[0];
    }

    private static String tryPromptTemplate(Claim c) {
        try {
            Map<String, Object> inputRecord = new Map<String, Object>{
                'Id'               => c.Id,
                'Name'             => c.Name,
                'PartCategory__c'  => c.PartCategory__c,
                'Symptom__c'       => c.Symptom__c,
                'Diagnosis__c'     => c.Diagnosis__c,
                'Odometer__c'      => c.Odometer__c,
                'EstimatedCost__c' => c.EstimatedCost__c
            };

            Invocable.Action a = Invocable.Action.createStandardAction(
                'generativeAi:generatePromptTemplateResponse');
            a.setInvocationParameter('promptTemplateDevName', TEMPLATE_DEV_NAME);
            a.setInvocationParameter('inputRecord', inputRecord);

            List<Invocable.Action.Result> results = a.invoke();
            if (results == null || results.isEmpty() || !results[0].isSuccess()) {
                return null;
            }
            Object out = results[0].getOutputParameters().get('promptResponse');
            if (out == null) return null;

            String text = String.valueOf(out).trim();
            return stripCodeFences(text);
        } catch (Exception e) {
            System.debug('ComposeRepairGuidance template call failed: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Rule-based guidance for the offline/fallback path. Keeps the demo
     * readable when Prompt Builder is unavailable. Intentionally short.
     */
    private static String buildFallback(Claim c) {
        String cat = (c.PartCategory__c != null) ? c.PartCategory__c.toLowerCase() : '';
        List<String> tips = new List<String>();

        if (cat.contains('battery')) {
            tips.add('• Run a full HV pack diagnostic scan before disassembly and store logs with the claim.');
            tips.add('• Follow PPE protocol for HV work — two-tech lockout required on pack removal.');
            tips.add('• Use only OEM replacement modules — aftermarket cells void the prior-auth.');
        } else if (cat.contains('brake')) {
            tips.add('• Inspect rotors and calipers alongside pad replacement; document wear measurements.');
            tips.add('• Bleed lines only after full pad-and-rotor swap is verified.');
        } else if (cat.contains('motor') || cat.contains('drive')) {
            tips.add('• Capture pre-removal NVH recording for the defect report.');
            tips.add('• Log inverter firmware version before and after replacement.');
        } else if (cat.contains('infotainment') || cat.contains('software')) {
            tips.add('• Attempt OTA reflash first; only escalate to hardware swap if reflash fails twice.');
            tips.add('• Back up customer profiles before hardware replacement.');
        } else {
            tips.add('• Document pre-repair state with photos attached to the claim record.');
            tips.add('• Use OEM parts only — aftermarket replacements void the prior-authorization.');
        }

        tips.add('• Submit the final invoice within 10 business days referencing claim ' + c.Name + '.');
        tips.add('\n_Target completion: 2 business days from parts receipt._');
        return '*🔧 Repair guidance*\n' + String.join(tips, '\n');
    }

    private static String stripCodeFences(String raw) {
        if (String.isBlank(raw)) return raw;
        String s = raw.trim();
        if (s.startsWith('```')) {
            s = s.replaceFirst('^```[a-zA-Z]*\\s*', '');
            if (s.endsWith('```')) s = s.substring(0, s.length() - 3).trim();
        }
        return s;
    }
}
