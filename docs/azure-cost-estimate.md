# Azure Cost Projection

Based on the complete `azure/full` architecture: 2 developers, 2 Moodle instances each, 1 Jump Host, 2 internal Load Balancers, 2 NAT Gateways, Blob + Files storage, managed disks, 3 public IPs (Jump Host + 2 NAT Gateways). Calculated with the Microsoft Azure Pricing Calculator, **West Europe**, Pay-as-you-go.

| Resource | Configuration | Estimated monthly cost |
|---|---|---:|
| Virtual Machines | 5 x `Standard_B2s`, Linux, 2 vCPU / 4 GB RAM, 730 h | $157.68 |
| OS Managed Disks | 5 x S4 Standard HDD, 32 GiB | $7.68 |
| Data Managed Disks | 4 x S4 Standard HDD, 10 GiB | $6.14 |
| Azure Load Balancer | Standard, 2 LB rules, ~10 GB processed | $18.30 |
| Azure Blob Storage | Standard, Hot, LRS, ~10 GB | $1.32 |
| Azure Files | HDD Standard, LRS, Transaction Optimized, ~10 GiB | $0.63 |
| NAT Gateway | 2 x resource-hours, 730 h + ~10 GB processed | $65.70 |
| Standard Public IP | 3 x static IPv4, 730 h | $10.95 |
| **TOTAL** | | **$268.40 / month** (~$3,220.80 / year) |

## Assumptions and notes

- **VMs**: `vm-mile-moodle-1/2`, `vm-hrvoje-moodle-1/2`, `vm-techsprint-jump`, assumed to run continuously (730 h). In real use, developer VMs would be deallocated when idle, lowering the actual cost — this is exactly what the `TechSprint VM Power Operator` role (`docs/azure-rbac.md`) lets each developer do for their own VMs.
- **Disks**: 5 OS disks + 4 data disks (10 GB Standard LRS each, per `azure/full/storage.tf`).
- **Load Balancer**: one per developer, one HTTP rule each; traffic volume isn't specified by the task, so 10 GB/month is a reasonable testing-environment assumption.
- **Blob / Files**: ~10 GB combined Blob (backups) and ~5 GB/developer Files (shared Moodle data) — small testing-scale figures, not sized for production data volumes.
- **NAT Gateway / Public IPs**: added after the initial estimate — Azure's implicit "default outbound access" (which the earlier design implicitly relied on) is deprecated for new resources, so each developer VNet now has its own NAT Gateway, which is the single largest new cost line.
- **Not separately costed**: VNets, subnets, NSGs, ASGs, Managed Identities, RBAC assignments, Resource Groups — these don't carry their own direct Azure charge.
- **`Standard_B2s`** is the exact size used by `var.vm_size` in `azure/full/variables.tf`; an earlier draft of this estimate incorrectly listed a different SKU (`B2als v2`) that the Terraform configuration never actually requests.
- Actual charges will differ with real pricing, subscription agreement, currency, and actual usage — treat **$268.40/month** as a modeled estimate, not an invoice guarantee.
- The available **Azure for Students Starter** subscription does not permit deploying this architecture (see `docs/azure-limitations.md`), so this estimate could not be cross-checked against a real bill.
