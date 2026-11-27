# Ansible Lab: Organize Inventories and Limit Targets

## 1. Purpose of This Lab

The purpose of this lab is to understand how Ansible organizes managed hosts into groups and controls which hosts receive commands.

In real-world environments, Ansible may manage hundreds of servers. We don't always want to execute a command on every server. Sometimes we need to test a change on one server before applying it to others.

This lab demonstrates how to:

- Organize hosts into inventory groups.
- Create parent and child groups.
- Visualize inventory structure.
- Preview selected hosts before execution.
- Select hosts using host patterns.
- Restrict execution using `--limit`.
- Execute a command on a specific managed host.
- Verify that only the intended host was modified.

## 2. Lab Environment

We used our existing local Ansible environment running through WSL and Docker.

| Component | Description |
|---|---|
| Controller | WSL (Ubuntu) |
| Managed hosts | web1 and web2 |
| Container environment | Docker |
| Inventory file | inventory |
| SSH user | automation |
| SSH ports | 2221 and 2222 |
| Project directory | `/mnt/d/kritika/ansible-lab` |

### Existing Inventory Configuration

Before starting, our inventory contained:

```ini
[web]
web1 ansible_host=127.0.0.1 ansible_port=2221
web2 ansible_host=127.0.0.1 ansible_port=2222

[all:vars]
ansible_user=automation
ansible_ssh_private_key_file=/home/nikita/.ssh/ansible_lab
ansible_python_interpreter=/usr/bin/python3
```

**Important terms:**

- `ansible_host`: Actual IP address or hostname used to connect.
- `ansible_port`: SSH port used for the connection.
- `ansible_user`: Remote SSH username.
- `ansible_ssh_private_key_file`: Private SSH key used for authentication.
- `ansible_python_interpreter`: Python executable on the managed host.
- `[all:vars]`: Variables applied to all inventory hosts.

Both web1 and web2 use localhost (`127.0.0.1`) but different SSH ports, so they represent two different managed environments.

## 3. Step 1: Verify Host Connectivity

First, we checked whether Ansible could communicate with both managed hosts.

```bash
ansible all -i inventory -m ansible.builtin.ping
```

**Explanation:**

- `ansible`: Runs an Ansible ad-hoc command.
- `all`: Targets all inventory hosts.
- `-i inventory`: Specifies the inventory file.
- `-m`: Specifies the module to execute.
- `ansible.builtin.ping`: Tests Ansible connectivity.

Expected result:

```text
web1 | SUCCESS
web2 | SUCCESS
```

Both hosts returned `pong`, confirming successful communication.

`changed: false` means no changes were made to the managed hosts.

## 4. Step 2: Organize Hosts into Groups

We created three new groups:

- `canary`: Contains web1.
- `stable`: Contains web2.
- `webservers`: Parent group containing both canary and stable.

### Command Used

```bash
cat >> inventory <<'EOF'

[canary]
web1

[stable]
web2

[webservers:children]
canary
stable
EOF
```

**Explanation:**

- `cat`: Used to write content into a file.
- `>>`: Appends content without overwriting existing data.
- `[canary]`: Creates a group containing web1.
- `[stable]`: Creates a group containing web2.
- `[webservers:children]`: Defines webservers as a parent group.
- `EOF`: Marks the end of the input.

We used `>>` to preserve our existing inventory configuration.

### Verify the Inventory

```bash
cat inventory
```

This displays the updated inventory file.

### Resulting Inventory Structure

```text
all
├── web
│   ├── web1
│   └── web2
│
└── webservers
    ├── canary
    │   └── web1
    └── stable
        └── web2
```

**Important:** A host can belong to multiple groups without creating another server. web1 belongs to both `web` and `canary`.

## 5. Step 3: Visualize Inventory Groups

We used the following command:

```bash
ansible-inventory -i inventory --graph
```

**Explanation:**

- `ansible-inventory`: Ansible utility for inspecting inventory.
- `-i inventory`: Specifies the inventory file.
- `--graph`: Displays groups and their host relationships.

Our output showed:

```text
@all:
  |--@ungrouped:
  |--@web:
  |  |--web1
  |  |--web2
  |--@webservers:
  |  |--@canary:
  |  |  |--web1
  |  |--@stable:
  |  |  |--web2
```

**What is ungrouped?**

It contains hosts that don't belong to any explicitly defined group. It was empty in our lab because both hosts already belonged to the `web` group.

## 6. Step 4: Preview Host Selection

Before executing commands, we learned how to preview which hosts Ansible would target.

### Select the Parent Group

```bash
ansible webservers -i inventory --list-hosts
```

Expected result:

```text
hosts (2):
  web1
  web2
```

`--list-hosts` displays selected hosts without executing any module.

### Select Only Canary Using Intersection

```bash
ansible 'webservers:&canary' -i inventory --list-hosts
```

Expected result:

