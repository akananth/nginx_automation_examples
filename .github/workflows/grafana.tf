name: Apply NGINXaaS WAF Deployment with Grafana

on:
  push:
    branches: [nginxaas-apply]
  workflow_dispatch:

jobs:
  grafana:
    name: 'Configure Grafana'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ./azure/nginxaas
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Update Azure CLI and Extensions
        run: |
          # Update Azure CLI to latest version
          sudo apt-get update
          sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
          curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
          
          # Update all installed extensions
          az extension update --name amg --yes
          az config set extension.use_dynamic_install=yes_without_prompt

      - name: Enable Grafana Service Account
        run: |
          az grafana update \
            --name "${{ needs.terraform.outputs.grafana_name }}" \
            --resource-group "${{ needs.terraform.outputs.resource_group_name }}" \
            --service-account Enabled \
            --api-version 2022-08-01  # Explicitly set supported API version

      - name: Create Service Account
        run: |
          az grafana service-account create \
            --name "${{ needs.terraform.outputs.grafana_name }}" \
            --resource-group "${{ needs.terraform.outputs.resource_group_name }}" \
            --service-account tf-sa \
            --role Admin \
            --display-name "Terraform Service Account" \
            --api-version 2022-08-01  # Explicitly set supported API version

      - name: Create Service Account Token
        run: |
          TOKEN=$(az grafana service-account token create \
            --name "${{ needs.terraform.outputs.grafana_name }}" \
            --resource-group "${{ needs.terraform.outputs.resource_group_name }}" \
            --service-account tf-sa \
            --token tf-token \
            --time-to-live 8760h \
            --api-version 2022-08-01 \  # Explicitly set supported API version
            --query token -o tsv)
          echo "::add-mask::$TOKEN"
          echo "GRAFANA_TOKEN=$TOKEN" >> $GITHUB_ENV

      - name: Import Grafana Dashboard
        run: |
          az grafana dashboard import \
            --name "${{ needs.terraform.outputs.grafana_name }}" \
            --resource-group "${{ needs.terraform.outputs.resource_group_name }}" \
            --definition "@./azure/nginxaas/n4-dashboard.json" \
            --token "$GRAFANA_TOKEN" \
            --api-version 2025-04-01  # Explicitly set supported API version

      - name: Verify Grafana Access
        run: |
          echo "Grafana URL: ${{ needs.terraform.outputs.grafana_url }}"
          echo "Try accessing Grafana with your Azure AD credentials"