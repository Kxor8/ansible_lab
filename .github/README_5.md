# Ansible Lab: Use Variables and Facts Across Inventories

## 1. Objective

The objective of this lab is to understand how Ansible manages multiple environments using separate inventories, variables, and system facts.

We learned how to:

- Create separate development and production inventories.
- Define environment-specific variables using `group_vars`.
- Override group variables for individual hosts using `host_vars`.
- Create one reusable playbook for multiple environments.
- Gather system information using Ansible facts.
- Temporarily override variables using extra variables (`-e`).
- Execute a playbook in check mode.

The main goal is to understand how the same Ansible playbook can work across different environments without creating separate playbooks for each environment.

---

## 2. Local Environment

We performed this lab using our existing local Ansible setup.

| Component | Configuration |
|---|---|
| Controller | WSL Ubuntu |
| Project directory | `/mnt/d/kritika/ansible-lab` |
| Development host | web1 |
| Production host | web2 |
| Remote user | automation |
| Connection | SSH |
| Development SSH port | 2221 |
| Production SSH port | 2222 |

We reused the existing Docker-based managed hosts instead of creating new machines.

## 3. Understanding the Important Concepts

### 3.1 Inventory

An inventory tells Ansible which machines it should manage.

In this lab, we created separate inventories for development and production.

### 3.2 group_vars

The `group_vars` directory stores variables for a group of hosts.

For example:

```yaml
app_environment: development
app_port: 8080
```

All hosts belonging to the corresponding group receive these variables.

### 3.3 host_vars

The `host_vars` directory stores variables for individual hosts.

For example:

```yaml
app_port: 8081
```

This allows us to override a group-level variable for a particular host.

### 3.4 Ansible Facts

Facts are system information automatically collected by Ansible from managed hosts.

Examples include:

- Operating system distribution
- Hostname
- IP addresses
- Memory information
- CPU information

We used:

```yaml
ansible_facts['distribution']
```

to display the operating system distribution.

### 3.5 Extra Variables

Extra variables allow us to pass values directly when executing a playbook.

Example:

```bash
ansible-playbook environment.yaml -i inventories/production/hosts -e "app_port=9090"
```

The extra variable overrides the inventory value for that execution.

It does not permanently modify the inventory file.

---

## 4. Project Directory Structure

We created the following structure:

```text
ansible-lab/
│
├── inventories/
│   │
│   ├── development/
│   │   ├── hosts
│   │   ├── group_vars/
│   │   │   └── web.yml
│   │   └── host_vars/
│   │       └── web1.yml
│   │
│   └── production/
│       ├── hosts
│       └── group_vars/
│           └── web.yml
│
├── environment.yaml
├── inventory
├── workspace.yaml
└── README.md
```

**Important:** We used `web` as the group name in both inventories. Since the variable directories are inside their respective inventory directories, development and production variables remain separate.

---

## 5. Step-by-Step Implementation

### Step 1: Navigate to the project directory

```bash
cd /mnt/d/kritika/ansible-lab
```

Check the current directory:

```bash
pwd
```

List existing files:

```bash
ls -la
```

### Step 2: Create development and production inventory directories

```bash
mkdir -p inventories/development inventories/production
```

Verify:

```bash
ls -R inventories
```

### Step 3: Create the development inventory

Create the inventory file:

```bash
vi inventories/development/hosts
```

Add:

```ini
[web]
web1 ansible_host=127.0.0.1 ansible_port=2221

[all:vars]
ansible_user=automation
ansible_ssh_private_key_file=/home/nikita/.ssh/ansible_lab
ansible_python_interpreter=/usr/bin/python3
```

Explanation:

- `[web]` creates a host group named `web`.
- `web1` is the development host.
- `ansible_host` specifies the IP address.
- `ansible_port` specifies the SSH port.
- `[all:vars]` defines common connection variables.

Verify:

```bash
cat inventories/development/hosts
```

### Step 4: Create the production inventory

```bash
vi inventories/production/hosts
```

Add:

```ini
[web]
web2 ansible_host=127.0.0.1 ansible_port=2222

[all:vars]
ansible_user=automation
ansible_ssh_private_key_file=/home/nikita/.ssh/ansible_lab
ansible_python_interpreter=/usr/bin/python3
```

Here, `web2` is our production host.

Verify:

```bash
cat inventories/production/hosts
```

### Step 5: Create group_vars directories

```bash
mkdir -p inventories/development/group_vars
mkdir -p inventories/production/group_vars
```

These directories store variables for the hosts belonging to the respective inventory groups.

### Step 6: Create development group variables

```bash
vi inventories/development/group_vars/web.yml
```

Add:

```yaml
app_environment: development
app_port: 8080
```

Explanation:

- `app_environment` identifies the environment.
- `app_port` defines the application port.

Verify:

```bash
cat inventories/development/group_vars/web.yml
```

### Step 7: Create production group variables

```bash
vi inventories/production/group_vars/web.yml
```

Add:

```yaml
app_environment: production
app_port: 80
```

Development and production now have different variable values.

Verify:

```bash
cat inventories/production/group_vars/web.yml
```

### Step 8: Create host_vars

We wanted to override the development port for `web1`.

First, create the directory:

```bash
mkdir -p inventories/development/host_vars
```

Create the host-specific variable file:

```bash
vi inventories/development/host_vars/web1.yml
```

Add:

```yaml
app_port: 8081
```

This overrides the development group variable `app_port: 8080` for `web1`.

Verify:

```bash
cat inventories/development/host_vars/web1.yml
```

