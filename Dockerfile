FROM registry.access.redhat.com/ubi8/nginx-120

# check /etc/nginx/nginx.conf for the default application root
ADD dist .

# check /etc/nginx/nginx.conf for the default port
EXPOSE 8080

CMD nginx -g "daemon off;"