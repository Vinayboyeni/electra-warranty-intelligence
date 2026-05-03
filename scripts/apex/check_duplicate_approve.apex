// Check if Approve fired twice on this claim — look at FeedItem timestamps
// and Claim.LastModifiedDate, plus any attached PDFs.
Id targetId = '0Zkbm0000004We1CAE';
List<FeedItem> feed = [
    SELECT Id, Body, CreatedDate, CreatedBy.Name
    FROM FeedItem WHERE ParentId = :targetId
    ORDER BY CreatedDate ASC
];
System.debug('Total feed items: ' + feed.size());
Integer dealerNotices = 0, customerNotices = 0;
for (FeedItem fi : feed) {
    String b = fi.Body;
    if (b == null) continue;
    if (b.contains('WhatsApp decision sent') || b.contains('Decision audit')) dealerNotices++;
    if (b.contains('Customer WhatsApp')) customerNotices++;
    System.debug('  [' + fi.CreatedDate + '] ' + b.left(120));
}
System.debug('Dealer notice count: ' + dealerNotices);
System.debug('Customer notice count: ' + customerNotices);
List<ContentVersion> pdfs = [
    SELECT Id, Title, CreatedDate
    FROM ContentVersion
    WHERE FirstPublishLocationId = :targetId
    ORDER BY CreatedDate ASC
];
System.debug('PDF versions: ' + pdfs.size());
for (ContentVersion cv : pdfs) System.debug('  [' + cv.CreatedDate + '] ' + cv.Title);
