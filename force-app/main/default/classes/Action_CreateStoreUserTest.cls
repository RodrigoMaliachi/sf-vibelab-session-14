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

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Action_CreateStoreUser.createUsers(new List<Id>{ testContact.Id });
            Test.stopTest();
        }

        User createdUser = [
            SELECT Id, Store_Access__c, ContactId
            FROM User
            WHERE Username = 'testa1@email.com'
            LIMIT 1
        ];

        List<PermissionSetAssignment> assignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId =: createdUser.Id
            AND PermissionSet.IsOwnedByProfile = false
        ];

        Assert.areEqual(
            2,
            assignments.size(),
            'A permission set should be assigned to the created user.'
        );
        Assert.areEqual(
            Action_CreateStoreUser.READ_ONLY,
            createdUser.Store_Access__c,
            'The created user should inherit the Contact read only access.'
        );
        Assert.areEqual(
            testContact.Id,
            createdUser.ContactId,
            'The created user should be related to the source Contact.'
        );
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
        Assert.areEqual(
            Action_CreateStoreUser.READ_ONLY,
            updatedUser.Store_Access__c,
            'The existing user access should match the updated Contact role.'
        );
    }

    @IsTest
    private static void emptyIdsDoNotCreateUsers() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Action_CreateStoreUser.createUsers(new List<Id>());
            Assert.areEqual(0, Limits.getQueries(), 'Empty input should return without querying records.');
            Assert.areEqual(0, Limits.getDmlStatements(), 'Empty input should return without performing DML.');
            Test.stopTest();
        }
    }

    @IsTest
    private static void throwsWhenDefaultSettingsAreMissing() {
        Account testAccount = new Factory_CommerceRecords.AccountFactory().build();
        testAccount.Name = 'Missing Settings';
        insert testAccount;

        Contact con = new Factory_CommerceRecords.ContactFactory(testAccount.Id).build();
        con.Email = 'missing.settings@example.com';
        con.FirstName = 'Missing';
        con.LastName = 'Settings';
        con.Ecomm_Type__c = Action_CreateStoreUser.BUY_ACCESS;
        insert con;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            try {
                Action_CreateStoreUser.createUsers(new List<Id>{ con.Id }, null);
                Assert.fail('Expected an exception when Default New User Settings are missing.');
            } catch (Action_CreateStoreUser.CreateStoreUserException e) {
                Assert.isTrue(
                    e.getMessage().contains('Default New User Settings are missing'),
                    'Exception should explain that the default configuration is missing.'
                );
            }
            Test.stopTest();
        }
    }

    @IsTest
    private static void ignoresUnknownContactId() {
        String contactPrefix = Contact.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix();
        Id fakeContactId = Id.valueOf(contactPrefix + '000000000001');

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Action_CreateStoreUser.createUsers(new List<Id>{ fakeContactId });
            Assert.areEqual(1, Limits.getQueries(), 'Only the Contact lookup should run for an unknown Contact id.');
            Assert.areEqual(0, Limits.getDmlStatements(), 'No users should be created when the Contact is not found.');
            Test.stopTest();
        }
    }
}