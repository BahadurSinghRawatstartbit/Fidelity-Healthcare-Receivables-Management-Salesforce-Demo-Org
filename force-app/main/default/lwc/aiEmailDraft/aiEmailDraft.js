import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import draftEmail from '@salesforce/apex/AiAssistController.draftEmail';

export default class AiEmailDraft extends LightningElement {
    @api recordId;

    isLoading = true;
    error;
    title = '';
    email = '';
    subject = '';
    body = '';

    connectedCallback() {
        this.load();
    }

    load() {
        this.isLoading = true;
        this.error = undefined;
        draftEmail({ leadId: this.recordId })
            .then((r) => {
                if (!r.ok) {
                    this.error = r.message;
                    return;
                }
                this.title = r.title;
                this.email = r.email;
                this.subject = r.subject;
                this.body = r.text;
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

    handleCopy() {
        const text = 'Subject: ' + this.subject + '\n\n' + this.body;
        const done = () =>
            this.dispatchEvent(new ShowToastEvent({ title: 'Copied', message: 'The email is on your clipboard. Paste it into your email.', variant: 'success' }));
        const fallback = () => {
            const box = document.createElement('textarea');
            box.value = text;
            document.body.appendChild(box);
            box.select();
            try {
                document.execCommand('copy');
                done();
            } catch (e) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Could not copy', message: 'Please select the text and copy it by hand.', variant: 'warning' }));
            }
            document.body.removeChild(box);
        };
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).then(done).catch(fallback);
        } else {
            fallback();
        }
    }

    message(e) {
        return (e && e.body && e.body.message) || 'Something went wrong. Please try again.';
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
