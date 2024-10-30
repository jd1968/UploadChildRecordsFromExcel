public with sharing class UploadController {

    // Get Map of lookup values
    private static Map<String, Map<String, Id>> referenceData  = new Map<String, Map<String, Id>>();

    private static List<FieldMetadata> fields;

    private static Map<String, Schema.SObjectField> fieldMap;

    private static Schema.SObjectType sObjectType;

    private static FieldMetadata parentRecordIdField = new FieldMetadata();

    @AuraEnabled
    public static void insertRecords(String sObjectTypeName, List<String> fieldNames, String parentFieldAPIName, String parentRecordId, List<List<String>> recordsList) {
       try {
            
            // Get the SObjectType dynamically from the name
            sObjectType = Schema.getGlobalDescribe().get(sObjectTypeName);

            // Check if the user has permission to create records of this type
            if (sObjectType.getDescribe().isCreateable()) {

                //populate this from metadata
                fields = getFieldMetadata(fieldNames);

                if(parentFieldAPIName != null && parentFieldAPIName != '') {   
                    parentRecordIdField.dataType = 'ID'; // don't do a lookup, it's an ID already
                    parentRecordIdField.fieldName = parentFieldAPIName;
                    fields.add(parentRecordIdField);
                }

                // get the keys for the referenceData Map - representing the reference (lookup/master-detail) fields in the list of fields
                getReferenceFields(fields);

                // get the lookup values to use
                getReferenceValues(recordsList, fields);

                // populate the lookup ids (foreign keys) to use
                getReferencedIds(sObjectType, recordsList, fields);

                List<SObject> records = new List<SObject>();

                for(List<String> record: recordsList){
                    SObject sObj = sObjectType.newSObject();

                    for(Integer fieldIndex = 0;fieldIndex <=fields.size()-1; fieldIndex++){

                        String fieldName = fields[fieldIndex].fieldName;
                        Object value;
                        Boolean ignore = false;

                        switch on fields[fieldIndex].dataType {
                            when 'REFERENCE' {
                                
                                value = getIdFromName(fieldIndex, record[fieldIndex]);
                            }
                            when 'ID' {
                                
                                value = parentRecordId;
                            }
                            when 'DOUBLE','CURRENCY','PERCENT','INTEGER' {
                                if(record[fieldIndex]!=''){
                                    value = Decimal.valueOf(record[fieldIndex]);
                                } else {
                                    value = null;
                                }
                            }
                            when 'DATE' {
                                
                                //convert record[fieldIndex] to Apex date format
                                value = Date.parse(record[fieldIndex]);
                            }

                            when '' {
                                ignore = true;
                            }
                            when else {
                                //attempt to use value as is
                                value = record[fieldIndex];
                            }
                        }

                        if(!ignore) {
                            sObj.put(fieldName, value);
                        }

                    }

                    records.add(sObj);

                }

                // insert records, rolling back all if any fail
                Database.DMLOptions options = new Database.DMLOptions();
                options.OptAllOrNone = true;

                List<Database.SaveResult> results = Database.insert(records, options);

            } else {
                throw new AuraHandledException('Insufficient permissions to create ' + sObjectTypeName + ' records.');
            }

        } catch (UploadController.DataException e) {

            String message = 'There was a problem with the data';

            throw new AuraHandledException(message + ': ' + e.getMessage());

        } catch (SObjectException e) {

            String message = 'There was a problem with the configuration of the component';

            throw new AuraHandledException(message + ': ' + e.getMessage());
        
        } catch (Exception e){

            String exceptionType = e.getTypeName();
            System.debug('Exception Type: ' + exceptionType);
            System.debug('Exception: ' + e);
            
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static List<FieldMetadata> getFieldMetadata(List<String> fieldNames){

        // Get the fields of the specified object
        fieldMap = sObjectType.getDescribe().fields.getMap();

        List<FieldMetadata> fields =  new List<FieldMetadata>();

        // for(FieldMetadata field: fields){
        for(String fieldName: fieldNames){
            Schema.SObjectField fieldMetadata = fieldMap.get(fieldName);

            FieldMetadata field = new FieldMetadata();

            if(fieldMetadata!=null){
                field.fieldName = fieldName;
                Schema.DescribeFieldResult fieldResult = fieldMetadata.getDescribe();
                field.dataType =  fieldResult.getType().toString();
                if(field.dataType == 'REFERENCE'){
                    field.referenceObject = fieldResult.getReferenceTo().toString();
                }
                
                
            } else {
                //add a dummy field
                field.dataType =  '';

            }
            fields.add(field);
        }

        return fields;

    }

    // for each field, if it's a reference field then create a placegolder in the referenceData map
    private static void  getReferenceFields(List<FieldMetadata> fields){

        Integer index = 0;

        for(FieldMetadata field : fields){

            if(field.dataType == 'Reference'){
                referenceData.put(index.toString(), new Map<String, Id>());
            }

            index++;
        }

    }

    // for each reference field, populate the lookup map with lookup Name values
    // e.g. will create an entry in reference Data of {3}:{'Morrocco', null} where 3 is the field index
    private static void  getReferenceValues(List<List<String>> records, List<FieldMetadata> fields){

        //loop through the records and populate the lookup map
        for(List<String> record : records){

            // for each value in record
            for(Integer i = 0; i < record.size(); i++){

                for(String referenceDataIndex : referenceData.keySet()){
                    if(i.toString() == referenceDataIndex){
                        String referenceFieldName = fields[Integer.valueOf(referenceDataIndex)].fieldName;
                        referenceData.get(referenceDataIndex).put(record.get(i), null);
                    }
                
                }
            }

        }

    }

    // for each reference data entry, query the Id, so we will end up with entries in referenceData like:
    // {3}:{'Morocco',[recordId]}
    private static void  getReferencedIds(Schema.SObjectType sObjectType, List<List<String>> records, List<FieldMetadata> fields){

        // Get the fields of the specified object
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();

        for(String referenceDataField : referenceData.keySet()){
            
            // which field to look up? Get the field name from the fields collection using index
            String fieldName = fields[Integer.valueOf(referenceDataField)].fieldName;

            // get the metadata for the field - this sill give us the related object to use to look up the Id
            Schema.DescribeFieldResult fieldResult = fieldMap.get(fieldName).getDescribe();
            List<Schema.SObjectType> referencedSObjects = fieldResult.getReferenceTo();

            if(referencedSObjects.size()> 1){
                throw new SObjectException('More than one referenced SObject for a reference field is not supported.  This happened for field: ' + fieldName);
            }
            
            String referencedObjectName = referencedSObjects[0].getDescribe().getName();

            List<String> objectNamesList = new List<String>();

            for(String key: referenceData.get(referenceDataField).keySet()){
                objectNamesList.add(key);
            }

            String query = 'SELECT Name, Id FROM ' + referencedObjectName + ' WHERE Name IN :objectNamesList';

            // execute SOQL Query and get Id from result
            // NB this is one of the few occasions where a query inside a loop is required
            // because we don't know how many lookup fields will be specified
            List<SObject> queriedRecords = Database.query(query);
            
            for(SObject obj: queriedRecords){
                if(obj.get('Id')== null){
                    throw new DataException('No Id found for Name: ' + obj.get('Name') + ' in SObject ' + referencedObjectName);
                }
                referenceData.get(referenceDataField).put(obj.get('Name').toString(), (Id)obj.get('Id'));
            }

        }

        
    }

   

    // return an Id from the Map containining referenced fields and Name/Id pairings
    private static String getIdFromName(Integer fieldIndex, String name){

        Map<String, Id> values = referenceData.get(fieldIndex.toString());

        Id value = values.get(Name);

        if(value==null){
            throw new DataException('No Id found for Name: ' + Name + ' in field index ' + fieldIndex);
        }

        return value;

    }


    public Class FieldMetadata {

        @AuraEnabled
        public String fieldName {get;set;}
        @AuraEnabled
        public String dataType {get;set;}
        @AuraEnabled
        public String referenceObject {get;set;}
    }

    public class InvalidDataTypeException extends Exception {

    }

    public class DataException extends Exception {

    }


}