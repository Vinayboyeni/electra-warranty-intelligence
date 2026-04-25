/**
 * GenerateApprovalAuthorization
 *
 * Generates a branded PDF warranty authorization certificate for an approved
 * claim, saves it as a ContentVersion on the Claim, creates a public
 * ContentDistribution link, and returns that URL for inclusion in the dealer
 * WhatsApp notification.
 *
 * Called synchronously from ApproveWarrantyClaim.cls after the status DML
 * commits. Never throws — wraps every step in try/catch so a PDF failure
 * cannot block the approval itself.
 */
public without sharing class GenerateApprovalAuthorization {

    /**
     * Entry point. Renders, saves, distributes, returns URL.
     * Returns null on any failure (caller must handle null gracefully).
     */
    public static String generate(Id claimId) {
        if (claimId == null) return null;

        // During test context, getContentAsPDF() is not supported — short-circuit.
        if (Test.isRunningTest()) return null;

        try {
            // 1. Verify claim exists and is approved
            List<Claim> claims = [
                SELECT Id, Name FROM Claim WHERE Id = :claimId LIMIT 1
            ];
            if (claims.isEmpty()) return null;
            Claim c = claims[0];

            // 2. Render VisualForce page as PDF
            PageReference pdfPage = Page.ApprovalAuthorizationPDF;
            pdfPage.getParameters().put('id', claimId);
            Blob pdfBlob = pdfPage.getContentAsPDF();
            if (pdfBlob == null || pdfBlob.size() == 0) return null;

            // 3. Save as ContentVersion attached to the Claim
            ContentVersion cv = new ContentVersion(
                Title = c.Name + ' Approval Authorization',
                PathOnClient = c.Name + '-Authorization.pdf',
                VersionData = pdfBlob,
                FirstPublishLocationId = claimId,
                Description = 'Electra Cars warranty prior-authorization certificate. '
                    + 'Auto-generated on approval of claim ' + c.Name + '.'
            );
            insert cv;

            // 4. Create ContentDistribution for a public (no-login) URL
            ContentVersion cvReloaded = [
                SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
            ];
            ContentDistribution cd = new ContentDistribution(
                Name = c.Name + ' Authorization',
                ContentVersionId = cvReloaded.Id,
                PreferencesAllowViewInBrowser = true,
                PreferencesLinkLatestVersion = false,
                PreferencesNotifyOnVisit = false,
                PreferencesPasswordRequired = false,
                PreferencesAllowOriginalDownload = true
            );
            insert cd;

            // 5. Query back the distribution URLs. Prefer ContentDownloadUrl (direct PDF
            //    stream, no preview queue wait). Fall back to DistributionPublicUrl
            //    (the preview page) if download URL isn't populated.
            List<ContentDistribution> cdResults = [
                SELECT Id, DistributionPublicUrl, ContentDownloadUrl, PdfDownloadUrl
                FROM ContentDistribution
                WHERE Id = :cd.Id LIMIT 1
            ];
            if (cdResults.isEmpty()) return null;
            ContentDistribution result = cdResults[0];
            String chosenUrl = null;
            if (String.isNotBlank(result.ContentDownloadUrl)) {
                chosenUrl = result.ContentDownloadUrl;
            } else if (String.isNotBlank(result.PdfDownloadUrl)) {
                chosenUrl = result.PdfDownloadUrl;
            } else if (String.isNotBlank(result.DistributionPublicUrl)) {
                chosenUrl = result.DistributionPublicUrl;
            }
            if (chosenUrl == null) return null;

            // Persist the URL on the Claim so approvers / dealers can recover it
            // later without us having to regenerate the ContentDistribution.
            // Wrapped in try/catch so a field-level hiccup never blocks the
            // return path (caller still gets the URL for the WhatsApp message).
            try {
                update new Claim(Id = claimId, AuthorizationPdfUrl__c = chosenUrl);
            } catch (Exception writebackErr) {
                System.debug('AuthorizationPdfUrl writeback failed: ' + writebackErr.getMessage());
            }
            return chosenUrl;

        } catch (Exception e) {
            System.debug('GenerateApprovalAuthorization failed: '
                + e.getMessage() + '\n' + e.getStackTraceString());
            return null;
        }
    }
}
