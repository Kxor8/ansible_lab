# Ansible Lab: Write an Idempotent Playbook

## 1. Objective

The objective of this lab was to understand how to create and execute an Ansible Playbook using YAML.

In the previous lab, we used Ansible Ad Hoc Commands to perform individual tasks directly from the terminal.

In this lab, we combined multiple tasks into one reusable YAML file called `workspace.yaml`.

We learned how to:

- Write an Ansible Playbook using YAML.
- Understand plays and tasks.
- Use the `file` and `copy` modules inside a playbook.
- Validate playbook syntax.
- Identify which hosts the playbook targets.
- Execute a playbook on multiple managed hosts.
- Verify the results.
- Understand and test idempotency.
- Use Ansible Check Mode (Dry Run).

## 2. Lab Environment

We performed this lab locally using WSL Ubuntu and Docker.

| Component | Details |
|---|---|
| Ansible Controller | WSL Ubuntu |
| Managed Host 1 | web1 |
| Managed Host 2 | web2 |
| Inventory File | inventory |
| Playbook File | workspace.yaml |
| Remote User | automation |

Our existing inventory already contained both `web1` and `web2` under the `webservers` group.

For this lab, we used `hosts: all`, which targets all hosts in the inventory.

## 3. Navigate to the Project Directory

First, we navigated to our existing Ansible project directory.

```bash
cd /mnt/d/kritika/ansible-lab
```

To verify our current directory:

```bash
pwd
```

Expected output:

```text
/mnt/d/kritika/ansible-lab
```

**Explanation:**

- `cd` means Change Directory.
- `pwd` displays the current working directory.

We created our new playbook inside this project directory.

## 4. Understanding Ansible Playbooks

An Ansible Playbook is a YAML file containing instructions that Ansible executes on managed hosts.

Instead of executing multiple individual commands, we can define all related tasks in one file and execute them together.

### Difference between a Play and a Task

**Play:**

A play defines:
- Which hosts Ansible should target.
- Which tasks should execute.
- Other execution settings.

**Task:**

A task represents one operation that Ansible needs to perform.

For example:
- Create a directory.
- Copy a file.
- Install a package.
- Start a service.

A play can contain multiple tasks.

## 5. Create the Playbook

We created a file named `workspace.yaml`.

```bash
nano workspace.yaml
```

The `nano` command opens a terminal-based text editor.

We added the following YAML content:

```yaml
- name: Prepare managed workspaces
  hosts: all
  gather_facts: false
  tasks:
    - name: Create the workspace directory
      ansible.builtin.file:
        path: /home/automation/workspace
        state: directory
        mode: "0750"

    - name: Write the workspace notice
      ansible.builtin.copy:
        dest: /home/automation/workspace/README.txt
        content: "Workspace managed by Ansible\n"
        mode: "0640"
```

### Understanding the YAML Structure

Let's understand each section.

### 5.1 Play Definition

```yaml
- name: Prepare managed workspaces
  hosts: all
  gather_facts: false
```

| Keyword | Explanation |
|---|---|
| `-` | Starts a new play in the YAML list |
| `name` | Describes the purpose of the play |
| `hosts: all` | Runs the play on all hosts in the inventory |
| `gather_facts: false` | Skips automatic fact collection |

**What is `gather_facts`?**

By default, Ansible collects system information from managed hosts before executing tasks.

This information is called facts.

For this lab, we did not need system information, so we set:

```yaml
gather_facts: false
```

This skips unnecessary fact collection.

### 5.2 Tasks Section

```yaml
tasks:
```

The `tasks` keyword defines the list of operations Ansible should execute.

Our playbook contains two tasks.

### 5.3 First Task: Create a Directory

```yaml
- name: Create the workspace directory
  ansible.builtin.file:
    path: /home/automation/workspace
    state: directory
    mode: "0750"
```

**Explanation:**

| Keyword | Purpose |
|---|---|
| `name` | Describes the task |
| `ansible.builtin.file` | Uses Ansible's file module |
| `path` | Specifies the directory location |
| `state: directory` | Ensures the directory exists |
| `mode: "0750"` | Sets directory permissions |

This task ensures that the following directory exists on both managed hosts:

```text
/home/automation/workspace
```

If the directory does not exist, Ansible creates it.

If it already exists with the requested permissions, Ansible does not recreate it.

### 5.4 Second Task: Create a File with Content

```yaml
- name: Write the workspace notice
  ansible.builtin.copy:
    dest: /home/automation/workspace/README.txt
    content: "Workspace managed by Ansible\n"
    mode: "0640"
```

**Explanation:**

| Keyword | Purpose |
|---|---|
| `name` | Describes the task |
| `ansible.builtin.copy` | Uses Ansible's copy module |
| `dest` | Specifies the destination file |
| `content` | Defines the text to write into the file |
| `mode: "0640"` | Sets file permissions |

