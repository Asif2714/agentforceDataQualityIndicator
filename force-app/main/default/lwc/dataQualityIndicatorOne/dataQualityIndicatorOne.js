import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';

export default class DataQualityIndicatorOne extends LightningElement {
    @api recordId;
    @api objectApiName;

    // Optional override: If not provided, we default to the required Opportunity field set below.
    @api fields; // comma-separated string or array of API names (e.g., "StageName,Amount,CloseDate")

    isLoading = true;
    error;
    // Store evaluated fields as objects: { apiName, label, isRequired }
    missingFields = [];
    requiredFields = [];
    percentage = 0;

    // Cache for field api names needed on the record wire
    _recordFieldApiNames = [];

    // Wire object info to resolve labels and validate fields
    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredObjectInfo({ data, error }) {
        if (error) {
            this.error = error;
            this.isLoading = false;
            return;
        }
        if (!data) {
            return;
        }

        try {
            const objFields = data.fields || {};

            // Normalize incoming @api fields into an array of API names.
            const explicitFields = this.normalizeFieldList(this.fields);
            if (explicitFields.length > 0) {
                // Use explicitly provided fields - mark Required/Recommended based on metadata and our default list
                const defaultRecommended = new Set(this.defaultOpportunityFields.map((f) => f));
                this.requiredFields = explicitFields
                    .filter((apiName) => !!objFields[apiName])
                    .map((apiName) => ({
                        apiName,
                        label: objFields[apiName]?.label || this.toFriendlyLabel(apiName),
                        isRequired: objFields[apiName]?.required === true || !defaultRecommended.has(apiName) ? false : false // will classify later; default false here
                    }));
            } else {
                // Fallback: derive from object info (required + layoutRequired)
                const requiredByMetadata = Object.keys(objFields)
                    .filter((apiName) => objFields[apiName]?.required === true)
                    .map((apiName) => ({ apiName, label: objFields[apiName]?.label || this.toFriendlyLabel(apiName), isRequired: true }));

                const layoutRequired = Object.keys(objFields)
                    .filter((apiName) => objFields[apiName]?.layoutRequired === true)
                    .map((apiName) => ({ apiName, label: objFields[apiName]?.label || this.toFriendlyLabel(apiName), isRequired: true }));

                const mergedMap = new Map();
                [...requiredByMetadata, ...layoutRequired].forEach((f) => {
                    if (!mergedMap.has(f.apiName)) {
                        mergedMap.set(f.apiName, f);
                    }
                });
                this.requiredFields = Array.from(mergedMap.values()).sort((a, b) =>
                    a.label.localeCompare(b.label)
                );
            }

            // Build list of fields to request in getRecord; default to Opportunity context
            const objectApi = this.objectApiName || 'Opportunity';
            this._recordFieldApiNames = this.requiredFields.map((f) => `${objectApi}.${f.apiName}`);

            this.error = undefined;
        } catch (e) {
            this.error = e;
        } finally {
            // wait for record wire
        }
    }

    // Expose reactive fields array for getRecord
    get recordFields() {
        return this._recordFieldApiNames;
    }

    // Wire record with dynamic fields
    @wire(getRecord, { recordId: '$recordId', fields: '$recordFields' })
    wiredRecord({ data, error }) {
        if (error) {
            this.error = error;
            this.isLoading = false;
            return;
        }
        if (!data) {
            // If no data yet (e.g., fields array empty), keep loading until object info populates
            this.isLoading = this.requiredFields.length === 0;
            return;
        }

        try {
            const evaluated = this.evaluateCompleteness(
                data.fields || {},
                this.requiredFields
            );
            this.missingFields = evaluated.missingFields;
            this.percentage = evaluated.percentage;
            // Derive groupings for UI
            this._missingRequired = this.missingFields.filter((f) => f.isRequired);
            this._missingRecommended = this.missingFields.filter((f) => !f.isRequired);
            this.error = undefined;
        } catch (e) {
            this.error = e;
        } finally {
            this.isLoading = false;
        }
    }

    get hasRequirements() {
        return (this.requiredFields && this.requiredFields.length > 0) || this.isLoading;
    }

    get hasMissing() {
        return this.missingFields && this.missingFields.length > 0;
    }

    get missingRequired() {
        return this._missingRequired || [];
    }

    get missingRecommended() {
        return this._missingRecommended || [];
    }

    get missingRequiredCount() {
        return this.missingRequired.length;
    }

    get missingRecommendedCount() {
        return this.missingRecommended.length;
    }

    get progressStyle() {
        const pct = Math.max(0, Math.min(100, this.percentage || 0));
        // Horizontal bar width
        return `width:${pct}%`;
    }


