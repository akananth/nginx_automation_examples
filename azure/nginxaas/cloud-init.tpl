#cloud-config
package_update: true
package_upgrade: true
packages:
  - curl
  - apt-transport-https

write_files:
- path: /etc/ssl/nginx/nginx-repo.crt
  content: ${nginx_cert}
  encoding: b64
- path: /etc/ssl/nginx/nginx-repo.key
  content: ${nginx_key}
  encoding: b64

runcmd:
  - curl -fsSL https://cs.nginx.com/static/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
  - echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://plus-pkgs.nginx.com/ubuntu $(lsb_release -cs) nginx-plus" | tee /etc/apt/sources.list.d/nginx-plus.list
  - apt-get update
  - apt-get install -y nginx-plus
  - systemctl enable nginx
  - systemctl start nginx