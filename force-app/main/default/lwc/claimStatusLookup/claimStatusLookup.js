import { LightningElement, track } from 'lwc';
import lookup from '@salesforce/apex/ClaimStatusController.lookup';
import submitResponse from '@salesforce/apex/ClaimStatusController.submitResponse';
import getAttachedFiles from '@salesforce/apex/ClaimStatusController.getAttachedFiles';
import publishUploadedFiles from '@salesforce/apex/ClaimStatusController.publishUploadedFiles';

export default class ClaimStatusLookup extends LightningElement {
    claimNumber = '';
    vin = '';
    @track result = null;
    isLoading = false;
    errorMessage = '';
    searched = false;

    // Clarification response state
    dealerResponse = '';
    isSubmittingResponse = false;
    responseSubmitted = false;
    responseError = '';
    responseMessage = '';

    // File upload state
    @track attachedFiles = [];
    uploadFeedback = '';
    filesLoaded = false;

    /**
     * Auto-fill + auto-look-up when the page is opened with a deep-link
     * query parameter, e.g. .../track?claim=WC-XXXXX or .../track?vin=ELXX5S24...
     * The intake agent surfaces this URL after claim creation so dealers
     * can land on the tracker with their claim already loaded.
     */
    connectedCallback() {
        try {
            const params = new URLSearchParams(window.location.search || '');
            const claimParam = params.get('claim') || params.get('claimNumber');
            const vinParam = params.get('vin');

            if (claimParam) {
                this.claimNumber = claimParam.trim().toUpperCase();
            }
            if (vinParam) {
                this.vin = vinParam.trim().toUpperCase();
            }
            if (this.claimNumber || this.vin) {
                // Defer one tick so the input bindings render before the lookup fires
                Promise.resolve().then(() => this.handleLookup());
            }
        } catch (err) {
            // URLSearchParams isn't critical — silently ignore if blocked
            console.warn('claimStatusLookup deep-link parse failed', err);
        }
    }

    handleClaimNumberChange(event) {
        this.claimNumber = (event.target.value || '').toUpperCase();
    }

    handleVinChange(event) {
        this.vin = (event.target.value || '').toUpperCase();
    }

    async handleLookup() {
        this.errorMessage = '';
        this.result = null;
        this.searched = false;
        this.resetResponseState();
        this.resetFileState();

        if (!this.claimNumber && !this.vin) {
            this.errorMessage = 'Enter a claim number (e.g., WC-00042) or a 17-character VIN.';
            return;
        }

        this.isLoading = true;
        try {
            const data = await lookup({
                claimNumber: this.claimNumber || null,
                vin: this.vin || null
            });
            this.result = data;
            this.searched = true;
            // Auto-load attached files when a claim is found
            if (data && data.found && data.claimId) {
                await this.loadAttachedFiles(data.claimId);
            }
        } catch (err) {
            this.errorMessage = 'Lookup failed. Please verify the claim number or VIN and try again.';
            console.error('ClaimStatusLookup error', err);
        } finally {
            this.isLoading = false;
        }
    }

    async loadAttachedFiles(claimId) {
        try {
            const files = await getAttachedFiles({ claimId });
            this.attachedFiles = Array.isArray(files) ? files : [];
            this.filesLoaded = true;
        } catch (err) {
            console.error('getAttachedFiles error', err);
            this.attachedFiles = [];
            this.filesLoaded = true;
        }
    }

    async handleUploadFinished(event) {
        const uploaded = event.detail && event.detail.files ? event.detail.files : [];
        const count = uploaded.length;
        this.uploadFeedback = count === 1
            ? `✅ Uploaded "${uploaded[0].name}" — attached to claim ${this.result.claimNumber}.`
            : `✅ Uploaded ${count} file${count === 1 ? '' : 's'} — attached to claim ${this.result.claimNumber}.`;

        if (this.result && this.result.claimId) {
            // Auto-publish so the OEM approver's Slack card surfaces the file
            // links inline. Non-blocking — if it fails the file is still
            // attached to the Claim and visible in Salesforce.
            try {
                await publishUploadedFiles({ claimId: this.result.claimId });
            } catch (err) {
                console.warn('publishUploadedFiles failed (non-blocking)', err);
            }

            // Refresh the file list so the new uploads appear immediately
            await this.loadAttachedFiles(this.result.claimId);
        }

        // Auto-clear the success message after a few seconds so it doesn't linger
        setTimeout(() => {
            this.uploadFeedback = '';
        }, 5000);
    }

