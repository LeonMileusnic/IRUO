# Identity and Access Design for OpenStack

## Required access model

- each developer can start, stop and reboot **only their own** VMs;
- developers must not be able to manage another developer's VMs;
- the DevOps Lead can manage all developer VMs;
- application VMs are not directly exposed to the public network.

## Production design: one project per developer

The clean way to get a real authorization boundary is one OpenStack project per developer, since Nova resources belong to a project:

```text
TechSprint
+-- techsprint-mile project    -> mile: VM Power Operator
+-- techsprint-hrvoje project  -> hrvoje: VM Power Operator
+-- techsprint-management project -> pero (lead): management role
```

The DevOps Lead additionally receives the VM Power Operator role on every developer project generated from the CSV (`techsprint-mile`, `techsprint-hrvoje`, and any project added later) — so the model scales to any number of developers without redesign.

The developer role would permit only Nova lifecycle actions (start/stop/reboot) — never quota changes, Keystone administration, provider-network edits, or administrative recovery actions. Project isolation, not role scoping alone, is what prevents a developer from touching another developer's VMs; metadata like `owner=mile` is useful for identification but is not an authorization boundary by itself.

## Why this can't be built here

The Red Hat Academy student account has no administrative Keystone permissions — attempts return HTTP 403, e.g.:

```text
You are not authorized to perform the requested action: identity:list_services. (HTTP 403)
```

So it cannot create additional projects, users, groups, roles, or policy rules. Runtime resources therefore live in the provided `finance` project instead, tagged with `project=techsprint`, `environment=testing`, `owner=<developer>` metadata for identification.

This is an Academy permission limit, not a flaw in the production design above — with administrative OpenStack credentials, the workflow `users.csv → create developer projects → resolve identities → assign VM Power Operator → deploy → assign Lead across all projects` is straightforward and was designed to be CSV-scalable from the start.

## What is actually implemented: scoped application credentials

Even with admin access, a Keystone role assignment is scoped to a *project*, not a VM — it couldn't by itself express "only this developer's own VM" while every developer's instances share one Academy project. So `openstack/iam.tf` implements the part of this requirement that **is** achievable here, using `openstack_identity_application_credential_v3` with `access_rules`. Creating an application credential for yourself is self-service, not an administrative action, so it works under the restricted Academy account.

Per developer, Terraform generates one credential whose `access_rules` permit only:

- `GET`/`POST` on `.../servers/{id}` and `.../servers/{id}/action` for that developer's own two Moodle instance IDs (status + start/stop/reboot);
- `GET`/`PUT` on that developer's own Swift container path (`/v1/AUTH_<project>/<their-container>/*`).

A broader credential is generated for the DevOps Lead, covering all developer instances. These (`terraform output developer_application_credentials`) are handed to each person instead of the shared `finance` login — Keystone rejects any Nova/Swift call outside the listed rules, regardless of what the underlying shared account could otherwise do.

This is not full project isolation (everyone's credential still shares the same underlying account/quota), but it is a real, enforced boundary — "start/stop/reboot only your own VM, read/write only your own backup container" — achievable without the administrative Keystone access this environment doesn't grant.
