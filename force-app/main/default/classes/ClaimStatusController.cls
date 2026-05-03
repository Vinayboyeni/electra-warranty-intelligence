/**
 * ClaimStatusController
 *
 * @AuraEnabled wrapper that lets the public Experience Cloud "Electra
 * Warranty Portal" surface a claim-status lookup widget without exposing
 * the existing @InvocableMethod GetClaimStatus directly.
 *
 * Runs `without sharing` because the portal serves dealer service
 * advisors looking up THEIR submitted claims — and the agent service
 * user that owns claims rarely has explicit sharing rules to the guest
 * user's profile. The lookup result is filtered by claim number / VIN
 * the dealer ALREADY KNOWS, so this is not a privacy-sensitive surface.
 */
public without sharing class ClaimStatusController {

    public class ClaimStatusInfo {
        @AuraEnabled public Boolean found;
        @AuraEnabled public Id claimId;
        @AuraEnabled public String claimNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String partCategory;
        @AuraEnabled public String symptom;
        @AuraEnabled public String dealerName;
        @AuraEnabled public String submissionDate;
        @AuraEnabled public String slaDueDate;
        @AuraEnabled public String approverComment;
        @AuraEnabled public String nextStep;
        @AuraEnabled public Decimal estimatedCost;
        @AuraEnabled public Decimal approvedAmount;
        @AuraEnabled public String authorizationPdfUrl;
        @AuraEnabled public String clarificationQuestion;
        @AuraEnabled public Boolean isAwaitingResponse;
        @AuraEnabled public String dealerResponseSummary;
    }

    public class SubmissionResult {
        @AuraEnabled public Boolean submitted;
        @AuraEnabled public String message;
        @AuraEnabled public String newStatus;
    }

    public class AttachedFile {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public Long fileSize;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String downloadUrl;
        @AuraEnabled public Boolean isImage;
    }

    /**
     * Look up a single claim by claim number OR VIN.
     * Returns a populated ClaimStatusInfo with `found=false` when nothing
     * matches — the LWC renders an empty-state in that case.
     */
    @AuraEnabled(cacheable=false)
    public static ClaimStatusInfo lookup(String claimNumber, String vin) {
        ClaimStatusInfo info = new ClaimStatusInfo();
        info.found = false;

        try {
            // All queries run in SYSTEM_MODE so the Site Guest User (which
            // can't be granted Claim/Vehicle Read by license) can still use
            // the public tracker.
            List<Claim> rows = null;
            String trimmedClaim = String.isNotBlank(claimNumber) ? claimNumber.trim() : null;
            String trimmedVin = String.isNotBlank(vin) ? vin.trim() : null;

            if (String.isNotBlank(trimmedClaim)) {
                rows = (List<Claim>) Database.query(
                    'SELECT Id, Name, Status, PartCategory__c, Symptom__c, '
                    + 'EstimatedCost__c, ApprovedAmount, Account.Name, ApprovalDate__c, '
                    + 'RejectionDate__c, SLA_Due_Date__c, ClarificationRequest__c, '
                    + 'DecisionRationale__c, RequiresFollowUp__c, DealerResponseSummary__c, '
                    + 'Vehicle__c, CreatedDate '
                    + 'FROM Claim WHERE Name = :trimmedClaim LIMIT 1',
                    AccessLevel.SYSTEM_MODE
                );
            } else if (String.isNotBlank(trimmedVin)) {
                // VIN lookup: find the most recent claim for this VIN
                List<Vehicle> vehicles = (List<Vehicle>) Database.query(
                    'SELECT AssetId FROM Vehicle '
                    + 'WHERE VehicleIdentificationNumber = :trimmedVin LIMIT 1',
                    AccessLevel.SYSTEM_MODE
                );
                if (!vehicles.isEmpty() && vehicles[0].AssetId != null) {
                    Id vehicleAssetId = vehicles[0].AssetId;
                    rows = (List<Claim>) Database.query(
                        'SELECT Id, Name, Status, PartCategory__c, Symptom__c, '
                        + 'EstimatedCost__c, ApprovedAmount, Account.Name, ApprovalDate__c, '
                        + 'RejectionDate__c, SLA_Due_Date__c, ClarificationRequest__c, '
                        + 'DecisionRationale__c, RequiresFollowUp__c, DealerResponseSummary__c, '
                        + 'Vehicle__c, CreatedDate '
                        + 'FROM Claim WHERE Vehicle__c = :vehicleAssetId '
                        + 'ORDER BY CreatedDate DESC LIMIT 1',
                        AccessLevel.SYSTEM_MODE
                    );
                }
            }

            if (rows == null || rows.isEmpty()) return info;

            Claim c = rows[0];
            info.found          = true;
            info.claimId        = c.Id;
            info.claimNumber    = c.Name;
            info.status         = c.Status;
            info.partCategory   = c.PartCategory__c;
            info.symptom        = c.Symptom__c;
            info.dealerName     = (c.Account != null) ? c.Account.Name : null;
            info.estimatedCost  = c.EstimatedCost__c;
            info.approvedAmount = c.ApprovedAmount;
            info.submissionDate = c.CreatedDate != null
                ? c.CreatedDate.format('MMM d, yyyy h:mm a') : null;
            info.slaDueDate     = c.SLA_Due_Date__c != null
                ? c.SLA_Due_Date__c.format('MMM d, yyyy h:mm a') : null;
            info.approverComment = c.DecisionRationale__c;

            info.clarificationQuestion = c.ClarificationRequest__c;
            info.dealerResponseSummary = c.DealerResponseSummary__c;
            info.isAwaitingResponse = ('Needs More Info'.equalsIgnoreCase(c.Status)
                && c.RequiresFollowUp__c == true
                && String.isNotBlank(c.ClarificationRequest__c));

            info.nextStep = inferNextStep(c);
            return info;
        } catch (Exception e) {
            System.debug('ClaimStatusController.lookup error: ' + e.getMessage());
            return info;
        }
    }

    /**
     * Records the dealer's written answer to the OEM approver's clarification
     * request. Updates DealerResponseSummary__c, flips Status back to
     * "Pending Approver Review", and clears the RequiresFollowUp__c flag.
     *
     * Called from the public claim-status LWC when the dealer types their
     * response into the textarea that appears under the "Needs More Info"
     * banner. After submission, the existing Slack_Notify_Approver_Flow
     * re-fires automatically (because Status changed back to Pending Approver
     * Review) and the OEM approver gets a fresh card with the dealer
     * response inline.
     */
    @AuraEnabled
    public static SubmissionResult submitResponse(String claimNumber, String dealerResponse) {
        SubmissionResult res = new SubmissionResult();
        res.submitted = false;

        if (String.isBlank(claimNumber)) {
            res.message = 'Claim number is required.';
            return res;
        }
        if (String.isBlank(dealerResponse)) {
            res.message = 'Please type your response before submitting.';
            return res;
        }

        try {
            String trimmedClaim = claimNumber.trim();
            List<Claim> rows = (List<Claim>) Database.query(
                'SELECT Id, Name, Status, RequiresFollowUp__c, DealerResponseSummary__c '
                + 'FROM Claim WHERE Name = :trimmedClaim LIMIT 1',
                AccessLevel.SYSTEM_MODE
            );
            if (rows.isEmpty()) {
                res.message = 'Claim not found.';
                return res;
            }

            Claim c = rows[0];
            if (c.Status == 'Approved' || c.Status == 'Rejected') {
                res.message = 'Claim is already ' + c.Status + '. No further response needed.';
                return res;
            }

            c.DealerResponseSummary__c = dealerResponse.trim();
            c.Status = 'Pending Approver Review';
            c.RequiresFollowUp__c = false;
            // Use SYSTEM_MODE so the update succeeds even when called by a
            // Site Guest User (Guest license forbids "Edit Claim" object
            // permission, so a regular DML would fail with FIELD_INTEGRITY_EXCEPTION).
            Database.update(c, AccessLevel.SYSTEM_MODE);

            res.submitted = true;
            res.newStatus = 'Pending Approver Review';
            res.message = 'Response sent. The OEM approver has been re-notified — SLA: 24 business hours.';
            return res;
        } catch (Exception e) {
            res.message = 'Failed to submit response: ' + e.getMessage();
            return res;
        }
    }

    /**
     * Returns files attached to a Claim record. Called from the LWC after a
     * successful upload to refresh the visible file list, and on initial
     * load so the dealer always sees what's already on file.
     *
     * Filters by image/PDF extensions only — other file types are skipped
     * to keep the UI focused on supporting evidence.
     */
    @AuraEnabled(cacheable=false)
    public static List<AttachedFile> getAttachedFiles(Id claimId) {
        List<AttachedFile> out = new List<AttachedFile>();
        if (claimId == null) return out;

        try {
            Id claimRecordId = claimId;
            // SYSTEM_MODE — guest user license can't grant ContentDocumentLink Read
            List<ContentDocumentLink> links = (List<ContentDocumentLink>) Database.query(
                'SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :claimRecordId',
                AccessLevel.SYSTEM_MODE
            );
            if (links.isEmpty()) return out;

            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

            List<ContentVersion> versions = (List<ContentVersion>) Database.query(
                'SELECT Id, ContentDocumentId, Title, FileExtension, FileType, '
                + 'ContentSize, CreatedDate '
                + 'FROM ContentVersion '
                + 'WHERE ContentDocumentId IN :docIds AND IsLatest = true '
                + 'ORDER BY CreatedDate DESC',
                AccessLevel.SYSTEM_MODE
            );

            Set<String> imageExts = new Set<String>{
                'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'heif', 'bmp'
            };

            for (ContentVersion cv : versions) {
                AttachedFile f = new AttachedFile();
                f.contentDocumentId = cv.ContentDocumentId;
                f.contentVersionId  = cv.Id;
                f.title             = cv.Title;
                f.fileExtension     = cv.FileExtension;
                f.fileSize          = cv.ContentSize;
                f.createdDate       = cv.CreatedDate;
                f.downloadUrl       = '/sfc/servlet.shepherd/version/download/' + cv.Id;
                f.isImage           = String.isNotBlank(cv.FileExtension)
                    && imageExts.contains(cv.FileExtension.toLowerCase());
                out.add(f);
            }
        } catch (Exception e) {
            System.debug('ClaimStatusController.getAttachedFiles error: ' + e.getMessage());
        }
        return out;
    }

    /**
     * Uploads a single file to the Claim by inserting a ContentVersion and
     * linking it to the Claim via ContentDocumentLink — both in SYSTEM_MODE.
     *
     * Why this exists: lightning-file-upload uses Salesforce's standard upload
     * pipeline which requires the running user to have Edit on the parent
     * record AND ContentVersion Create. The Site Guest User license forbids
     * granting either, so the standard component fails with "Can't upload".
     * This custom path bypasses the license restriction by running the DML
     * in system mode — same pattern we already use for lookup/submitResponse.
     *
     * Called from the LWC's <input type="file"> handler after the file is
     * read into base64.
     */
    @AuraEnabled
    public static AttachedFile uploadFile(Id claimId, String fileName, String base64Data, String contentType) {
        if (claimId == null || String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('Missing required upload parameters.');
        }

        try {
            // 1. Insert ContentVersion (the actual file blob) in SYSTEM_MODE
            ContentVersion cv = new ContentVersion(
                Title = fileName,
                PathOnClient = fileName,
                VersionData = EncodingUtil.base64Decode(base64Data),
                IsMajorVersion = true
            );
            Database.insert(cv, AccessLevel.SYSTEM_MODE);

            // 2. Re-query to get the ContentDocumentId (auto-populated on insert)
            ContentVersion inserted = (ContentVersion) Database.query(
                'SELECT Id, ContentDocumentId, Title, FileExtension, ContentSize, CreatedDate '
                + 'FROM ContentVersion WHERE Id = :cv.Id LIMIT 1',
                AccessLevel.SYSTEM_MODE
            )[0];

            // 3. Link the ContentDocument to the Claim
            ContentDocumentLink link = new ContentDocumentLink(
                ContentDocumentId = inserted.ContentDocumentId,
                LinkedEntityId = claimId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            Database.insert(link, AccessLevel.SYSTEM_MODE);

            Set<String> imageExts = new Set<String>{
                'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'heif', 'bmp'
            };

            AttachedFile out = new AttachedFile();
            out.contentDocumentId = inserted.ContentDocumentId;
            out.contentVersionId  = inserted.Id;
            out.title             = inserted.Title;
            out.fileExtension     = inserted.FileExtension;
            out.fileSize          = inserted.ContentSize;
            out.createdDate       = inserted.CreatedDate;
            out.downloadUrl       = '/sfc/servlet.shepherd/version/download/' + inserted.Id;
            out.isImage           = String.isNotBlank(inserted.FileExtension)
                && imageExts.contains(inserted.FileExtension.toLowerCase());
            return out;
        } catch (Exception e) {
            System.debug('uploadFile error: ' + e.getMessage());
            throw new AuraHandledException('Upload failed: ' + e.getMessage());
        }
    }

    /**
     * Creates a public ContentDistribution for every image/PDF currently
     * attached to the Claim that doesn't already have one, then stores the
     * most recent image's public URL on Claim.PhotoPublicUrl__c so the
     * Slack approver card surfaces it inline.
     *
     * Called from the LWC right after lightning-file-upload finishes.
     * Idempotent — running it multiple times only creates distributions
     * for files that don't have them yet.
     *
     * Returns the number of new ContentDistributions created.
     */
    @AuraEnabled
    public static Integer publishUploadedFiles(Id claimId) {
        if (claimId == null) return 0;

        Set<String> publishExts = new Set<String>{
            'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'heif', 'bmp', 'pdf'
        };
        Set<String> imageExts = new Set<String>{
            'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'heif', 'bmp'
        };

        try {
            Id claimRecordId = claimId;
            // 1. Find all linked ContentDocuments — SYSTEM_MODE for guest access
            List<ContentDocumentLink> links = (List<ContentDocumentLink>) Database.query(
                'SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :claimRecordId',
                AccessLevel.SYSTEM_MODE
            );
            if (links.isEmpty()) return 0;

            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

            // 2. Get the latest ContentVersion for each linked document
            List<ContentVersion> versions = (List<ContentVersion>) Database.query(
                'SELECT Id, ContentDocumentId, Title, FileExtension, FileType, CreatedDate '
                + 'FROM ContentVersion '
                + 'WHERE ContentDocumentId IN :docIds AND IsLatest = true '
                + 'ORDER BY CreatedDate DESC',
                AccessLevel.SYSTEM_MODE
            );
            if (versions.isEmpty()) return 0;

            // 3. Find which already have ContentDistribution
            Set<Id> versionIds = new Set<Id>();
            for (ContentVersion cv : versions) versionIds.add(cv.Id);

            Set<Id> alreadyDistributed = new Set<Id>();
            for (ContentDistribution cd : (List<ContentDistribution>) Database.query(
                'SELECT ContentVersionId FROM ContentDistribution WHERE ContentVersionId IN :versionIds',
                AccessLevel.SYSTEM_MODE
            )) {
                alreadyDistributed.add(cd.ContentVersionId);
            }

            // 4. Create ContentDistribution for image/PDF versions that don't have one
            List<ContentDistribution> toInsert = new List<ContentDistribution>();
            for (ContentVersion cv : versions) {
                if (alreadyDistributed.contains(cv.Id)) continue;
                String ext = cv.FileExtension == null ? '' : cv.FileExtension.toLowerCase();
                if (!publishExts.contains(ext)) continue;

                ContentDistribution cd = new ContentDistribution(
                    Name = (cv.Title != null ? cv.Title : 'Claim attachment'),
                    ContentVersionId = cv.Id,
                    PreferencesAllowViewInBrowser = true,
                    PreferencesLinkLatestVersion = false,
                    PreferencesNotifyOnVisit = false,
                    PreferencesPasswordRequired = false,
                    PreferencesAllowOriginalDownload = true
                );
                toInsert.add(cd);
            }

            if (!toInsert.isEmpty()) Database.insert(toInsert, AccessLevel.SYSTEM_MODE);

            // 5. Find the most recent IMAGE distribution and stamp its URL on Claim.PhotoPublicUrl__c
            //    (versions are sorted by CreatedDate DESC — first image hit is the latest)
            Id latestImageVersionId = null;
            for (ContentVersion cv : versions) {
                String ext = cv.FileExtension == null ? '' : cv.FileExtension.toLowerCase();
                if (imageExts.contains(ext)) {
                    latestImageVersionId = cv.Id;
                    break;
                }
            }

            if (latestImageVersionId != null) {
                Id imgVerId = latestImageVersionId;
                List<ContentDistribution> imageDists = (List<ContentDistribution>) Database.query(
                    'SELECT DistributionPublicUrl FROM ContentDistribution '
                    + 'WHERE ContentVersionId = :imgVerId '
                    + 'ORDER BY CreatedDate DESC LIMIT 1',
                    AccessLevel.SYSTEM_MODE
                );
                if (!imageDists.isEmpty()
                    && String.isNotBlank(imageDists[0].DistributionPublicUrl)) {
                    Database.update(
                        new Claim(Id = claimId,
                                  PhotoPublicUrl__c = imageDists[0].DistributionPublicUrl),
                        AccessLevel.SYSTEM_MODE
                    );
                }
            }

            return toInsert.size();
        } catch (Exception e) {
            System.debug('publishUploadedFiles error: ' + e.getMessage());
            return 0;
        }
    }

    private static String inferNextStep(Claim c) {
        if (c.Status == 'Approved') {
            return 'Approved on ' + (c.ApprovalDate__c != null
                ? c.ApprovalDate__c.format('MMM d') : 'recently')
                + '. Authorization PDF was emailed to your dealership. Submit your final repair invoice within 10 business days.';
        }
        if (c.Status == 'Rejected') {
            return 'Rejected on ' + (c.RejectionDate__c != null
                ? c.RejectionDate__c.format('MMM d') : 'recently')
                + '. To request a goodwill exception, reply GOODWILL in the dealer chat.';
        }
        if (c.Status == 'Needs More Info' && c.RequiresFollowUp__c == true) {
            return 'OEM approver requested clarification: '
                + (c.ClarificationRequest__c != null ? c.ClarificationRequest__c : 'See Chatter for details')
                + '. Use the response box below to reply.';
        }
        if (c.Status == 'Pending Approver Review') {
            return 'Awaiting OEM approver review. SLA: '
                + (c.SLA_Due_Date__c != null
                    ? c.SLA_Due_Date__c.format('MMM d, h:mm a')
                    : '24 business hours from submission') + '.';
        }
        if (c.Status == 'Submitted') {
            return 'Routing in progress — auto-approve, auto-reject, or queue for human review will fire shortly.';
        }
        return 'Status: ' + c.Status;
    }
}