import { LightningElement, api } from 'lwc';

export default class ElectraHero extends LightningElement {
    @api headline = 'Submit a warranty claim in under 2 minutes.';
    @api subheadline = 'ARIA, our AI-powered service writer, walks you through every prior-authorization request — VIN to verdict — without a single email.';
    @api primaryCtaLabel = 'Start a claim with ARIA';
    @api secondaryCtaLabel = 'Track an existing claim';

    handlePrimaryCta() {
        // Smooth-scroll to the chat widget anchor on the same page.
        // Falls back to a no-op if the embedded chat hasn't loaded yet.
        const evt = new CustomEvent('electrastartclaim', { bubbles: true, composed: true });
        this.dispatchEvent(evt);
        const chatBtn = document.querySelector('.embeddedMessagingConversationButton');
        if (chatBtn) chatBtn.click();
    }

    handleSecondaryCta() {
        const tracker = document.querySelector('c-claim-status-lookup');
        if (tracker && tracker.scrollIntoView) {
            tracker.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }
}