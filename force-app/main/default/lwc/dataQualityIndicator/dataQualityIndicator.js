import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';
import getRulesForObject from '@salesforce/apex/DataQualityService.getRulesForObject';

/**
 * Reusable, metadata-driven Data Quality Indicator.
 * - Admins configure Data_Quality_Rule__c records per object (no deployments).
 * - LWC detects object, fetches rules via Apex (cacheable), builds LDS field list dynamically,
 *   fetches record values, computes a weighted completeness score, and renders SLDS UI.
 *
 * Design constraints:
 * - No hardcoded objects/fields.
 * - Apex is only for data retrieval; logic remains in JS.
 * - Handle missing permissions/fields gracefully.
 */
export default class DataQualityIndicator extends LightningElement {
    @api recordId;
    @api objectApiName;

    isLoading = true;
    error;

    // Rules from Apex: [{ fieldApiName, isRequired, weight }]
    rules = [];

    // Map of apiName -> label from getObjectInfo
    fieldLabels = new Map();

    // Dynamic list of fields for LDS getRecord: ["ObjectApi.Field__c", ...]
    _recordFieldApiNames = [];

    // Computed results
    percentage = 0;
    status = 'Poor';
    missingRequired = [];
    missingRecommended = [];

    // Tooltip explaining scoring approach
    get hasTooltip() {
        return true;
    }
    get tooltipText() {
        return 'Score uses admin-configured Data Quality Rules. Required fields and custom weights increase impact.';
    }

    // 1) Wire object info to get labels and security-aware field presence
    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredInfo({ data, error }) {
        if (error) {
            this.error = error;
            this.isLoading = false;
            return;
        }
        if (!data) return;

        const lbls = new Map();
        Object.keys(data.fields || {}).forEach((api) => {
            lbls.set(api, data.fields[api].label || api);
        });
        this.fieldLabels = lbls;
        this.tryBuildFieldList();
    }

    // 2) Fetch active rules for the object
    @wire(getRulesForObject, { objectApiName: '$objectApiName' })
    wiredRules({ data, error }) {
        if (error) {
            this.error = error;
            this.isLoading = false;
            return;
        }
        if (!data) return;

        const seen = new Set();
        this.rules = (data || []).filter(r => {
            const api = (r.fieldApiName || '').trim();
            if (!api || seen.has(api)) return false;
            seen.add(api);
            return true;
        });
        this.tryBuildFieldList();
    }

    // Build the LDS field list once we have both rules and labels
    tryBuildFieldList() {
        if (!this.rules || this.rules.length === 0 || this.fieldLabels.size === 0) {
            return;
        }
        const objectApi = this.objectApiName;
        const fields = [];
        for (const r of this.rules) {
            // Only include fields that appear in object info (guards FLS/inaccessible too)
            if (this.fieldLabels.has(r.fieldApiName)) {
                fields.push(`${objectApi}.${r.fieldApiName}`);
            }
        }
        this._recordFieldApiNames = fields;
        // Allow getRecord to re-evaluate
        this.isLoading = false;
    }

    // 3) Fetch record with dynamic fields
    @wire(getRecord, { recordId: '$recordId', fields: '$_recordFieldApiNames' })
    wiredRecord({ data, error }) {
        if (error) {
            // If some fields are inaccessible, LDS can error; handle gracefully and still compute using what we have
            this.error = error;
            this.computeWith(null);
            return;
        }
        this.error = undefined;
        this.computeWith(data);
    }

    // Compute completeness and missing fields
    computeWith(record) {
        const fieldMap = record?.fields || {};
        const requiredMissing = [];
        const recommendedMissing = [];

        let totalWeight = 0;
        let achievedWeight = 0;

        for (const r of this.rules) {
            const api = r.fieldApiName;
            const isRequired = r.isRequired === true;
            const label = this.fieldLabels.get(api) || this.toFriendlyLabel(api);
            const weight = (r.weight != null ? Number(r.weight) : (isRequired ? 2 : 1));

            totalWeight += weight;

            const f = fieldMap[api];
            const val = f ? f.value : undefined;
            const isMissing =
                val === null ||
                val === undefined ||
                (typeof val === 'string' && val.trim() === '') ||
                (Array.isArray(val) && val.length === 0);

            if (isMissing) {
                const entry = { apiName: api, label, isRequired };
                if (isRequired) requiredMissing.push(entry);
                else recommendedMissing.push(entry);
            } else {
                achievedWeight += weight;
            }
        }

        const pct = totalWeight > 0 ? Math.round((achievedWeight / totalWeight) * 100) : 100;
        this.percentage = Math.max(0, Math.min(100, pct));
        this.missingRequired = requiredMissing.sort((a, b) => a.label.localeCompare(b.label));
        this.missingRecommended = recommendedMissing.sort((a, b) => a.label.localeCompare(b.label));
        this.status = this.computeStatus(this.percentage);
    }

    computeStatus(pct) {
        if (pct < 50) return 'Poor';
        if (pct <= 80) return 'At Risk';
        return 'Healthy';
    }

    // UI getters
    get hasRules() {
        return (this.rules && this.rules.length > 0);
    }
    get missingRequiredCount() {
        return this.missingRequired.length || 0;
    }
    get missingRecommendedCount() {
        return this.missingRecommended.length || 0;
    }
    get progressStyle() {
        const pct = Math.max(0, Math.min(100, this.percentage || 0));
        return `width:${pct}%`;
    }
    get progressBarClass() {
        const pct = this.percentage || 0;
        if (pct < 50) return 'dq-progress dq-progress_red';
        if (pct <= 80) return 'dq-progress dq-progress_yellow';
        return 'dq-progress dq-progress_green';
    }
    get progressBarCombinedClass() {
        return `slds-progress-bar ${this.progressBarClass}`;
    }
    get statusIconName() {
        const pct = this.percentage || 0;
        if (pct < 50) return 'utility:error';
        if (pct <= 80) return 'utility:warning';
        return 'utility:success';
    }
    get statusIconClass() {
        const pct = this.percentage || 0;
        if (pct < 50) return 'slds-icon-text-error';
        if (pct <= 80) return 'slds-icon-text-warning';
        return 'slds-icon-text-success';
    }
    get statusLabel() {
        const pct = this.percentage || 0;
        if (pct < 50) return 'Poor';
        if (pct <= 80) return 'At Risk';
        return 'Healthy';
    }

    // Fallback friendly label generator
    toFriendlyLabel(apiName) {
        return String(apiName)
            .replace(/__c$/, '')
            .replace(/Id$/, '')
            .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
            .trim();
    }
}
