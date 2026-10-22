@IsTest
private class AiAssistControllerTest {

    private static Lead newLead(String email) {
        Lead l = new Lead(LastName = 'Ai', Company = 'Ai Clinic', LeadSource = 'Other', Email = email);
        insert l;
        return l;
    }

    private static Call_Log__c newCall(Id leadId, String notes) {
        Call_Log__c c = new Call_Log__c(
            Lead__c = leadId, Call_Type__c = 'Outbound', Call_Outcome__c = 'Call Back',
            Call_Date_Time__c = Datetime.now(), Call_Notes__c = notes
        );
        insert c;
        return c;
    }

    @IsTest
    static void callSummaryIsSavedOnTheCall() {
        Call_Log__c c = newCall(newLead(null).Id, 'Spoke for six minutes, interested in unpaid claims help.');
        AiAssistController.mockResponse = 'Dr was interested and asked for a call back.';

        AiAssistController.Result r = AiAssistController.summariseCall(c.Id);

        System.assert(r.ok);
        System.assertEquals('Dr was interested and asked for a call back.', r.text);
        System.assertEquals(r.text, [SELECT AI_Summary__c FROM Call_Log__c WHERE Id = :c.Id].AI_Summary__c);
    }

    @IsTest
    static void callWithTooLittleInformationIsNotSaved() {
        Call_Log__c c = newCall(newLead(null).Id, null);
        AiAssistController.mockResponse = 'Not enough information to summarise. Add call notes first.';

        AiAssistController.Result r = AiAssistController.summariseCall(c.Id);

        System.assert(!r.ok);
        System.assertEquals(null, [SELECT AI_Summary__c FROM Call_Log__c WHERE Id = :c.Id].AI_Summary__c);
    }

    @IsTest
    static void emailDraftNeedsAnEmailAddress() {
        AiAssistController.mockResponse = 'unused';
        System.assert(!AiAssistController.draftEmail(newLead(null).Id).ok);
    }

    @IsTest
    static void emailDraftIsReturnedButNeverSent() {
        Lead l = newLead('doctor@example.com');
        newCall(l.Id, 'Interested in help with claims.');
        AiAssistController.mockResponse = 'Hi Dr, thanks for your time.';

        Test.startTest();
        AiAssistController.Result r = AiAssistController.draftEmail(l.Id);
        System.assertEquals(0, Limits.getEmailInvocations(), 'The assistant must never send an email');
        Test.stopTest();

        System.assert(r.ok);
        System.assertEquals('Hi Dr, thanks for your time.', r.text);
        System.assertEquals('doctor@example.com', r.email);
        System.assert(String.isNotBlank(r.subject));
    }

    @IsTest
    static void leadBriefReturnsBriefAndNextStep() {
        Lead l = newLead(null);
        newCall(l.Id, 'Asked about pricing.');
        AiAssistController.mockResponse = 'Who: Dr Ai';

        AiAssistController.Result r = AiAssistController.leadBrief(l.Id);

        System.assertEquals('Who: Dr Ai', r.text);
        System.assertEquals('Who: Dr Ai', r.nextStep);
        System.assertEquals('Ai', r.title);
    }

    @IsTest
    static void opportunityBriefReturnsBriefAndNextStep() {
        Account a = new Account(Name = 'Ai Clinic');
        insert a;
        Opportunity o = new Opportunity(Name = 'Ai Deal', AccountId = a.Id, StageName = 'Qualified Opportunity', CloseDate = Date.today().addDays(30));
        insert o;
        AiAssistController.mockResponse = 'Deal: Ai Deal';

        AiAssistController.Result r = AiAssistController.opportunityBrief(o.Id);

        System.assertEquals('Deal: Ai Deal', r.text);
        System.assertEquals('Ai Deal', r.title);
    }
}
