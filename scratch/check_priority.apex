Schema.DescribeFieldResult F = Claim.Priority__c.getDescribe();
List<Schema.PicklistEntry> P = F.getPicklistValues();
for (Schema.PicklistEntry pe : P) {
    System.debug('VALUE: ' + pe.getValue());
}
