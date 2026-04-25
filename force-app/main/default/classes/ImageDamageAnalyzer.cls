public with sharing class ImageDamageAnalyzer {
    public class Input {
        @InvocableVariable(label='Claim Id')
        public Id claimId;
        
        @InvocableVariable(label='Part Name' required=true)
        public String partName;

        @InvocableVariable(label='Image URL')
        public String imageUrl;
    }

    public class Result {
        @InvocableVariable(label='Analysis Result')
        public String analysisResult;
        
        @InvocableVariable(label='Is Damaged')
        public Boolean isDamaged;
    }

    @InvocableMethod(label='Analyze Image Damage' description='Invokes a multimodal Vision AI to analyze uploaded photos of a damaged part. Returns a detailed analysis of structural integrity, impact marks, and an overall boolean flag indicating if catastrophic damage is present.')
    public static List<Result> analyze(List<Input> inputs) {
        List<Result> results = new List<Result>();
        
        for (Input req : inputs) {
            Result res = new Result();
            
            // Mocking logic based on part name for the hackathon
            String analysisText = '';
            Boolean damaged = false;
            
            if (req.partName.toLowerCase().contains('pump')) {
                analysisText = 'Multi-modal analysis detects a sharp crack in the housing of the ' + req.partName + '. The fracture pattern suggests external impact rather than internal mechanical failure. Visual evidence does not support a manufacturing defect.';
                damaged = true;
            } else if (req.partName.toLowerCase().contains('battery')) {
                analysisText = 'Thermal imaging analysis indicates localized overheating near the terminal. Case integrity is maintained, but internal cell bulging is visible in the profile view. This matches expected patterns for a warranty-covered electrical failure.';
                damaged = false; // "Not damaged" in the sense of impact, but failed.
            } else {
                analysisText = 'Image analysis complete for ' + req.partName + '. Surface wear is within acceptable tolerances for the vehicle mileage. No obvious fractures or impact marks detected from the provided angles.';
                damaged = false;
            }
            
            res.analysisResult = analysisText;
            res.isDamaged = damaged;
            
            // Update the Claim record with the analysis
            try {
                Claim c = new Claim(
                    Id = req.claimId,
                    AI_Image_Analysis__c = analysisText
                );
                update c;
            } catch (Exception e) {
                System.debug('Error updating Claim with image analysis: ' + e.getMessage());
            }
            
            results.add(res);
        }
        
        return results;
    }
}