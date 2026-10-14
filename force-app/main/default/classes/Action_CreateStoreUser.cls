public with sharing class Action_CreateStoreUser {
    @InvocableMethod(label='Create Store User' description='Creates a store user with permission set assignment')
    public static void createUsers(List<Id> ids) {
        try {
            Storefront_User_Setting__mdt setting = Storefront_User_Setting__mdt.getInstance('Default');

            Database.DMLOptions dlo = new Database.DMLOptions();
            dlo.EmailHeader.triggerUserEmail = true;

            Map<Id, Contact> contacts = new Map<Id, Contact>([
                SELECT Id, FirstName, LastName, Email, AccountId 
                FROM Contact 
                WHERE Id IN :ids
            ]);
            Profile profile = [SELECT Id FROM Profile WHERE Name = :setting.Profile__c LIMIT 1];
            
            List<User> usersToCreate = new List<User>();
            for (Contact contact : contacts.values()) {
                User user = new User();
                user.Username = contact.email;
                user.FirstName = contact.FirstName;
                user.LastName = contact.LastName;
                user.Email = contact.Email;
                user.ProfileId = profile.Id;
                user.CommunityNickname = (user.FirstName + user.LastName + Datetime.now()).abbreviate(40);
                user.TimeZoneSidKey = 'America/Los_Angeles';
                user.Alias = (user.FirstName.subString(0,1) + user.LastName).abbreviate(8);
                user.LocaleSidKey = 'en_US';
                user.EmailEncodingKey = 'UTF-8';
                user.LanguageLocaleKey = 'en_US';
                user.IsActive = true;
                user.ContactId = contact.Id;
                user.setOptions(dlo);
                usersToCreate.add(user);
            }
            
            Database.insert(usersToCreate, dlo);

            System.enqueueJob(new Utils_AssignPermissionSets(usersToCreate, setting.Permission_Sets__c));
                
        } catch (Exception e) {
            System.debug('Failed to create users: ' + e.getMessage());
        }
    }
}