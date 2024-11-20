    @isTest
private class UploadControllerTest {

    @isTest
    static void insertTest() {

        Account testAccount1 = new Account();

        testAccount1.Name = 'Test Account 1';
        testAccount1.BillingCity = 'London';
        testAccount1.BillingCountry = 'UK';
        
        insert testAccount1;

        Account testAccount2 = new Account();

        testAccount2.Name = 'Test Account 2';
        testAccount2.BillingCity = 'Swindon';
        testAccount2.BillingCountry = 'UK';
        
        insert testAccount2;

        List<String> fieldNames = new List<String>();
        fieldNames.add('FirstName');
        fieldNames.add('LastName');
        fieldNames.add('Email');
        fieldNames.add('Phone');
        fieldNames.add('Birthdate');
        fieldNames.add('MailingLatitude');
        fieldNames.add('MailingLongitude');
        fieldNames.add('ReportsToId');

        //create a contact for 'reportsTo'
        Contact reportsToContact = new Contact();
        reportsToContact.accountId = testAccount2.Id;
        reportsToContact.LastName = 'Bossman';
        insert reportsToContact;


        // Create records for the Contacts
        List<List<String>> contactRecords = createContactRecords(10);

        Test.startTest();

        UploadController.insertRecords('Contact', fieldNames, 'accountId', testAccount2.Id, contactRecords);
    
        Test.stopTest();


        List<Contact> contacts = [SELECT Id, AccountId FROM Contact WHERE AccountId = :testAccount2.Id];

        Assert.areEqual(11,contacts.size(),'Incorrect number of contacts created');

        Assert.areEqual(testAccount2.id, contacts[0].AccountId, 'Contacts should have correct Account Id');


    }

    @isTest
    static void insertExceptionTest() {

        //create contacts with incorrect AccountId
        List<List<String>> contactRecords = createContactRecords(10);

        List<String> fieldNames = new List<String>();

        Boolean isException = false;

        fieldNames.add('FirstName');
        fieldNames.add('LastName');
        
        Test.startTest();

        try {
            UploadController.insertRecords('Contact', fieldNames, 'accountId', 'xxx', contactRecords);

        } catch (Exception e) {
            
            isException = true;
            Assert.areEqual('System.AuraHandledException', e.getTypeName(),'Exception is of the wrong type');
            
        }

        Assert.areEqual(true, isException, 'Exception should have been thrown');

        Test.stopTest();


    }

    static List<List<String>> createContactRecords(Integer count){

        List<List<String>> contactRecords = new List<List<String>>();
    
        for (Integer i = 0; i < 10; i++) {

            List<String> contactRecord = new List<String>();

            contactRecord.add('Test');
            contactRecord.add('Contact' + i);
            contactRecord.add('test.contact@test.com');
            contactRecord.add('123-456-7890');
            contactRecord.add('1/3/1978');
            contactRecord.add('1');
            contactRecord.add('0');
            contactRecord.add('Bossman');
            
            contactRecords.add(contactRecord);
        }

        return contactRecords;
    }
    
}