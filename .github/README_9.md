# Ansible Labs 1 & 2 --- Beginner Notes

**Project directory:** `/mnt/d/kritika/ansible-lab`\
**Inventory:** `inventory`\
**Managed hosts:** `web1`, `web2`\
**Remote user:** `automation`

These notes cover the two completed labs: running maintenance commands
and managing scheduled reports with Cron.

------------------------------------------------------------------------

# Lab 1: Run Maintenance Commands and Handle Failures

## Objective

Use Ansible to run maintenance tasks on multiple hosts, handle command
failures, and save a result file on the Ansible controller.

## What we did

1.  Prepared a maintenance input file and a readiness marker on both
    managed hosts.
2.  Read a file whose name contains spaces using the `command` module
    and `argv`.
3.  Saved the command output to another file on each host.
4.  Ran a maintenance script from the controller on each host.
5.  Used `creates` to prevent the script from running again when its
    report already existed.
6.  Ran a shell pipeline and checked its return code and expected
    output.
7.  Used `delegate_to: localhost` to create a receipt file on the
    controller for each host.
8.  Deliberately removed the readiness marker from `web1` to test
    failure handling, confirmed that the task failed there, then
    restored the marker and reran the playbook successfully.

## Important files

  -----------------------------------------------------------------------
  File                                Purpose
  ----------------------------------- -----------------------------------
  `maintenance.yml`                   Playbook containing the maintenance
                                      tasks

  `scripts/host-maintenance.sh`       Script executed on the managed
                                      hosts

  `receipts/web1.txt`                 Result receipt saved on the
                                      controller for `web1`

  `receipts/web2.txt`                 Result receipt saved on the
                                      controller for `web2`
  -----------------------------------------------------------------------

## Key Ansible concepts

### 1. `command` with `argv`

Use `ansible.builtin.command` to run a command without a shell. Use
`argv` when arguments include spaces or need to be passed safely as
separate values.

``` yaml
- name: Read maintenance input
  ansible.builtin.command:
    argv:
      - cat
      - "/home/automation/maintenance input.txt"
  register: maintenance_input
  changed_when: false
```

-   `register` stores the command result in a variable.
-   `changed_when: false` tells Ansible that this read-only task does
    not change the host.

### 2. `copy` using registered output

``` yaml
- name: Save command output
  ansible.builtin.copy:
    content: "{{ maintenance_input.stdout }}"
    dest: /home/automation/command-result.txt
    owner: automation
    group: automation
    mode: "0644"
```

`stdout` contains the command's normal output.

### 3. `script` and `creates`

``` yaml
- name: Run maintenance script
  ansible.builtin.script:
    cmd: scripts/host-maintenance.sh 'Maintenance checked'
    creates: /home/automation/maintenance-run/report.txt
```

-   `script` transfers a script from the controller and runs it on the
    managed host.
-   `creates` skips the task if the specified file already exists. This
    helps avoid repeating work.

### 4. Failure handling

The maintenance script checked whether the readiness file existed. If it
was missing, the script printed an error and exited with return code
`42`.

The playbook used `failed_when` to define when the task should be
treated as failed. This allowed us to test how Ansible reports a failed
task.

**Important:** A non-zero return code normally indicates command
failure. Use `failed_when` when you need to define a specific failure
condition.

### 5. `shell` and `pipefail`

A shell pipeline can hide an earlier command's failure unless `pipefail`
is enabled.

``` yaml
- name: Check maintenance input
  ansible.builtin.shell: |
    set -o pipefail
    wc -l < "/home/automation/maintenance input.txt"
  register: line_count
  changed_when: false
  failed_when: line_count.rc != 0 or line_count.stdout | int != 1
```

-   `shell` runs the command through a shell.
-   `set -o pipefail` makes a pipeline report a failure if a command in
    it fails.
-   `failed_when` checks both the return code and the expected line
    count.

### 6. `delegate_to: localhost`

