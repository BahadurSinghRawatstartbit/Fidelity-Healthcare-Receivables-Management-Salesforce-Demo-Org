@IsTest
private class MeetingSchedulerControllerTest {

    @IsTest
    static void returnsFutureSlotsOnBusinessDaysOnly() {
        Lead l = new Lead(LastName = 'Slot', Company = 'Slot Clinic', LeadSource = 'Other');
        insert l;

        List<MeetingSchedulerController.Slot> slots = MeetingSchedulerController.getAvailableSlots(l.Id);

        System.assert(!slots.isEmpty(), 'Expected at least one available slot');
        for (MeetingSchedulerController.Slot s : slots) {
            System.assert(s.value > Datetime.now(), 'Slots must be in the future');
            String dow = s.value.format('E');
            System.assert(dow != 'Sat' && dow != 'Sun', 'Slots must not fall on a weekend');
        }
    }

    @IsTest
    static void busySlotIsExcluded() {
        Lead l = new Lead(LastName = 'Busy', Company = 'Busy Clinic', LeadSource = 'Other');
        insert l;
        MeetingSchedulerController.Slot first = MeetingSchedulerController.getAvailableSlots(l.Id)[0];

        insert new Event(
            Subject = 'Existing',
            StartDateTime = first.value,
            EndDateTime = first.value.addMinutes(30),
            OwnerId = UserInfo.getUserId()
        );

        for (MeetingSchedulerController.Slot s : MeetingSchedulerController.getAvailableSlots(l.Id)) {
            System.assertNotEquals(first.value, s.value, 'A booked slot must not be offered');
        }
    }

    @IsTest
    static void schedulingSetsMeetingDateTime() {
        Lead l = new Lead(LastName = 'Book', Company = 'Book Clinic', LeadSource = 'Other', Email = 'book@example.com');
        insert l;
        Datetime slot = MeetingSchedulerController.getAvailableSlots(l.Id)[0].value;

        Test.startTest();
        MeetingSchedulerController.scheduleMeeting(l.Id, slot);
        Test.stopTest();

        System.assertEquals(slot, [SELECT Meeting_Date_Time__c FROM Lead WHERE Id = :l.Id].Meeting_Date_Time__c);
    }

    @IsTest
    static void pastSlotIsRejected() {
        Lead l = new Lead(LastName = 'Past', Company = 'Past Clinic', LeadSource = 'Other');
        insert l;
        try {
            MeetingSchedulerController.scheduleMeeting(l.Id, Datetime.now().addDays(-1));
            System.assert(false, 'Expected an exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void leadWithoutEmailIsRejected() {
        Lead l = new Lead(LastName = 'NoMail', Company = 'NoMail Clinic', LeadSource = 'Other');
        insert l;
        try {
            MeetingSchedulerController.scheduleMeeting(l.Id, Datetime.now().addDays(1));
            System.assert(false, 'Expected an exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void sameTimeCannotBeBookedTwice() {
        Lead a = new Lead(LastName = 'First', Company = 'First Clinic', LeadSource = 'Other', Email = 'first@example.com');
        Lead b = new Lead(LastName = 'Second', Company = 'Second Clinic', LeadSource = 'Other', Email = 'second@example.com');
        insert new List<Lead>{ a, b };
        Datetime slot = MeetingSchedulerController.getAvailableSlots(a.Id)[0].value;

        MeetingSchedulerController.scheduleMeeting(a.Id, slot);

        try {
            MeetingSchedulerController.scheduleMeeting(b.Id, slot);
            System.assert(false, 'Expected the second booking of the same slot to be rejected');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        System.assertEquals(null, [SELECT Meeting_Date_Time__c FROM Lead WHERE Id = :b.Id].Meeting_Date_Time__c);
    }
}
