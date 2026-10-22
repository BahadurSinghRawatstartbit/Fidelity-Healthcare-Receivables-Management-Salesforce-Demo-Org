public with sharing class AiAssistController {

    // Tests cannot call the AI service, so they set this to a canned answer.
    @TestVisible private static String mockResponse;

    private static final Integer MAX_CALLS_IN_HISTORY = 5;
    private static final String NOT_ENOUGH = 'Not enough information';

    public class Result {
        @AuraEnabled public Boolean ok = true;
        @AuraEnabled public String message;
        @AuraEnabled public String text;        // main answer (summary, email body, or brief)
        @AuraEnabled public String nextStep;    // second answer on the brief screens
        @AuraEnabled public String email;       // lead email address, for the draft screen
        @AuraEnabled public String subject;
        @AuraEnabled public String title;       // record name shown in the header
    }

    // ---------------------------------------------------------------- F1 call summary
    @AuraEnabled
    public static Result summariseCall(Id callLogId) {
        Result r = new Result();
        Call_Log__c call = [SELECT Id, Name FROM Call_Log__c WHERE Id = :callLogId];
        r.title = call.Name;
        String text = generate('Fidelity_Call_Summary', new Map<String, Object>{
            'Input:Call_Log' => recordRef(callLogId)
        });
        if (text.startsWith(NOT_ENOUGH)) {
            r.ok = false;
            r.message = 'There is not enough in the call notes to summarise. Add notes to this call, then try again.';
            return r;
        }
        update new Call_Log__c(Id = callLogId, AI_Summary__c = text);
        r.text = text;
        return r;
    }

    // ---------------------------------------------------------------- F2 email draft
    @AuraEnabled
    public static Result draftEmail(Id leadId) {
        Result r = new Result();
        Lead l = [SELECT Id, Name, Email FROM Lead WHERE Id = :leadId];
        r.title = l.Name;
        r.email = l.Email;
        if (String.isBlank(l.Email)) {
            r.ok = false;
            r.message = 'This lead has no email address. Add one to the lead, then try again.';
            return r;
        }
        String latest = 'None recorded.';
        List<Call_Log__c> calls = [
            SELECT AI_Summary__c, Call_Notes__c FROM Call_Log__c
            WHERE Lead__c = :leadId ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (!calls.isEmpty()) {
            if (String.isNotBlank(calls[0].AI_Summary__c)) {
                latest = calls[0].AI_Summary__c;
            } else if (String.isNotBlank(calls[0].Call_Notes__c)) {
                latest = calls[0].Call_Notes__c;
            }
        }
        r.text = generate('Fidelity_Followup_Email_Draft', new Map<String, Object>{
            'Input:Lead' => recordRef(leadId),
            'Input:LatestCallSummary' => latest
        });
        r.subject = 'Following up - Fidelity Healthcare Receivables Management';
        return r;
    }

    // ---------------------------------------------------------------- F3 + F4 lead
    @AuraEnabled
    public static Result leadBrief(Id leadId) {
        Result r = new Result();
        r.title = [SELECT Name FROM Lead WHERE Id = :leadId].Name;
        String history = callHistory(leadId);
        Map<String, Object> inputs = new Map<String, Object>{
            'Input:Lead' => recordRef(leadId),
            'Input:CallHistory' => history
        };
        r.text = generate('Fidelity_Lead_Brief', inputs);
        r.nextStep = generate('Fidelity_Lead_Next_Step', inputs);
        return r;
    }

    // ---------------------------------------------------------------- F3 + F4 opportunity
    @AuraEnabled
    public static Result opportunityBrief(Id opportunityId) {
        Result r = new Result();
        r.title = [SELECT Name FROM Opportunity WHERE Id = :opportunityId].Name;
        Map<String, Object> inputs = new Map<String, Object>{
            'Input:Opportunity' => recordRef(opportunityId)
        };
        r.text = generate('Fidelity_Opportunity_Brief', inputs);
        r.nextStep = generate('Fidelity_Opportunity_Next_Step', inputs);
        return r;
    }

    // ---------------------------------------------------------------- helpers
    private static String callHistory(Id leadId) {
        List<String> lines = new List<String>();
        for (Call_Log__c c : [
            SELECT Call_Date_Time__c, Call_Type__c, Call_Outcome__c, Call_Notes__c
            FROM Call_Log__c WHERE Lead__c = :leadId
            ORDER BY CreatedDate DESC LIMIT :MAX_CALLS_IN_HISTORY
        ]) {
            lines.add('- ' + c.Call_Date_Time__c + ' | ' + c.Call_Type__c + ' | outcome: ' + c.Call_Outcome__c
                + ' | notes: ' + (String.isBlank(c.Call_Notes__c) ? 'none' : c.Call_Notes__c));
        }
        return lines.isEmpty() ? 'None recorded.' : String.join(lines, '\n');
    }

    private static Map<String, String> recordRef(Id recordId) {
        return new Map<String, String>{ 'id' => String.valueOf(recordId) };
    }

    private static String generate(String templateName, Map<String, Object> inputs) {
        if (mockResponse != null) {
            return mockResponse;
        }
        ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        input.isPreview = false;
        input.inputParams = new Map<String, ConnectApi.WrappedValue>();
        for (String key : inputs.keySet()) {
            ConnectApi.WrappedValue wrapped = new ConnectApi.WrappedValue();
            wrapped.value = inputs.get(key);
            input.inputParams.put(key, wrapped);
        }
        input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        input.additionalConfig.applicationName = 'PromptBuilderPreview';
        try {
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation out =
                ConnectApi.EinsteinLlm.generateMessagesForPromptTemplate(templateName, input);
            if (out == null || out.generations == null || out.generations.isEmpty()) {
                throw new AuraHandledException('The AI did not return an answer. Please try again.');
            }
            return out.generations[0].text.trim();
        } catch (ConnectApi.ConnectApiException e) {
            throw new AuraHandledException('The AI assistant could not complete this request. Nothing was changed. Please try again in a moment.');
        }
    }
}
