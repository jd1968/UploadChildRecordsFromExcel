/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */

/* eslint-disable no-console */
/* eslint no-unused-vars: ["error", { "argsIgnorePattern": "^_" }] */

import { LightningElement, track, api } from 'lwc';
import { createRecord, updateRecord } from 'lightning/uiRecordApi';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { readAsBinaryString } from './readFile';
import SHEETJS_ZIP from '@salesforce/resourceUrl/sheetjs'
import insertRecords from '@salesforce/apex/UploadController.insertRecords';

export default class ExcelUpload extends LightningElement {    
    // Id of currently displayed record (component is only for display on record pages)
    @api recordId;  
    @api title;
    @api label;
    @api fieldNames;
    @api parentFieldAPIName;
    @api objectType; // the type of object to insert records into

    // state management to display spinners and the modal used while uploading the component
    ready = false;
    error = false;    

    uploading = false;
    uploadStep = 0;
    uploadMessage = '';
    uploadDone = false;
    uploadError = false;

    records = [];
    
    get loading() { return !this.ready && !this.error; }

    constructor() {
        super();

        loadScript(this, SHEETJS_ZIP + '/xlsx.full.min.js')
        .then(() => {
            if(!window.XLSX) {
                throw new Error('Error loading SheetJS library (XLSX undefined)');                
            }
            this.ready = true;
        })
        .catch(error => {
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Excel Upload: Error loading SheetJS',
                    message: error.message,
                    variant: 'error'
                })
            );
        });
    }

    // The promise chain for upload a new file will
    // 1. read the file, 2. parse it and extract the Excel cells and 
    // update the record, 3. upload the file to the record as "attachment"
    // (ContentVersion to be more precise), and 4. shortly wait to display
    // the modal before letting it disappear
    uploadFile(evt) {
        const recordId = this.recordId;               
        let file;
        
        Promise.resolve(evt.target.files)        
        .then( files => {
            this.uploading = true;
            this.uploadStep = "1";
            this.uploadMessage = 'Reading File';
            this.uploadDone = false;
            this.uploadError = false;

            if(files.length !== 1) {
                throw new Error("Error accessing file -- " + 
                    (files.length === 0 ? 
                        'No file received' : 
                        'Multiple files received'
                    ));
            }        
 
            file = files[0];
            return readAsBinaryString(file);
        })                
        .then( blob => {
            this.uploadStep = "2";
            this.uploadMessage = 'Extracting Data';

            let workbook = window.XLSX.read(blob, {type: 'binary'});    

            if(!workbook || !workbook.Workbook) { throw new Error("Cannot read Excel File (incorrect file format?)"); }
            if(workbook.SheetNames.length < 1) { throw new Error("Excel file does not contain any sheets"); }            
            
            let sheetName = workbook.SheetNames[0];           
            let sheet = workbook.Sheets[sheetName];
            console.log('sheet',sheet);

            let range = sheet['!ref'];
            console.log('range',range);

            const jsonData = XLSX.utils.sheet_to_json(sheet, { header: 1 });

            // reset records so previous attempts don't get saved
            this.records = [];

            for(const row of jsonData.slice(1)) {
                const record = [];

                //don't try to create records for empty rows
                if(row.length > 0){

                    for(const value of row){
                        record.push(this.tidyValue(value));
                    }
            
                    this.records.push(record);

                }
                
            }

            this.uploadStep = "3";
            this.uploadMessage = 'Inserting Records';

            // Call Apex method and pass the object type and records
            const fieldNameList = this.fieldNames.split(',');
            console.log(fieldNameList);
            return insertRecords({ sObjectTypeName: this.objectType, parentFieldAPIName:this.parentFieldAPIName, parentRecordId: recordId, fieldNames: fieldNameList, recordsList: this.records})
                              
        })
        .then( _cv => {
            this.uploadStep = "4";
            // Unfortunately, the last step won't get a check mark -- 
            // the base component <lightning-progress-indicator> is missing this functionality        
            this.uploadMessage = "Done";  
            this.uploadDone = true;       
            return new Promise(function(resolve, _reject){ 
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.setTimeout(resolve, 1000); 
            });             
        })
        .then( () => {
            this.closeModal();

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Excel Upload: Success',
                    message: this.records.length + ' records uploaded',
                    variant: 'success'
                })
            );             
        })
        
        .catch( err => {
            this.uploadError = true;
            this.uploadMessage = "Error: " + err.body.message + "\n\nNo records were inserted.  Please correct the data or check the configuration of the component.";
            console.log(err);
        });
    }

    tidyValue(obj) {
        // Check if the object is a string
        if (typeof obj === 'string') {
            return obj.trim();
        }
        return obj; // Return the object unchanged if it's not a string
    }

    closeModal() {
        this.uploading = false;
        this.uploadStep = 0;
        this.uploadMessage = '';
        this.uploadDone = false;
        this.uploadError = false;       
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
        });
        this.dispatchEvent(event);
    }
}