```text
hosts (1):
  web1
```

**Understanding `:&`**

The `:&` operator represents an intersection between two groups.

- `webservers` contains web1 and web2.
- `canary` contains web1.
- Their intersection contains only web1.

This is useful when we need to select hosts belonging to multiple groups simultaneously.

## 7. Step 5: Restrict Execution Using --limit

We also learned another way to restrict the target hosts.

```bash
ansible webservers -i inventory --limit canary --list-hosts
```

Expected result:

```text
hosts (1):
  web1
```

**What does `--limit` do?**

`--limit` narrows the initial host selection to the specified hosts or groups.

In this example:

1. `webservers` initially selects web1 and web2.
2. `--limit canary` restricts the selection.
3. Only web1 remains.

### Difference Between Intersection and Limit

| Method | Purpose |
|---|---|
| `webservers:&canary` | Selects hosts belonging to both groups |
| `--limit canary` | Restricts the initial selection to canary |

Both methods selected web1 in our lab.

## 8. Step 6: Execute a Command on Canary Only

Now we performed an actual change on the canary host.

We created an empty file named `canary-ready` inside web1's automation user's home directory.

### Command Used

```bash
ansible webservers -i inventory --limit canary -m ansible.builtin.command -a 'touch /home/automation/canary-ready'
```

**Explanation:**

| Component | Purpose |
|---|---|
| `webservers` | Initial target group |
| `-i inventory` | Specifies inventory |
| `--limit canary` | Restricts execution to web1 |
| `-m` | Specifies the Ansible module |
| `ansible.builtin.command` | Executes a Linux command remotely |
| `-a` | Passes arguments to the module |
| `touch` | Creates an empty file |

Expected output:

```text
web1 | CHANGED | rc=0 >>
```

**Understanding the result:**

- `CHANGED`: The command modified the host by creating the file.
- `rc=0`: The Linux command completed successfully.
- Only web1 was targeted.

web2 was not modified.

## 9. Step 7: Verify Changes on Both Hosts

We needed to confirm that the marker file existed on web1 but not on web2.

### Command Used

```bash
ansible webservers -i inventory -m ansible.builtin.command -a 'ls /home/automation'
```

**Explanation:**

- `ls`: Lists files in a directory.
- `/home/automation`: Directory being inspected.
- Ansible executes this command on both managed hosts.

Our output:

```text
web1 | CHANGED | rc=0 >>
canary-ready

web2 | CHANGED | rc=0 >>
```

### Verification Result

| Host | Result |
|---|---|
| web1 | `canary-ready` exists |
| web2 | `canary-ready` does not exist |

This confirmed that our command affected only the intended canary host.

**Note:** The `command` module generally reports `CHANGED` when it executes a command, even for read-only commands such as `ls`. It does not necessarily mean files were modified.

## 10. Step 8: Verify the Controller

Finally, we checked the controller's current project directory.

```bash
ls
```

This checks the local WSL project directory.

We expected not to find `canary-ready` because the file was created remotely on web1, not on the Ansible controller.

## 11. Important Commands Summary

| Command | Purpose |
|---|---|
| `cat inventory` | Display inventory configuration |
| `cat >> inventory` | Append content to inventory |
| `ansible all -i inventory -m ansible.builtin.ping` | Test connectivity |
| `ansible-inventory -i inventory --graph` | Display inventory hierarchy |
| `ansible webservers -i inventory --list-hosts` | Preview parent group hosts |
| `ansible 'webservers:&canary' -i inventory --list-hosts` | Preview intersection selection |
| `ansible webservers -i inventory --limit canary --list-hosts` | Preview limited selection |
| `ansible webservers -i inventory --limit canary -m ansible.builtin.command -a 'touch /home/automation/canary-ready'` | Create marker on canary |
| `ansible webservers -i inventory -m ansible.builtin.command -a 'ls /home/automation'` | Verify files on both hosts |
| `ls` | Inspect controller directory |

## 12. Key Learnings

By completing this lab, we learned:

1. Ansible inventory groups help organize managed hosts.
2. A host can belong to multiple groups.
3. Parent groups can contain child groups using `:children`.
4. `ansible-inventory --graph` helps visualize inventory structure.
5. `--list-hosts` previews targets without executing commands.
6. `:&` selects the intersection of groups.
7. `--limit` restricts the initial target selection.
8. Ansible ad-hoc commands can execute Linux commands remotely.
9. Verifying remote state helps ensure commands affect only intended hosts.

## 13. Real-World Application

Consider a company managing 100 web servers.

Instead of deploying a new application to all 100 servers immediately, the team can:

1. Deploy the application to a small canary group.
2. Verify application health and performance.
3. If everything works, deploy to the stable group.
4. Avoid affecting all production servers if the change fails.

This is the basic idea behind canary-based deployment and controlled automation.

---

**Lab Status: Completed**
