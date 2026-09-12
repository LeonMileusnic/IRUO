# Resource Naming and Tagging Scheme

## Naming convention

TechSprint resources use predictable names based on resource type, project and owner.

| Resource | Example |
|---|---|
| Resource Group | `rg-techsprint-mile` |
| Virtual Network | `vnet-mile` |
| Virtual Machine | `vm-mile-moodle-1` |
| Network Interface | `nic-mile-1` |
| Load Balancer | `lb-mile-internal` |
| Application Security Group | developer-specific ASG |
| Storage Account | generated developer-specific name |
| Managed Disk | `disk-mile-moodle-1-data` |
| Jump Host | `vm-techsprint-jump` |

The convention makes the resource type and owner visible directly from the resource name.

## Tags

Common tags are applied through Terraform:

| Tag | Value |
|---|---|
| `project` | `techsprint` |
| `environment` | `testing` |

Developer-owned resources additionally use:

| Tag | Example |
|---|---|
| `owner` | `mile` |

Resources associated with individual Moodle nodes can additionally contain the instance number.

Example:

```text
project     = techsprint
environment = testing
owner       = mile
instance    = 1
```
