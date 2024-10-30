# Excel Upload Child Records Lightning Web Component

## Description

A Lightning Component that allows you to upload an Excel File containing multiple rows of data, to create detail (child) records related to a mster record (i.e. on a Lightning Record Page).

For example, use the component on an account record page to load contacts from an Excel file.  The contact records are created and linked to the account.

## How to Use the Component
The component should be added to a record page.  It uses the 'recordId' property to set the parent record Id.  

The first tab of the Excel file will be used.  The first row will be ignored as it's assumed this will be column headers.

## Properties

### Title
The top-level title that is displayed on the component e.g. 'Upload Excel File'

### Label 
The secondary text that is displayed on the component e.g. 'Excel File'

### objectType
The API Name of the type of objects to create e.g. 'Contact'

### parentFieldAPIName
The API Name of the field (Master-detail or Lookup) on the object to use as the parent record Id.  For example if adding contacts to an account, the value would be 'accountId'

### fieldNames
A comma-delimited list of field names that map to columns in the Excel sheet.  If there are fields that are not used, an empty field should be specified.  For example for an Excel file of Contacts where the first two columns are ignored and the third and fourth contain First Name and Last Name, the value of the property would be:

    ,,FirstName, LastName


# License

See LICENSE file in this repository.  

This component uses the [SheetJS Community Edition library](https://github.com/SheetJS/sheetjs),
which is licensed under the Apache License 2.0.  See the LICENSE file in 
force-app/main/default/staticresources/sheetjs.
