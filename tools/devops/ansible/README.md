# Ansible - Configuration Management and Automation

## Overview

Ansible is an open-source automation tool for configuration management, application deployment, and orchestration. Created by Michael DeHaan and now maintained by Red Hat, Ansible uses a simple, human-readable language (YAML) to describe automation tasks.

The defining characteristic of Ansible is its **agentless architecture** -- it connects to managed nodes over SSH (or WinRM for Windows) and requires no software to be installed on target machines beyond Python.

## Why Use Ansible?

| Benefit | Description |
|---|---|
| **Agentless** | No daemon or agent needed on managed nodes -- just SSH and Python |
| **Simple syntax** | YAML playbooks are readable by anyone, not just developers |
| **Idempotent** | Running the same playbook multiple times produces the same result |
| **Extensible** | Thousands of modules for cloud, network, containers, and more |
| **Push-based** | You control when and where changes are applied |
| **No central server required** | Can run from any workstation (though AWX/AAP can serve as a central UI) |
| **Large ecosystem** | Ansible Galaxy provides community roles and collections |

## Architecture

```
┌──────────────────┐
│  Control Node    │    SSH / WinRM
│  (your machine)  │──────────────────┐
│                  │───────────┐      │
│  - ansible       │           │      │
│  - ansible-playbook          │      │
│  - inventory     │           │      │
│  - playbooks     │           ▼      ▼
└──────────────────┘    ┌──────────┐  ┌──────────┐
                        │ Managed  │  │ Managed  │
                        │ Node 1   │  │ Node 2   │
                        │ (SSH+Py) │  │ (SSH+Py) │
                        └──────────┘  └──────────┘
```

- **Control Node** -- Where Ansible runs (your laptop, CI server, or Ansible Automation Platform)
- **Managed Nodes** -- Target machines being configured
- **Inventory** -- List of managed nodes (static file or dynamic from cloud APIs)
- **Playbook** -- YAML file defining tasks to execute
- **Module** -- Unit of work (e.g., `apt`, `copy`, `service`, `docker_container`)
- **Role** -- Reusable bundle of tasks, handlers, files, templates, and variables
- **Collection** -- Distribution format for roles, modules, and plugins

## Installation

### macOS

```bash
# Via pip (recommended)
pip3 install ansible

# Via Homebrew
brew install ansible
```

### Linux (Ubuntu/Debian)

```bash
# Via pip (recommended for latest version)
sudo apt update && sudo apt install -y python3-pip
pip3 install ansible

# Via APT
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
```

### Linux (RHEL/CentOS/Fedora)

```bash
# Fedora
sudo dnf install ansible

# RHEL 9 (via subscription)
sudo dnf install ansible-core
```

### Windows

Ansible does not run natively on Windows as a control node. Use WSL 2:

```powershell
wsl --install
# Inside WSL:
pip3 install ansible
```

### Verify

```bash
ansible --version
ansible-community --version   # Full collection version
```

## Inventory

The inventory defines which hosts Ansible manages.

### Static Inventory (INI Format)

```ini
# inventory/hosts.ini
[webservers]
web1.example.com
web2.example.com ansible_port=2222

[dbservers]
db1.example.com ansible_user=dbadmin
db2.example.com

[production:children]
webservers
dbservers

[production:vars]
ansible_python_interpreter=/usr/bin/python3
ntp_server=time.example.com
```

### Static Inventory (YAML Format)

```yaml
# inventory/hosts.yml
all:
  children:
    webservers:
      hosts:
        web1.example.com:
        web2.example.com:
          ansible_port: 2222
    dbservers:
      hosts:
        db1.example.com:
          ansible_user: dbadmin
        db2.example.com:
    production:
      children:
        webservers:
        dbservers:
      vars:
        ansible_python_interpreter: /usr/bin/python3
```

### Dynamic Inventory

For cloud environments, use dynamic inventory plugins:

```bash
# AWS EC2
pip3 install boto3 botocore
ansible-inventory -i aws_ec2.yml --graph
```

```yaml
# aws_ec2.yml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
keyed_groups:
  - key: tags.Environment
    prefix: env
filters:
  tag:ManagedBy: ansible
```

## Ad-Hoc Commands

Quick one-off tasks without writing a playbook:

