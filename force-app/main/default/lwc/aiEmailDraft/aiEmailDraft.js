import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import draftEmail from '@salesforce/apex/AiAssistController.draftEmail';

export default class AiEmailDraft extends NavigationMixin(LightningElement) {
    _recordId;
    started = false;

    isLoading = true;
    error;
    title = '';
    email = '';
    subject = '';
    body = '';

    // Salesforce hands the record Id to a quick-action component AFTER it is created,
    // so wait for it instead of loading in connectedCallback.
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value && !this.started) {
            this.started = true;
            this.load(true);
        }
    }

    load(openComposerWhenReady) {
        this.isLoading = true;
        this.error = undefined;
        draftEmail({ leadId: this._recordId })
            .then((r) => {
                if (!r.ok) {
                    this.error = r.message;
                    return;
                }
                this.title = r.title;
                this.email = r.email;
                this.subject = r.subject;
                this.body = r.text;
                if (openComposerWhenReady) {
                    this.openComposer();
                }
            })
            .catch((e) => {
                this.error = this.message(e);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRegenerate() {
        this.load(false);
    }

    handleOpenComposer() {
        this.openComposer();
    }

    // Opens Salesforce's standard email composer with the AI draft already filled in.
    openComposer() {
        const html = this.escapeHtml(this.body).replace(/\r?\n/g, '<br>');
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: 'Global.SendEmail' },
            state: {
                recordId: this._recordId,
                defaultFieldValues: encodeDefaultFieldValues({
                    Subject: this.subject,
                    HtmlBody: html
                })
            }
        });
    }

    escapeHtml(text) {
        return (text || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
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