This task creates:

```text
/home/automation/workspace/README.txt
```

With the following content:

```text
Workspace managed by Ansible
```

**Important: Understanding `content` vs `src`**

In our previous lab, we used:

```yaml
src: /path/to/source/file
dest: /path/to/destination/file
```

Here, we used:

```yaml
content: "Workspace managed by Ansible\n"
```

The difference:

- `src`: Reads an existing source file from the Ansible controller.
- `content`: Provides the text directly inside the playbook.

Therefore, we did not need to create a separate source file on our controller.

The `\n` adds a newline at the end of the text.

## 6. Important YAML Concepts

YAML is a human-readable data format commonly used for configuration files and Ansible Playbooks.

Some important rules we followed:

1. Indentation matters in YAML.
2. Use spaces instead of tabs.
3. A hyphen (`-`) starts an item in a list.
4. A colon (`:`) separates a key from its value.
5. Nested elements must be indented correctly.
6. Quoting permission values such as `"0750"` preserves them as strings.

## 7. Validate Playbook Syntax

Before executing a playbook, we should check whether its syntax is valid.

We ran:

```bash
ansible-playbook workspace.yaml --syntax-check
```

**Purpose:**

- `ansible-playbook`: Runs or validates an Ansible Playbook.
- `workspace.yaml`: Specifies the playbook file.
- `--syntax-check`: Checks the playbook structure and syntax without executing tasks.

Expected output:

```text
playbook: workspace.yaml
```

Our syntax check passed.

**Important:** Syntax validation does not verify remote connectivity or prove that the tasks will work.

We initially ran this command without explicitly providing the inventory.

Ansible displayed warnings because our local `ansible.cfg` was ignored due to the world-writable project directory.

Therefore, for subsequent commands, we explicitly supplied:

```bash
-i inventory
```

## 8. Verify Target Hosts

Next, we checked which hosts our playbook would target.

Command:

```bash
ansible-playbook workspace.yaml -i inventory --list-hosts
```

**Purpose:**

Displays the hosts selected by the playbook without executing any tasks.

Output:

```text
play #1 (all): Prepare managed workspaces
pattern: ['all']
hosts (2):
  web1
  web2
```

**Explanation:**

- `play #1`: The first play in our playbook.
- `all`: The host pattern defined in the playbook.
- `hosts (2)`: Two managed hosts were selected.
- `web1` and `web2`: Our two managed hosts.

This confirmed that our playbook would execute on both hosts.

## 9. Execute the Playbook

After validating syntax and checking the target hosts, we executed the playbook.

Command:

```bash
ansible-playbook workspace.yaml -i inventory
```

This command executes all tasks defined in the playbook.

### What happened?

**First task:**

```text
TASK [Create the workspace directory]
changed: [web1]
changed: [web2]
```

Ansible created:

```text
/home/automation/workspace
```

on both hosts.

**Second task:**

```text
TASK [Write the workspace notice]
changed: [web2]
changed: [web1]
```

Ansible created:

```text
/home/automation/workspace/README.txt
```

with the specified content.

### Understanding the PLAY RECAP

Our first execution returned:

```text
web1 : ok=2 changed=2 unreachable=0 failed=0
web2 : ok=2 changed=2 unreachable=0 failed=0
```

| Field | Meaning |
|---|---|
| `ok` | Number of successfully executed tasks |
| `changed` | Number of tasks that made changes |
| `unreachable` | Number of hosts Ansible could not contact |
| `failed` | Number of failed tasks |
| `skipped` | Number of skipped tasks |

**Why was `changed=2`?**

Because this was the first execution.

Ansible needed to:

1. Create the workspace directory.
2. Create the README file.

Both operations made changes on each host.

There were no unreachable hosts or failed tasks.

## 10. Verify the Actual File Contents

After executing the playbook, we verified whether the README file was created correctly on both hosts.

Command:

```bash
ansible all -i inventory -m ansible.builtin.command -a 'cat /home/automation/workspace/README.txt'
```

**Explanation:**

| Argument | Purpose |
|---|---|
| `all` | Targets all hosts |
| `-i inventory` | Specifies the inventory |
| `-m` | Specifies the module |
| `ansible.builtin.command` | Executes a Linux command remotely |
| `cat` | Displays file contents |

Output from both hosts:

```text
Workspace managed by Ansible
```

This confirmed that the file existed and contained the expected text on both hosts.

**Note:** The ad hoc command may report `CHANGED` because the command module reports execution as changed by default. It does not mean that the file was modified.

## 11. Verify Idempotency

This was one of the most important parts of the lab.

### What is Idempotency?