### Step 9: Verify inventory variables

To inspect the final variables assigned to `web1`:

```bash
ansible-inventory -i inventories/development/hosts --host web1
```

Expected important values:

```json
{
    "app_environment": "development",
    "app_port": 8081
}
```

The actual output also contains the SSH connection details.

**What did we learn?**

- Group variable: `app_port = 8080`
- Host variable: `app_port = 8081`
- Final value for `web1`: `8081`

Host-specific variables take precedence over the group variable in this example.

---

## 6. Create a Reusable Playbook

We created one playbook to display environment information for both development and production.

Create the file:

```bash
vi environment.yaml
```

Add:

```yaml
- name: Display environment information
  hosts: web
  gather_facts: true

  tasks:
    - name: Display application environment
      ansible.builtin.debug:
        msg: "Environment: {{ app_environment }}"

    - name: Display application port
      ansible.builtin.debug:
        msg: "Application port: {{ app_port }}"

    - name: Display operating system
      ansible.builtin.debug:
        msg: "Operating system: {{ ansible_facts['distribution'] }}"
```

### Explanation of the playbook

| Keyword | Meaning |
|---|---|
| `name` | Name of the play or task |
| `hosts` | Specifies which inventory group to target |
| `gather_facts` | Collects system information from managed hosts |
| `tasks` | Contains the actions to perform |
| `ansible.builtin.debug` | Displays information |
| `msg` | Message to display |
| `{{ variable }}` | Retrieves the value of a variable |

We used `ansible_facts['distribution']` to display the operating system.

**Why did we use `hosts: web`?**

Both inventories have a group named `web`. This allows the same playbook to target the appropriate host depending on which inventory we supply.

---

## 7. Execute the Playbook

### Step 10: Run against development

Command:

```bash
ansible-playbook environment.yaml -i inventories/development/hosts
```

Expected output:

```text
Environment: development
Application port: 8081
Operating system: Ubuntu
```

The playbook executed against `web1`.

The port was `8081` because the host-specific variable overrode the group variable.

### Step 11: Run against production

Command:

```bash
ansible-playbook environment.yaml -i inventories/production/hosts
```

Expected output:

```text
Environment: production
Application port: 80
Operating system: Ubuntu
```

The playbook executed against `web2`.

**Important:** We did not create a second playbook. We reused `environment.yaml` and changed only the inventory supplied to Ansible.

---

## 8. Override Variables Using Extra Variables

### Step 12: Temporarily override the production port

We wanted to change the production port from `80` to `9090` for one execution.

Command:

```bash
ansible-playbook environment.yaml -i inventories/production/hosts -e "app_port=9090"
```

Expected output:

```text
Environment: production
Application port: 9090
Operating system: Ubuntu
```

Explanation:

- `-e` stands for extra variables.
- `app_port=9090` supplies a temporary variable value.
- The extra variable takes precedence over inventory variables.

The inventory file was not modified.

### Step 13: Verify the original production value

Command:

```bash
ansible-inventory -i inventories/production/hosts --host web2
```

We verified that the original value remained:

```json
"app_port": 80
```

This confirmed that the override applied only to that playbook execution.

---

## 9. Execute in Check Mode

### Step 14: Run the playbook in check mode

Command:

```bash
ansible-playbook environment.yaml -i inventories/production/hosts --check
```

Check mode is also known as dry-run mode.

It allows Ansible to simulate supported changes without applying them.

In our lab, the playbook only displayed information, so it completed successfully with:

```text
ok=4
changed=0
failed=0
unreachable=0
```

No changes were made to the managed host.

---

## 10. Important Commands Used in This Lab

| Command | Purpose |
|---|---|
| `pwd` | Displays the current directory |
| `ls -la` | Lists files and directories |
| `mkdir -p` | Creates directories |
| `ls -R inventories` | Displays inventory directory structure |
| `vi filename` | Creates or edits a file |
| `cat filename` | Displays file contents |
| `ansible-inventory -i inventory --host hostname` | Displays variables assigned to a host |
| `ansible-playbook playbook.yaml -i inventory` | Executes a playbook |
| `ansible-playbook ... -e "key=value"` | Overrides a variable for one execution |
| `ansible-playbook ... --check` | Executes in check mode |

---

## 11. Final Results

We successfully completed the lab using our local Ansible environment.

| Objective | Result |
|---|---|
| Separate development inventory | Completed |
| Separate production inventory | Completed |
| Configure group variables | Completed |
| Configure host-specific variables | Completed |
| Verify variable precedence | Completed |
| Create reusable playbook | Completed |
| Gather system facts | Completed |
| Execute against development | Completed |
| Execute against production | Completed |
| Override variables using `-e` | Completed |
| Verify original inventory values | Completed |
| Execute check mode | Completed |

## 12. Key Takeaways

1. Inventories define which hosts Ansible manages.
2. Separate inventories can be maintained for development and production.
3. `group_vars` defines variables for groups of hosts.
4. `host_vars` defines variables for individual hosts.
5. Host-specific variables can override group variables.
6. Facts provide information about managed systems.
7. Extra variables passed using `-e` have high precedence and can temporarily override inventory values.
8. A single reusable playbook can manage multiple environments.
9. Check mode helps simulate supported changes before applying them.

### Real-World Use Case

In a company, development, staging, and production servers may require different application ports, environment names, or configurations.

Instead of maintaining separate playbooks for every environment, we can maintain separate inventories and variable files while reusing the same playbook.

This makes Ansible automation easier to maintain, reuse, and scale.
