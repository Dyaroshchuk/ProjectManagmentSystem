// PMIMP demo users.
//
//   sf apex run -o pmimp -f scripts/apex/create-demo-users.apex
//
// Rerunnable: usernames are derived from the org ID, so a second run finds the
// existing users instead of creating duplicates. Inactive demo users are
// reactivated. Missing permission set assignments are added.
//
// Personas (Developer-edition scratch org has 1 free Salesforce + 3 free
// Salesforce Platform licenses, see README):
//   Owner    = the scratch org admin running this script (not created here)
//   Admin    = workspace Admin           (Salesforce Platform)
//   Member   = workspace Member          (Salesforce Platform)
//   Viewer   = workspace Viewer          (Salesforce Platform)
//   Outsider = has app access, but no workspace membership (Salesforce)
//
// Passwords are not set. To log in as a demo user:
//   sf org generate password -o pmimp --on-behalf-of <username>
// or use "Login" on the user record in Setup.

// The org ID makes usernames globally unique and stable for this org.
String domain = UserInfo.getOrganizationId().toLowerCase() + '.pmimp.example.com';
String nickSuffix = UserInfo.getOrganizationId().right(6).toLowerCase();

// persona key, first name, last name, alias (max 8), profile name
List<List<String>> personas = new List<List<String>>{
    new List<String>{ 'admin', 'Demo', 'Admin', 'pmadmin', 'Standard Platform User' },
    new List<String>{ 'member', 'Demo', 'Member', 'pmmember', 'Standard Platform User' },
    new List<String>{ 'viewer', 'Demo', 'Viewer', 'pmviewer', 'Standard Platform User' },
    new List<String>{ 'outsider', 'Demo', 'Outsider', 'pmoutsdr', 'Standard User' }
};

// Permission sets per persona. Sets that don't exist yet (before task 1.4) are skipped.
Map<String, List<String>> permSetsByPersona = new Map<String, List<String>>{
    'owner' => new List<String>{ 'PMIMP_User', 'PMIMP_Workspace_Creator', 'PMIMP_App_Admin', 'PMIMP_API_Access' },
    'admin' => new List<String>{ 'PMIMP_User' },
    'member' => new List<String>{ 'PMIMP_User' },
    'viewer' => new List<String>{ 'PMIMP_User' },
    'outsider' => new List<String>{ 'PMIMP_User' }
};

// ---- Profiles --------------------------------------------------------------
Set<String> profileNames = new Set<String>();
for (List<String> p : personas) {
    profileNames.add(p[4]);
}
Map<String, Id> profileIdByName = new Map<String, Id>();
for (Profile pr : [SELECT Id, Name FROM Profile WHERE Name IN :profileNames]) {
    profileIdByName.put(pr.Name, pr.Id);
}
for (String name : profileNames) {
    if (!profileIdByName.containsKey(name)) {
        throw new IllegalArgumentException('Profile not found: ' + name);
    }
}

// ---- Users -----------------------------------------------------------------
User runningUser = [
    SELECT Id, Username, TimeZoneSidKey, LocaleSidKey, LanguageLocaleKey, EmailEncodingKey
    FROM User
    WHERE Id = :UserInfo.getUserId()
];

Map<String, String> usernameByPersona = new Map<String, String>();
for (List<String> p : personas) {
    usernameByPersona.put(p[0], 'pmimp.' + p[0] + '@' + domain);
}

Map<String, User> existingByUsername = new Map<String, User>();
for (User u : [SELECT Id, Username, IsActive FROM User WHERE Username IN :usernameByPersona.values()]) {
    existingByUsername.put(u.Username, u);
}

List<User> toInsert = new List<User>();
List<User> toReactivate = new List<User>();
for (List<String> p : personas) {
    String username = usernameByPersona.get(p[0]);
    User existing = existingByUsername.get(username);
    if (existing == null) {
        toInsert.add(
            new User(
                Username = username,
                Email = username,
                FirstName = p[1],
                LastName = p[2],
                Alias = p[3],
                CommunityNickname = 'pmimp-' + p[0] + '-' + nickSuffix,
                ProfileId = profileIdByName.get(p[4]),
                TimeZoneSidKey = runningUser.TimeZoneSidKey,
                LocaleSidKey = runningUser.LocaleSidKey,
                LanguageLocaleKey = runningUser.LanguageLocaleKey,
                EmailEncodingKey = runningUser.EmailEncodingKey
            )
        );
    } else if (!existing.IsActive) {
        toReactivate.add(new User(Id = existing.Id, IsActive = true));
    }
}

Database.DMLOptions noEmail = new Database.DMLOptions();
noEmail.EmailHeader.triggerUserEmail = false;
if (!toInsert.isEmpty()) {
    Database.insert(toInsert, noEmail);
}
if (!toReactivate.isEmpty()) {
    update toReactivate;
}

// Persona -> user ID (owner = running admin)
Map<String, Id> userIdByPersona = new Map<String, Id>{ 'owner' => runningUser.Id };
for (User u : [SELECT Id, Username FROM User WHERE Username IN :usernameByPersona.values()]) {
    for (String persona : usernameByPersona.keySet()) {
        if (usernameByPersona.get(persona) == u.Username) {
            userIdByPersona.put(persona, u.Id);
        }
    }
}

// ---- Permission sets -------------------------------------------------------
Set<String> permSetNames = new Set<String>();
for (List<String> names : permSetsByPersona.values()) {
    permSetNames.addAll(names);
}
Map<String, Id> permSetIdByName = new Map<String, Id>();
for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN :permSetNames]) {
    permSetIdByName.put(ps.Name, ps.Id);
}

Set<String> existingAssignments = new Set<String>();
for (PermissionSetAssignment psa : [
    SELECT AssigneeId, PermissionSetId
    FROM PermissionSetAssignment
    WHERE AssigneeId IN :userIdByPersona.values() AND PermissionSetId IN :permSetIdByName.values()
]) {
    existingAssignments.add(psa.AssigneeId + ':' + psa.PermissionSetId);
}

List<PermissionSetAssignment> toAssign = new List<PermissionSetAssignment>();
Set<String> skippedPermSets = new Set<String>();
for (String persona : permSetsByPersona.keySet()) {
    Id userId = userIdByPersona.get(persona);
    for (String psName : permSetsByPersona.get(persona)) {
        Id psId = permSetIdByName.get(psName);
        if (psId == null) {
            skippedPermSets.add(psName);
            continue;
        }
        if (!existingAssignments.contains(userId + ':' + psId)) {
            toAssign.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = psId));
        }
    }
}
if (!toAssign.isEmpty()) {
    insert toAssign;
}

// ---- Summary ---------------------------------------------------------------
System.debug(LoggingLevel.ERROR, 'PMIMP demo users: created ' + toInsert.size() +
    ', reactivated ' + toReactivate.size() + ', permission set assignments added ' + toAssign.size());
if (!skippedPermSets.isEmpty()) {
    System.debug(LoggingLevel.ERROR, 'Permission sets not deployed yet (skipped): ' + skippedPermSets);
}
System.debug(LoggingLevel.ERROR, 'owner -> ' + runningUser.Username);
for (String persona : usernameByPersona.keySet()) {
    System.debug(LoggingLevel.ERROR, persona + ' -> ' + usernameByPersona.get(persona));
}