```bash
# Ping all hosts
ansible all -i inventory/hosts.ini -m ping

# Run a shell command
ansible webservers -m shell -a "uptime"

# Copy a file
ansible webservers -m copy -a "src=app.conf dest=/etc/app.conf owner=root mode=0644"

# Install a package
ansible webservers -m apt -a "name=nginx state=present" --become

# Restart a service
ansible webservers -m service -a "name=nginx state=restarted" --become

# Gather facts
ansible web1.example.com -m setup

# Run on localhost
ansible localhost -m debug -a "msg='Hello from Ansible'"
```

## Playbooks

Playbooks are YAML files that define a set of tasks to execute on managed nodes.

### Basic Playbook

```yaml
# playbooks/webserver.yml
---
- name: Configure web servers
  hosts: webservers
  become: true
  vars:
    http_port: 80
    app_version: "2.1.0"

  tasks:
    - name: Update apt cache
      apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Install nginx
      apt:
        name: nginx
        state: present

    - name: Deploy nginx configuration
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/sites-available/default
        owner: root
        group: root
        mode: "0644"
      notify: Restart nginx

    - name: Ensure nginx is running and enabled
      service:
        name: nginx
        state: started
        enabled: true

    - name: Deploy application
      unarchive:
        src: "https://releases.example.com/app-{{ app_version }}.tar.gz"
        dest: /var/www/html
        remote_src: true
      notify: Restart nginx

  handlers:
    - name: Restart nginx
      service:
        name: nginx
        state: restarted
```

### Running Playbooks

```bash
# Basic run
ansible-playbook -i inventory/hosts.ini playbooks/webserver.yml

# With extra variables
ansible-playbook playbooks/deploy.yml -e "app_version=2.2.0 environment=production"

# Dry run (check mode)
ansible-playbook playbooks/webserver.yml --check --diff

# Limit to specific hosts
ansible-playbook playbooks/webserver.yml --limit web1.example.com

# Start at a specific task
ansible-playbook playbooks/webserver.yml --start-at-task "Deploy application"

# List tasks without running
ansible-playbook playbooks/webserver.yml --list-tasks

# Step through tasks one at a time
ansible-playbook playbooks/webserver.yml --step
```

### Conditionals, Loops, and Error Handling

```yaml
tasks:
  # Conditional
  - name: Install packages (Debian)
    apt:
      name: "{{ item }}"
      state: present
    loop:
      - nginx
      - certbot
      - python3-certbot-nginx
    when: ansible_os_family == "Debian"

  # Loop with dict
  - name: Create users
    user:
      name: "{{ item.name }}"
      groups: "{{ item.groups }}"
      state: present
    loop:
      - { name: "deploy", groups: "www-data" }
      - { name: "monitor", groups: "adm" }

  # Error handling
  - name: Attempt risky operation
    block:
      - name: Run migration
        command: /app/migrate.sh
    rescue:
      - name: Rollback on failure
        command: /app/rollback.sh
    always:
      - name: Send notification
        slack:
          token: "{{ slack_token }}"
          msg: "Migration completed (may have rolled back)"
```

## Roles

Roles provide a structured way to organize playbooks into reusable components.

### Role Directory Structure

```
roles/
  nginx/
    defaults/        # Default variables (lowest priority)
      main.yml
    vars/            # Role variables (higher priority)
      main.yml
    tasks/           # Task files
      main.yml
    handlers/        # Handler definitions
      main.yml
    templates/       # Jinja2 templates
      nginx.conf.j2
    files/           # Static files
      index.html
    meta/            # Role metadata and dependencies
      main.yml
```

### Creating and Using Roles

```bash
# Create role skeleton
ansible-galaxy role init roles/nginx
```

```yaml
# roles/nginx/tasks/main.yml
---
- name: Install nginx
  apt:
    name: nginx
    state: present
  notify: Restart nginx

- name: Deploy configuration
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Restart nginx

# roles/nginx/handlers/main.yml
---
- name: Restart nginx
  service:
    name: nginx
    state: restarted

# roles/nginx/defaults/main.yml
---
nginx_worker_processes: auto
nginx_worker_connections: 1024
```

```yaml
# playbooks/site.yml
---
- name: Configure web servers
  hosts: webservers
  become: true
  roles:
    - common
    - nginx
    - { role: app, app_version: "2.1.0" }
```

## Collections

Collections are the modern distribution format for Ansible content, bundling roles, modules, and plugins together.

