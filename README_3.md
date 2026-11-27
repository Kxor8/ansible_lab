# Ansible Lab: Inspect Hosts with Ad Hoc Commands

## 1. Objective

The objective of this lab was to learn how to use **Ansible Ad Hoc Commands** to perform one-time tasks on multiple managed hosts without creating an Ansible Playbook.

We performed the following tasks:

- Inspect managed hosts.
- Execute Linux commands remotely.
- Gather system information (facts).
- Create directories on managed hosts.
- Copy files from the Ansible controller to managed hosts.
- Understand idempotency.

## 2. Lab Environment

We performed this lab locally using WSL and Docker.

| Component | Details |
|---|---|
| Ansible Controller | WSL Ubuntu |
| Managed Host 1 | web1 |
| Managed Host 2 | web2 |
| Inventory File | inventory |
| Target Group | webservers |
| Remote User | automation |

Our inventory already contained the `webservers` group, which included `web1` and `web2`.

## 3. Understanding Ad Hoc Commands

An Ansible Ad Hoc Command allows us to execute a task directly from the terminal without creating a YAML playbook.

### General syntax

```bash
ansible <host-pattern> -i <inventory-file> -m <module> -a '<arguments>'
```

Explanation:

- `ansible`: Runs Ansible.
- `<host-pattern>`: Specifies which hosts to target.
- `-i`: Specifies the inventory file.
- `-m`: Specifies the Ansible module.
- `-a`: Passes arguments to the module.

For example:

```bash
ansible webservers -i inventory -m ansible.builtin.ping
```

This checks connectivity with all hosts in the `webservers` group.

## 4. Inspect Hosts with Modules

### Step 1: Navigate to the project directory

```bash
cd /mnt/d/kritika/ansible-lab
```

This is our local Ansible project directory containing the inventory file.

### Step 2: List hosts in the webservers group

```bash
ansible webservers -i inventory --list-hosts
```

**Purpose:**

Displays the hosts included in the `webservers` group.

Expected hosts:

```text
web1
web2
```

This command only lists the hosts. It does not execute anything on them.

### Step 3: Check the operating system kernel

```bash
ansible webservers -i inventory -m ansible.builtin.command -a 'uname -s'
```

**Purpose:**

Executes the Linux `uname -s` command on both managed hosts.

Expected output:

```text
Linux
```

**Important concepts:**

- `command` executes a command on the remote host.
- `uname -s` displays the operating system kernel name.
- Both managed hosts execute the command independently.

### Step 4: Gather OS distribution information

```bash
ansible webservers -i inventory -m ansible.builtin.setup -a 'filter=ansible_distribution'
```

**Purpose:**

Collects system information (facts) from both managed hosts.

The `setup` module gathers facts such as:

- Operating system distribution
- IP addresses
- Hostname
- Memory
- Processor information

Here, we used the filter to retrieve only the `ansible_distribution` fact.

This helped us identify the Linux distribution running on each host.

## 5. Declare a Managed Directory

In this section, we created a directory on both managed hosts using the Ansible `file` module.

### Step 1: Create the directory

```bash
ansible webservers -i inventory -m ansible.builtin.file -a 'path=/home/automation/ops state=directory mode=0750'
```

**Purpose:**

Creates a directory named `ops` on both `web1` and `web2`.

Explanation of arguments:

| Argument | Meaning |
|---|---|
| `path` | Location of the directory |
| `state=directory` | Ensures the directory exists |
| `mode=0750` | Sets directory permissions |

The directory was created at:

```text
/home/automation/ops
```

### Step 2: Verify idempotency

Run the same command again:

```bash
ansible webservers -i inventory -m ansible.builtin.file -a 'path=/home/automation/ops state=directory mode=0750'
```

This time, both hosts returned:

```text
"changed": false
```

**What is idempotency?**

Idempotency means that running the same Ansible task multiple times produces the same desired state without making unnecessary changes.

Since the directory already existed with the requested permissions, Ansible did not recreate or modify it.

