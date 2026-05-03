// Probe Claim_Risk_Verdict template against a specific claim.
// Dumps the raw response so we can see whether the LLM is hallucinating
// "missing fields" or whether ConnectApi is genuinely returning empty.

String claimName = 'WC-HFCAU';
List<Claim> rows = [
    SELECT Id, Name, PartCategory__c, Symptom__c, Odometer__c,
           EstimatedCost__c, Eligibility__c
    FROM Claim WHERE Name = :claimName LIMIT 1
];
if (rows.isEmpty()) { System.debug('Not found: ' + claimName); }
else {
    Claim c = rows[0];
    System.debug('Input fields:');
    System.debug('  PartCategory__c: ' + c.PartCategory__c);
    System.debug('  Symptom__c: ' + c.Symptom__c);
    System.debug('  Odometer__c: ' + c.Odometer__c);
    System.debug('  EstimatedCost__c: ' + c.EstimatedCost__c);
    System.debug('  Eligibility__c: ' + c.Eligibility__c);

    Map<String, Object> claimMap = new Map<String, Object>{
        'Id' => c.Id,
        'Name' => c.Name,
        'PartCategory__c' => c.PartCategory__c,
        'Symptom__c' => c.Symptom__c,
        'Odometer__c' => c.Odometer__c,
        'EstimatedCost__c'=> c.EstimatedCost__c,
        'Eligibility__c' => c.Eligibility__c
    };

    ConnectApi.EinsteinPromptTemplateGenerationsInput inp =
        new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    ConnectApi.EinsteinLlmAdditionalConfigInput addCfg =
        new ConnectApi.EinsteinLlmAdditionalConfigInput();
    addCfg.applicationName = 'PromptBuilderPreview';
    inp.additionalConfig = addCfg;
    inp.isPreview = false;

    ConnectApi.WrappedValue wv = new ConnectApi.WrappedValue();
    wv.value = claimMap;
    inp.inputParams = new Map<String, ConnectApi.WrappedValue>{
        'Input:Claim' => wv
    };

    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation r =
        ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Claim_Risk_Verdict', inp);
    System.debug('Generation errors: ' + JSON.serialize(r.generationErrors));
    System.debug('Generations count: ' + (r.generations == null ? 0 : r.generations.size()));
    if (r.generations != null && !r.generations.isEmpty()) {
        String fullText = r.generations[0].text;
        System.debug('Raw response length: ' + (fullText == null ? 0 : fullText.length()));
        // Print in chunks to avoid log truncation
        if (fullText != null) {
            Integer chunkSize = 200;
            for (Integer i = 0; i < fullText.length(); i += chunkSize) {
                Integer endIdx = Math.min(i + chunkSize, fullText.length());
                System.debug('  [' + i + ']: ' + fullText.substring(i, endIdx));
            }
        }
    }
    System.debug('Resolved prompt length: ' + (r.prompt == null ? 0 : r.prompt.length()));
    if (r.prompt != null) {
        // Print prompt in chunks too
        Integer chunkSize = 200;
        for (Integer i = 0; i < r.prompt.length(); i += chunkSize) {
            Integer endIdx = Math.min(i + chunkSize, r.prompt.length());
            System.debug('  prompt[' + i + ']: ' + r.prompt.substring(i, endIdx));
        }
    }
}