``` yaml
- name: Save a receipt on the controller
  ansible.builtin.copy:
    content: |
      host={{ inventory_hostname }}
      input_lines={{ line_count.stdout }}
    dest: "receipts/{{ inventory_hostname }}.txt"
  delegate_to: localhost
  become: false
```

`delegate_to: localhost` runs this task on the Ansible controller
instead of the managed host. `inventory_hostname` identifies the host
currently being processed.

## Useful commands

Run the playbook:

``` bash
ansible-playbook -i inventory maintenance.yml
```

Check a file on both hosts:

``` bash
ansible all -i inventory -b -m ansible.builtin.command -a 'cat /home/automation/command-result.txt'
```

Check controller-side receipts:

``` bash
cat receipts/web1.txt
cat receipts/web2.txt
```

## Lab 1 outcome

-   Maintenance tasks ran on both managed hosts.
-   The missing readiness file caused the expected failure on `web1`.
-   Restoring the readiness file allowed the playbook to complete
    successfully.
-   Controller-side receipt files were created for both hosts.

------------------------------------------------------------------------

# Lab 2: Manage Scheduled Host Reports with Cron

## Objective

Use Ansible to deploy a script and schedule it to run every minute on
both managed hosts. Update the scheduled job, remove a temporary job,
and verify idempotency.

## What we did

1.  Checked whether Cron was installed and running on both hosts.
2.  Installed Cron and started its process because the lab containers
    did not automatically start services during package installation.
3.  Created a report script on the controller.
4.  Deployed the script to both managed hosts.
5.  Created a Cron job for the `automation` user to run the script every
    minute.
6.  Verified that the script generated report entries.
7.  Changed the report phase from `initial` to `verified`.
8.  Created and then removed a temporary Cron job.
9.  Reran the playbook and confirmed that no changes were needed.

## Important files

  ---------------------------------------------------------------------------------
  File                                          Purpose
  --------------------------------------------- -----------------------------------
  `reporting.yml`                               Playbook that deploys the script
                                                and manages the Cron job

  `files/host-report.sh`                        Script deployed to both managed
                                                hosts

  `/home/automation/reporting/host-report.sh`   Deployed script on each managed
                                                host

  `/home/automation/reporting/report.log`       Report log generated on each
                                                managed host
  ---------------------------------------------------------------------------------

## Report script: `files/host-report.sh`

``` bash
#!/bin/bash

set -e
umask 027

REPORT_DIR="/home/automation/reporting"
REPORT_FILE="$REPORT_DIR/report.log"

mkdir -p "$REPORT_DIR"

echo "timestamp=$(date -u +%s) host=$(hostname) phase=$1" >> "$REPORT_FILE"
```

### Script explanation

-   `#!/bin/bash` runs the script using Bash.
-   `set -e` stops the script if a command fails.
-   `umask 027` sets restrictive default permissions for newly created
    files.
-   `mkdir -p` creates the report directory if it does not already
    exist.
-   `date -u +%s` generates the current UTC time as a Unix timestamp.
-   `hostname` prints the managed host's hostname.
-   `$1` is the first argument passed to the script (`initial` or
    `verified`).
-   `>>` appends a new line to the report log instead of replacing its
    contents.

Example report entry:

``` text
timestamp=1795849681 host=c5433b0f4d5c phase=initial
```

## Playbook: `reporting.yml`

The playbook used in the lab:

``` yaml
---
- name: Manage scheduled host reports
  hosts: all
  become: true
  gather_facts: false

  vars:
    report_phase: verified

  tasks:
    - name: Create report directory
      ansible.builtin.file:
        path: /home/automation/reporting
        state: directory
        owner: automation
        group: automation
        mode: "0750"

    - name: Deploy report script
      ansible.builtin.copy:
        src: files/host-report.sh
        dest: /home/automation/reporting/host-report.sh
        owner: automation
        group: automation
        mode: "0750"

    - name: Schedule report every minute
      ansible.builtin.cron:
        name: ansible-host-report
        user: automation
        minute: "*"
        job: /home/automation/reporting/host-report.sh {{ report_phase }}
```

### Playbook explanation

