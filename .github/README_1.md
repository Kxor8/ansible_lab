# Ansible Lab: Configure an Ansible Project and Privileges

## 1. Lab Objective

The objective of this lab was to understand how Ansible manages its project configuration, selects the Python interpreter on managed nodes, and executes commands with different privilege levels.

We performed everything using our local Docker-based Ansible environment.

### Our lab environment

| Component | Details |
|---|---|
| Ansible Controller | WSL Ubuntu |
| Project directory | `/mnt/d/kritika/ansible-lab` |
| Managed Node 1 | `web1` |
| Managed Node 2 | `web2` |
| SSH user | `automation` |
| Target OS | Ubuntu 24.04 |
| Target Python | Python 3.12.3 |

**How our setup works:**

```text
             Ansible Controller
                (WSL Ubuntu)
                     |
                Ansible CLI
                     |
               ansible.cfg
                     |
                 Inventory
                     |
             SSH Connection
                /       \
               /         \
            web1         web2
          (Docker)     (Docker)
```

The controller sends instructions to the managed nodes through SSH.

---

## 2. Step 1 – Create and Load Project Configuration

### Objective

Create an `ansible.cfg` file to define default settings for our Ansible project.

### What is ansible.cfg?

`ansible.cfg` is the main configuration file used by Ansible.

Without this file, Ansible uses its default settings. By creating this file, we can customize how Ansible behaves for our project.

For example:
- Which inventory file to use.
- Which Python interpreter to use by default.
- Whether SSH host-key checking is enabled.
- Whether privilege escalation is enabled by default.

### Command 1: Navigate to the project

```bash
cd /mnt/d/kritika/ansible-lab
```

**Objective:** Navigate to our existing Ansible project directory.

### Command 2: Check project files

```bash
ls -l
```

**Objective:** List the files and directories present in our project.

### Command 3: Create ansible.cfg

```bash
nano ansible.cfg
```

We added the following configuration:

```ini
[defaults]
inventory = ./inventory
host_key_checking = False
interpreter_python = auto_silent

[privilege_escalation]
become = False
```

### Understanding each configuration

| Configuration | Purpose |
|---|---|
| `[defaults]` | Contains general Ansible settings. |
| `inventory = ./inventory` | Specifies the default inventory file. |
| `host_key_checking = False` | Disables SSH host-key checking. |
| `interpreter_python = auto_silent` | Automatically detects Python on managed nodes without interpreter discovery warnings. |
| `[privilege_escalation]` | Contains privilege escalation settings. |
| `become = False` | Keeps privilege escalation disabled by default. |

**Why did we use `become = False`?**

We don't want Ansible to execute every command as root automatically.

We want normal commands to run using the SSH user `automation`. We can explicitly request elevated privileges when needed.

### Problem encountered: Ansible ignored ansible.cfg

Initially, Ansible displayed:

```text
[WARNING]: Ansible is being run in a world writable directory
CONFIG_FILE() = None
```

Our project is stored inside `/mnt/d`, a Windows-mounted directory accessed through WSL.

Ansible ignored the configuration file because of its world-writable directory security restriction.

### Solution: Set ANSIBLE_CONFIG

We used:

```bash
export ANSIBLE_CONFIG=/mnt/d/kritika/ansible-lab/ansible.cfg
```

**What does this command do?**

- `export` creates an environment variable.
- `ANSIBLE_CONFIG` tells Ansible which configuration file to use.
- The path specifies our project's configuration file.

We verified it using:

```bash
ansible --version
```

We also ran:

```bash
ansible-config dump --only-changed
```

### What is ansible-config dump?

It displays the effective Ansible configuration settings.

The `--only-changed` option displays settings that differ from their defaults.

Our output confirmed:

```text
CONFIG_FILE() = /mnt/d/kritika/ansible-lab/ansible.cfg
DEFAULT_BECOME = False
DEFAULT_HOST_LIST = ['/mnt/d/kritika/ansible-lab/inventory']
HOST_KEY_CHECKING = False
INTERPRETER_PYTHON = auto_silent
```

**What did we achieve?**

Ansible successfully loaded our project configuration.

---

## 3. Step 2 – Configure Target Python Interpreter

### Objective

Specify which Python interpreter Ansible should use on managed nodes.

### First, understand the concept

Ansible runs on the controller, but its modules execute on managed nodes.

Many Ansible modules require Python on the managed nodes.

Therefore, Ansible needs to know which Python interpreter is available on each target machine.

### Command 1: Inspect inventory

```bash
cat inventory
```

**Objective:** Display our existing inventory file.

Our inventory contains information about:
- Managed nodes (`web1` and `web2`).
- Their connection details.
- SSH username and authentication settings.

### Command 2: Check Python on managed nodes