    resetFileState() {
        this.attachedFiles = [];
        this.uploadFeedback = '';
        this.filesLoaded = false;
    }

    handleDealerResponseChange(event) {
        this.dealerResponse = event.target.value || '';
        // Clear stale error as soon as the dealer types
        if (this.responseError) this.responseError = '';
    }

    async handleSubmitResponse() {
        this.responseError = '';

        const text = (this.dealerResponse || '').trim();
        if (!text) {
            this.responseError = 'Please type your response before sending.';
            return;
        }
        if (!this.result || !this.result.claimNumber) {
            this.responseError = 'No claim loaded. Look up a claim first.';
            return;
        }

        this.isSubmittingResponse = true;
        try {
            const out = await submitResponse({
                claimNumber: this.result.claimNumber,
                dealerResponse: text
            });
            if (out && out.submitted === true) {
                this.responseSubmitted = true;
                this.responseMessage = out.message
                    || 'Response sent. The OEM approver has been re-notified.';
                // Refresh local view so the badge / next-step text reflect the new status
                this.result = {
                    ...this.result,
                    status: out.newStatus || 'Pending Approver Review',
                    isAwaitingResponse: false,
                    dealerResponseSummary: text,
                    nextStep: 'Awaiting OEM approver review (re-submitted with your response). SLA: 24 business hours.'
                };
            } else {
                this.responseError = (out && out.message)
                    || 'We could not submit your response. Please try again.';
            }
        } catch (err) {
            this.responseError = 'Submission failed. Please try again.';
            console.error('ClaimStatusLookup submitResponse error', err);
        } finally {
            this.isSubmittingResponse = false;
        }
    }

    resetResponseState() {
        this.dealerResponse = '';
        this.isSubmittingResponse = false;
        this.responseSubmitted = false;
        this.responseError = '';
        this.responseMessage = '';
    }

    handleKeyup(event) {
        if (event.key === 'Enter') this.handleLookup();
    }

    handleReset() {
        this.claimNumber = '';
        this.vin = '';
        this.result = null;
        this.errorMessage = '';
        this.searched = false;
        this.resetResponseState();
        this.resetFileState();
    }

    get acceptedFormats() {
        return ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.heic', '.heif', '.bmp', '.pdf'];
    }

    get hasAttachedFiles() {
        return this.filesLoaded && this.attachedFiles && this.attachedFiles.length > 0;
    }

    get noAttachedFiles() {
        return this.filesLoaded && (!this.attachedFiles || this.attachedFiles.length === 0);
    }

    get hasResult() {
        return this.searched && this.result && this.result.found === true;
    }

    get noResult() {
        return this.searched && this.result && this.result.found === false;
    }

    get statusBadgeClass() {
        if (!this.result || !this.result.status) return 'electra-badge electra-badge--neutral';
        const s = this.result.status.toLowerCase();
        if (s === 'approved') return 'electra-badge electra-badge--approved';
        if (s === 'rejected') return 'electra-badge electra-badge--rejected';
        if (s === 'needs more info') return 'electra-badge electra-badge--info';
        return 'electra-badge electra-badge--pending';
    }

    get hasApprovedAmount() {
        return this.result
            && this.result.approvedAmount != null
            && this.result.estimatedCost != null
            && Number(this.result.approvedAmount) < Number(this.result.estimatedCost);
    }

    get formattedEstimated() {
        if (!this.result || this.result.estimatedCost == null) return '—';
        return '$' + Number(this.result.estimatedCost).toFixed(2);
    }

    get formattedApproved() {
        if (!this.result || this.result.approvedAmount == null) return '—';
        return '$' + Number(this.result.approvedAmount).toFixed(2);
    }

    get hasDealerResponseAlreadyOnFile() {
        // Show the previously-submitted response when status is no longer
        // "Needs More Info" but a dealer response is on the claim — gives the
        // dealer visible confirmation of what they sent earlier.
        return this.result
            && !this.result.isAwaitingResponse
            && !this.responseSubmitted
            && this.result.dealerResponseSummary
            && this.result.dealerResponseSummary.length > 0;
    }
}