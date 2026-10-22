import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getAvailableSlots from '@salesforce/apex/MeetingSchedulerController.getAvailableSlots';
import scheduleMeeting from '@salesforce/apex/MeetingSchedulerController.scheduleMeeting';

export default class MeetingScheduler extends LightningElement {
    @api recordId;

    slots = [];
    selected;
    isLoading = true;
    isSaving = false;
    error;

    connectedCallback() {
        getAvailableSlots({ leadId: this.recordId })
            .then((result) => {
                this.slots = result;
            })
            .catch((e) => {
                this.error = this.message(e);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get days() {
        const byDay = new Map();
        this.slots.forEach((s) => {
            if (!byDay.has(s.dayLabel)) {
                byDay.set(s.dayLabel, []);
            }
            byDay.get(s.dayLabel).push({
                value: s.value,
                timeLabel: s.timeLabel,
                variant: s.value === this.selected ? 'brand' : 'neutral'
            });
        });
        return Array.from(byDay, ([label, slots]) => ({ label, slots }));
    }

    get hasDays() {
        return this.slots.length > 0;
    }

    get isScheduleDisabled() {
        return !this.selected || this.isSaving;
    }

    handleSelect(event) {
        this.selected = event.target.dataset.value;
    }

    handleSchedule() {
        this.isSaving = true;
        scheduleMeeting({ leadId: this.recordId, slot: this.selected })
            .then(() => notifyRecordUpdateAvailable([{ recordId: this.recordId }]))
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Meeting scheduled',
                        message: 'The invitation, confirmation email and reminders are on their way.',
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch((e) => {
                this.error = this.message(e);
                this.isSaving = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    message(e) {
        return (e && e.body && e.body.message) || 'Something went wrong.';
    }
}
