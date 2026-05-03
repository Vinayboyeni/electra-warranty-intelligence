/**
 * Retrieves the URL of the latest image attachment for the current chat
 * session. Works for WhatsApp and Embedded Service portal chats.
 *
 * Lookup order (returns at first hit):
 *   1. ContentDocumentLink linked directly to the supplied MessagingSession Id
 *   2. ContentDocumentLink linked to most recent session of the supplied
 *      MessagingEndUser
 *   3. Most recent image ContentVersion created in the last 10 minutes
 *      (org-wide heuristic — works for demo where one chat is active)
 *
 * Image detection: case-insensitive match on FileExtension OR FileType.
 *
 * Always returns a Result — never throws — so the caller can decide
 * whether to proceed when no image is found.
 */
public without sharing class GetWhatsAppMediaUrl {
    private static final Set<String> IMAGE_EXTS = new Set<String>{
        'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'heif', 'bmp'
    };

    public class Input {
        @InvocableVariable(label='Messaging Session Id' description='Optional. If provided, fetches attachment for this session.')
        public String messagingSessionId;

        @InvocableVariable(label='Messaging User Id' description='Optional. If provided, fetches latest attachment for this user.')
        public String messagingUserId;
    }

    public class Result {
        @InvocableVariable(label='Image URL' description='Salesforce content URL for the latest image.')
        public String imageUrl;
        @InvocableVariable(label='Content Document Id' description='Id of the latest content document.')
        public String contentDocumentId;
        @InvocableVariable(label='Success' description='True if an image was found.')
        public Boolean success;
    }

    @InvocableMethod(label='Get WhatsApp Media URL' description='Retrieves the URL of the latest image attachment uploaded by the dealer in the current chat session.')
    public static List<Result> getMediaUrl(List<Input> inputs) {
        List<Result> outputs = new List<Result>();
        if (inputs == null) return outputs;

        for (Input input : inputs) {
            Result r = new Result();
            r.success = false;

            try {
                Id sessionId;
                if (String.isNotBlank(input.messagingSessionId)) {
                    sessionId = (Id) input.messagingSessionId;
                } else if (String.isNotBlank(input.messagingUserId)) {
                    List<MessagingSession> sessions = [
                        SELECT Id FROM MessagingSession
                        WHERE MessagingEndUserId = :input.messagingUserId
                        ORDER BY CreatedDate DESC LIMIT 1
                    ];
                    if (!sessions.isEmpty()) sessionId = sessions[0].Id;
                }

                ContentVersion cv = null;
                Id linkedDocId = null;

                // Tier 1: ContentDocumentLink on the session
                if (sessionId != null) {
                    List<ContentDocumentLink> links = [
                        SELECT ContentDocumentId
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :sessionId
                    ];
                    if (!links.isEmpty()) {
                        Set<Id> docIds = new Set<Id>();
                        for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);
                        List<ContentVersion> versions = [
                            SELECT Id, ContentDocumentId, FileExtension, FileType, CreatedDate
                            FROM ContentVersion
                            WHERE ContentDocumentId IN :docIds
                              AND IsLatest = true
                            ORDER BY CreatedDate DESC
                        ];
                        for (ContentVersion v : versions) {
                            if (isImage(v)) { cv = v; linkedDocId = v.ContentDocumentId; break; }
                        }
                    }
                }

                // Tier 2: ContentDocumentLink on the messaging end-user
                if (cv == null && String.isNotBlank(input.messagingUserId)) {
                    Id userId = (Id) input.messagingUserId;
                    List<ContentDocumentLink> userLinks = [
                        SELECT ContentDocumentId
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :userId
                    ];
                    if (!userLinks.isEmpty()) {
                        Set<Id> docIds = new Set<Id>();
                        for (ContentDocumentLink l : userLinks) docIds.add(l.ContentDocumentId);
                        List<ContentVersion> versions = [
                            SELECT Id, ContentDocumentId, FileExtension, FileType, CreatedDate
                            FROM ContentVersion
                            WHERE ContentDocumentId IN :docIds
                              AND IsLatest = true
                            ORDER BY CreatedDate DESC
                        ];
                        for (ContentVersion v : versions) {
                            if (isImage(v)) { cv = v; linkedDocId = v.ContentDocumentId; break; }
                        }
                    }
                }

                // Tier 3: Most recent image ContentVersion in last 10 minutes
                //   Last-resort fallback when the link isn't on session or user.
                if (cv == null) {
                    Datetime cutoff = Datetime.now().addMinutes(-10);
                    List<ContentVersion> recent = [
                        SELECT Id, ContentDocumentId, FileExtension, FileType, CreatedDate
                        FROM ContentVersion
                        WHERE CreatedDate >= :cutoff
                          AND IsLatest = true
                        ORDER BY CreatedDate DESC LIMIT 25
                    ];
                    for (ContentVersion v : recent) {
                        if (isImage(v)) { cv = v; linkedDocId = v.ContentDocumentId; break; }
                    }
                }

                if (cv != null) {
                    r.imageUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;
                    r.contentDocumentId = linkedDocId;
                    r.success = true;
                }
            } catch (Exception e) {
                System.debug('GetWhatsAppMediaUrl swallowed: ' + e.getMessage());
            }
            outputs.add(r);
        }
        return outputs;
    }

    private static Boolean isImage(ContentVersion v) {
        if (v == null) return false;
        if (String.isNotBlank(v.FileExtension)
            && IMAGE_EXTS.contains(v.FileExtension.toLowerCase())) return true;
        if (String.isNotBlank(v.FileType)) {
            String t = v.FileType.toUpperCase();
            if (t == 'PNG' || t == 'JPG' || t == 'JPEG' || t == 'GIF'
                || t == 'WEBP' || t == 'HEIC' || t == 'HEIF' || t == 'BMP'
                || t == 'IMAGE') return true;
        }
        return false;
    }
}