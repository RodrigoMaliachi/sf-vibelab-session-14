@IsTest
public class Action_CreateStoreUserTest {

    @IsTest
    private static void createUserTest() {

        Factory_CommerceRecords.AccountFactory accountFactory = new Factory_CommerceRecords.AccountFactory();
        accountFactory.accountName = 'Test LN1';
        accountFactory.type = 'Prospect';
        Account testAccount = accountFactory.create();

        Contact testContact = new Factory_CommerceRecords.ContactFactory(testAccount.Id).build();
        testContact.Email = 'testa1@email.com';
        testContact.FirstName = 'Test';
        testContact.LastName = 'LN1';
        testContact.Ecomm_Type__c = Action_CreateStoreUser.READ_ONLY;
        insert testContact;

        BuyerGroup testBuyerGroup = new Factory_CommerceRecords.BuyerGroupFactory().create();

        Test.startTest();
        Action_CreateStoreUser.createUsers(new List<Id>{ testContact.Id });
        Test.stopTest();

        Assert.areNotEqual(0, [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId IN (SELECT Id FROM User WHERE Username = 'testa1@email.com')].size());

        User createdUser = [
            SELECT Id, Store_Access__c, ContactId
            FROM User
            WHERE Username = 'testa1@email.com'
            LIMIT 1
        ];
        Assert.areEqual(1, [SELECT COUNT() FROM User WHERE ContactId = :testContact.Id]);
        Assert.areEqual(Action_CreateStoreUser.READ_ONLY, createdUser.Store_Access__c);
        Assert.areEqual(testContact.Id, createdUser.ContactId);
    }

    @IsTest
    private static void updatesExistingUserAccess() {
        Factory_CommerceRecords.CommerceFactoryResponse response = Factory_CommerceRecords.buildCommerceUser();
        Contact con;
        User existingUser;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            con = [SELECT Id FROM Contact WHERE Id =: response.contactId];
            con.Ecomm_Type__c = Action_CreateStoreUser.READ_ONLY;
            update con;


            existingUser = [SELECT Id FROM User WHERE Id = :response.userId];
            existingUser.Store_Access__c = Action_CreateStoreUser.BUY_ACCESS;
            update existingUser;
        }


        Test.startTest();
        Action_CreateStoreUser.createUsers(new List<Id>{ con.Id });
        Test.stopTest();

        User updatedUser = [SELECT Store_Access__c FROM User WHERE Id = :existingUser.Id];
        Assert.areEqual(Action_CreateStoreUser.READ_ONLY, updatedUser.Store_Access__c);
    }
}