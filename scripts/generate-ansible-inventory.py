#!/usr/bin/env python3

import json
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        print(
            "Usage: generate-ansible-inventory.py "
            "<terraform-output.json> <inventory.ini>"
        )
        sys.exit(1)

    terraform_output_path = Path(sys.argv[1])
    inventory_path = Path(sys.argv[2])

    with terraform_output_path.open("r", encoding="utf-8") as file:
        terraform_output = json.load(file)

    jump_ip = terraform_output["jump_host_floating_ip"]["value"]
    moodle_instances = terraform_output["moodle_instances"]["value"]
    developer_networks = terraform_output["developer_networks"]["value"]
    backup_containers = terraform_output["developer_backup_containers"]["value"]
    app_credentials = terraform_output["developer_application_credentials"]["value"]

    developers = {}

    for instance_name, instance in moodle_instances.items():
        username = instance["username"]

        if username not in developers:
            developers[username] = {}

        developers[username][instance["instance_number"]] = {
            "name": instance_name,
            "ip": instance["ip_address"],
        }

    lines = []

    lines.append("[jump_hosts]")
    lines.append(
        f"jump ansible_host={jump_ip} ansible_user=cloud-user"
    )
    lines.append("")

    for username in sorted(developers):
        lines.append(f"[{username}_moodle]")

        instances = developers[username]

        for number in sorted(instances):
            instance = instances[number]

            line = (
                f"{instance['name']} "
                f"ansible_host={instance['ip']} "
                "ansible_user=cloud-user"
            )

            if number == 1:
                line += (
                    f" developer_network="
                    f"{developer_networks[username]}"
                )

            if number == 2:
                primary_ip = instances[1]["ip"]
                line += f" nfs_server_ip={primary_ip}"

            # Every instance mounts its own developer's Swift container
            # directly (independent of the primary/secondary NFS pairing).
            credential = app_credentials[username]
            line += (
                f" swift_container={backup_containers[username]}"
                f" swift_app_credential_id={credential['id']}"
                f" swift_app_credential_secret={credential['secret']}"
            )

            lines.append(line)

        lines.append("")

    lines.append("[moodle_primary]")

    for username in sorted(developers):
        lines.append(developers[username][1]["name"])

    lines.append("")
    lines.append("[moodle_secondary]")

    for username in sorted(developers):
        lines.append(developers[username][2]["name"])

    lines.append("")
    lines.append("[moodle:children]")

    for username in sorted(developers):
        lines.append(f"{username}_moodle")

    lines.append("")
    lines.append("[moodle:vars]")
    lines.append(
        "ansible_ssh_common_args="
        f"'-o ProxyJump=cloud-user@{jump_ip}'"
    )
    lines.append("")

    inventory_path.parent.mkdir(parents=True, exist_ok=True)

    inventory_path.write_text(
        "\n".join(lines),
        encoding="utf-8",
    )

    print(f"Inventory generated: {inventory_path}")


if __name__ == "__main__":
    main()