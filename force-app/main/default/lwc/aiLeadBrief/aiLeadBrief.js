import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import leadBrief from '@salesforce/apex/AiAssistController.leadBrief';
import opportunityBrief from '@salesforce/apex/AiAssistController.opportunityBrief';

export default class AiLeadBrief extends LightningElement {
    @api recordId;
    @api objectApiName;

    isLoading = true;
    error;
    title = '';
    briefRows = [];
    next = { main: '', why: '' };

    get heading() {
        return this.objectApiName === 'Opportunity' ? 'Deal briefing' : 'Prospect briefing';
    }

    connectedCallback() {
        this.load();
    }

    load() {
        this.isLoading = true;
        this.error = undefined;
        const call = this.objectApiName === 'Opportunity' ? opportunityBrief : leadBrief;
        call({ [this.objectApiName === 'Opportunity' ? 'opportunityId' : 'leadId']: this.recordId })
            .then((r) => {
                this.title = r.title;
                this.briefRows = this.rows(r.text);
                this.next = this.nextStep(r.nextStep);
            })
            .catch((e) => {
                this.error = this.message(e);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    rows(text) {
        return (text || '')
            .split(/\r?\n/)
            .map((l) => l.trim())
            .filter((l) => l)
            .map((l, i) => {
                const m = l.match(/^([^:]{1,40}):\s*(.*)$/);
                return m ? { key: 'r' + i, label: m[1], value: m[2] } : { key: 'r' + i, label: '', value: l };
            });
    }

    nextStep(text) {
        const out = { main: '', why: '' };
        (text || '').split(/\r?\n/).forEach((l) => {
            const line = l.trim();
            if (/^next step:/i.test(line)) {
                out.main = line.replace(/^next step:\s*/i, '');
            } else if (/^why:/i.test(line)) {
                out.why = line.replace(/^why:\s*/i, '');
            } else if (line && !out.main) {
                out.main = line;
            }
        });
        return out;
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