```bash
# Install a collection
ansible-galaxy collection install community.docker
ansible-galaxy collection install amazon.aws

# Install from requirements file
ansible-galaxy collection install -r requirements.yml
```

```yaml
# requirements.yml
collections:
  - name: community.docker
    version: ">=3.0.0"
  - name: amazon.aws
    version: ">=7.0.0"
  - name: community.general
```

```yaml
# Using collection modules in playbooks
- name: Manage Docker containers
  hosts: docker_hosts
  tasks:
    - name: Start a container
      community.docker.docker_container:
        name: myapp
        image: myapp:latest
        ports:
          - "8080:80"
        state: started
```

## Ansible Vault

Ansible Vault encrypts sensitive data (passwords, API keys, certificates) so they can be safely committed to version control.

```bash
# Create an encrypted file
ansible-vault create secrets.yml

# Encrypt an existing file
ansible-vault encrypt vars/production.yml

# View encrypted file
ansible-vault view secrets.yml

# Edit encrypted file
ansible-vault edit secrets.yml

# Decrypt a file
ansible-vault decrypt secrets.yml

# Re-key (change password)
ansible-vault rekey secrets.yml

# Run playbook with vault password
ansible-playbook site.yml --ask-vault-pass
ansible-playbook site.yml --vault-password-file ~/.vault_pass

# Encrypt a single string
ansible-vault encrypt_string 'SuperSecret123' --name 'db_password'
```

The encrypted string can be embedded directly in YAML:

```yaml
# vars/secrets.yml
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  6562313663623361...
```

## Configuration (`ansible.cfg`)

```ini
# ansible.cfg (project root)
[defaults]
inventory = inventory/hosts.yml
roles_path = roles
collections_path = collections
remote_user = deploy
private_key_file = ~/.ssh/deploy_key
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
timeout = 30

[privilege_escalation]
become = True
become_method = sudo
become_ask_pass = False

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

## Best Practices

1. **Use roles for everything** -- even simple playbooks benefit from the structure
2. **Name every task** -- makes output readable and debugging easier
3. **Use `ansible-lint`** -- catch issues before they hit production
   ```bash
   pip3 install ansible-lint
   ansible-lint playbooks/
   ```
4. **Keep secrets in Vault** -- never commit plaintext passwords or keys
5. **Use `--check --diff`** -- preview changes before applying
6. **Tag your tasks** -- enable selective execution
   ```yaml
   tasks:
     - name: Install packages
       apt: name=nginx state=present
       tags: [install, nginx]
   ```
   ```bash
   ansible-playbook site.yml --tags install
   ```
7. **Use handlers for service restarts** -- avoids unnecessary restarts
8. **Pin collection and role versions** in `requirements.yml`
9. **Avoid `command` and `shell`** when a dedicated module exists
10. **Use `ansible-navigator`** for a modern, container-based execution environment

## Ansible Automation Platform and ansible-navigator

### ansible-navigator

A modern replacement for `ansible-playbook` that runs playbooks inside execution environments (containers), ensuring reproducibility.

```bash
pip3 install ansible-navigator

# Run a playbook
ansible-navigator run site.yml --mode stdout

# Interactive mode (TUI)
ansible-navigator run site.yml

# Use a specific execution environment
ansible-navigator run site.yml --execution-environment-image quay.io/ansible/creator-ee:latest
```

### Ansible Automation Platform (AAP)

Red Hat's commercial offering (successor to Ansible Tower/AWX) provides:

- Web UI and REST API for managing automation
- Role-based access control
- Job scheduling and workflow orchestration
- Centralized logging and audit trails
- Execution environments for reproducible automation

AWX is the open-source upstream project for AAP.

```bash
# Deploy AWX on Kubernetes via the AWX Operator
kubectl apply -f https://raw.githubusercontent.com/ansible/awx-operator/devel/deploy/awx-operator.yaml
```

## Resources

- [Official Ansible Documentation](https://docs.ansible.com/)
- [Ansible Galaxy](https://galaxy.ansible.com/) -- Community roles and collections
- [Ansible Lint](https://ansible.readthedocs.io/projects/lint/)
- [Ansible Navigator](https://ansible.readthedocs.io/projects/navigator/)
- [AWX Project](https://github.com/ansible/awx)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [Jinja2 Template Documentation](https://jinja.palletsprojects.com/)
- [Ansible Examples (GitHub)](https://github.com/ansible/ansible-examples)
