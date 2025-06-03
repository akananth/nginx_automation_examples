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
    content: |
      ${nginx_cert}
    permissions: '0644'

  - path: /etc/ssl/nginx/nginx-repo.key
    content: |
      ${nginx_key}
    permissions: '0600'


  - path: /etc/nginx/license.jwt
    content: |
      ${nginx_jwt}
    permissions: '0644'

runcmd:
  - mkdir -p /etc/ssl/nginx
  - sudo apt update
  - sudo apt install apt-transport-https lsb-release ca-certificates wget gnupg2 ubuntu-keyring
  - wget -qO - https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
  - echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://pkgs.nginx.com/plus/ubuntu $(lsb_release -cs) nginx-plus" | tee /etc/apt/sources.list.d/nginx-plus.list
  - sudo wget -P /etc/apt/apt.conf.d https://cs.nginx.com/static/files/90pkgs-nginx
  - sudo apt update
  - sudo apt install -y nginx-plus
  - sudo systemctl enable nginx
  - sudo systemctl restart nginx
