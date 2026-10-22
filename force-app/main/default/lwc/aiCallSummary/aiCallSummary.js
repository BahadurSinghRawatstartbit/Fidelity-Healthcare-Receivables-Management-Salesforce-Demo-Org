import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import summariseCall from '@salesforce/apex/AiAssistController.summariseCall';

export default class AiCallSummary extends LightningElement {
    @api recordId;

    isLoading = true;
    error;
    title = '';
    summary = '';

    connectedCallback() {
        this.load();
    }

    load() {
        this.isLoading = true;
        this.error = undefined;
        summariseCall({ callLogId: this.recordId })
            .then((r) => {
                if (!r.ok) {
                    this.error = r.message;
                    return undefined;
                }
                this.title = r.title;
                this.summary = r.text;
                return notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            })
            .catch((e) => {
                this.error = this.message(e);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRegenerate() {
        this.load();
    }

    message(e) {
        return (e && e.body && e.body.message) || 'Something went wrong. Please try again.';
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