-   `hosts: all` runs the play on all hosts in the inventory.
-   `become: true` runs tasks with elevated privileges where required.
-   `gather_facts: false` skips automatic host fact collection.
-   `report_phase` stores the phase argument passed to the script.
-   `ansible.builtin.file` ensures the report directory exists with the
    required ownership and permissions.
-   `ansible.builtin.copy` deploys the script from the controller to
    each host.
-   `ansible.builtin.cron` creates or updates a named Cron job for the
    `automation` user.
-   `minute: "*"` means the job runs every minute.
-   `name` gives the Cron job a stable identifier so Ansible can update
    or remove that specific job.

## Important Cron commands

View the `automation` user's Cron jobs:

``` bash
crontab -u automation -l
```

Check whether the Cron process is running:

``` bash
pgrep -a cron
```

Run the report script manually as the `automation` user:

``` bash
runuser -u automation -- /home/automation/reporting/host-report.sh initial
```

View the latest report entries:

``` bash
tail -n 5 /home/automation/reporting/report.log
```

## Ansible commands used

### Install Cron

``` bash
ansible all -i inventory -b -m ansible.builtin.apt -a 'name=cron state=present update_cache=yes'
```

### Start Cron in the lab containers

``` bash
ansible all -i inventory -b -m ansible.builtin.command -a 'cron'
```

### Verify Cron is running

``` bash
ansible all -i inventory -b -m ansible.builtin.command -a 'pgrep -a cron'
```

### Run the playbook

``` bash
ansible-playbook -i inventory reporting.yml
```

### Create a temporary Cron job

``` bash
ansible all -i inventory -b -m ansible.builtin.cron -a 'name=temporary-report-test user=automation minute=*/5 job="echo temporary >> /tmp/cron-test.log"'
```

### Remove the temporary Cron job

``` bash
ansible all -i inventory -b -m ansible.builtin.cron -a 'name=temporary-report-test user=automation state=absent'
```

### Verify the remaining Cron job

``` bash
ansible all -i inventory -b -m ansible.builtin.shell -a 'crontab -u automation -l'
```

The final crontab on each host contained only:

``` cron
#Ansible: ansible-host-report
* * * * * /home/automation/reporting/host-report.sh verified
```

## Lab 2 outcome

-   Cron was installed and running on both hosts.
-   The report script was deployed successfully.
-   The scheduled job generated report entries on both hosts.
-   The job was updated from `initial` to `verified`.
-   The temporary Cron job was removed.
-   The final playbook run reported `changed=0` on both hosts.

------------------------------------------------------------------------

# Concepts to remember

  -----------------------------------------------------------------------
  Concept                             Simple meaning
  ----------------------------------- -----------------------------------
  `command`                           Runs a command without a shell

  `shell`                             Runs a command through a shell;
                                      useful for pipes and shell features

  `script`                            Copies and runs a local script on a
                                      managed host

  `copy`                              Copies a file or writes content to
                                      a destination

  `register`                          Saves task output in a variable

  `changed_when`                      Defines when Ansible should report
                                      a task as changed

  `failed_when`                       Defines when Ansible should report
                                      a task as failed

  `creates`                           Skips a task when a specified file
                                      already exists

  `delegate_to`                       Runs a task on a different host,
                                      such as the controller

  `cron`                              Creates, updates, or removes
                                      scheduled jobs

  `become`                            Runs tasks with elevated privileges

  `idempotency`                       Repeated runs produce no additional
                                      changes when the desired state is
                                      already reached
  -----------------------------------------------------------------------

## Note about the Ansible warning

During these labs, Ansible displayed a warning that the project
directory under `/mnt/d` is world-writable and that it was ignoring
`ansible.cfg` from that directory.

The warning did not prevent the playbooks from running. It is an
environment/permissions warning, not a task failure.

------------------------------------------------------------------------

## Final status

-   **Lab 1 --- Run Maintenance Commands and Handle Failures:
    Completed**
-   **Lab 2 --- Manage Scheduled Host Reports with Cron: Completed**
