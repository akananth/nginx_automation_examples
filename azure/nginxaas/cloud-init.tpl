#cloud-config
package_update: true
package_upgrade: true
packages:
  - ca-certificates
  - apt-transport-https
  - lsb-release
  - gnupg
  - wget
  - curl

write_files:
  - path: /etc/ssl/nginx/nginx-repo.crt
    permissions: '0644'
    content: |
      ${nginx_cert}

  - path: /etc/ssl/nginx/nginx-repo.key
    permissions: '0644'
    content: |
      ${nginx_key}

  - path: /etc/nginx/license.jwt
    permissions: '0644'
    content: |
      ${nginx_jwt}

runcmd:
  - mkdir -p /etc/ssl/nginx
  - apt update
  - apt install apt-transport-https lsb-release ca-certificates wget gnupg2 ubuntu-keyring

  # Add NGINX signing key
  - wget -qO - https://cs.nginx.com/static/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg

  # Configure nginx-plus repo/etc/apt/sources.list.d/nginx-plus.list
  - echo "deb [signed-by=/etc/apt/keyrings/nginx.gpg] https://pkgs.nginx.com/plus/ubuntu `lsb_release -cs` nginx-plus" | sudo tee /etc/apt/sources.list.d/nginx-plus.list
  
  # Download policy for nginx repo
  - wget -P /etc/apt/apt.conf.d https://cs.nginx.com/static/files/90pkgs-nginx

  # Update and install nginx-plus
  - apt update
  - apt install -y nginx-plus

  # Start and enable nginx
  - systemctl enable nginx
  - systemctl restart nginx
