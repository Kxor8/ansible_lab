# Manage Packages and a Working Service – Ansible Lab

## 1. Objectives

- Install and remove packages using Ansible.
- Use variables to control package state.
- Understand idempotency.
- Install and configure Nginx.
- Deploy a static HTML page.
- Manage services using Ansible.
- Validate configuration files.
- Use handlers to reload services.
- Verify HTTP responses using curl.

## 2. Package Management

Created `packages.yml`:

```yaml
- name: Declare a utility package state
  hosts: all
  gather_facts: false
  become: true

  vars:
    utility_state: present

  tasks:
    - name: Install or remove the tree package
      ansible.builtin.apt:
        name: tree
        state: "{{ utility_state }}"
        update_cache: false
        install_recommends: false
```

### Commands

```bash
# Check syntax
ansible-playbook packages.yml -i inventory --syntax-check

# Install tree
ansible-playbook packages.yml -i inventory

# Verify installation
ansible all -i inventory -m ansible.builtin.command -a 'tree --version'

# Repeat installation to test idempotency
ansible-playbook packages.yml -i inventory

# Remove tree
ansible-playbook packages.yml -i inventory -e "utility_state=absent"

# Repeat removal to test idempotency
ansible-playbook packages.yml -i inventory -e "utility_state=absent"
```

**Important concepts:**
- `present`: ensures the package is installed.
- `absent`: ensures the package is removed.
- `-e`: passes an extra variable, overriding the playbook variable for that run.
- `become: true`: executes tasks with elevated privileges.
- `changed=0`: means no changes were necessary.

## 3. Prepare the Website

Create the static HTML page:

```bash
printf 'Ansible service ready\n' > page.txt

# Verify the page
cat page.txt
```

Create the Nginx configuration:

```bash
cat > nginx-course.conf <<'NGINX'
events {}
http {
    server {
        listen 8080;
        root /var/www/ansible-site;
        index index.html;
    }
}
NGINX

# Verify configuration
cat nginx-course.conf
```

**Configuration explanation:**

- `events {}`: required Nginx configuration block.
- `http {}`: contains HTTP server settings.
- `listen 8080`: Nginx listens on port 8080.
- `root`: directory containing website files.
- `index index.html`: default webpage.

## 4. Deploy Nginx Using Ansible

Created `nginx_deploy.yml`:

```yaml
- name: Deploy a working web service
  hosts: all
  gather_facts: false
  become: true

  tasks:
    - name: Install nginx without refreshing package lists
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: false
        install_recommends: false
        policy_rc_d: 101

    - name: Prepare the site directory
      ansible.builtin.file:
        path: /var/www/ansible-site
        state: directory
        owner: root
        group: root
        mode: "0755"

    - name: Deploy the static page
      ansible.builtin.copy:
        src: /mnt/d/kritika/ansible-lab/page.txt
        dest: /var/www/ansible-site/index.html
        owner: root
        group: root
        mode: "0644"

    - name: Validate and deploy nginx configuration
      ansible.builtin.copy:
        src: /mnt/d/kritika/ansible-lab/nginx-course.conf
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: "0644"
        validate: /usr/sbin/nginx -t -c %s
      notify: Reload nginx

    - name: Keep nginx running
      ansible.builtin.service:
        name: nginx
        state: started

  handlers:
    - name: Reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

### Commands

```bash
# Check playbook syntax
ansible-playbook nginx_deploy.yml -i inventory --syntax-check

# Deploy Nginx
ansible-playbook nginx_deploy.yml -i inventory
```

**Important concepts:**

- `policy_rc_d: 101`: prevents automatic service startup during package installation.
- `validate`: checks the configuration before deploying it. `%s` represents the temporary candidate file.
- `state: started`: ensures Nginx is running.
- `notify`: triggers a handler when a task changes something.
- `handlers`: executes notified tasks, normally at the end of the play.

## 5. Install curl and Verify the Website

Initially, curl was not installed on the managed hosts.

Install it using Ansible:

```bash
ansible all -i inventory -b -m ansible.builtin.apt -a 'name=curl state=present update_cache=false install_recommends=false'
```

Verify the website response:

```bash
ansible all -i inventory -m ansible.builtin.command -a 'curl --fail --silent --show-error http://127.0.0.1:8080/'
```

Expected output:

```text
Ansible service ready
```

This confirms that Nginx is serving the webpage on both hosts.

## 6. Update Configuration and Use Handlers

Updated `nginx-course.conf`:

```nginx
events {}
http {
    server_tokens off;

    server {
        listen 8080;
        root /var/www/ansible-site;
        index index.html;
    }
}
```

Verify the updated configuration:

```bash
cat nginx-course.conf
```

Apply the updated configuration:

```bash
ansible-playbook nginx_deploy.yml -i inventory
```

Because the configuration changed, Ansible notified the `Reload nginx` handler.

Verify HTTP response headers:

```bash
ansible all -i inventory -m ansible.builtin.command -a 'curl --fail --silent --show-error -I http://127.0.0.1:8080/'
```

Expected important headers:

```text
HTTP/1.1 200 OK
Server: nginx
```

`server_tokens off;` hides the Nginx version from the response header.

## 7. Final Idempotency Test

Run the deployment playbook again:

```bash
ansible-playbook nginx_deploy.yml -i inventory
```

Expected:
- All tasks should show `ok`.
- `changed=0` on both hosts.
- The reload handler should not execute.

This confirms that Ansible maintains the desired state without unnecessary changes.

## 8. Important Concepts Summary

| Concept | Meaning |
|---|---|
| `apt` | Manages Debian/Ubuntu packages |
| `present` / `absent` | Installs / removes packages |
| `copy` | Copies files to managed hosts |
| `file` | Creates and manages directories and files |
| `validate` | Validates configuration before deployment |
| `service` | Manages services |
| `notify` | Notifies a handler when a task changes |
| `handlers` | Runs notified tasks |
| `started` | Ensures a service is running |
| `reloaded` | Reloads a running service |
| `changed=0` | No changes were required |

## 9. Final Outcome

Successfully completed:

- Installed and removed `tree` on both managed hosts.
- Deployed Nginx on `web1` and `web2`.
- Served a static webpage on port 8080.
- Validated Nginx configuration before deployment.
- Started and reloaded Nginx using Ansible.
- Hid the Nginx version from HTTP headers.
- Verified HTTP 200 responses.
- Practised idempotency.

**Main takeaway:** Ansible helps maintain the desired state of packages, files, configurations, and services consistently across multiple servers.
