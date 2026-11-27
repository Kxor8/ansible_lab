# Distribute and Inspect Managed Files – Ansible Lab

## 1. Objective

Learn how to use Ansible to:
- Create and distribute files to managed hosts.
- Set file ownership and permissions.
- Inspect files and generate SHA256 checksums.
- Create host-specific reports.
- Fetch reports from managed hosts to the controller.
- Verify idempotency.

**Environment:**
- Controller: WSL Ubuntu
- Managed hosts: `web1`, `web2`
- Remote user: `automation`

## 2. Step 1 – Create the source file

Created `site-banner.txt` on the Ansible controller.

```bash
printf 'Managed service banner\n' > site-banner.txt
cat site-banner.txt
```

We also tried setting private permissions:

```bash
chmod 0600 site-banner.txt
stat -c '%a %n' site-banner.txt
```

**Note:** The file showed `777` because it is stored on the Windows-mounted `/mnt/d` filesystem. Linux permission changes may not be reflected there.

## 3. Step 2 – Distribute the banner

Created `deploy-banner.yml`.

```yaml
- name: Distribute the managed banner
  hosts: all
  gather_facts: false
  become: true

  tasks:
    - name: Create the managed site directory
      ansible.builtin.file:
        path: /srv/ansible-site
        state: directory
        owner: root
        group: automation
        mode: "0750"

    - name: Copy the banner to managed hosts
      ansible.builtin.copy:
        src: /mnt/d/kritika/ansible-lab/site-banner.txt
        dest: /srv/ansible-site/banner.txt
        owner: root
        group: automation
        mode: "0640"
```

**What we learned:**
- `become: true` – runs tasks with elevated privileges.
- `file` – creates directories and manages permissions.
- `copy` – copies files from controller to managed hosts.
- `owner` and `group` – specify file ownership.
- `mode` – sets permissions.

Commands:

```bash
ansible-playbook deploy-banner.yml -i inventory --syntax-check

ansible-playbook deploy-banner.yml -i inventory
```

## 4. Step 3 – Verify file access

Checked whether the automation user could read the copied banner without sudo.

```bash
ansible all -i inventory -m ansible.builtin.command -a 'cat /srv/ansible-site/banner.txt'
```

Both hosts successfully displayed the banner.

## 5. Step 4 – Inspect the banner and generate reports

Created `inspect-and-collect.yml`.

```yaml
- name: Inspect the banner and prepare host reports
  hosts: all
  gather_facts: true

  tasks:
    - name: Inspect the managed banner
      ansible.builtin.stat:
        path: /srv/ansible-site/banner.txt
        checksum_algorithm: sha256
      register: banner_info

    - name: Display banner metadata
      ansible.builtin.debug:
        var: banner_info.stat

    - name: Create a report on each managed host
      become: true
      ansible.builtin.copy:
        dest: /srv/ansible-site/node-report.txt
        content: |
          host={{ inventory_hostname }}
          distribution={{ ansible_facts['distribution'] }}
          banner_sha256={{ banner_info.stat.checksum }}
        owner: root
        group: automation
        mode: "0640"
```

**What we learned:**

| Module / Variable | Purpose |
|---|---|
| `gather_facts` | Collects information about managed hosts |
| `stat` | Inspects file details and calculates checksum |
| `register` | Stores task output in a variable |
| `debug` | Displays stored information |
| `inventory_hostname` | Gives the current host's name |
| `ansible_facts` | Provides system information |
| `copy` | Creates the report file |

Commands:

```bash
ansible-playbook inspect-and-collect.yml -i inventory --syntax-check

ansible-playbook inspect-and-collect.yml -i inventory
```

## 6. Step 5 – Verify checksums and reports

Checked the original file's checksum:

```bash
sha256sum site-banner.txt
```

Read reports from both managed hosts:

```bash
ansible all -i inventory -m ansible.builtin.command -a 'cat /srv/ansible-site/node-report.txt'
```

Both hosts had the same SHA256 checksum as the controller's source file.

## 7. Step 6 – Fetch reports to the controller

Added the following task to `inspect-and-collect.yml`:

```yaml
    - name: Fetch reports from managed hosts
      ansible.builtin.fetch:
        src: /srv/ansible-site/node-report.txt
        dest: /mnt/d/kritika/ansible-lab/reports/
        flat: false
```

**What is `fetch`?**

It copies files from managed hosts back to the Ansible controller.

`flat: false` preserves the hostname and remote directory structure, preventing reports from different hosts from overwriting each other.

Executed:

```bash
ansible-playbook inspect-and-collect.yml -i inventory
```

Verified the downloaded reports:

```bash
cat reports/web1/srv/ansible-site/node-report.txt

cat reports/web2/srv/ansible-site/node-report.txt
```

## 8. Step 7 – Test idempotency

Ran the playbook again:

```bash
ansible-playbook inspect-and-collect.yml -i inventory
```

Final result:

| Result | web1 | web2 |
|---|---:|---:|
| OK | 5 | 5 |
| Changed | 0 | 0 |
| Failed | 0 | 0 |

**Idempotency:** Running the same Ansible playbook repeatedly does not make unnecessary changes when the desired state is already achieved.

## 9. Final Directory Structure

```text
ansible-lab/
├── inventory
├── site-banner.txt
├── deploy-banner.yml
├── inspect-and-collect.yml
└── reports/
    ├── web1/
    │   └── srv/ansible-site/node-report.txt
    └── web2/
        └── srv/ansible-site/node-report.txt
```

## 10. Key Takeaways

- `copy` distributes files from controller to managed hosts.
- `fetch` retrieves files from managed hosts to controller.
- `stat` checks file properties and checksums.
- `register` stores task results for reuse.
- `debug` displays variables and task information.
- `become` provides elevated privileges.
- `mode`, `owner`, and `group` manage file permissions and ownership.
- Idempotency ensures repeatable and safe automation.

**Lab Status: Completed successfully on both managed hosts.**