```bash
ansible all -m ansible.builtin.command -a "python3 --version"
```

**Understanding the command:**

| Part | Meaning |
|---|---|
| `ansible` | Runs Ansible from the command line. |
| `all` | Targets all hosts in the inventory. |
| `-m` | Specifies the module. |
| `ansible.builtin.command` | Executes a command on remote hosts. |
| `-a` | Supplies arguments to the module. |
| `python3 --version` | Displays the installed Python version. |

Our output:

```text
web2 | CHANGED >>
Python 3.12.3

web1 | CHANGED >>
Python 3.12.3
```

Both managed nodes had Python 3.12.3 installed.

### Command 3: Edit inventory

```bash
nano inventory
```

Under the existing `[all:vars]` section, we added:

```ini
ansible_python_interpreter=/usr/bin/python3
```

### What does this setting mean?

It explicitly tells Ansible to use:

```text
/usr/bin/python3
```

as the Python interpreter on the managed nodes.

### Understanding the difference

We now have two Python interpreter settings:

**In ansible.cfg:**

```ini
interpreter_python = auto_silent
```

This defines the default Python interpreter discovery behaviour.

**In inventory:**

```ini
ansible_python_interpreter=/usr/bin/python3
```

This explicitly specifies the interpreter for the inventory hosts.

Inventory connection variables take precedence over the configuration default.

### Command 4: Verify inventory

```bash
cat inventory
```

**Objective:** Confirm that the Python interpreter setting was added correctly.

### Command 5: Test Ansible connectivity

```bash
ansible all -m ansible.builtin.ping
```

Our output:

```text
web2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}

web1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### What does ping actually do?

The Ansible ping module checks whether Ansible can communicate with the managed node and execute its module successfully.

It is not the same as the Linux network `ping` command.

**What did we achieve?**

- Both managed nodes were reachable.
- Python was available.
- Ansible successfully executed its ping module.

---

## 4. Step 3 – Compare Normal and Elevated Execution

### Objective

Understand how Ansible executes commands as a normal SSH user and how it can temporarily switch to root privileges.

This concept is called **Privilege Escalation**.

### First, understand the users

Our SSH connection uses:

```text
automation
```

This is the normal user through which Ansible connects to our Docker containers.

However, some administrative operations require root privileges.

For example:
- Installing software.
- Managing system services.
- Modifying protected configuration files.
- Changing system-level permissions.

Ansible provides privilege escalation through `become`.

### Command 1: Check the normal remote user

```bash
ansible all -m ansible.builtin.command -a 'id -un'
```

**Understanding the command:**

- `id` displays user identity information.
- `-u` displays the effective user ID.
- `-n` displays the username instead of the numerical ID.

Our output:

```text
web1 | CHANGED >>
automation

web2 | CHANGED >>
automation
```

This confirmed that commands were executing as `automation`.

### Command 2: Execute as root

```bash
ansible all -m ansible.builtin.command -a 'id -un' --become
```

Here, `--become` requests privilege escalation.

Ansible attempts to execute the command using sudo.

Initially, we encountered two problems.

### Problem 1: sudo was not installed

Error:

```text
/bin/sh: 1: sudo: not found
```

We checked the containers:

```bash
docker exec web1 which sudo
docker exec web2 which sudo
```

Both returned empty output.

We checked the operating system:

```bash
docker exec web2 cat /etc/os-release
```

It showed Ubuntu 24.04 LTS.

### Solution: Install sudo

For web1:

```bash
docker exec -u root web1 apt-get update
docker exec -u root web1 apt-get install -y sudo
```

For web2:

```bash
docker exec -u root web2 apt-get update
docker exec -u root web2 apt-get install -y sudo
```

**Understanding these commands:**

| Command | Objective |
|---|---|
| `docker exec` | Executes a command inside a running container. |
| `-u root` | Runs the command as root inside the container. |
| `apt-get update` | Updates the package repository information. |
| `apt-get install -y sudo` | Installs sudo without an interactive confirmation. |

We verified the installation:

```bash
docker exec web1 which sudo
docker exec web2 which sudo
```

Both returned:

```text
/usr/bin/sudo
```

### Problem 2: Missing sudo password

After installing sudo, we tried:

```bash
ansible all -m ansible.builtin.command -a 'id -un' --become
```

But received:

```text
Missing sudo password
```

This happened because the `automation` user required a password to execute sudo commands.

For our lab, we configured passwordless sudo.

### Solution: Configure passwordless sudo

For web1:

```bash
docker exec -u root web1 sh -c 'echo "automation ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/automation'

docker exec -u root web1 chmod 440 /etc/sudoers.d/automation
```

For web2:

```bash
docker exec -u root web2 sh -c 'echo "automation ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/automation'

