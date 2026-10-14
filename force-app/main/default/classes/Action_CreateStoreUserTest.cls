@IsTest
public class Action_CreateStoreUserTest {

    @IsTest
    private static void createUserTest() {
        Assert.areEqual(0, [SELECT Id FROM Contact WHERE Email = 'testa1@email.com'].size());
        Assert.areEqual(0, [SELECT Id FROM User WHERE Username = 'testa1@email.com'].size());

        BuyerGroup testBuyerGroup = new Factory_CommerceRecords.BuyerGroupFactory().create();

        Factory_CommerceRecords.AccountFactory accountFactory = new Factory_CommerceRecords.AccountFactory();
        accountFactory.accountName = 'Test LN1';
        accountFactory.type = 'Prospect';
        Account testAccount = accountFactory.create();

        Factory_CommerceRecords.ContactFactory contactFactory = new Factory_CommerceRecords.ContactFactory(testAccount.Id);
        contactFactory.email = 'testa1@email.com';
        contactFactory.firstName = 'Test';
        contactFactory.lastName = 'LN1';
        Contact testContact = contactFactory.create();

        Test.startTest();
        testAccount.Type = 'Customer - Direct';
        update testAccount;
        Test.stopTest();

        User u = [SELECT Id FROM User WHERE Username = 'testa1@email.com'];
        Assert.areNotEqual(null, u);

        Assert.areNotEqual(0, [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :u.Id].size());
    }
}