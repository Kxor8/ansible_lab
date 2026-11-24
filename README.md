# Ansible Local Lab --- Setup & Revision Notes

## 1. Lab architecture

We created a small Ansible environment locally:

-   **Control node:** WSL Ubuntu, where Ansible is installed and
    commands are run.
-   **Managed nodes:** Two Ubuntu Docker containers, `web1` and `web2`.
-   **Connection:** Ansible connects to each container over SSH.
-   **Authentication:** SSH key-based authentication.

``` text
WSL Ubuntu (Ansible control node)
        |
        | SSH
        |
        +---- 127.0.0.1:2221 ----> web1 (container, port 22)
        |
        +---- 127.0.0.1:2222 ----> web2 (container, port 22)
```

Working directory:

``` bash
cd /mnt/d/kritika/ansible-lab
```

## 2. Create the Docker managed nodes

We created `docker-compose.yml`:

``` yaml
services:
  web1:
    image: ubuntu:24.04
    container_name: web1
    ports:
      - "2221:22"
    command: >
      bash -c "apt-get update &&
      apt-get install -y openssh-server python3 &&
      mkdir -p /run/sshd &&
      /usr/sbin/sshd -D"

  web2:
    image: ubuntu:24.04
    container_name: web2
    ports:
      - "2222:22"
    command: >
      bash -c "apt-get update &&
      apt-get install -y openssh-server python3 &&
      mkdir -p /run/sshd &&
      /usr/sbin/sshd -D"
```

Start the containers:

``` bash
docker compose up -d
```

Check that they are running:

``` bash
docker ps
```

Check SSH service inside a container:

``` bash
docker exec web1 pgrep -a sshd
```

Check SSH listening ports (we installed `iproute2` because `ss` was
initially missing):

``` bash
docker exec web1 apt-get update
docker exec web1 apt-get install -y iproute2
docker exec web1 ss -lntp
```

**Important:** Docker maps the container's SSH port `22` to ports `2221`
and `2222` on the WSL host. That is why our inventory uses `127.0.0.1`
with different ports.

## 3. Create an SSH key

On the WSL control node:

``` bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_lab
```

This creates:

-   `~/.ssh/ansible_lab` --- private key; keep it secure.
-   `~/.ssh/ansible_lab.pub` --- public key; copy this to managed nodes.

## 4. Create the automation user on both containers

``` bash
docker exec web1 useradd -m -s /bin/bash automation
docker exec web2 useradd -m -s /bin/bash automation
```

Create the SSH directory:

``` bash
docker exec web1 mkdir -p /home/automation/.ssh
docker exec web2 mkdir -p /home/automation/.ssh
```

Copy the public key into each container:

``` bash
docker cp ~/.ssh/ansible_lab.pub web1:/tmp/ansible_lab.pub
docker cp ~/.ssh/ansible_lab.pub web2:/tmp/ansible_lab.pub
```

Add the key to `authorized_keys`:

``` bash
docker exec web1 bash -c "cat /tmp/ansible_lab.pub >> /home/automation/.ssh/authorized_keys"
docker exec web2 bash -c "cat /tmp/ansible_lab.pub >> /home/automation/.ssh/authorized_keys"
```

Set ownership and permissions:

``` bash
docker exec web1 chown -R automation:automation /home/automation/.ssh
docker exec web2 chown -R automation:automation /home/automation/.ssh

docker exec web1 chmod 700 /home/automation/.ssh
docker exec web2 chmod 700 /home/automation/.ssh

docker exec web1 chmod 600 /home/automation/.ssh/authorized_keys
docker exec web2 chmod 600 /home/automation/.ssh/authorized_keys
```

### Test SSH manually

``` bash
ssh -p 2221 -i ~/.ssh/ansible_lab automation@127.0.0.1
```

``` bash
ssh -p 2222 -i ~/.ssh/ansible_lab automation@127.0.0.1
```

The first connection may ask whether to trust the host key. Type `yes`.
Use `exit` to leave the remote container shell and return to WSL.

## 5. Install Ansible on the control node

``` bash
sudo apt update
sudo apt install ansible-core -y
```

Check the installation:

``` bash
ansible --version
```

Ansible is installed on the **control node**, not inside the managed
containers.

## 6. Create the inventory

Create a file named `inventory` in the project directory:

``` ini
[web]
web1 ansible_host=127.0.0.1 ansible_port=2221
web2 ansible_host=127.0.0.1 ansible_port=2222

[all:vars]
ansible_user=automation
ansible_ssh_private_key_file=/home/nikita/.ssh/ansible_lab
ansible_python_interpreter=/usr/bin/python3
```

### What each part means

  -----------------------------------------------------------------------
  Entry                               Meaning
  ----------------------------------- -----------------------------------
  `[web]`                             A group containing our managed
                                      hosts

  `web1`, `web2`                      Host aliases used by Ansible

  `ansible_host`                      Address Ansible connects to

  `ansible_port`                      SSH port exposed by Docker

  `[all:vars]`                        Variables applied to all inventory
                                      hosts

  `ansible_user`                      Remote user Ansible logs in as

  `ansible_ssh_private_key_file`      Private SSH key used for
                                      authentication

  `ansible_python_interpreter`        Python executable on each managed
                                      node
  -----------------------------------------------------------------------

The interpreter setting is important because Ansible modules commonly
use Python on managed nodes.

Check which hosts Ansible reads from the inventory:

``` bash
ansible all -i inventory --list-hosts
```

## 7. Test Ansible connectivity

``` bash
ansible all -i inventory -m ansible.builtin.ping
```

Expected result:

``` text
web1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
web2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

**Remember:** `ansible.builtin.ping` is not a normal network/ICMP ping.
It checks that Ansible can connect and run its module on the managed
node.

-   `pong` means the test succeeded.
-   `changed: false` means the test did not change the managed machine.
