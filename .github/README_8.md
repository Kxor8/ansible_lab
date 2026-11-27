# Ansible Lab: Build and Manage a Website Using Ansible

---

## 1. Lab Objective

In this lab, we combined three Ansible topics into one practical project:

1. **Control tasks with conditions and loops**
   - `when`
   - `loop`
   - `register`
   - `stat`

2. **Render and validate configuration templates**
   - Jinja2 templates
   - Dynamic variables
   - Nginx configuration validation
   - Handlers

3. **Package automation using Ansible roles**
   - Role directory structure
   - Defaults
   - Tasks
   - Templates
   - Handlers

### What did we build?

We created an Ansible role named `managed_site` that:

- Creates maintenance directories and files based on conditions.
- Checks whether an approval file exists.
- Generates multiple maintenance check files using a loop.
- Creates a website page using a Jinja2 template.
- Generates different Nginx configurations for two hosts.
- Validates Nginx configuration before deploying it.
- Reloads Nginx through a handler when configuration changes.

---

## 2. Our Local Environment

We used:

| Component | Details |
|---|---|
| Controller | WSL Ubuntu |
| Managed hosts | Docker containers |
| Inventory | `inventory` |
| Remote user | `automation` |
| SSH hosts | `web1`, `web2` |
| Project directory | `/mnt/d/kritika/ansible-lab` |

Our commands use `-i inventory` because our inventory file is named `inventory`.

---

## 3. Project Directory Structure

The new files created for this lab:

```text
ansible-lab/
│
├── inventory
│
├── host_vars/
│   ├── web1.yml
│   └── web2.yml
│
├── group_vars/
│   ├── all.yml
│   ├── canary.yml
│   └── stable.yml
│
├── roles/
│   └── managed_site/
│       │
│       ├── defaults/
│       │   └── main.yml
│       │
│       ├── tasks/
│       │   └── main.yml
│       │
│       ├── templates/
│       │   ├── page.txt.j2
│       │   └── nginx.conf.j2
│       │
│       └── handlers/
│           └── main.yml
│
└── site.yml
```

### What is the purpose of each directory?

| Directory/file | Purpose |
|---|---|
| `host_vars` | Variables specific to individual hosts |
| `group_vars` | Variables shared by inventory groups |
| `roles` | Contains reusable automation |
| `defaults` | Default values for a role |
| `tasks` | Tasks executed by the role |
| `templates` | Jinja2 template files |
| `handlers` | Tasks triggered by notifications |
| `site.yml` | Main playbook that calls the role |

**Important:** We kept our existing inventory and previous lab files intact.

---

## 4. Configure Host Variables

We created two host-specific variable files.

### `host_vars/web1.yml`

```yaml
maintenance_enabled: true
```

### `host_vars/web2.yml`

```yaml
maintenance_enabled: false
```

**Why?**

We wanted maintenance to be enabled on `web1` but disabled on `web2`.

Ansible automatically loads host variables from the `host_vars` directory.

---

## 5. Configure Group Variables

### `group_vars/all.yml`

```yaml
maintenance_checks:
  - name: disk
    purpose: Inspect disk space
  - name: logs
    purpose: Inspect application logs
  - name: packages
    purpose: Inspect package state
```

This defines a list of maintenance checks.

Because the file is named `all.yml`, these variables are available to all hosts.

### `group_vars/canary.yml`

```yaml
site_environment: development
site_port: 8081
site_maintenance: true
```

### `group_vars/stable.yml`

```yaml
site_environment: production
site_port: 8082
site_maintenance: false
```

Our inventory already contained these groups:

- `canary` → `web1`
- `stable` → `web2`

**Why?**

We wanted each host to deploy a different website configuration without creating separate playbooks.

---

## 6. Configure Role Defaults

File: `roles/managed_site/defaults/main.yml`

```yaml
site_environment: training
site_port: 8080
site_maintenance: false
```

These are fallback values for the role.

If a higher-priority variable is not defined, Ansible uses these defaults.

In our lab, group variables override these defaults.

For example:

- `web1` gets `development` and port `8081`.
- `web2` gets `production` and port `8082`.

---

## 7. Verify Inventory Variables

We checked the variables Ansible loaded for each host.

```bash
ansible-inventory -i inventory --host web1
```

```bash
ansible-inventory -i inventory --host web2
```

To view the inventory group structure:

```bash
ansible-inventory -i inventory --graph
```

**Why?**

Before running a playbook, it is useful to confirm that Ansible has loaded the correct host and group variables.

---

## 8. Understand Conditions: `when`

We used conditions to decide whether tasks should execute.

Example:

```yaml
- name: Create maintenance enabled marker
  ansible.builtin.copy:
    content: "Maintenance is enabled\n"
    dest: /home/automation/maintenance-policy/enabled.txt
  when:
    - maintenance_enabled | bool
    - ansible_facts.os_family == "Debian"
```

### Explanation

- `when` controls whether a task runs.
- `maintenance_enabled | bool` checks whether maintenance is enabled.
- `ansible_facts.os_family` checks the operating system family.
- Both conditions must be true because we used a list of conditions.

Our Ubuntu containers report:

```text
distribution: Ubuntu
os_family: Debian
```

This is why the Debian OS-family condition worked.

### Remove a marker when maintenance is disabled

```yaml
- name: Remove maintenance marker when disabled
  ansible.builtin.file:
    path: /home/automation/maintenance-policy/enabled.txt
    state: absent
  when: >
    not (maintenance_enabled | bool) or
    ansible_facts.os_family != "Debian"
```

Here, `or` means either condition can trigger the task.

**Result:**
- `web1`: maintenance marker created.
- `web2`: maintenance marker not created.

---

## 9. Understand Loops: `loop`

We created multiple maintenance check files using one task.

```yaml
- name: Create maintenance check files using a loop
  ansible.builtin.copy:
    content: |
      Host: {{ inventory_hostname }}
      Check: {{ item.name }}
      Purpose: {{ item.purpose }}
    dest: "/home/automation/maintenance-policy/checks/{{ item.name }}.txt"
    owner: automation
    group: automation
    mode: '0640'
  loop: "{{ maintenance_checks }}"
  when:
    - maintenance_enabled | bool
    - ansible_facts.os_family == "Debian"
```

### Explanation

`loop` repeats a task for every item in a list.

Our list contains:

- disk
- logs
- packages

The special variable `item` represents the current list item.

For example:

```yaml
item.name
item.purpose
```

Ansible creates these files:

```text
checks/
├── disk.txt
├── logs.txt
└── packages.txt
```

We did not need to write three separate tasks.

---

## 10. Understand `register` and `stat`

We needed to check whether an approval file existed on each host.

First, we created an approval fixture on `web1`:

```bash
ansible web1 -i inventory -b -m ansible.builtin.file -a 'path=/home/automation/maintenance-approved state=touch owner=automation group=automation mode=0644'
```

Then we used the `stat` module:

```yaml
- name: Check whether approval file exists
  ansible.builtin.stat:
    path: /home/automation/maintenance-approved
  register: approval_info
```

### What does this do?

- `stat` checks information about a file.
- `register` stores the task result in a variable named `approval_info`.
- `approval_info.stat.exists` tells us whether the file exists.

We used that registered result in another task:

```yaml
- name: Create approval marker when approval exists
  ansible.builtin.copy:
    content: "Maintenance approved\n"
    dest: /home/automation/maintenance-policy/approved.txt
  when: approval_info.stat.exists
```

And handled the opposite condition:

```yaml
- name: Remove approval marker when approval is missing
  ansible.builtin.file:
    path: /home/automation/maintenance-policy/approved.txt
    state: absent
  when: not approval_info.stat.exists
```

**Result:**

- `web1`: approval file exists, so approval marker is created.
- `web2`: approval file does not exist, so approval marker is removed if present.

### Important concepts

| Keyword/module | Meaning |
|---|---|
| `stat` | Checks file information |
| `register` | Saves task output |
| `when` | Uses a condition to control execution |
| `approval_info.stat.exists` | Checks whether the file exists |

---

## 11. Create the Website Page Using Jinja2

File: `roles/managed_site/templates/page.txt.j2`

```jinja2
host={{ inventory_hostname }}
environment={{ site_environment }}
distribution={{ ansible_facts.distribution }}
```

### What is Jinja2?

Jinja2 is a template engine used by Ansible.

It allows us to insert variables and dynamic values into files.

For example:

```jinja2
{{ inventory_hostname }}
```

Ansible replaces this with the current host name.

We used:

- `inventory_hostname` → current managed host.
- `site_environment` → development or production.
- `ansible_facts.distribution` → Ubuntu.

### Deploy the template

```yaml
- name: Deploy website page from template
  ansible.builtin.template:
    src: page.txt.j2
    dest: /var/www/role-site/index.html
    owner: root
    group: root
    mode: '0644'
```

The `template` module processes the Jinja2 variables and copies the generated file to the managed host.

---

## 12. Create the Nginx Configuration Template

File: `roles/managed_site/templates/nginx.conf.j2`

```jinja2
events {}

http {
    server_tokens off;

    server {
        listen {{ site_port }};
        root /var/www/role-site;
        index index.html;

        add_header X-Environment "{{ site_environment | upper }}" always;

{% if site_maintenance %}
        add_header X-Maintenance "enabled" always;
{% else %}
        add_header X-Maintenance "disabled" always;
{% endif %}
    }
}
```

