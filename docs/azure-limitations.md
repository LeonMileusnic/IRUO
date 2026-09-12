# Constraints of the Azure Test Environment

The full Azure TechSprint architecture is implemented in `azure/full`.

The available **Azure for Students Starter** subscription does not permit registration of the required resource providers:

- Microsoft.Compute
- Microsoft.Network
- Microsoft.Storage

Provider registration returned `DisallowedProvider`. Because this restriction is imposed by the subscription itself (not the Terraform configuration), the full environment cannot be runtime-deployed here.

The implementation has instead been checked statically:

```bash
terraform -chdir=azure/full init
terraform -chdir=azure/full fmt -check
terraform -chdir=azure/full validate
```

This confirms the configuration is syntactically valid and internally consistent, but it does **not** confirm a successful `apply` — that would require a subscription without the Starter restriction above. See `azure/starter-test/README.md` for the provider-registration test that surfaced this limitation.
