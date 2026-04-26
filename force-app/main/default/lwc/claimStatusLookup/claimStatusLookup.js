import { LightningElement, track } from 'lwc';
import lookup from '@salesforce/apex/ClaimStatusController.lookup';

export default class ClaimStatusLookup extends LightningElement {
    claimNumber = '';
    vin = '';
    @track result = null;
    isLoading = false;
    errorMessage = '';
    searched = false;

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
        } catch (err) {
            this.errorMessage = 'Lookup failed. Please verify the claim number or VIN and try again.';
            console.error('ClaimStatusLookup error', err);
        } finally {
            this.isLoading = false;
        }
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
}
