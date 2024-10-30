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

        // Create records for the Contacts
        List<List<String>> contactRecords = new List<List<String>>();
    
        for (Integer i = 0; i < 10; i++) {

            List<String> contactRecord = new List<String>();

            contactRecord.add('Test');
            contactRecord.add('Contact' + i);
            contactRecord.add('test.contact@test.com');
            contactRecord.add('123-456-7890');
            contactRecord.add('1/3/1978');
            
            contactRecords.add(contactRecord);
        }

        Test.startTest();

        UploadController.insertRecords('Contact', fieldNames, 'accountId', testAccount2.Id, contactRecords);
    
        Test.stopTest();


        List<Contact> contacts = [SELECT Id, AccountId FROM Contact];

        Assert.areEqual(10, contacts.size(),'Incorrect number of contacts created');

        Assert.areEqual(testAccount2.id, contacts[0].AccountId, 'Contacts should have correct Account Id');


    }
    
}