// Probes each Prompt Template via ConnectApi and reports its live state.
// "OK live" means template is Active and the LLM responded.
// "Empty" means the template exists but isn't Active OR the input variable
// name doesn't match what the template expects.
// "Error" means a real failure (license, perm, network).

System.debug('========== PROMPT TEMPLATE LIVE PROBE ==========');

List<Claim> claims = [
    SELECT Id, Name, PartCategory__c, Symptom__c, Diagnosis__c,
           Odometer__c, EstimatedCost__c, Eligibility__c, ReasonCode__c,
           Account.Name, Vehicle__r.Name
    FROM Claim WHERE Status IN ('Pending Approver Review', 'Submitted')
    LIMIT 1
];
if (claims.isEmpty()) { System.debug('No test claim'); } else {
    Claim c = claims[0];
    System.debug('Test claim: ' + c.Name);

    Map<String, Map<String, ConnectApi.WrappedValue>> tests =
        new Map<String, Map<String, ConnectApi.WrappedValue>>();

    Map<String, Object> claimMap = new Map<String, Object>{
        'Id' => c.Id, 'Name' => c.Name, 'PartCategory__c' => c.PartCategory__c,
        'Symptom__c' => c.Symptom__c, 'Diagnosis__c' => c.Diagnosis__c,
        'Odometer__c' => c.Odometer__c, 'EstimatedCost__c' => c.EstimatedCost__c,
        'Eligibility__c' => c.Eligibility__c, 'ReasonCode__c' => c.ReasonCode__c
    };
    ConnectApi.WrappedValue claimWv = new ConnectApi.WrappedValue();
    claimWv.value = claimMap;
    tests.put('Claim_Risk_Verdict',
        new Map<String, ConnectApi.WrappedValue>{ 'Input:Claim' => claimWv });
    tests.put('Compose_Repair_Guidance_Message',
        new Map<String, ConnectApi.WrappedValue>{ 'Input:Claim' => claimWv });

    ConnectApi.WrappedValue reasonWv = new ConnectApi.WrappedValue();
    reasonWv.value = 'Wear & Tear';
    ConnectApi.WrappedValue ratWv = new ConnectApi.WrappedValue();
    ratWv.value = 'Not covered under standard warranty.';
    tests.put('Compose_Dealer_Rejection_Message',
        new Map<String, ConnectApi.WrappedValue>{
            'Input:Claim'             => claimWv,
            'Input:ReasonCode'        => reasonWv,
            'Input:AdjusterRationale' => ratWv
        });

    for (String devName : tests.keySet()) {
        System.debug('--- ' + devName + ' ---');
        try {
            ConnectApi.EinsteinPromptTemplateGenerationsInput inp =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            ConnectApi.EinsteinLlmAdditionalConfigInput addCfg =
                new ConnectApi.EinsteinLlmAdditionalConfigInput();
            addCfg.applicationName = 'PromptBuilderPreview';
            inp.additionalConfig = addCfg;
            inp.isPreview = false;
            inp.inputParams = tests.get(devName);

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation r =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(devName, inp);

            Integer count = (r == null || r.generations == null) ? 0 : r.generations.size();
            if (count > 0 && String.isNotBlank(r.generations[0].text)) {
                System.debug('  ✅ OK LIVE — ' + count + ' generation(s)');
                System.debug('  preview: ' + r.generations[0].text.left(180));
            } else {
                System.debug('  ⚠ EMPTY — template exists but no LLM response.');
                System.debug('     Likely cause: template not Activated in Prompt Builder');
                System.debug('     OR input variable name in template != "Claim" (we send Input:Claim)');
            }
        } catch (Exception e) {
            System.debug('  ❌ ERROR — ' + e.getMessage().left(200));
        }
    }
}
