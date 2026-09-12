# OpenStack Deployment Overview

## 1. Overview

Terraform provisions the OpenStack infrastructure; Ansible configures the OS and Moodle. Both read the shared `data/users.csv` (`ime;prezime;rola`, semicolon-separated). Terraform normalizes `;` to `,`, derives `username = lower(ime)`, and maps `rola == "devops_lead"` to the internal `lead` role (anything else becomes `developer`).

Tested input:

- `pero` (pero;peric) - DevOps Lead
- `mile` (mile;milic) - developer
- `hrvoje` (hrvoje;horvat) - developer

Adding a row to the CSV generates a full new developer environment on the next deployment — nothing is hardcoded to two developers.

---

## 2. Architecture and Network Isolation

Each developer gets an isolated environment: a private network + subnet, a router with external connectivity (Internet egress), a security group, two Moodle instances with dedicated Cinder data volumes, a private Octavia load balancer, and a Swift backup container.

A separate management network hosts the Jump Host, the only instance with a Floating IP. The Jump Host also attaches directly to every developer network (multi-NIC), giving it SSH reach into all environments without creating any connectivity *between* developer networks.

Developer networks are generated dynamically from `10.10.0.0/16`:

| Environment | Network |
|---|---|
| mile | `10.10.1.0/24` |
| hrvoje | `10.10.2.0/24` |
| management | `10.10.100.0/24` |

There is no direct connection between `mile` and `hrvoje`.

---

## 3. Compute and Sizing

Two Moodle instances per developer (HA topology), with explicit Neutron ports and fixed IPs for deterministic addressing. Image: `rhel8` (`var.image_name`).

The task requires 2 vCPU / 4 GB RAM per VM. The Red Hat Academy `default` flavor only provides 2 vCPU / 2 GB RAM — no larger flavor is available to the student account. `var.flavor_name` documents this and should be set to a real ≥4 GB flavor (e.g. `m1.medium`) on any other OpenStack. This is an Academy capacity limitation, not the intended production sizing.

---

## 4. Security

- **Jump Host**: SSH (22) restricted to `var.admin_source_cidr` — a real administrator range, not the whole Internet. Terraform's validation block refuses `0.0.0.0/0`. It is the only instance with a Floating IP.
- **Moodle servers**: SSH (22) and HTTP (80) restricted to their own developer network only; no Floating IP. Administrative access goes through the Jump Host via SSH ProxyJump.
- **Secrets**: `MOODLE_DB_PASSWORD` / `MOODLE_ADMIN_PASSWORD` are required environment variables, never committed to Git.
- **Backup credentials**: the admin OpenStack RC file stays on the deployment workstation, never copied to application VMs (see §6).

---

## 5. Load Balancing and High Availability

One private Octavia load balancer per developer: HTTP listener on port 80, round-robin pool, both Moodle instances as backend members, HTTP health monitor on `/moodle-health.html` (created by the Ansible Moodle playbook). The VIP stays private, no Floating IP.

This provides the required two-node topology per developer. It is not a full production active-active Moodle design (no shared session/cache layer) — the task only requires demonstrating the infrastructure and automation, which this does.

During Academy testing, a load balancer was accepted by the Octavia API and reached `PENDING_CREATE` with a valid VIP and Amphora assignment; the student account lacked permission to inspect further. The Terraform configuration itself validates cleanly.

---

## 6. Storage

**Block** — every Moodle instance gets a dedicated 10 GB Cinder volume, separate from the OS disk. Ansible formats it XFS (if not already) and mounts it at `/data`.

