// PMIMP sample data.
//
//   sf apex run -o pmimp -f scripts/apex/create-demo-users.apex   (first)
//   sf apex run -o pmimp -f scripts/apex/seed-data.apex
//   (or: npm run seed)
//
// Rerunnable: every record is matched on a deterministic key and upserted, never
// blindly inserted (Workspace by Name, members by Unique_Key__c = WorkspaceId:UserId,
// projects by Prefix_Unique_Key__c = WorkspaceId:PREFIX, work items by their key).
//
// Skeleton (task 0.4). The data model doesn't exist yet, and anonymous Apex fails to
// compile if it references a missing object, so sections are added as objects land:
//   1.5 / 1.6  Workspace "PMIMP Demo" + members: owner (running admin) = Owner,
//              admin = Admin, member = Member, viewer = Viewer. Outsider gets nothing.
//   2.x        Project DEMO (Software template) with work items across all statuses,
//              a parent with subtasks, an archived item.
//   3.x        Positions spread so the board shows a realistic order.

// ---- Demo users (from create-demo-users.apex) -------------------------------
String domain = UserInfo.getOrganizationId().toLowerCase() + '.pmimp.example.com';
List<String> personas = new List<String>{ 'admin', 'member', 'viewer', 'outsider' };

Map<String, String> usernameByPersona = new Map<String, String>();
for (String persona : personas) {
    usernameByPersona.put(persona, 'pmimp.' + persona + '@' + domain);
}

Map<String, Id> userIdByPersona = new Map<String, Id>{ 'owner' => UserInfo.getUserId() };
for (User u : [SELECT Id, Username FROM User WHERE Username IN :usernameByPersona.values() AND IsActive = TRUE]) {
    for (String persona : personas) {
        if (usernameByPersona.get(persona) == u.Username) {
            userIdByPersona.put(persona, u.Id);
        }
    }
}

List<String> missing = new List<String>();
for (String persona : personas) {
    if (!userIdByPersona.containsKey(persona)) {
        missing.add(persona);
    }
}
if (!missing.isEmpty()) {
    throw new IllegalArgumentException(
        'Demo users missing: ' + missing + '. Run scripts/apex/create-demo-users.apex first.'
    );
}

// ---- Workspaces and members (task 1.5 / 1.6) --------------------------------
// TODO

// ---- Projects and workflows (task 2.x) --------------------------------------
// TODO

// ---- Work items (task 2.x / 3.x) --------------------------------------------
// TODO

System.debug(LoggingLevel.ERROR, 'PMIMP seed data: demo users found ' + userIdByPersona.size() + ' (incl. owner). No business data yet.');
