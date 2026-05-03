@IsTest
private class GetPendingClarificationTest {

    private static Claim setup(String status, String question) {
        Account dealer = TestDataFactory.createDealer();
        Vehicle v = TestDataFactory.createVehicle();
        Claim c = TestDataFactory.createClaim(dealer.Id, v.AssetId);
        c.Status = status;
        if (String.isNotBlank(question)) {
            c.ClarificationRequest__c = question;
        }
        update c;
        return c;
    }

    @IsTest
    static void hasPendingClarification_returnsQuestion() {
        Claim c = setup('Needs More Info', 'Send the inverter serial number');
        GetPendingClarification.Input inp = new GetPendingClarification.Input();
        inp.claimNumber = c.Name;

        Test.startTest();
        List<GetPendingClarification.Result> r =
            GetPendingClarification.getClarification(new List<GetPendingClarification.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].hasPendingClarification);
        System.assertEquals('Send the inverter serial number', r[0].clarificationQuestion);
    }

    @IsTest
    static void noQuestionOnFile_returnsFalse() {
        Claim c = setup('Needs More Info', null);
        GetPendingClarification.Input inp = new GetPendingClarification.Input();
        inp.claimNumber = c.Name;

        Test.startTest();
        List<GetPendingClarification.Result> r =
            GetPendingClarification.getClarification(new List<GetPendingClarification.Input>{inp});
        Test.stopTest();

        System.assertEquals(false, r[0].hasPendingClarification);
    }

    @IsTest
    static void otherStatus_returnsNoPending() {
        Claim c = setup('Pending Approver Review', null);
        GetPendingClarification.Input inp = new GetPendingClarification.Input();
        inp.claimNumber = c.Name;

        Test.startTest();
        List<GetPendingClarification.Result> r =
            GetPendingClarification.getClarification(new List<GetPendingClarification.Input>{inp});
        Test.stopTest();

        System.assertEquals(false, r[0].hasPendingClarification);
        System.assertNotEquals(null, r[0].message);
    }

    @IsTest
    static void claimNotFound_returnsMessage() {
        GetPendingClarification.Input inp = new GetPendingClarification.Input();
        inp.claimNumber = 'WC-NOPE9';

        Test.startTest();
        List<GetPendingClarification.Result> r =
            GetPendingClarification.getClarification(new List<GetPendingClarification.Input>{inp});
        Test.stopTest();

        System.assertEquals(false, r[0].hasPendingClarification);
        System.assertNotEquals(null, r[0].message);
    }

    @IsTest
    static void byVin_findsClaim() {
        Claim c = setup('Needs More Info', 'What is the odometer?');
        Vehicle v = [SELECT VehicleIdentificationNumber FROM Vehicle WHERE AssetId = :c.Vehicle__c LIMIT 1];

        GetPendingClarification.Input inp = new GetPendingClarification.Input();
        inp.vin = v.VehicleIdentificationNumber;

        Test.startTest();
        List<GetPendingClarification.Result> r =
            GetPendingClarification.getClarification(new List<GetPendingClarification.Input>{inp});
        Test.stopTest();

        System.assertEquals(true, r[0].hasPendingClarification);
    }

    @IsTest
    static void nullList_returnsEmpty() {
        Test.startTest();
        List<GetPendingClarification.Result> r = GetPendingClarification.getClarification(null);
        Test.stopTest();

        System.assertEquals(0, r.size());
    }

    @IsTest
    static void blankInputs_handlesGracefully() {
        GetPendingClarification.Input inp = new GetPendingClarification.Input();

        Test.startTest();
        List<GetPendingClarification.Result> r =
            GetPendingClarification.getClarification(new List<GetPendingClarification.Input>{inp});
        Test.stopTest();

        System.assertEquals(false, r[0].hasPendingClarification);
    }
}