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
  # NGINX Plus certificate and key
  - path: /etc/ssl/nginx/nginx-repo.crt
    encoding: b64
    content: ${nginx_cert}
    permissions: '0644'
  - path: /etc/ssl/nginx/nginx-repo.key
    encoding: b64
    content: ${nginx_key}
    permissions: '0600'
  # JWT license file
  - path: /etc/nginx/license.jwt
    content: ${nginx_jwt}
    permissions: '0600'
  # NGINX Plus repo config
  - path: /etc/apt/auth.conf.d/nginx.conf
    content: |
      machine pkgs.nginx.com
      login token
      password ${nginx_jwt}
    permissions: '0600'

runcmd:
  # Create required directories
  - sudo mkdir -p /etc/ssl/nginx
  
  # Add NGINX signing key
  - wget -qO - https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
  
  # Add NGINX Plus repository
  - echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://pkgs.nginx.com/plus/ubuntu `lsb_release -cs` nginx-plus" | sudo tee /etc/apt/sources.list.d/nginx-plus.list
  
  # Install NGINX Plus
  - sudo apt update
  - sudo apt install -y nginx-plus
  
  # Verify installation
  - sudo nginx -v
  
  # Basic NGINX configuration
  - sudo tee /etc/nginx/conf.d/default.conf <<EOF
    server {
        listen 80;
        server_name _;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
    EOF
  
  # Restart NGINX
  - sudo systemctl restart nginx