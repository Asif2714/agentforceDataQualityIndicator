import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import OBJECT_API_NAME_FIELD from '@salesforce/schema/Data_Quality_Config__c.Object_API_Name__c';
import CREATED_DATE_FIELD from '@salesforce/schema/Data_Quality_Config__c.CreatedDate';
import LAST_MODIFIED_DATE_FIELD from '@salesforce/schema/Data_Quality_Config__c.LastModifiedDate';

import saveConfiguration from '@salesforce/apex/DataQualityService.saveConfiguration';
import getFieldConfigs from '@salesforce/apex/DataQualityService.getFieldConfigs';

const FIELDS = [OBJECT_API_NAME_FIELD, CREATED_DATE_FIELD, LAST_MODIFIED_DATE_FIELD];

export default class DataQualityConfigEditor extends LightningElement {
    @api recordId;

    @track rows = [];
    @track isLoading = true;
    @track error;

    targetObjectApiName;
    _record;
    objectInfo;
    availableFieldOptions = []; // All fields from object info

    // Weight Options - value must match the picklist API value (fullName), not the label
    get weightOptions() {
        return [
            { label: '1 - Low', value: '1' },
            { label: '2 - Minor', value: '2' },
            { label: '3 - Medium', value: '3' },
            { label: '4 - High', value: '4' },
            { label: '5 - Critical', value: '5' },
        ];
    }

    // 1. Fetch the Target Object API Name and Metadata from the Config Record
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredConfigRecord({ error, data }) {
        if (data) {
            this._record = data;
            this.targetObjectApiName = getFieldValue(data, OBJECT_API_NAME_FIELD);
            this.error = undefined;
        } else if (error) {
            this.error = 'Error loading config record: ' + (error.body ? error.body.message : error.message);
            this.targetObjectApiName = undefined;
        }
    }

    get displayObjectName() {
        return this.targetObjectApiName || 'Loading...';
    }

    get displayCreatedDate() {
        return getFieldValue(this._record, CREATED_DATE_FIELD);
    }

    get displayLastModifiedDate() {
        return getFieldValue(this._record, LAST_MODIFIED_DATE_FIELD);
    }

    // 2. Fetch Object Info for the Target Object to populate field picklists
    @wire(getObjectInfo, { objectApiName: '$targetObjectApiName' })
    wiredObjectInfo({ error, data }) {
        if (data) {
            this.objectInfo = data;
            const options = [];
            Object.keys(data.fields).forEach(apiKey => {
                options.push({
                    label: data.fields[apiKey].label,
                    value: apiKey,
                    // Store extra data if needed, e.g. type
                });
            });
            // Sort by label
            options.sort((a, b) => a.label.localeCompare(b.label));
            this.availableFieldOptions = options;

            // Now that we have fields, fetch existing config
            this.fetchExistingConfig();
        } else if (error) {
            // If the object name is invalid or not found
            this.error = 'Error loading Object Info. Check API Name: ' + (error.body ? error.body.message : error.message);
            this.isLoading = false;
        }
    }

    // 3. Fetch existing rows if any
    fetchExistingConfig() {
        this.isLoading = true;
        getFieldConfigs({ configId: this.recordId })
            .then(result => {
                if (result && result.length > 0) {
                    this.rows = result.map((item, index) => {
                        return {
                            key: Math.random().toString(36).substring(2, 15),
                            id: item.id,
                            fieldApiName: item.apiName,
                            label: item.label,
                            weight: item.weight || '1 - Low',
                            isRequired: item.isRequired,
                            // availableOptions will be calculated by computeAvailableOptions
                            availableOptions: []
                        };
                    });
                } else {
                    // Start with one empty row if none exist
                    this.handleAddRow();
                }
                this.computeAvailableOptions();
                this.isLoading = false;
            })
            .catch(err => {
                this.error = 'Error loading existing config: ' + err.body.message;
                this.isLoading = false;
            });
    }

    handleAddRow() {
        // Prevent adding if no object info yet
        if (!this.targetObjectApiName || !this.availableFieldOptions.length) {
            return;
        }

        const newRow = {
            key: Math.random().toString(36).substring(2, 15),
            fieldApiName: '',
            label: '',
            weight: '1',
            isRequired: false,
            availableOptions: []
        };
        this.rows = [...this.rows, newRow];
        this.computeAvailableOptions();
    }

    handleRemoveRow(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.rows.splice(index, 1);
        // Force refresh
        this.rows = [...this.rows];
        this.computeAvailableOptions();
    }

    handleFieldChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const val = event.detail.value;
        this.rows[index].fieldApiName = val;

        this.computeAvailableOptions();
    }

    handleWeightChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.rows[index].weight = event.detail.value;
    }

    handleRequiredChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.rows[index].isRequired = event.detail.checked;
    }

    // Filter Picklists: Remove fields selected in other rows
    computeAvailableOptions() {
        const selectedFields = new Set();
        this.rows.forEach(r => {
            if (r.fieldApiName) selectedFields.add(r.fieldApiName);
        });

        // Update each row's options
        this.rows = this.rows.map(row => {
            // Options for this row = All Options - (Selected by others)
            // ie. If I selected 'Name', 'Name' should be in MY options, but not others.

            const mySelection = row.fieldApiName;

            const filtered = this.availableFieldOptions.filter(opt => {
                // If this option is not selected by anyone, include it
                if (!selectedFields.has(opt.value)) return true;
                // If this option is selected by ME, include it
                if (opt.value === mySelection) return true;
                return false;
            });

            return { ...row, availableOptions: filtered };
        });
    }

    get disableAdd() {
        // Disable adding if we ran out of fields (rare) or haven't loaded
        return !this.availableFieldOptions || this.availableFieldOptions.length === 0;
    }

    handleSave() {
        // Validate
        const toSave = [];
        let isValid = true;

        // Basic validation: check empty fields
        this.rows.forEach(r => {
            if (!r.fieldApiName) {
                isValid = false;
            }

            const opt = this.availableFieldOptions.find(o => o.value === r.fieldApiName);
            let finalLabel = r.label || (opt ? opt.label : r.fieldApiName);

            toSave.push({
                id: r.id,
                apiName: r.fieldApiName,
                label: finalLabel,
                weight: r.weight,
                isRequired: !!r.isRequired
            });
        });

        if (!isValid) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'All rows must have a selected field.',
                variant: 'error'
            }));
            return;
        }

        // Call Apex
        this.isLoading = true;
        saveConfiguration({ configId: this.recordId, itemsJson: JSON.stringify(toSave) })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Configuration saved.',
                    variant: 'success'
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error saving',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
                this.isLoading = false;
            });
    }
}