# Scryn Security Scan Action

Run a [Scryn](https://www.scryn.cloud) security scan (DAST) against a target URL in your GitHub Actions workflow. Scryn uses OWASP ZAP to find vulnerabilities in web applications and APIs.

## Prerequisites

- A [Scryn](https://www.scryn.cloud) account (sign up and see pricing at [scryn.cloud](https://www.scryn.cloud))
- An API token with **Create scans** permission (create one in Scryn: **Profile → API tokens**)

## Setup

1. Add your Scryn API token as a repository secret:
   - **Settings → Secrets and variables → Actions → New repository secret**
   - Name: `SCRYN_API_TOKEN`
   - Value: your Scryn API token

2. Use the action in your workflow (see examples below).

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `target_url` | Yes | - | Target URL to scan (e.g. `https://your-app.example.com`) |
| `scan_type` | No | `baseline` | Scan type: `baseline`, `full`, `spider`, or `api` |
| `api_url` | No | `https://api.scryn.cloud` | Scryn API base URL (change for self-hosted) |
| `wait_for_completion` | No | `false` | Wait for the scan to complete before the step finishes |
| `timeout` | No | `3600` | Timeout in seconds when waiting for completion |
| `openapi_spec_url` | No | - | OpenAPI/Swagger spec URL (required when `scan_type` is `api`) |
| `fail_on_high_or_critical` | No | `true` | Fail the step when the scan finds high (or critical) severity alerts |

## Outputs

| Output | Description |
|--------|-------------|
| `scan_id` | ID of the created scan (always set) |
| `status` | Final scan status (set when `wait_for_completion` is true) |
| `total_alerts` | Total number of alerts (set when `wait_for_completion` is true) |

## Examples

### Basic: trigger a scan and continue

```yaml
jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Scryn security scan
        uses: scryncloud/security-scan-action@v1
        env:
          SCRYN_API_TOKEN: ${{ secrets.SCRYN_API_TOKEN }}
        with:
          target_url: https://your-app.example.com
          scan_type: baseline
```

### Wait for completion and fail on high-severity findings

```yaml
      - name: Scryn security scan
        uses: scryncloud/security-scan-action@v1
        env:
          SCRYN_API_TOKEN: ${{ secrets.SCRYN_API_TOKEN }}
        with:
          target_url: https://staging.myapp.com
          scan_type: baseline
          wait_for_completion: true
          timeout: 1800
          fail_on_high_or_critical: true
```

### API scan with OpenAPI spec

```yaml
      - name: Scryn API security scan
        uses: scryncloud/security-scan-action@v1
        env:
          SCRYN_API_TOKEN: ${{ secrets.SCRYN_API_TOKEN }}
        with:
          target_url: https://api.myapp.com
          scan_type: api
          openapi_spec_url: https://api.myapp.com/openapi.json
          wait_for_completion: true
```

### Use outputs in later steps

```yaml
      - name: Scryn security scan
        id: scryn
        uses: scryncloud/security-scan-action@v1
        env:
          SCRYN_API_TOKEN: ${{ secrets.SCRYN_API_TOKEN }}
        with:
          target_url: https://myapp.example.com
          wait_for_completion: true

      - name: Use scan ID
        run: echo "Scan ID is ${{ steps.scryn.outputs.scan_id }}"
```

## License

MIT
