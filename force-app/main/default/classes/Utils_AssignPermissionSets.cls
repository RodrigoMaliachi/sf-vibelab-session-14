public with sharing class Utils_AssignPermissionSets implements Queueable {
    List<User> users;
    String permissionSetNames;

    public Utils_AssignPermissionSets(List<User> users, String permissionSetNames) {
        this.users = users;
        this.permissionSetNames = permissionSetNames;       
    }

    public void execute(QueueableContext qc) {
        List<String> names = permissionSetNames.split(',');
        
        List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name IN :names AND Type != 'Group'];

        List<PermissionSetAssignment> permissionSetAssignments = new List<PermissionSetAssignment>();
        for (PermissionSet ps : permissionSets) {
            for (User u : users) {
                PermissionSetAssignment permissionSetAssignment = new PermissionSetAssignment();
                permissionSetAssignment.AssigneeId = u.Id;
                permissionSetAssignment.PermissionSetId = ps.Id;
                permissionSetAssignments.add(permissionSetAssignment);
            }
        }

        insert permissionSetAssignments;
    }
}
