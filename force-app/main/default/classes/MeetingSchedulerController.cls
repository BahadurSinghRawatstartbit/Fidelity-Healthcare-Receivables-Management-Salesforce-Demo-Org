public with sharing class MeetingSchedulerController {

    private static final Integer DAYS_AHEAD = 5;
    private static final Integer FIRST_HOUR = 9;
    private static final Integer LAST_HOUR = 17;
    private static final Integer SLOT_STEP_MINUTES = 30;
    private static final Integer DEFAULT_DURATION = 30;
    private static final Integer MAX_DURATION = 120;

    public class Slot {
        @AuraEnabled public Datetime value;
        @AuraEnabled public String dayLabel;
        @AuraEnabled public String timeLabel;
    }

    @AuraEnabled
    public static List<Slot> getAvailableSlots(Id leadId, Integer durationMinutes) {
        Integer duration = cleanDuration(durationMinutes);
        Datetime now = Datetime.now();
        Date today = Date.today();
        Datetime windowEnd = Datetime.newInstance(today.addDays(DAYS_AHEAD * 2), Time.newInstance(0, 0, 0, 0));

        List<Event> busy = [
            SELECT StartDateTime, EndDateTime
            FROM Event
            WHERE OwnerId = :UserInfo.getUserId()
              AND StartDateTime < :windowEnd
              AND EndDateTime > :now
              AND (WhoId != :leadId OR WhoId = null)
        ];

        List<Slot> slots = new List<Slot>();
        Integer businessDays = 0;
        Date day = today;
        while (businessDays < DAYS_AHEAD) {
            Datetime dayStart = Datetime.newInstance(day, Time.newInstance(12, 0, 0, 0));
            String dow = dayStart.format('E');
            if (dow != 'Sat' && dow != 'Sun') {
                businessDays++;
                Datetime closing = Datetime.newInstance(day, Time.newInstance(LAST_HOUR, 0, 0, 0));
                for (Integer h = FIRST_HOUR; h < LAST_HOUR; h++) {
                    for (Integer m = 0; m < 60; m += SLOT_STEP_MINUTES) {
                        Datetime start = Datetime.newInstance(day, Time.newInstance(h, m, 0, 0));
                        Datetime finish = start.addMinutes(duration);
                        // the meeting must end by closing time and not run into another meeting
                        if (start > now && finish <= closing && !isBusy(busy, start, finish)) {
                            Slot s = new Slot();
                            s.value = start;
                            s.dayLabel = start.format('EEEE, MMM d');
                            s.timeLabel = start.format('h:mm a');
                            slots.add(s);
                        }
                    }
                }
            }
            day = day.addDays(1);
        }
        return slots;
    }

    @AuraEnabled
    public static void scheduleMeeting(Id leadId, Datetime slot, Integer durationMinutes) {
        if (slot == null || slot <= Datetime.now()) {
            throw new AuraHandledException('Please choose a time in the future.');
        }
        Integer duration = cleanDuration(durationMinutes);
        Lead target = [SELECT Email FROM Lead WHERE Id = :leadId];
        if (String.isBlank(target.Email)) {
            throw new AuraHandledException('Add an email address to this lead first - the meeting confirmation and reminders are sent by email.');
        }
        Datetime slotEnd = slot.addMinutes(duration);
        Integer clashes = [
            SELECT COUNT()
            FROM Event
            WHERE OwnerId = :UserInfo.getUserId()
              AND StartDateTime < :slotEnd
              AND EndDateTime > :slot
              AND (WhoId != :leadId OR WhoId = null)
        ];
        if (clashes > 0) {
            throw new AuraHandledException('That time has just been taken. Please choose another slot.');
        }
        try {
            update new Lead(Id = leadId, Meeting_Date_Time__c = slot, Meeting_Duration_Minutes__c = duration);
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    private static Integer cleanDuration(Integer durationMinutes) {
        if (durationMinutes == null || durationMinutes <= 0) {
            return DEFAULT_DURATION;
        }
        return Math.min(durationMinutes, MAX_DURATION);
    }

    private static Boolean isBusy(List<Event> busy, Datetime start, Datetime finish) {
        for (Event e : busy) {
            if (e.StartDateTime < finish && e.EndDateTime > start) {
                return true;
            }
        }
        return false;
    }
}
