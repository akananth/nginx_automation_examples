# Deploy NGINX Ingress Controller with App ProtectV5 in AWS Cloud
==================================================================================================

## Table of Contents
  - [Introduction](#introduction)
  - [Architecture Diagram](#architecture-diagram)
  - [Prerequisites](#prerequisites)
  - [Assets](#assets)
  - [Tools](#tools)
  - [GitHub Secrets Configuration](#github-secrets-configuration)
    - [Required Secrets](#required-secrets)
    - [How to Add Secrets](#how-to-add-secrets)
  - [Workflow Runs](#workflow-runs)
    - [STEP 1: Workflow Branches](#step-1-workflow-branches)
    - [STEP 2: Modify terraform.tfvars](#step-2-modify-terraformtfvars)
    - [STEP 3: Modify variable.tf](#step-3-modify-variabletf)
    - [STEP 4: Modify Backend.tf](#step-4-modify-backendtf)
    - [STEP 5: Configuring data.tf for Remote State](#step-5-configuring-datatf-for-Remote-State)
    - [STEP 6: Set Bucket Name](#step-6-set-bucket-name)
    - [STEP 7: Policy ](#step-7-Policy)
    - [STEP 8: Deployment Workflow](#step-8-Deployment-workflow)
    - [STEP 9: Destroy Workflow](#step-9-Destroy-workflow)
    - [STEP 10: Validation](#step-10-validation)
  - [Conclusion](#conclusion)
  - [Support](#support)
  - [Community Code of Conduct](#community-code-of-conduct)
  - [License](#license)
  - [Copyright](#copyright)
    - [F5 Networks Contributor License Agreement](#f5-networks-contributor-license-agreement)

## Introduction
---------------
This demo guide provides a comprehensive, step-by-step walkthrough for configuring the NGINX Ingress Controller alongside NGINX App Protect v5 on the AWS Cloud platform. It utilizes Terraform scripts to automate the deployment process, making it more efficient and streamlined. For further details, please consult the official [documentation](https://docs.nginx.com/nginx-ingress-controller/installation/integrations/). Also, you can find more insights in the DevCentral article: <Coming Soon>

--------------

## Architecture Diagram
![System Architecture](assets/AWS.jpeg)

## Prerequisites
* [NGINX Plus with App Protect and NGINX Ingress Controller license](https://www.nginx.com/free-trial-request/)
* [AWS Account](https://aws.amazon.com) - Due to the assets being created, the free tier will not work.
* [GitHub Account](https://github.com)

## Assets
* **nap:**       NGINX Ingress Controller for Kubernetes with NGINX App Protect (WAF and API Protection)
* **infra:**     AWS Infrastructure (VPC, IGW, etc.)
* **eks:**       AWS Elastic Kubernetes Service
* **arcadia:**   Arcadia Finance test web application and API
* **policy:**    NGINX WAF Compiler Docker and Policy
* **S3:**        Amazon S3 bucket and IAM role and policy for storage.

## Tools
* **Cloud Provider:** AWS
* **IAC:** Terraform
* **IAC State:** Amazon S3
* **CI/CD:** GitHub Actions

## GitHub Secrets Configuration

This workflow requires the following secrets to be configured in your GitHub repository:

### Required Secrets

| Secret Name            | Type    | Description                                                                 | Example Value/Format        |
|------------------------|---------|-----------------------------------------------------------------------------|----------------------------|
| `AWS_ACCESS_KEY_ID`     | Secret  | AWS IAM user access key ID with sufficient permissions                     | `AKIAXXXXXXXXXXXXXXXX`     |
| `AWS_SECRET_ACCESS_KEY` | Secret  | Corresponding secret access key for the AWS IAM user                       | (40-character mixed case string) |
| `AWS_SESSION_TOKEN`     | Secret  | Session token for temporary AWS credentials (if using MFA)                 | (Base64-encoded string)    |
| `NGINX_JWT`             | Secret  | JSON Web Token for NGINX license authentication                            | `eyJhbGciOi...` (JWT format) |
| `NGINX_Repo_CRT`        | Secret  | NGINX Certificate in PKCS#12 format                                        | `api.p12` file contents    |
| `NGINX_Repo_KEY`        | Secret  | Private key for securing HTTPS and verifying SSL/TLS certificates          | YourCertificatePrivatekey  |

### How to Add Secrets

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Enter the secret name exactly as shown above
5. Paste the secret value
6. Click **Add secret**

## Workflow Runs

### STEP 1: Workflow Branches
**DEPLOY**
  | Workflow     | Branch Name      |
  | ------------ | ---------------- |
  |Apply-nic-napv5| apply-nic-napv5   |

**DESTROY**
  | Workflow     | Branch Name       |
  | ------------ | ----------------- |
  | Destroy-nic-napv5| destroy-nic-napv5   |

### STEP 2: Modify terraform.tfvars
Rename `infra/terraform.tfvars.examples` to `infra/terraform.tfvars` and add the following data:
  * project_prefix  = "Your project identifier name in **lower case** letters only - this will be applied as a prefix to all assets"
  * resource_owner = "Your-name"
  * aws_region     = "AWS Region" ex. us-east-1
  * azs            = ["us-east-1a", "us-east1b"] - Change to Correct Availability Zones based on selected Region

### STEP 3: Modify variable.tf
Modify the `S3/variable.tf` file inside the `S3 directory`:
  * default     = "your-unique-bucket-name"  # Replace with your actual bucket name

### STEP 4: Modify Backend.tf
Modify the `Backend.tf` file in the `Infra/Backend.tf`, `eks-cluster/Backend.tf`, `Nap/Backend.tf`, `Policy/Backend.tf`, and `Arcadia/Backend.tf` directories. 
  * bucket         = "your-unique-bucket-name"  # Your S3 bucket name
  * region         = "your-aws-region-name"   By default us-east-1

### STEP 5: Configuring `data.tf` for Remote State

Each `data.tf` file in the following directories needs to use the correct format:

- `eks-cluster/data.tf`
- `Nap/data.tf`
- `Policy/data.tf`
- `Arcadia/data.tf`

### Example Configuration:

```hcl
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket         = "your-unique-bucket-name"   # Your S3 bucket name
    key            = "path/to/your/statefile.tfstate"  # Path to your state file
    region         = "us-west-2"                # AWS region
  }
}
```
### STEP 6: Set Bucket Name
Add the name of your S3 bucket inside the `destroy-nic-napv5` workflow file, which is located in the Terraform _S3 job:
  
  * echo "bucket_name="your-unique-bucket-name" >> $GITHUB_OUTPUT


### STEP 7: Policy 

The repository includes a default policy file named policy.json, which can be found in the policy directory. 

.. figure:: assets/policy-1.png

Users have the option to utilize the existing policy or, if preferred, create a custom policy. To do this, place the custom policy in the designated policy folder and name it "policy.json" or any name you choose. If you decide to use a different name, update the corresponding name in the workflow file accordingly.

.. figure:: assets/policy-2.png

### STEP 8: Deployment Workflow  

* Step 1: Check out a branch for the deploy workflow using the following naming convention

 * nic-napv5 deployment branch: apply-nic-napv5

.. figure:: assets/add-lb.png

* Step 2: Push your deploy branch to the forked repo

.. figure:: assets/add-lb.png

* Step 3: Back in GitHub, navigate to the Actions tab of your forked repo and monitor your build

.. figure:: assets/add-lb.png

* Step 4: Once the pipeline completes, verify your assets were deployed to AWS 

.. figure:: assets/add-lb.png


### STEP 9: Destroy Workflow  

* Step 1: From your main branch, check out a new branch for the destroy workflow using the following naming convention

 * nic-napv5 destroy branch: destroy-nic-napv5

.. figure:: assets/add-lb.png

* Step 2: Push your destroy branch to the forked repo

.. figure:: assets/add-lb.png

* Step 3: Back in GitHub, navigate to the Actions tab of your forked repo and monitor your workflow

.. figure:: assets/add-lb.png

* Step 4: Once the pipeline is completed, verify that your assets were destroyed

.. figure:: assets/add-lb.png


### STEP 10: Validation  

Users can now access the application through the NGINX Ingress Controller Load Balancer, which enhances security for the backend application by implementing the configured Web Application Firewall (WAF) policies. This setup not only improves accessibility but also ensures that the application is protected from various web threats.

.. figure:: assets/lb-domain-access.png

* With malicious attacks:

.. figure:: assets/sql-inj.png

* Verify that the cross-site scripting is detected and blocked by NGINX App Protect.

.. figure:: assets/sql-inj-detect.png



### Conclusion  

This article outlines deploying a robust security framework using the NGINX Ingress Controller and NGINX App Protect WAF version 5 for a sample web application hosted on AWS EKS. We leveraged the NGINX Automation Examples Repository and integrated it into a CI/CD pipeline for streamlined deployment. Although the provided code and security configurations are foundational and may not cover every possible scenario, they serve as a valuable starting point for implementing NGINX Ingress Controller and NGINX App Protect version 5 in your own cloud environments.

## Support
For support, please open a GitHub issue. Note that the code in this repository is community-supported and is not supported by F5 Networks.

## Community Code of Conduct
Please refer to the [F5 DevCentral Community Code of Conduct](code_of_conduct.md).

## License
[Apache License 2.0](LICENSE)

## Copyright
Copyright 2014-2020 F5 Networks Inc.

### F5 Networks Contributor License Agreement
Before you start contributing to any project sponsored by F5 Networks, Inc. (F5) on GitHub, you will need to sign a Contributor License Agreement (CLA).


Workflow Instructions
######################

`Deploy NGINX Ingress Controller with App ProtectV5 Workflow <./xc-console-demo-guide.rst>`__