docker exec -u root web2 chmod 440 /etc/sudoers.d/automation
```

### Understanding the sudoers configuration

```text
automation ALL=(ALL) NOPASSWD:ALL
```

| Part | Meaning |
|---|---|
| `automation` | User receiving the permission. |
| First `ALL` | Applies on all hosts. |
| `(ALL)` | Can execute commands as any user. |
| `NOPASSWD` | Does not require a password. |
| Final `ALL` | Applies to all commands. |

We also used:

```bash
chmod 440 /etc/sudoers.d/automation
```

This sets read-only permissions for the owner and group, with no permissions for others.

This is important because sudo expects secure permissions on sudoers configuration files.

### Verify sudo

We checked:

```bash
docker exec -u automation web1 sudo -n whoami
docker exec -u automation web2 sudo -n whoami
```

Expected output:

```text
root
root
```

Now the automation user could execute sudo commands without entering a password.

### Command 3: Retry Ansible with --become

```bash
ansible all -m ansible.builtin.command -a 'id -un' --become
```

Our successful output:

```text
web1 | CHANGED | rc=0 >>
root

web2 | CHANGED | rc=0 >>
root
```

**What did we achieve?**

Ansible successfully connected as `automation`, used sudo, and executed the command as root.

---

## 5. Step 4 – Verify Normal Execution Again

### Objective

Confirm that using `--become` for one command does not permanently change our default execution privileges.

We ran:

```bash
ansible all -m ansible.builtin.command -a 'id -un'
```

Our output:

```text
web2 | CHANGED | rc=0 >>
automation

web1 | CHANGED | rc=0 >>
automation
```

This confirmed that normal execution still uses the `automation` user.

Our configuration remains:

```ini
[privilege_escalation]
become = False
```

We only request elevated privileges when required by using `--become`.

---

## 6. Important Ansible Concepts Learned

| Concept | What it does |
|---|---|
| `ansible.cfg` | Defines project configuration and defaults. |
| Inventory | Defines managed hosts and host-specific variables. |
| `ANSIBLE_CONFIG` | Specifies which Ansible configuration file to load. |
| `ansible-config dump` | Displays effective configuration settings. |
| `interpreter_python` | Defines the default target Python discovery behaviour. |
| `ansible_python_interpreter` | Specifies the Python interpreter for managed hosts. |
| `command` module | Executes commands on managed nodes. |
| `ping` module | Checks Ansible connectivity and module execution. |
| `become` | Enables privilege escalation. |
| `--become` | Requests privilege escalation for an individual command. |
| `sudo` | Allows permitted users to execute commands with elevated privileges. |
| `NOPASSWD` | Allows sudo execution without a password. |

## 7. Commands Practised in This Lab

```bash
# Navigate to project
cd /mnt/d/kritika/ansible-lab

# List project files
ls -l

# Create configuration
nano ansible.cfg

# Explicitly select Ansible configuration
export ANSIBLE_CONFIG=/mnt/d/kritika/ansible-lab/ansible.cfg

# Check Ansible version and loaded configuration
ansible --version

# Display changed configuration settings
ansible-config dump --only-changed

# Display inventory
cat inventory

# Edit inventory
nano inventory

# Check Python version on managed nodes
ansible all -m ansible.builtin.command -a "python3 --version"

# Test Ansible connectivity
ansible all -m ansible.builtin.ping

# Check remote username
ansible all -m ansible.builtin.command -a 'id -un'

# Execute command with elevated privileges
ansible all -m ansible.builtin.command -a 'id -un' --become

# Check sudo installation
docker exec web1 which sudo
docker exec web2 which sudo

# Check operating system
docker exec web2 cat /etc/os-release

# Install sudo
docker exec -u root web1 apt-get update
docker exec -u root web1 apt-get install -y sudo

docker exec -u root web2 apt-get update
docker exec -u root web2 apt-get install -y sudo

# Configure sudo permissions
docker exec -u root web1 sh -c 'echo "automation ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/automation'
docker exec -u root web1 chmod 440 /etc/sudoers.d/automation

docker exec -u root web2 sh -c 'echo "automation ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/automation'
docker exec -u root web2 chmod 440 /etc/sudoers.d/automation

# Verify passwordless sudo
docker exec -u automation web1 sudo -n whoami
docker exec -u automation web2 sudo -n whoami
```

---

## 8. Final Lab Outcome

We successfully completed all three objectives:

1. Created and loaded project-level Ansible configuration.
2. Configured the Python interpreter for managed nodes through inventory.
3. Compared normal execution and elevated execution using privilege escalation.

Both Docker containers, `web1` and `web2`, passed the final checks.

**Most important takeaway:**

Ansible connects to managed nodes using an SSH user, executes modules using Python, and can temporarily obtain elevated privileges through `become` when administrative operations are required.

**Lab Status: COMPLETED**
