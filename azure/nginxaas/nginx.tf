resource "azurerm_nginx_configuration" "main" {
    nginx_deployment_id = azurerm_nginx_deployment.main.id
    root_file           = "/etc/nginx/nginx.conf"
  
    config_file {
      content = base64encode(<<-EOT
        user nginx;
        worker_processes auto;
        worker_rlimit_nofile 8192;
        pid /run/nginx/nginx.pid;
        load_module modules/ngx_http_app_protect_module.so;
  
        events {
            worker_connections 4000;
        }
  
        error_log /var/log/nginx/error.log error;
  
        http {
            app_protect_enforcer_address 127.0.0.1:50000;
            server {
                listen 80 default_server;
                app_protect_enable on;
                app_protect_policy_file /etc/app_protect/conf/NginxDefaultPolicy.json; # Reference default path
                server_name localhost;
                location / {
                    return 200 'Hello World';
                }
            }
        }
      EOT
      )
      virtual_path = "/etc/nginx/nginx.conf"
    }
  
    depends_on = [azurerm_nginx_deployment.main]
  }