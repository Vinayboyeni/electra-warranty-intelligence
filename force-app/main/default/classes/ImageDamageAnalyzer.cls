/**
 * ImageDamageAnalyzer
 *
 * Invoked by ARIA after a dealer uploads a photo on WhatsApp. Three jobs:
 *   1. Run a multimodal vision analysis (today: mocked per part category;
 *      production swap-in: ConnectApi.EinsteinLLM with a vision template).
 *   2. Persist the analysis text on Claim.AI_Image_Analysis__c.
 *   3. Make the photo itself reachable from the Claim record AND from the
 *      approver Slack card by:
 *        a) linking the ContentDocument to the Claim (Files related list)
 *        b) creating a public ContentDistribution
 *        c) writing the public URL to Claim.PhotoPublicUrl__c
 *
 * Wrapped in try/catch around side effects so a sharing/permission hiccup
 * never blocks the textual analysis from being saved.
 */
public without sharing class ImageDamageAnalyzer {
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

        @InvocableVariable(label='Photo Public URL')
        public String photoPublicUrl;
    }

    @InvocableMethod(label='Analyze Image Damage' description='Invokes a multimodal Vision AI to analyze uploaded photos of a damaged part. Returns a detailed analysis of structural integrity, impact marks, and an overall boolean flag indicating if catastrophic damage is present.')
    public static List<Result> analyze(List<Input> inputs) {
        List<Result> results = new List<Result>();

        for (Input req : inputs) {
            Result res = new Result();

            // 1. Run the vision analysis (mocked for hackathon)
            String analysisText = runMockedVisionAnalysis(req.partName);
            Boolean damaged = req.partName != null
                && req.partName.toLowerCase().contains('pump');
            res.analysisResult = analysisText;
            res.isDamaged = damaged;

            // 2. Save analysis text on the Claim
            try {
                update new Claim(
                    Id = req.claimId,
                    AI_Image_Analysis__c = analysisText
                );
            } catch (Exception e) {
                System.debug('Error saving image analysis: ' + e.getMessage());
            }

            // 3. Link photo to Claim + create public URL
            //    (so approver sees the photo in Slack + on the Claim record)
            String publicUrl = linkPhotoAndCreateDistribution(req.claimId, req.imageUrl);
            res.photoPublicUrl = publicUrl;

            results.add(res);
        }

        return results;
    }

    /**
     * Hackathon stand-in for a real vision LLM. Switches on part name to
     * produce a contextually plausible analysis. Replace with a real
     * ConnectApi.EinsteinLLM multimodal call when going to production.
     */
    private static String runMockedVisionAnalysis(String partName) {
        if (String.isBlank(partName)) {
            return 'Image analysis complete. No structural anomalies detected from the provided angles.';
        }
        String p = partName.toLowerCase();
        if (p.contains('pump')) {
            return 'Multi-modal analysis detects a sharp crack in the housing of the ' + partName + '. The fracture pattern suggests external impact rather than internal mechanical failure. Visual evidence does not support a manufacturing defect.';
        }
        if (p.contains('battery')) {
            return 'Thermal imaging analysis indicates localized overheating near the terminal. Case integrity is maintained, but internal cell bulging is visible in the profile view. This matches expected patterns for a warranty-covered electrical failure.';
        }
        return 'Image analysis complete for ' + partName + '. Surface wear is within acceptable tolerances for the vehicle mileage. No obvious fractures or impact marks detected from the provided angles.';
    }

    /**
     * Resolves the ContentVersion from the imageUrl (which is in the
     * /sfc/servlet.shepherd/version/download/{cvId} format produced by
     * GetWhatsAppMediaUrl), then:
     *   a) creates a ContentDocumentLink on the Claim — so the file shows
     *      in the Claim's Files related list
     *   b) creates a ContentDistribution — yields a public URL the approver
     *      Slack card can link to
     *   c) writes the URL to Claim.PhotoPublicUrl__c
     *
     * Returns the public URL, or null on any failure.
     */
    private static String linkPhotoAndCreateDistribution(Id claimId, String imageUrl) {
        if (claimId == null || String.isBlank(imageUrl)) return null;
        if (Test.isRunningTest()) return null;

        try {
            // Parse the ContentVersion Id from the shepherd URL
            String cvId = parseContentVersionId(imageUrl);
            if (String.isBlank(cvId)) return null;

            ContentVersion cv = [
                SELECT Id, ContentDocumentId, Title FROM ContentVersion
                WHERE Id = :cvId LIMIT 1
            ];

            // a) link to Claim if not already linked
            List<ContentDocumentLink> existing = [
                SELECT Id FROM ContentDocumentLink
                WHERE ContentDocumentId = :cv.ContentDocumentId
                  AND LinkedEntityId = :claimId
                LIMIT 1
            ];
            if (existing.isEmpty()) {
                insert new ContentDocumentLink(
                    ContentDocumentId = cv.ContentDocumentId,
                    LinkedEntityId    = claimId,
                    ShareType         = 'V',
                    Visibility        = 'AllUsers'
                );
            }

            // b) create public ContentDistribution
            ContentDistribution cd = new ContentDistribution(
                Name                            = 'Damage photo for claim ' + claimId,
                ContentVersionId                = cv.Id,
                PreferencesAllowViewInBrowser   = true,
                PreferencesLinkLatestVersion    = false,
                PreferencesNotifyOnVisit        = false,
                PreferencesPasswordRequired     = false,
                PreferencesAllowOriginalDownload = true
            );
            insert cd;

            ContentDistribution result = [
                SELECT DistributionPublicUrl, ContentDownloadUrl
                FROM ContentDistribution WHERE Id = :cd.Id LIMIT 1
            ];
            String publicUrl = !String.isBlank(result.DistributionPublicUrl)
                ? result.DistributionPublicUrl
                : result.ContentDownloadUrl;
            if (String.isBlank(publicUrl)) return null;

            // c) save URL to Claim
            try {
                update new Claim(Id = claimId, PhotoPublicUrl__c = publicUrl);
            } catch (Exception writeErr) {
                System.debug('PhotoPublicUrl writeback failed: ' + writeErr.getMessage());
            }
            return publicUrl;
        } catch (Exception e) {
            System.debug('linkPhotoAndCreateDistribution failed: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Pulls the ContentVersion 18-or-15-char Id off the end of an imageUrl
     * shaped like '/sfc/servlet.shepherd/version/download/068xxxxxxxxxxxx'.
     */
    private static String parseContentVersionId(String url) {
        if (String.isBlank(url)) return null;
        String trimmed = url;
        if (trimmed.endsWith('/')) trimmed = trimmed.substring(0, trimmed.length() - 1);
        Integer slash = trimmed.lastIndexOf('/');
        if (slash < 0) return null;
        String tail = trimmed.substring(slash + 1);
        // Strip any trailing query string
        Integer q = tail.indexOf('?');
        if (q >= 0) tail = tail.substring(0, q);
        if (tail.length() != 15 && tail.length() != 18) return null;
        if (!tail.startsWith('068')) return null;  // ContentVersion key prefix
        return tail;
    }
}