Idempotency means that applying the same desired configuration repeatedly should not produce unnecessary changes once the desired state has been achieved.

For example:

- If a directory does not exist, Ansible creates it.
- If the directory already exists with the correct permissions, Ansible leaves it unchanged.
- If a file has the correct content and permissions, Ansible does not rewrite it unnecessarily.

### Execute the Playbook Again

We ran the same command again:

```bash
ansible-playbook workspace.yaml -i inventory
```

This time, the output showed:

```text
TASK [Create the workspace directory]
ok: [web1]
ok: [web2]

TASK [Write the workspace notice]
ok: [web1]
ok: [web2]
```

PLAY RECAP:

```text
web1 : ok=2 changed=0 unreachable=0 failed=0
web2 : ok=2 changed=0 unreachable=0 failed=0
```

### Why did `changed=0`?

Because both hosts already had:

- The workspace directory.
- The correct directory permissions.
- The README file.
- The correct file content.
- The correct file permissions.

Ansible checked the current state and found that everything already matched the desired configuration.

Therefore, it did not make any unnecessary changes.

This is idempotency in practice.

## 12. Ansible Check Mode (Dry Run)

Finally, we used Ansible Check Mode.

Command:

```bash
ansible-playbook workspace.yaml -i inventory --check
```

### What is Check Mode?

Check Mode allows Ansible to preview whether changes would be required without actually applying them.

It is also commonly called a Dry Run.

**What happens when we use `--check`?**

- Ansible checks the current state of managed hosts.
- It compares the current state with the desired state.
- It predicts whether changes are required.
- It does not apply the predicted changes.

Our output showed:

```text
TASK [Create the workspace directory]
ok: [web1]
ok: [web2]

TASK [Write the workspace notice]
ok: [web2]
ok: [web1]
```

PLAY RECAP:

```text
web1 : ok=2 changed=0 unreachable=0 failed=0
web2 : ok=2 changed=0 unreachable=0 failed=0
```

**Why was `changed=0`?**

Because the desired state was already achieved during our previous executions.

Check Mode confirmed that Ansible did not predict any further changes.

**Important:** Check Mode is a preview, not a replacement for executing and verifying the actual playbook.

## 13. Important Commands Used in This Lab

| Command | Purpose |
|---|---|
| `cd /mnt/d/kritika/ansible-lab` | Navigate to the project |
| `pwd` | Display current directory |
| `nano workspace.yaml` | Create/edit the playbook |
| `cat workspace.yaml` | Display playbook contents |
| `ansible-playbook workspace.yaml --syntax-check` | Validate playbook syntax |
| `ansible-playbook workspace.yaml -i inventory --list-hosts` | List target hosts |
| `ansible-playbook workspace.yaml -i inventory` | Execute the playbook |
| `ansible all -i inventory -m ansible.builtin.command -a 'cat /home/automation/workspace/README.txt'` | Verify remote file contents |
| `ansible-playbook workspace.yaml -i inventory --check` | Preview changes without applying them |

## 14. Difference Between Ad Hoc Commands and Playbooks

| Ad Hoc Commands | Playbooks |
|---|---|
| Execute individual tasks | Execute multiple tasks |
| Written directly in the terminal | Written in YAML files |
| Useful for quick operations | Useful for reusable automation |
| No playbook file required | Requires a playbook file |
| Example: `ansible` | Example: `ansible-playbook` |

In our previous lab, we used ad hoc commands to create directories and copy files.

In this lab, we used a YAML playbook to define similar desired states and execute them together.

## 15. Final Lab Result

All lab objectives were completed successfully.

| Lab Objective | Status |
|---|---|
| Create YAML playbook | Completed |
| Define a play and tasks | Completed |
| Use the file module | Completed |
| Use the copy module | Completed |
| Validate syntax | Completed |
| Verify target hosts | Completed |
| Execute playbook | Completed |
| Verify remote file contents | Completed |
| Verify idempotency | Completed |
| Perform Check Mode | Completed |

## 16. Key Takeaways

1. An Ansible Playbook is a reusable YAML file containing automation instructions.
2. A play defines the target hosts and the tasks to execute.
3. A task represents an individual operation.
4. The `file` module manages files and directories.
5. The `copy` module can create a file using the `content` argument or transfer an existing controller-side file using `src`.
6. `--syntax-check` validates the playbook structure.
7. `--list-hosts` previews the selected hosts.
8. `ansible-playbook` executes the playbook.
9. Idempotency prevents unnecessary changes when the desired state already exists.
10. `--check` previews potential changes without applying them.

**Most important takeaway:**

Instead of manually executing multiple commands, we can define the desired state in a YAML playbook and let Ansible ensure that all managed hosts match that state consistently.

This is one of the fundamental ideas behind configuration management and infrastructure automation.
