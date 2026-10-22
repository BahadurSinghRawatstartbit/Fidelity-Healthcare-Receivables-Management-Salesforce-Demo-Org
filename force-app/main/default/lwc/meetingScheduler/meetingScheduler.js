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
    duration = '30';
    isLoading = true;
    isSaving = false;
    error;

    durationOptions = [
        { label: '30 minutes', value: '30' },
        { label: '45 minutes', value: '45' },
        { label: '1 hour', value: '60' },
        { label: '1 hour 30 minutes', value: '90' }
    ];

    connectedCallback() {
        this.loadSlots();
    }

    loadSlots() {
        this.isLoading = true;
        this.error = undefined;
        this.selected = undefined;
        getAvailableSlots({ leadId: this.recordId, durationMinutes: parseInt(this.duration, 10) })
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

    handleDuration(event) {
        this.duration = event.detail.value;
        this.loadSlots();
    }

    handleSelect(event) {
        this.selected = event.target.dataset.value;
    }

    handleSchedule() {
        this.isSaving = true;
        scheduleMeeting({
            leadId: this.recordId,
            slot: this.selected,
            durationMinutes: parseInt(this.duration, 10)
        })
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
