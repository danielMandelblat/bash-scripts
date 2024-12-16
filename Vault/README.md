# README: Automate Vault HA Cluster

## Overview
The `automate_vault_ha_cluster.sh` script automates the deployment and configuration of a HashiCorp Vault High-Availability (HA) cluster. It simplifies the provisioning of resources, Vault initialization, backend storage setup (e.g., Raft), and ensures readiness for HA failover in a Kubernetes environment.

This script is designed to handle Vault installation, unsealing, access configuration (e.g., LDAP, Kubernetes), and the creation of local users and policies.

## Features
- Automated deployment of Vault via Helm.
- Initialization and unsealing of Vault nodes.
- Configures LDAP for authentication.
- Enables Kubernetes authentication for service accounts.
- Creates local admin and backup users with specific policies.
- Automatically sets up backup cron jobs for Vault tokens.
- Prints the root token and ingress URL for Vault UI access.

## Prerequisites
1. **Kubernetes Cluster**:
   - A running Kubernetes cluster with `kubectl` configured.
2. **Helm**:
   - Helm must be installed to deploy the Vault Helm chart.
3. **Dependencies**:
   - jq (for JSON parsing)
   - Vault CLI
4. **LDAP**:
   - An accessible LDAP or Active Directory server.
5. **Namespace**:
   - Ensure the namespace (`vault` by default) exists or will be created during script execution.
6. **Permissions**:
   - Admin-level permissions on the Kubernetes cluster.

## Script Variables

| Variable                     | Description                                      |
|------------------------------|--------------------------------------------------|
| `namespace`                  | Kubernetes namespace where Vault will be deployed (default: `vault`). |
| `ingress_url`                | URL for Vault UI access.                         |
| `default_admin`              | Username for the default admin user.             |
| `default_admin_password`     | Password for the default admin user.             |
| `default_backup_user`        | Username for the backup user.                    |
| `default_backup_user_password` | Password for the backup user.                  |
| `ldap_bind_user`             | LDAP bind user for authentication.               |
| `ldap_bind_user_password`    | LDAP bind user password.                         |
| `ldap_server`                | LDAP server URL.                                 |
| `ldap_user_dn`               | LDAP user distinguished name.                    |
| `ldap_group_dn`              | LDAP group distinguished name.                   |
| `roles`                      | Kubernetes service account mappings to namespaces. |

## Usage

### Script Execution Modes
The script can be executed in various modes using the `setup` argument:

| Mode                | Description                                      |
|---------------------|--------------------------------------------------|
| (No argument)       | Installs Vault using Helm and performs full configuration. |
| `--config-only`     | Configures an already installed Vault cluster.   |
| `unseal`            | Unseals all Vault nodes in the cluster.          |
| `access_config`     | Configures authentication methods (LDAP, Kubernetes, etc.). |

### Example Commands

1. **Full Deployment and Configuration**:
   ```bash
   ./automate_vault_ha_cluster.sh