## 6. Copy a Controller File to Both Targets

In this section, we created a file on the Ansible controller and copied it to both managed hosts.

### Step 1: Create a file on the controller

```bash
printf 'Managed by Ansible\n' > message.txt
```

**Purpose:**

Creates a file named `message.txt` in our current project directory.

The file contains:

```text
Managed by Ansible
```

Verify the file:

```bash
cat message.txt
```

**Important concept:**

The file is created on the Ansible controller (our WSL environment), not on the managed hosts.

### Step 2: Copy the file to both managed hosts

```bash
ansible webservers -i inventory -m ansible.builtin.copy -a 'src=/mnt/d/kritika/ansible-lab/message.txt dest=/home/automation/ops/message.txt mode=0640'
```

**Purpose:**

Copies `message.txt` from the controller to both managed hosts.

Explanation of arguments:

| Argument | Meaning |
|---|---|
| `src` | Source file location on the controller |
| `dest` | Destination file location on managed hosts |
| `mode=0640` | Sets file permissions |

Source location:

```text
/mnt/d/kritika/ansible-lab/message.txt
```

Destination location on both hosts:

```text
/home/automation/ops/message.txt
```

**Important concept:**

The Ansible `copy` module reads the source file from the controller and transfers it to the specified destination on each managed host.

### Step 3: Verify copy idempotency

Run the same copy command again:

```bash
ansible webservers -i inventory -m ansible.builtin.copy -a 'src=/mnt/d/kritika/ansible-lab/message.txt dest=/home/automation/ops/message.txt mode=0640'
```

Both hosts returned:

```text
"changed": false
```

**Why?**

Ansible checked the source and destination files and found that their contents and permissions already matched.

Therefore, no unnecessary file transfer or modification was required.

### Step 4: Verify the copied file contents

```bash
ansible webservers -i inventory -m ansible.builtin.command -a 'cat /home/automation/ops/message.txt'
```

Expected output from both hosts:

```text
Managed by Ansible
```

This confirmed that the file was successfully copied and its contents were correct on both managed hosts.

## 7. Important Ansible Modules Used

| Module | Purpose |
|---|---|
| `ansible.builtin.command` | Executes commands on remote hosts |
| `ansible.builtin.setup` | Gathers system facts |
| `ansible.builtin.file` | Creates and manages files and directories |
| `ansible.builtin.copy` | Copies files from controller to managed hosts |

## 8. Important Concepts Learned

### Ad Hoc Commands

Used to perform quick, one-time operations without writing playbooks.

### Managed Hosts

The remote machines where Ansible executes tasks. In our lab, these were `web1` and `web2`.

### Controller

The machine from which Ansible commands are executed. In our lab, this was WSL Ubuntu.

### Facts

Information automatically collected from managed hosts using the `setup` module.

### Idempotency

Ansible checks the current state and makes changes only when required.

Common output:

| Output | Meaning |
|---|---|
| `CHANGED` | Ansible made a change |
| `SUCCESS` with `changed: false` | Task completed without requiring changes |
| `FAILED` | Task encountered an error |

**Note:** The `command` module can report `CHANGED` even for read-only commands such as `uname` or `cat`. This does not necessarily mean the system was modified.

## 9. Final Lab Result

All lab objectives were completed successfully.

| Task | Result |
|---|---|
| List managed hosts | Completed |
| Execute remote Linux command | Completed |
| Gather OS distribution facts | Completed |
| Create `ops` directory | Completed |
| Verify directory idempotency | Completed |
| Create controller-side file | Completed |
| Copy file to both hosts | Completed |
| Verify copy idempotency | Completed |
| Verify copied file contents | Completed |

## 10. Key Takeaway

This lab introduced us to Ansible Ad Hoc Commands and some commonly used built-in modules.

We learned how to inspect remote hosts, gather facts, create directories, copy files, and verify the desired state across multiple machines.

**Most importantly, we learned how Ansible uses idempotency to avoid unnecessary changes when the desired state has already been achieved.**
