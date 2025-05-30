#cloud-config
package_update: true
package_upgrade: true
packages:
  - ca-certificates
  - apt-transport-https
  - lsb-release
  - gnupg
  - wget

write_files:
  - path: /etc/apt/auth.conf.d/nginx.conf
    content: |
      machine pkgs.nginx.com
      login token
      password ${nginx_jwt}
    permissions: '0600'

runcmd:
  # Add NGINX signing key
  - wget -qO - https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
  
  # Add NGINX Plus repository
  - echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://pkgs.nginx.com/plus/ubuntu `lsb_release -cs` nginx-plus" | sudo tee /etc/apt/sources.list.d/nginx-plus.list
  
  # Install NGINX Plus
  - sudo apt update
  - sudo apt install -y nginx-plus
  
  # Copy JWT license
  - sudo mkdir -p /etc/nginx/ssl
  - echo '${nginx_jwt}' | sudo tee /etc/nginx/ssl/license.jwt > /dev/null
  - sudo chmod 600 /etc/nginx/ssl/license.jwt
  
  # Configure NGINX (basic HTTP config)
  - sudo tee /etc/nginx/conf.d/default.conf <<EOF
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
    EOF
  
  # Restart NGINX
  - sudo systemctl restart nginx