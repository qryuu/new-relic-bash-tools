# new-relic-bash-tools

Scripts that can be used with New Relic.

Designed for automated infrastructure operations, such as periodic OS patch updates or maintenance tasks executed via **AWS Systems Manager (SSM)** or cron, without requiring a CI/CD pipeline or heavy dependencies.

---

## Tools

### 1. `record_change_tracking.sh` (Recommended)

Records a **Change Tracking** event to New Relic using the NerdGraph (GraphQL) API (`changeTrackingCreateEvent`).

#### Features
- **Zero External Dependencies**: Requires only standard `bash` and `curl` (no `jq` or Python packages required).
- **Infrastructure Agent Compatible**: Automatically inspects `/etc/newrelic-infra.yml` for `display_name` or `override_hostname` before falling back to system hostname / FQDN. This guarantees seamless correlation with existing Infrastructure host entities.
- **Secure Key Management**: Supports both environment variables and **AWS Systems Manager Parameter Store** (SecureString).

#### Prerequisites
- A New Relic **User API Key** (starts with `NRAK-...`).  
  *(Note: Ingestion License Keys from `newrelic-infra.yml` cannot be used for NerdGraph operations).*
- Linux host with `curl` and `bash`.

#### Usage

```bash
# 1. Provide API Key via environment variable (or let it fetch from SSM Parameter Store)
export NEW_RELIC_API_KEY="NRAK-XXXXXXXXXXXXXXXXXXXXXXXX"

# 2. Run with default parameters (Host resolved from newrelic-infra.yml, Version from `uname -r`)
./record_change_tracking.sh

# Or customize arguments:
# ./record_change_tracking.sh "<ENTITY_QUERY>" "<VERSION>" "<DESCRIPTION>" "<USER>"
./record_change_tracking.sh "name = '$(hostname)' AND domain = 'INFRA'" "6.1.100-kernel" "Monthly security patch applied" "ssm-user"
```

#### AWS Systems Manager (SSM Run Command) Example

In an SSM Run Command (`AWS-RunShellScript`) document, you can combine OS updates with Change Tracking in a single workflow:

```bash
# 1. Perform OS update
sudo yum update -y

# 2. Inject User API Key securely from SSM Parameter Store (SecureString)
export NEW_RELIC_API_KEY="{{ ssm-secure:/newrelic/user-key }}"

# 3. Record Change Tracking event
./record_change_tracking.sh "name = '$(hostname)' AND domain = 'INFRA'" "$(uname -r)" "Kernel & package security patch applied" "ssm-user"
```

---

### 2. `deployment_marker.sh` (Deprecated)

Sends legacy deployment markers via the New Relic REST API v2 (`/v2/applications/${application_id}/deployments.json`).

> **Warning**  
> The REST API v2 deployment markers endpoint is scheduled for **End of Life (EOL) on July 31, 2027**.  
> Please use `record_change_tracking.sh` for all new and existing setups.

---

## License

[MIT License](LICENSE)
