#!/usr/bin/env bash
# -----------------------------------------------------
#  Script Name:    install_nginx.sh
#  Version:        1.1.3
#  Author:         Feigelman Evgeny
#  Date:           2025-02-12
#  Description:    This script will help you with NGNIX installation and configuration.
#                  
#                  
set -o errexit
set -o pipefail
#set -x
# -----------------------------------------------------

# Variables 

s_available=/etc/nginx/sites-available/
s_enabled=/etc/nginx/sites-enabled/
my_domain=feigelman.com
test_script=/usr/lib/cgi-bin/test.py
nginx_conf=/etc/nginx/sites-available/default

Help()
{
   # Display Help
   echo "This script can check if NGINX is installed,"
   echo "Check that the virtual host is configured. If not," 
   echo "it will ask for a virtual host name and configure it."
   echo "Check the dependencies of userdir, auth, and CGI." 
   echo "If they are not present, install them"
   echo
   echo "Syntax: install_nginx.sh [-h|i|I|d|D]"
   echo "options:"
   echo "h     Print this Help. "
   echo "i     Print if NGINX is installed or not. "
   echo "I     Install NGINX. "
   echo "d     Check that the virtual host is configured and configure it. "
   echo "D     Check the dependencies of userdir, auth, and CGI. If they are not present, install them. "
   echo
}

check_nginx()
{
    if ! command -v nginx > /dev/null 2>&1; then
        echo "NGINX is not installed."
    else
        echo "NGINX is installed"
    fi
}

# Function will check if NGINX is installed and install if not presented.

check_install_nginx()
{
    if ! which nginx > /dev/null 2>&1; then
        sudo apt update -y
        sudo apt install nginx -y
    else
        echo "NGINX is installed"
    fi
}

# Function will check if NGINX extras are installed and install them.

check_install_extras(){
    for pkg in apache2-utils nginx-extras; do
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "installed"; then
            echo "$pkg is installed."
        else
            echo "$pkg is NOT installed. Installing..."
            sudo apt install -y "$pkg"
        fi
    done
    }

# Function will create a virtual host in NGNIX  
create_virtual_host(){
    read -p "Enter desired virtual host , for example example.com: " my_domain
    if [ -f "$s_available/$my_domain.conf" ]; then
        echo "Virtual host $my_domain already exists. Skipping."
        return
    fi

    cat > "$s_available/$my_domain.conf" <<EOF
server {
    listen 80;
    server_name $my_domain;
    root /var/www/$my_domain;
    index index.html;
}
EOF
    if [ ! -L "$s_enabled/$my_domain.conf" ]; then
        ln -s "$s_available/$my_domain.conf" "$s_enabled/$my_domain.conf"
    fi

    sudo systemctl restart nginx
}
create_files(){
    if [ ! -d "/var/www/$my_domain" ]; then 
        sudo mkdir -p "/var/www/$my_domain"
        sudo chown -R www-data:www-data "/var/www/$my_domain"
        sudo chmod -R 755 "/var/www/$my_domain"
cat > "/var/www/$my_domain/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $my_domain</title>
</head>
<body>
    <h1>Success! The $my_domain virtual host is working!</h1>
</body>
</html>
EOF
    else
        echo "/var/www/$my_domain already exists"
    fi


}
# Functiuon will check if any virtual hosts are exists exchept the default and create one.
check_and_create_virtual_host() {
    existing_vhosts=$(find "$s_enabled" -type l ! -name "default" || true)

    if [[ -n "$existing_vhosts" ]]; then
        echo "Virtual hosts already exist:"
        echo "$existing_vhosts"
    else
        echo "No virtual hosts found. Creating a new one..."
        create_virtual_host
    fi
}


add_auth(){
    local user=''
    local password=''
    local passfile="/etc/nginx/.htpasswd"
    local nginx_config="/etc/nginx/conf.d/restricred.conf"
    read -p "Enter username: " user
    read -s -p "Enter password: " password
    if [ ! -f "$passfile" ]; then
        sudo htpasswd -bc "$passfile" "$user" "$password"
    else
        sudo htpasswd -b "$passfile" "$user" "$password"
    fi
    echo "User '$user' added successfully to $passfile."
    cat > $nginx_config <<EOF
    location /secure {
        auth_basic "Restricted Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
EOF
}

# Install CGI Packages  
install_cgi(){
    sudo apt update -y 
    sudo apt install fcgiwrap spawn-fcgi -y 
    sudo systemctl enable --now fcgiwrap 

}

# Config CGI 
config_cgi(){
    sudo cp "$nginx_conf" "$nginx_conf.bak"

cgi_block=$(cat <<EOF

    # Enable CGI scripts execution
    location /cgi-bin/ {
        root /usr/lib/;  # Directory where CGI scripts are stored
        fastcgi_pass unix:/run/fcgiwrap.socket;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param QUERY_STRING \$query_string;
        fastcgi_param REQUEST_METHOD \$request_method;
        fastcgi_param CONTENT_TYPE \$content_type;
        fastcgi_param CONTENT_LENGTH \$content_length;
    }
EOF
)

    if grep -q "location /cgi-bin/" "$nginx_conf"; then
        echo "CGI configuration already exists in $nginx_conf"
    else
        sudo sed -i "/^}/i $cgi_block" "$nginx_conf"
        echo "CGI configuration added successfully!"
    fi

    sudo nginx -t && sudo systemctl restart nginx
    echo "Nginx restarted with CGI support."

}

# Create a CGI sctipt
create_test_script(){
    cat > $test_script <<EOF
#!/usr/bin/env python3

print("Content-type: text/html\n")
print("<html><body><h1>Hello from Python CGI</h1></body></html>")

EOF
    sudo chmod +x $test_script
    sudo chown www-data: $test_script 
}

# Userdir
config_userdir(){
user_dir=$(cat <<EOF
location ~ ^/~(.+?)(/.*)?$ {
    alias /home/\$1/public_html\$2;
}
EOF
)
    if grep -q "alias /home/"  "$nginx_conf"; then
        echo "Userdir configuration already exists in $nginx_conf"
    else
        sudo sed -i "/^}/i $user_dir" "$nginx_conf"
        echo  "Added user directrory."
    fi
    sudo nginx -t && sudo systemctl restart nginx
    echo "Nginx restarted with user directrory."
 
}

#Menu
while getopts ":hiIdD" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      i) # Print if NGNIX installed 
        check_nginx
         exit;;
      I) # Install NGINX 
         check_install_nginx
         check_install_extras
         exit;;
      d) # Check that the virtual host is configured. If not, ask for a virtual host name and configure it.
         check_and_create_virtual_host
         create_files
         exit;;
      D) # Check the dependencies of userdir, auth, and CGI. If they are not present, install them.
          add_auth
          install_cgi
          config_cgi
          create_test_script
          config_userdir
          exit;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done