### Important Jinja2 syntax

| Syntax | Purpose |
|---|---|
| `{{ variable }}` | Displays a variable value |
| `{% if condition %}` | Starts a condition |
| `{% else %}` | Alternative condition |
| `{% endif %}` | Ends the condition |
| `| upper` | Converts text to uppercase |

### What happens on our hosts?

**web1**

```text
listen 8081;
X-Environment: DEVELOPMENT
X-Maintenance: enabled
```

**web2**

```text
listen 8082;
X-Environment: PRODUCTION
X-Maintenance: disabled
```

One template produces different configurations based on host variables.

---

## 13. Validate Nginx Configuration Before Deployment

This was an important part of the lab.

```yaml
- name: Deploy and validate Nginx configuration
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    validate: '/usr/sbin/nginx -t -c %s'
  notify: Reload managed site
```

### What does `validate` do?

Before replacing the destination file, Ansible:

1. Generates a temporary configuration from the template.
2. Runs the Nginx validation command against it.
3. Copies it to the destination only if validation succeeds.

The `%s` represents the temporary file path.

### Why is this important?

An invalid Nginx configuration can prevent Nginx from starting or reloading.

Validation protects the existing configuration from being replaced with an invalid candidate.

### Our negative test

We temporarily backed up the valid template:

```bash
cp roles/managed_site/templates/nginx.conf.j2 roles/managed_site/templates/nginx.conf.j2.good
```

Then inserted invalid Nginx syntax:

```bash
printf 'invalid nginx configuration;\n' > roles/managed_site/templates/nginx.conf.j2
```

We ran:

```bash
ansible-playbook site.yml -i inventory
```

Ansible failed with an error similar to:

```text
failed to validate
unknown directive "invalid"
changed: false
```

This was expected.

It proved that Ansible rejected the invalid configuration before deploying it.

### Restore the valid template

```bash
mv roles/managed_site/templates/nginx.conf.j2.good roles/managed_site/templates/nginx.conf.j2
```

Run the playbook again:

```bash
ansible-playbook site.yml -i inventory
```

The valid configuration was restored and deployed successfully.

---

## 14. Understand Handlers

File: `roles/managed_site/handlers/main.yml`

```yaml
---
- name: Reload managed site
  ansible.builtin.service:
    name: nginx
    state: reloaded
```

We connected the handler to the Nginx template task using:

```yaml
notify: Reload managed site
```

### What is a handler?

A handler is a special task that runs only when another task notifies it.

In our case:

- If the Nginx configuration changes and passes validation, the handler is notified.
- Ansible reloads Nginx.
- If the configuration does not change, the handler does not run.

**Why use a handler?**

We do not need to reload Nginx unnecessarily every time the playbook runs.

---

## 15. Ensure Nginx Is Running

We added this task:

```yaml
- name: Ensure Nginx is running
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```

Explanation:

- `state: started` ensures Nginx is running.
- `enabled: true` ensures Nginx starts automatically when the container or system boots.

---

## 16. Understand the Main Playbook

File: `site.yml`

```yaml
---
- name: Configure and deploy managed websites
  hosts: webservers
  become: true
  gather_facts: true

  roles:
    - managed_site
```

### Explanation

| Keyword | Meaning |
|---|---|
| `hosts` | Selects the target inventory group |
| `become: true` | Runs tasks with elevated privileges |
| `gather_facts: true` | Collects information about managed hosts |
| `roles` | Executes the specified role |

Instead of placing every task in `site.yml`, we organized them into the reusable `managed_site` role.

This makes the playbook cleaner and easier to maintain.

---

## 17. Execute the Playbook

First, we checked the syntax:

```bash
ansible-playbook site.yml -i inventory --syntax-check
```

Expected output:

```text
playbook: site.yml
```

Then we backed up the existing Nginx configuration:

```bash
ansible all -i inventory -b -m ansible.builtin.copy -a 'src=/etc/nginx/nginx.conf dest=/etc/nginx/nginx.conf.ansible-lab-backup remote_src=true'
```

Finally, we executed the playbook:

```bash
ansible-playbook site.yml -i inventory
```

Our first successful execution reported:

```text
PLAY RECAP

web1 : ok=12 changed=9 unreachable=0 failed=0
web2 : ok=11 changed=5 unreachable=0 failed=0
```

The changes were expected because we were deploying the files and configurations for the first time.

---

## 18. Verify Maintenance Files

We checked the files created on the managed hosts:

```bash
ansible all -i inventory -m ansible.builtin.command -a 'find /home/automation/maintenance-policy -type f'
```

Expected behaviour:

