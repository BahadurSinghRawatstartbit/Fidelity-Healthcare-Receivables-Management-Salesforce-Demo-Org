@IsTest
private class MeetingSchedulerControllerTest {

    private static Lead newLead(String lastName, String email) {
        Lead l = new Lead(LastName = lastName, Company = lastName + ' Clinic', LeadSource = 'Other', Email = email);
        insert l;
        return l;
    }

    @IsTest
    static void returnsFutureSlotsOnBusinessDaysOnly() {
        Lead l = newLead('Slot', null);
        List<MeetingSchedulerController.Slot> slots = MeetingSchedulerController.getAvailableSlots(l.Id, 30);

        System.assert(!slots.isEmpty(), 'Expected at least one available slot');
        for (MeetingSchedulerController.Slot s : slots) {
            System.assert(s.value > Datetime.now(), 'Slots must be in the future');
            String dow = s.value.format('E');
            System.assert(dow != 'Sat' && dow != 'Sun', 'Slots must not fall on a weekend');
        }
    }

    @IsTest
    static void longerMeetingsOfferFewerSlots() {
        Lead l = newLead('Long', null);
        Integer short30 = MeetingSchedulerController.getAvailableSlots(l.Id, 30).size();
        Integer long90 = MeetingSchedulerController.getAvailableSlots(l.Id, 90).size();
        System.assert(long90 < short30, 'A 90 minute meeting must have fewer start times than a 30 minute one');
    }

    @IsTest
    static void busySlotIsExcluded() {
        Lead l = newLead('Busy', null);
        MeetingSchedulerController.Slot first = MeetingSchedulerController.getAvailableSlots(l.Id, 30)[0];

        insert new Event(
            Subject = 'Existing',
            StartDateTime = first.value,
            EndDateTime = first.value.addMinutes(30),
            OwnerId = UserInfo.getUserId()
        );

        for (MeetingSchedulerController.Slot s : MeetingSchedulerController.getAvailableSlots(l.Id, 30)) {
            System.assertNotEquals(first.value, s.value, 'A booked slot must not be offered');
        }
    }

    @IsTest
    static void longMeetingBlocksEarlierSlotThatWouldOverlap() {
        Lead l = newLead('Overlap', null);
        MeetingSchedulerController.Slot first = MeetingSchedulerController.getAvailableSlots(l.Id, 30)[0];
        Datetime blockedStart = first.value.addMinutes(60);
        insert new Event(
            Subject = 'Existing',
            StartDateTime = blockedStart,
            EndDateTime = blockedStart.addMinutes(30),
            OwnerId = UserInfo.getUserId()
        );

        for (MeetingSchedulerController.Slot s : MeetingSchedulerController.getAvailableSlots(l.Id, 90)) {
            System.assertNotEquals(first.value, s.value, 'A 90 minute meeting starting here would run into the existing one');
        }
    }

    @IsTest
    static void schedulingSetsMeetingDateTimeAndDuration() {
        Lead l = newLead('Book', 'book@example.com');
        Datetime slot = MeetingSchedulerController.getAvailableSlots(l.Id, 60)[0].value;

        Test.startTest();
        MeetingSchedulerController.scheduleMeeting(l.Id, slot, 60);
        Test.stopTest();

        Lead saved = [SELECT Meeting_Date_Time__c, Meeting_Duration_Minutes__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(slot, saved.Meeting_Date_Time__c);
        System.assertEquals(60, saved.Meeting_Duration_Minutes__c);
        Event ev = [SELECT StartDateTime, EndDateTime FROM Event WHERE WhoId = :l.Id AND Subject = 'Discovery Meeting'];
        System.assertEquals(slot.addMinutes(60), ev.EndDateTime, 'The calendar event must last the chosen duration');
    }

    @IsTest
    static void pastSlotIsRejected() {
        Lead l = newLead('Past', 'past@example.com');
        try {
            MeetingSchedulerController.scheduleMeeting(l.Id, Datetime.now().addDays(-1), 30);
            System.assert(false, 'Expected an exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void leadWithoutEmailIsRejected() {
        Lead l = newLead('NoMail', null);
        try {
            MeetingSchedulerController.scheduleMeeting(l.Id, Datetime.now().addDays(1), 30);
            System.assert(false, 'Expected an exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void sameTimeCannotBeBookedTwice() {
        Lead a = newLead('First', 'first@example.com');
        Lead b = newLead('Second', 'second@example.com');
        Datetime slot = MeetingSchedulerController.getAvailableSlots(a.Id, 30)[0].value;

        MeetingSchedulerController.scheduleMeeting(a.Id, slot, 30);

        try {
            MeetingSchedulerController.scheduleMeeting(b.Id, slot, 30);
            System.assert(false, 'Expected the second booking of the same slot to be rejected');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        System.assertEquals(null, [SELECT Meeting_Date_Time__c FROM Lead WHERE Id = :b.Id].Meeting_Date_Time__c);
    }
}
