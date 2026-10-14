public with sharing class Action_CreateStoreUser {
    @TestVisible
    private static final String DEFAULT_SETTINGS_DEVELOPER_NAME = 'Default';
    @TestVisible
    private static final String READ_ONLY = 'Read Only';
    @TestVisible
    private static final String BUY_ACCESS = 'Buy Access';
    private static final Set<String> ACCESS_OPTIONS = new Set<String>{ READ_ONLY, BUY_ACCESS };
    
    @InvocableMethod(label='Create Store User' description='Creates a store user with permission set assignment')
    public static void createUsers(List<Id> ids) {
        createUsers(ids, Storefront_User_Setting__mdt.getInstance(DEFAULT_SETTINGS_DEVELOPER_NAME));
    }

    @TestVisible
    private static void createUsers(List<Id> ids, Storefront_User_Setting__mdt settings) {
        if (ids == null || ids.isEmpty()) {
            return;
        }

        try {
            if (settings == null) {
                throw new CreateStoreUserException('Default New User Settings are missing.');
            }

            List<Contact> contacts = [
                SELECT Id, FirstName, LastName, Email, Ecomm_Type__c
                FROM Contact
                WHERE Id IN :ids
                AND Ecomm_Type__c IN :ACCESS_OPTIONS
            ];
            if (contacts.isEmpty()) {
                return;
            }

            Map<Id, Contact> contactsById = new Map<Id, Contact>(contacts);
            Map<Id, User> existingUsersByContactId = findExistingUsers(contactsById.keySet());
            List<User> usersToUpdate = new List<User>();
            List<Contact> contactsToCreateUsersFor = selectContactsToCreate(
                contacts,
                existingUsersByContactId,
                usersToUpdate
            );

            if (!usersToUpdate.isEmpty()) {
                update usersToUpdate;
            }

            List<User> usersToCreate = createMissingUsers(contactsToCreateUsersFor, settings);
            if (!usersToCreate.isEmpty()) {
                insertUsers(usersToCreate, settings);
            }
        } catch (Exception e) {
            throw new CreateStoreUserException('Unable to provision community users: ' + e.getMessage());
        }
    }

    private static Map<Id, User> findExistingUsers(Set<Id> contactIds) {
        Map<Id, User> usersByContactId = new Map<Id, User>();
        for (User existingUser : [
            SELECT Id, ContactId, Store_Access__c
            FROM User
            WHERE ContactId IN :contactIds
        ]) {
            usersByContactId.put(existingUser.ContactId, existingUser);
        }
        return usersByContactId;
    }

    private static List<Contact> selectContactsToCreate(
        List<Contact> contacts,
        Map<Id, User> existingUsersByContactId,
        List<User> usersToUpdate
    ) {
        List<Contact> contactsToCreate = new List<Contact>();
        for (Contact contact : contacts) {
            User existingUser = existingUsersByContactId.get(contact.Id);
            if (existingUser != null) {
                if (existingUser.Store_Access__c != contact.Ecomm_Type__c) {
                    existingUser.Store_Access__c = contact.Ecomm_Type__c;
                    usersToUpdate.add(existingUser);
                }
            } else if (String.isNotBlank(contact.Email) &&
                String.isNotBlank(contact.FirstName) && String.isNotBlank(contact.LastName)) {
                contactsToCreate.add(contact);
            }
        }
        return contactsToCreate;
    }

    private static List<User> createMissingUsers(List<Contact> contacts, Storefront_User_Setting__mdt settings) {
        List<User> users = new List<User>();
        if (contacts.isEmpty()) {
            return users;
        }

        Profile profile = [SELECT Id FROM Profile WHERE Name = :settings.Profile__c LIMIT 1];
        for (Contact contact : contacts) {
            users.add(buildCommunityUser(contact, profile.Id));
        }
        return users;
    }

    private static void insertUsers(List<User> users, Storefront_User_Setting__mdt settings) {
        Database.DMLOptions options = new Database.DMLOptions();
        options.EmailHeader.triggerUserEmail = true;
        Database.insert(users, options);
        System.enqueueJob(new Utils_AssignPermissionSets(users, settings.Permission_Sets__c));
    }

    private static User buildCommunityUser(Contact contact, Id profileId) {
        User newUser = new User();
        newUser.Username = contact.Email;
        newUser.FirstName = contact.FirstName;
        newUser.LastName = contact.LastName;
        newUser.Email = contact.Email;
        newUser.ProfileId = profileId;
        newUser.CommunityNickname = (contact.FirstName + contact.LastName + Datetime.now()).abbreviate(40);
        newUser.TimeZoneSidKey = 'America/Los_Angeles';
        newUser.Alias = (contact.FirstName.substring(0, 1) + contact.LastName).abbreviate(8);
        newUser.LocaleSidKey = 'en_US';
        newUser.EmailEncodingKey = 'UTF-8';
        newUser.LanguageLocaleKey = 'en_US';
        newUser.IsActive = true;
        newUser.ContactId = contact.Id;
        newUser.Store_Access__c = contact.Ecomm_Type__c;

        Database.DMLOptions options = new Database.DMLOptions();
        options.EmailHeader.triggerUserEmail = true;
        newUser.setOptions(options);
        return newUser;
    }

    public class CreateStoreUserException extends Exception {}
}