- `web1` contains maintenance check files, the enabled marker and the approval marker.
- `web2` has no maintenance files because maintenance is disabled.

To inspect the contents:

```bash
ansible web1 -i inventory -m ansible.builtin.command -a 'cat /home/automation/maintenance-policy/checks/disk.txt /home/automation/maintenance-policy/checks/logs.txt /home/automation/maintenance-policy/checks/packages.txt'
```

---

## 19. Verify Website Content

We checked the generated website page:

```bash
ansible all -i inventory -m ansible.builtin.command -a 'cat /var/www/role-site/index.html'
```

Expected output for web1:

```text
host=web1
environment=development
distribution=Ubuntu
```

Expected output for web2:

```text
host=web2
environment=production
distribution=Ubuntu
```

---

## 20. Verify Websites Through HTTP

We used `curl` to check whether the websites were responding.

### Test canary host

```bash
ansible canary -i inventory -m ansible.builtin.command -a 'curl --fail --silent --show-error -i http://127.0.0.1:8081/'
```

Expected:

```text
HTTP/1.1 200 OK
X-Environment: DEVELOPMENT
X-Maintenance: enabled
```

### Test stable host

```bash
ansible stable -i inventory -m ansible.builtin.command -a 'curl --fail --silent --show-error -i http://127.0.0.1:8082/'
```

Expected:

```text
HTTP/1.1 200 OK
X-Environment: PRODUCTION
X-Maintenance: disabled
```

This confirmed that both websites were responding with the correct host-specific configuration.

---

## 21. Understand Idempotency

Idempotency is one of the most important concepts in Ansible.

It means that running the same playbook repeatedly with the same desired configuration should not make unnecessary changes.

We ran:

```bash
ansible-playbook site.yml -i inventory
```

After the configuration had already been deployed, the result was:

```text
PLAY RECAP

web1 : ok=11 changed=0 unreachable=0 failed=0 skipped=3
web2 : ok=10 changed=0 unreachable=0 failed=0 skipped=4
```

### What does `changed=0` mean?

It means Ansible checked the desired state and found that everything was already correct.

No changes were required.

This is a successful idempotency test.

---

## 22. Important Ansible Concepts Learned

| Concept | What we learned |
|---|---|
| Inventory | Defines the managed hosts and groups |
| `host_vars` | Stores host-specific variables |
| `group_vars` | Stores group-specific variables |
| `when` | Runs tasks conditionally |
| `loop` | Repeats a task for multiple items |
| `stat` | Checks whether a file exists |
| `register` | Stores task results in a variable |
| Jinja2 | Generates dynamic configuration files |
| `template` | Renders and deploys templates |
| `validate` | Checks a generated file before deployment |
| Handler | Runs when notified by a changed task |
| Role | Organizes automation into reusable components |
| Idempotency | Avoids unnecessary changes on repeated runs |

---

## 23. Common Commands for Revision

```bash
# Check inventory structure
ansible-inventory -i inventory --graph

# Check variables for a host
ansible-inventory -i inventory --host web1

# Test playbook syntax
ansible-playbook site.yml -i inventory --syntax-check

# Preview changes
ansible-playbook site.yml -i inventory --check

# Execute the playbook
ansible-playbook site.yml -i inventory

# Execute against one group
ansible-playbook site.yml -i inventory --limit canary

# Check managed hosts
ansible all -i inventory -m ansible.builtin.ping

# Check website response
ansible canary -i inventory -m ansible.builtin.command -a 'curl --fail --silent --show-error -i http://127.0.0.1:8081/'
```

---

## 24. Important Notes

### World-writable directory warning

We repeatedly saw:

```text
Ansible is being run in a world writable directory
```

This happened because our project is stored under the Windows-mounted D: drive in WSL.

Ansible ignored the local `ansible.cfg` as a security precaution.

This warning did not prevent our playbook from executing successfully.

### Existing Nginx configuration backup

We saved the original configuration on both managed hosts at:

```text
/etc/nginx/nginx.conf.ansible-lab-backup
```

If you ever need to restore it:

```bash
ansible all -i inventory -b -m ansible.builtin.copy -a 'src=/etc/nginx/nginx.conf.ansible-lab-backup dest=/etc/nginx/nginx.conf remote_src=true'
```

Then reload Nginx:

```bash
ansible all -i inventory -b -m ansible.builtin.service -a 'name=nginx state=reloaded'
```

Note that restoring the old configuration also restores its previous listening-port configuration.

---

## 25. Final Lab Outcome

**Completed successfully.**

We built and executed one reusable Ansible role that manages two websites with different environments and maintenance settings.

We also tested invalid Nginx configuration handling and confirmed that repeated playbook execution produced zero changes.

**End of Lab Notes**