    // Inline style for circular path using CSS custom property to drive stroke-dashoffset
    get circularStyle() {
        const pct = Math.max(0, Math.min(100, this.percentage || 0));
        return `--pct:${pct}`;
    }

    // Helpers

    // Normalize supported field inputs: array or comma-separated string. Trims and dedupes.
    normalizeFieldList(input) {
        if (!input) return [];
        let arr = Array.isArray(input) ? input : String(input).split(',');
        const set = new Set(
            arr
                .map((s) => String(s).trim())
                .filter((s) => s.length > 0)
        );
        return Array.from(set);
    }

    // Default Opportunity field API names per requirements
    get defaultOpportunityFields() {
        return [
            'OwnerId',                 // Opportunity Owner
            'Amount',
            'IsPrivate',               // Private
            'ExpectedRevenue',
            'Name',                    // Opportunity Name
            'CloseDate',
            'AccountId',               // Account Name
            'NextStep',
            'Type',
            'StageName',               // Stage
            'LeadSource',
            'Probability',             // Probability (%)
            'CampaignId',              // Primary Campaign Source
            'OrderNumber__c',          // Order Number (custom)
            'MainCompetitors__c',      // Main Competitor(s) (custom)
            'CurrentGenerators__c',    // Current Generator(s) (custom)
            'DeliveryInstallationStatus__c', // Delivery/Installation Status (custom)
            'TrackingNumber__c'        // Tracking Number (custom)
        ];
    }

    // Evaluate completeness given UI API field map and requiredFields [{apiName,label,isRequired}]
    evaluateCompleteness(fieldMap, required) {
        const missing = [];
        required.forEach((req) => {
            const f = fieldMap[req.apiName];
            const value = f ? f.value : undefined;
            const isMissing =
                value === null ||
                value === undefined ||
                (typeof value === 'string' && value.trim() === '') ||
                (Array.isArray(value) && value.length === 0);
            if (isMissing) {
                // ensure we carry label and required flag
                missing.push({
                    apiName: req.apiName,
                    label: req.label || this.toFriendlyLabel(req.apiName),
                    isRequired: req.isRequired === true
                });
            }
        });
        const total = required.length;
        const complete = total - missing.length;
        const pct = total > 0 ? Math.round((complete / total) * 100) : 100;
        return { missingFields: missing, percentage: pct };
    }

    // On component init, if fields input is not provided, default to the Opportunity field list above.
    connectedCallback() {
        if (!this.fields) {
            this.fields = this.defaultOpportunityFields;
        }
    }

    // Color coding for progress bar based on percentage
    get progressBarClass() {
        const pct = this.percentage || 0;
        if (pct < 50) return 'dq-progress dq-progress_red';
        if (pct <= 80) return 'dq-progress dq-progress_yellow';
        return 'dq-progress dq-progress_green';
    }

    // Combined class for progress bar with static and dynamic parts
    get progressBarCombinedClass() {
        return `slds-progress-bar ${this.progressBarClass}`;
    }

    // Header status icon name based on percentage
    get statusIconName() {
        const pct = this.percentage || 0;
        if (pct < 50) return 'utility:error';
        if (pct <= 80) return 'utility:warning';
        return 'utility:success';
    }

    // Header status icon class to colorize icon
    get statusIconClass() {
        const pct = this.percentage || 0;
        if (pct < 50) return 'slds-icon-text-error';
        if (pct <= 80) return 'slds-icon-text-warning';
        return 'slds-icon-text-success';
    }

    // Emit event to allow parent to highlight fields later
    handleHighlightClick() {
        /**
         * Dispatches a custom event 'highlightmissing' with detail including
         * missing required and recommended fields as API names.
         * Parent container (e.g., a flexipage wrapper) can listen and act.
         */
        const detail = {
            required: this.missingRequired.map(f => f.apiName),
            recommended: this.missingRecommended.map(f => f.apiName)
        };
        this.dispatchEvent(new CustomEvent('highlightmissing', { detail, bubbles: true, composed: true }));
    }

    // Status label and color state for ring
    get statusLabel() {
        const pct = this.percentage || 0;
        if (pct < 50) return 'Poor Data Quality';
        if (pct <= 80) return 'At Risk';
        return 'Healthy';
    }

    // Utility: convert API names to user-friendly labels when metadata is unavailable
    toFriendlyLabel(apiName) {
        const map = {
            CampaignId: 'Campaign',
            OrderNumber__c: 'Order Number',
            NextStep: 'Next Step'
        };
        if (map[apiName]) return map[apiName];
        // Generic transform: remove suffixes and split words
        return String(apiName)
            .replace(/__c$/, '')
            .replace(/Id$/, '')
            .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
            .trim();
    }
}
