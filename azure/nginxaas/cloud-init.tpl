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
    permissions: '0600'
    content: |
      ${nginx_key}

  - path: /etc/nginx/license.jwt
    permissions: '0644'
    content: |
      ${nginx_jwt}

runcmd:
  - mkdir -p /etc/ssl/nginx

  # Add NGINX signing key
  - wget -qO - https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

  # Configure nginx-plus repo
  - echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg sslcert=/etc/ssl/nginx/nginx-repo.crt sslkey=/etc/ssl/nginx/nginx-repo.key] https://pkgs.nginx.com/plus/ubuntu $(lsb_release -cs) nginx-plus" | tee /etc/apt/sources.list.d/nginx-plus.list

  # Download policy for nginx repo
  - wget -P /etc/apt/apt.conf.d https://cs.nginx.com/static/files/90pkgs-nginx

  # Update and install nginx-plus
  - apt update
  - apt install -y nginx-plus

  # Start and enable nginx
  - systemctl enable nginx
  - systemctl restart nginx
