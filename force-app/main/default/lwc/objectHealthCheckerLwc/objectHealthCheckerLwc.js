import { LightningElement, track } from 'lwc';
import getHealthStats from '@salesforce/apex/ObjectHealthChecker.getHealthStats';

export default class ObjectHealthCheckerLwc extends LightningElement {
    @track selectedObject = '';
    @track fieldStats = [];
    @track isLoading = false;
    @track errorMessage = '';
    @track successMessage = '';

    // Available objects for selection - in a real implementation, this could be dynamically fetched
    // For now, we'll provide a reasonable list of common objects
    objects = [
        { label: 'Account', value: 'Account' },
        { label: 'Contact', value: 'Contact' },
        { label: 'Opportunity', value: 'Opportunity' },
        { label: 'Lead', value: 'Lead' },
        { label: 'Case', value: 'Case' },
        { label: 'Product2', value: 'Product2' },
        { label: 'User', value: 'User' },
        { label: 'Custom Object 1', value: 'CustomObject1__c' },
        { label: 'Custom Object 2', value: 'CustomObject2__c' }
    ];

    constructor() {
        super();
        // Initialize fieldStats to ensure it's always an array
        this.fieldStats = [];
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.fieldStats = [];
        this.errorMessage = '';
        this.successMessage = '';
    }

    handleClick() {
        if (!this.selectedObject) {
            this.errorMessage = 'Please select an object to check';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        // Call the Apex method with proper error handling
        // Using the new LWC-specific method
        getHealthStats(this.selectedObject)
            .then(fieldStats => {
                console.log('Received field stats:', fieldStats);
                
                // Direct assignment since we're getting the array directly
                this.fieldStats = fieldStats;
                this.successMessage = 'Retrieved ' + fieldStats.length + ' field statistics';
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Apex call error:', error);
                console.error('Error body:', error.body);
                this.errorMessage = 'Error calling Apex method: ' + (error.body?.message || error.message || 'Unknown error');
                this.fieldStats = [];
                this.isLoading = false;
            });
    }
}