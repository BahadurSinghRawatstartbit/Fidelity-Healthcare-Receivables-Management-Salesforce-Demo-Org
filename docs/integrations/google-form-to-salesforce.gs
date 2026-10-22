/**
 * Google Form -> Salesforce Lead
 *
 * Sends each Google Form response to Salesforce's public Web-to-Lead endpoint, which creates a Lead.
 * The Lead Assignment flow then routes it and notifies the owner, exactly like a landing-page lead.
 *
 * SETUP (one time)
 *  1. In Salesforce: Setup > Web-to-Lead > tick "Enable Web-to-Lead".
 *  2. Open the Google Form > three dots > Script editor. Paste this file.
 *  3. Make sure the question titles in the form match QUESTION_MAP below (or edit the map).
 *  4. In the script editor: Triggers (clock icon) > Add Trigger >
 *       function: onFormSubmit | event source: From form | event type: On form submit.
 *  5. Submit a test response and check Leads in Salesforce.
 *
 * NOTE: This endpoint is unauthenticated and public. Collect business contact details only -
 * never patient or health information.
 */

var SALESFORCE_ORG_ID = '00Dg800000OSUIHEA5';
var LEAD_SOURCE = 'Google Campaign'; // must match a Lead Source picklist value

// Google Form question title -> Web-to-Lead field name
var QUESTION_MAP = {
  'First name': 'first_name',
  'Last name': 'last_name',
  'Practice name': 'company',
  'Email': 'email',
  'Phone': 'phone'
};

function onFormSubmit(e) {
  var payload = {
    oid: SALESFORCE_ORG_ID,
    lead_source: LEAD_SOURCE
  };

  e.response.getItemResponses().forEach(function (item) {
    var field = QUESTION_MAP[item.getItem().getTitle()];
    if (field) {
      payload[field] = item.getResponse();
    }
  });

  var res = UrlFetchApp.fetch('https://webto.salesforce.com/servlet/servlet.WebToLead?encoding=UTF-8', {
    method: 'post',
    payload: payload,
    followRedirects: false,
    muteHttpExceptions: true
  });

  console.log('Salesforce responded ' + res.getResponseCode());
}
