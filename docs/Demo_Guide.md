# Fidelity Demo Guide

Source of truth for scope: `Fidelity Healthcare Receivables Management  Requirement Document.pdf`.
Scope built: Priority 1 and Priority 2. Priority 3 (Cases/ticketing, advanced onboarding, advanced AI/campaign automation) is deliberately not built.

Org alias: `fidelityDemo`. App: **Fidelity Sales Console**. Dashboard: **Fidelity Sales Management Dashboard** (folder "Fidelity Dashboards").

## 1. The 12-step storyline and what to click

| # | Doc step | In Salesforce |
|---|---|---|
| 1 | Landing page form creates a Lead | Open `docs/integrations/landing-page-web-to-lead.html` in a browser and submit. A Lead appears with Source = Google Campaign. (Requires Web-to-Lead enabled, see section 3.) |
| 2 | Auto-assign + notify | The lead lands in a queue (Referral, Inbound and Event go to the Sales / Closer Queue; everything else to the Outbound/Inbound Calling Queue). The owner/queue gets a bell notification. |
| 3 | Caller calls | On the Lead click **Log Call Outcome**. This is where RingCentral/Dialpad call data would land (see section 4). |
| 4 | Outcome = Interested | Pick Interested. Lead status becomes Interested, the welcome email is sent, and a "Schedule discovery meeting" task is created. |
| 5 | Meeting scheduling | On the Lead click **Schedule Meeting**, pick a free slot. The Event is created, the prospect gets a confirmation, status becomes Discovery Meeting Scheduled. The lead needs an email address. |
| 6 | Reminders | 24 hours, 1 hour and 15 minutes before the meeting. The reminders are attached to the calendar event, not the lead, so the lead can still be converted while they are pending. To show it live, book a slot about 16 minutes away. |
| 7 | Discovery done | Set Status to Discovery Completed. A "Qualify lead and convert" task is created for the user making the change. |
| 8 | Convert | Click **Convert** on the Lead. Account + Contact + Opportunity are created. If the lead still has a future discovery meeting, that meeting is deleted so the slot is free again. |
| 9 | Proposal | Set the Opportunity Stage to Proposal Sent. Proposal date, follow-up date, a follow-up task and an email are created automatically. |
| 10 | Auto follow-up | If the stage has not moved by the follow-up date, a no-response email and an escalation task are created. |
| 11 | Close | Closed Won, or Closed Lost. A Loss Reason is required for Closed Lost. |
| 12 | Dashboard | Open **Fidelity Sales Management Dashboard**. |

Leads with "No Response" as the call outcome are followed up automatically each day at 09:00 UTC: a follow-up email, an escalation task, and the outcome resets to Follow-up Required.

The **Suggested Next Action** field on the Lead shows what should happen next. It is rule-based on the status.
It is a suggestion only; the salesperson decides.

## 2. Reports and list views

Reports (folder "Fidelity Sales Reports"): Leads by Status, Leads by Source, Lead Source Performance, Interested Leads, Leads Needing Follow-up, Referral Leads, Conference and Event Leads, Discovery Meetings, Pipeline by Stage, Proposals Sent, Closed Won and Lost, Loss Reasons, Activities by Type, Open Follow-up Tasks, Calls by Outcome.

Lead list views: Referral Leads, Conference and Event Leads, Interested Leads, Google and Landing Page Leads, Follow-up Due.
Call Log list view: All Calls (Audit).

Campaign: "Conference 2026 - Healthcare Revenue Summit" with two event leads attached.

## 3. One-time setup that only an admin can do in the org

1. Setup > Deliverability > Access level = **All email**, otherwise no emails are delivered.
2. Setup > Web-to-Lead > tick **Enable Web-to-Lead**.
3. Host `landing-page-web-to-lead.html` somewhere, and change its `retURL` to your thank-you page.
4. Google Form: paste `docs/integrations/google-form-to-salesforce.gs` into the form's Apps Script and add the "On form submit" trigger.
5. Create demo users and assign roles and permission sets (see section 5).

## 4. Integrations: what is built and what is a concept

| Item | Status |
|---|---|
| Landing page to Lead | Working, using Salesforce Web-to-Lead. Needs step 2 above. |
| Google Form to Lead | Working script provided. Needs steps 2 and 4 above. |
| RingCentral / Dialpad | **Concept only.** Calls are logged on `Call_Log__c`, which has fields for number, duration, outcome, notes and Recording URL. Both vendors offer a Salesforce connector that logs calls and recordings against Leads and Contacts. Which one works depends on the plan and API access, to be confirmed during implementation. |
| Slack | **Concept only.** Requires a Slack workspace and the Salesforce app for Slack. Not connected. |
| AI assistance | **Not connected.** `AI_Summary__c` is a reserved field. The Suggested Next Action is rule-based, not AI. Real AI (Prompt Builder, Agentforce) depends on licences and is an implementation-phase item. The calling stays human-led by design. |

## 5. Security and HIPAA talking points

Do not claim the configuration is HIPAA compliant. Compliance depends on the contract with Salesforce (including a signed BAA), the edition, the add-ons such as Shield or Platform Encryption, the data stored and how integrations are configured. All of that must be validated in discovery.

What the demo can show:
- Roles: Sales Head > Sales Representative; Sales Head > Calling Manager > Caller (Ethiopia).
- Permission sets: **Fidelity Caller** (leads and call logs only, no Opportunities or Accounts), **Fidelity Sales Rep**, **Fidelity Sales Manager** (sees all records), plus the original **Fidelity Sales User**.
- Field history on Lead Status, and the Setup Audit Trail.
- Do not collect patient or health information through the public web form.

Org-wide sharing defaults are still the Developer Edition defaults (not private). Tighten them before showing record-level privacy.

## 6. Meetings: how booking behaves

- One meeting per time slot per user. The picker hides taken slots and the system also rejects a double booking.
- A lead has one open discovery meeting. Booking a new time replaces the old one (the old event and its reminders are deleted).
- Converting a lead removes its future discovery meeting.
- Leads booked before this change keep their old reminder schedule until those reminders have fired, and cannot be converted until then.

## 7. Known limits

- Reminder timings (24h, 1h, 15 min) are set inside the flow, so changing them means editing the flow. A settings screen is a later enhancement.
- Emails are not tracked as activities without Einstein Activity Capture or similar, so the dashboard has no email count.
- Lead to Opportunity field mapping is the standard Salesforce mapping.
- Free licences: 1 full Salesforce licence is free; Platform licences cannot see Leads or Opportunities.
