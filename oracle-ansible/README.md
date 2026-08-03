# Oracle 19c RAC / ADG Ansible Automation

Ansible-based automation for installing Oracle Database 19c (19.3.0) in four deployment architectures. Converted from the original Vagrant shell-script project at [indiff/vagrant-projects OracleRAC/19.3.0](https://github.com/indiff/vagrant-projects/tree/dev/OracleRAC%2F19.3.0).

---

## Supported Architectures

| `arch_type` | Description |
|---|---|
| `rac` | Oracle RAC cluster (primary only) |
| `adg` | Standalone primary + standalone standby (Active Data Guard) |
| `rac_adg` | RAC primary cluster + RAC standby cluster (ADG between clusters) |
| `rac_standalone_adg` | RAC primary cluster + single-node standby (ADG) |

---

## Prerequisites

1. **Ansible ≥ 2.12** on the control node.
2. **Oracle Linux 7 / 8** on all target nodes.
3. Oracle 19c installer ZIPs:
   - `LINUX.X64_193000_grid_home.zip`
   - `LINUX.X64_193000_db_home.zip`

   Place them in `ORCL_software/` at the root of this repository (same level as `oracle-ansible/`).

4. All target nodes must be reachable via SSH as `root` from the control node.
5. Each node requires at minimum:
   - OS disk (`sda`)
   - `/u01` disk (`sdb`, ≥ 50 GB)
   - ≥ 4 shared ASM disks (`sdc`, `sdd`, `sde`, `sdf`, …) — RAC nodes must share these via a SAN / shared storage backend.

---

## Quick Start

### 1. Configure inventory

```bash
cd oracle-ansible
cp inventory/hosts.yml inventory/hosts.local.yml    # create a local copy
$EDITOR inventory/hosts.local.yml                   # fill in real IPs
$EDITOR inventory/group_vars/all.yml                # set passwords, software names, etc.
```

> **Important:** Never commit real passwords. Use Ansible Vault or environment variables.

### 2. (Optional) Encrypt secrets with Ansible Vault

```bash
ansible-vault encrypt_string 'MyRealSysPassword' --name sys_password
```

Paste the output into `inventory/group_vars/all.yml` and pass `--ask-vault-pass` when running playbooks.

### 3. Run the deployment

#### RAC only
```bash
ansible-playbook -i inventory/hosts.local.yml site.yml -e arch_type=rac
```

#### Standalone ADG
```bash
ansible-playbook -i inventory/hosts.local.yml site.yml -e arch_type=adg
```

#### RAC primary + RAC standby with ADG
```bash
ansible-playbook -i inventory/hosts.local.yml site.yml -e arch_type=rac_adg
```

#### RAC primary + standalone standby with ADG
```bash
ansible-playbook -i inventory/hosts.local.yml site.yml -e arch_type=rac_standalone_adg
```

Or run an individual playbook directly:
```bash
ansible-playbook -i inventory/hosts.local.yml playbooks/install_rac.yml
```

---

## Directory Structure

```
oracle-ansible/
├── site.yml                            # Main entry point (arch_type dispatch)
├── inventory/
│   ├── hosts.yml                       # Inventory template (copy & edit)
│   └── group_vars/
│       ├── all.yml                     # Global variables (versions, passwords…)
│       ├── rac_primary.yml             # RAC primary cluster vars (SCAN IPs, cluster name)
│       ├── rac_standby.yml             # RAC standby cluster vars
│       ├── adg_primary.yml             # Standalone ADG primary vars
│       └── adg_standby.yml             # Standalone ADG standby vars
├── playbooks/
│   ├── install_rac.yml                 # RAC only
│   ├── install_adg.yml                 # Standalone ADG
│   ├── install_rac_adg.yml             # RAC + RAC ADG
│   └── install_standalone_adg.yml      # RAC + standalone ADG
└── roles/
    ├── common/                         # OS baseline (all nodes)
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── locale.yml
    │   │   ├── timezone.yml
    │   │   ├── packages.yml
    │   │   ├── kernel.yml              # Kernel params + resource limits
    │   │   ├── users.yml               # OS groups/users (grid, oracle)
    │   │   ├── storage.yml             # /u01 mount + ASM disk partitioning + udev
    │   │   ├── hosts.yml               # /etc/hosts generation
    │   │   ├── chrony.yml              # NTP configuration
    │   │   ├── ssh.yml                 # SSH key exchange (all cluster nodes)
    │   │   └── stage_dir.yml           # /etc/opt/oracle-rac/setup.env + stage dir
    │   ├── templates/
    │   │   ├── hosts.j2
    │   │   ├── chrony.conf.j2
    │   │   ├── setup.env.j2
    │   │   └── 99-oracle-asmdevices.rules.j2
    │   └── handlers/main.yml
    ├── oracle_gi/                      # Grid Infrastructure install
    │   └── tasks/
    │       ├── main.yml
    │       ├── extract.yml             # Copy + unzip GI installer
    │       ├── install.yml             # gridSetup.sh (silent)
    │       ├── root_scripts.yml        # orainstRoot.sh + root.sh
    │       ├── config.yml              # configToolAllCommands
    │       └── diskgroup.yml           # Create RECO diskgroup
    ├── oracle_db/                      # RDBMS install + DB creation
    │   └── tasks/
    │       ├── main.yml
    │       ├── extract.yml             # Copy + unzip DB installer
    │       ├── install.yml             # runInstaller (silent) + root.sh
    │       └── create_db.yml           # dbca (silent) — skipped for standby
    └── oracle_adg/                     # Active Data Guard configuration
        ├── tasks/
        │   ├── main.yml
        │   ├── configure_primary.yml   # ARCHIVELOG, force logging, redo logs, LOG_ARCHIVE_DEST_2
        │   ├── configure_standby.yml   # RMAN active duplication, MRP startup
        │   └── verify.yml              # V$DATABASE / V$ARCHIVE_DEST check
        └── templates/
            ├── tnsnames.ora.j2
            ├── listener.ora.j2
            └── init_standby.ora.j2
```

---

## Key Configuration Variables

All variables live in `inventory/group_vars/all.yml`. The most important ones:

| Variable | Default | Description |
|---|---|---|
| `arch_type` | `rac` | Deployment architecture (see table above) |
| `gi_software` | `LINUX.X64_193000_grid_home.zip` | GI installer filename |
| `db_software` | `LINUX.X64_193000_db_home.zip` | DB installer filename |
| `db_name` | `ORCL` | Primary DB unique name |
| `adg_standby_db_name` | `ORCLSTBY` | Standby DB unique name |
| `sys_password` | `DemoSys_1` | SYS / SYSASM password |
| `pdb_password` | `DemoPdb_1` | PDB admin password |
| `asm_disk_num` | `4` | Number of shared ASM disks per node |
| `p1_ratio` | `80` | % of ASM disk size for DATA (rest → RECO) |
| `cdb` | `true` | Create as Container Database |
| `ora_languages` | `en,zh_CN` | Oracle installation languages |
| `system_timezone` | `Asia/Shanghai` | System timezone |

Per-cluster variables (SCAN IPs, cluster name) are set in the per-group files under `inventory/group_vars/`.

---

## Notes

- **Serial execution for GI root scripts:** The `oracle_gi` install playbooks use `serial: [1, "100%"]` so that `root.sh` runs on node 1 before node 2 — a hard requirement for Oracle Clusterware.
- **Idempotency:** File-creates guards (`args: creates:`) and `run_once` make most tasks safe to re-run.
- **Passwords:** Cleared from `setup.env` after installation. Use `--ask-vault-pass` with Ansible Vault for production.
- **Software staging:** Installer ZIPs are copied to each target node under `/tmp/oracle_stage`. Ensure sufficient disk space (≥ 10 GB free in `/tmp`).
