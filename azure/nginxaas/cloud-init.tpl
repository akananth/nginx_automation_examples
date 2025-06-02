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
  - path: /tmp/nginx-repo.crt
    encoding: b64
    content: ${nginx_cert}
    permissions: '0644'
  - path: /tmp/nginx-repo.key
    encoding: b64
    content: ${nginx_key}
    permissions: '0600'
  - path: /etc/apt/auth.conf.d/nginx.conf
    content: |
      machine pkgs.nginx.com
      login token
      password ${nginx_jwt}
    permissions: '0600'

runcmd:
  # Create SSL directory & move certs there
  - mkdir -p /etc/ssl/nginx
  - mv /tmp/nginx-repo.crt /etc/ssl/nginx/nginx-repo.crt
  - mv /tmp/nginx-repo.key /etc/ssl/nginx/nginx-repo.key

  # Add NGINX signing key and repo
  - wget -qO - https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
  - echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://pkgs.nginx.com/plus/ubuntu $(lsb_release -cs) nginx-plus" | tee /etc/apt/sources.list.d/nginx-plus.list

  # Update & install NGINX Plus
  - apt update
  - apt install -y debian-archive-keyring
  - apt update
  - apt install -y nginx-plus

  # Verify installation and enable service
  - nginx -v
  - systemctl status nginx

  # Write license.jwt file
  - echo '${nginx_jwt}' | tee /etc/nginx/license.jwt

  # Basic default server config
  - |
    cat <<'EOF' > /etc/nginx/conf.d/default.conf
    server {
        listen 80;
        server_name _;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
    EOF

  # Restart and enable NGINX
  - systemctl restart nginx
  - systemctl enable nginx