**File** (shared Moodle data between the two nodes of a developer) — Manila availability could not be confirmed on Academy (Shared File Systems CLI wasn't exposed, and the account lacks permission to check the full service catalog). Instead, `moodle-1` exports `/data/shared` over NFS from its Cinder volume; `moodle-2` mounts it automatically. Restricted to the developer's own network, `root_squash` enabled. Configured by `ansible/playbooks/configure-file-storage.yml`. In production with Manila available, a managed shared filesystem would remove the dependency on `moodle-1` staying up.

**Object** (backups) — each developer gets a dedicated Swift container (`techsprint-<username>-moodle-backups`). `scripts/backup-openstack.sh` dumps the DB, archives Moodle files + data, and uploads to the container using the admin RC credentials (never copied to application VMs).

In addition, each developer's container is now **automatically mounted on both of their Moodle VMs** via `ansible/playbooks/configure-object-storage.yml`, which installs `rclone` and runs it as a systemd service (`techsprint-objectstore.service`) mounting `swift:<container>` at `/data/objectstore`. This closes the earlier gap where object storage was reachable only from the admin workstation. Authentication uses the scoped `openstack_identity_application_credential_v3` created per developer in `openstack/iam.tf` (§7) — not the shared admin RC file.

---

## 7. IAM and RBAC

Full design and rationale live in `docs/openstack-iam-rbac.md`. Summary: the ideal model (one Keystone project per developer) can't be built here — the Academy student account gets HTTP 403 on administrative Keystone calls (e.g. `identity:list_services`), and even with admin access, Keystone roles are project-scoped, not per-VM, so they couldn't express "only this developer's own VM" inside one shared project anyway.

What's actually enforced: `openstack/iam.tf` creates a self-service `openstack_identity_application_credential_v3` per developer, restricted via `access_rules` to start/stop/reboot only their own two Moodle instance IDs and read/write only their own Swift container — plus a broader one for the DevOps Lead covering all instances. This works without administrative permissions and is handed out (`terraform output developer_application_credentials`) instead of the shared `finance` project login.

---

## 8. Automation

**Ansible** (`ansible/playbooks/`): `configure-moodle.yml` installs Apache/MariaDB/PHP, formats and mounts the data disk, installs Moodle 4.1 (chosen for RHEL 8 package compatibility — not a production recommendation) via CLI, and creates the LB health endpoint. `configure-file-storage.yml` sets up the NFS share (§6). `configure-object-storage.yml` mounts Swift (§6).

**Dynamic inventory** — `scripts/generate-ansible-inventory.py` turns `terraform output -json` (Floating IP, per-instance private IPs, developer networks, Swift container + credentials) into an Ansible inventory, so IPs and usernames never need manual syncing between Terraform and Ansible.

**Deployment** — `scripts/deploy-openstack.sh data/users.csv`, after sourcing the OpenStack RC file and exporting `MOODLE_DB_PASSWORD`, `MOODLE_ADMIN_PASSWORD` and `TF_VAR_admin_source_cidr`:

```bash
source ~/developer1-finance-rc
export MOODLE_DB_PASSWORD='<password>'
export MOODLE_ADMIN_PASSWORD='<password>'
export TF_VAR_admin_source_cidr='<your-ip>/32'
./scripts/deploy-openstack.sh data/users.csv
```

It validates the CSV and required env vars, runs `terraform init/validate/apply`, generates the inventory, then runs the three Ansible playbooks in order (Moodle → file storage → object storage). One run, any number of CSV rows — validated with the required two-developers-plus-lead structure.

**Separation of concerns**: Terraform owns networking/compute/storage/load-balancing; Ansible owns OS/application configuration; the shell/Python scripts glue the two together and drive backups.

---

## 9. Naming and Tags

Pattern: `techsprint-<owner>-<resource>` (e.g. `techsprint-mile-network`, `techsprint-mile-moodle-1`, `techsprint-mile-moodle-backups`); management resources use `techsprint-management-*`.

Tags (`project:techsprint`, `environment:testing`, `owner:<username>`, `role:<moodle|jump-host|management>`) are applied wherever the resource/provider supports tags (networks, subnets, routers, security groups, ports, Floating IP, LB and its listener/pool/members). Where tags aren't supported, equivalent `metadata` is used instead (compute instances, Cinder volumes, Swift containers). `openstack_lb_monitor_v2` supports neither in the Academy provider version, so the health monitor relies on naming alone.

---

## 10. Red Hat Academy Environment and Its Limitations

Developed and tested against the Academy's `finance` project (`source ~/developer1-finance-rc`). `terraform validate` passes cleanly, and an earlier full `terraform plan` produced the expected resource set. The following runtime restrictions prevented a complete end-to-end deployment — they are infrastructure/permission limits of the shared lab, not bugs in the Terraform configuration:

- **Compute capacity**: the final Moodle VM batch failed with `No valid host was found. There are not enough hosts available.` (Nova scheduler, insufficient shared capacity) — instances entered `ERROR`. Because of this, further deploy attempts were not repeated blindly.
- **Stuck instance deletion**: some instances got stuck `SHUTOFF` mid-delete; recovering them needs an administrative Nova action, which returned HTTP 403. Worked around by backing up Terraform state and removing the stale resources from state.
- **Octavia**: a test load balancer reached `PENDING_CREATE` with a real VIP; inspecting the underlying Amphora needed permissions the student account doesn't have.
- **Keystone**: administrative identity operations return HTTP 403 (see §7) — no custom projects/roles/policies.
- **Manila**: the Shared File Systems CLI wasn't exposed, and there's no way to confirm availability without admin access to the service catalog — hence the NFS fallback in §6.

None of this is presented as successfully deployed, runtime-verified functionality; it's the actual state, documented explicitly.

---

## 11. Production Improvements

If deployed outside the Academy sandbox: separate OpenStack project per developer, managed Manila shares, a currently-supported Moodle release and OS, real ≥4 GB flavors, HTTPS instead of plain HTTP, centralized secrets management and monitoring/logging, database HA, backup retention + restore testing, and highly-available load-balancer infrastructure.

---

## 12. Repository Structure

```text
openstack/            compute, floating-ip, jump-network, keypair, loadbalancer,
                       locals, moodle-ports, network, object-storage, iam,
                       outputs, providers, security, storage, variables, versions
ansible/               ansible.cfg, inventory/, playbooks/
  playbooks/           configure-moodle.yml, configure-file-storage.yml,
                       configure-object-storage.yml
scripts/               backup-openstack.sh, deploy-openstack.sh,
                       generate-ansible-inventory.py
docs/                  openstack.md, openstack-iam-rbac.md
data/                  users.csv
```

---

## 13. Summary

CSV-driven Terraform + Ansible IaC provisioning isolated, network-segmented Moodle environments per developer on OpenStack, with real (not just documented) least-privilege access control via application credentials, automatic dual storage mounting, and a dynamically generated Ansible inventory. `terraform validate` passes; full end-to-end runtime deployment was blocked by Academy capacity/permission limits documented in §10, not by the configuration itself.
