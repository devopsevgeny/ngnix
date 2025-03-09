#!/usr/bin/env bash
# -----------------------------------------------------
#  Script Name:    install_nginx.sh
#  Version:        1.1.3
#  Author:         Feigelman Evgeny
#  Date:           2025-02-12
#  Description:    This script will help you with NGINX installation and configuration.
#                  
#                  
set -o errexit
set -o pipefail
#set -x
# -----------------------------------------------------

# Variables 

S_AVAILABLE=/etc/nginx/sites-available/
S_ENABLED=/etc/nginx/sites-enabled/
MY_DOMAIN=feigelman.com
TEST_SCRIPT=/usr/lib/cgi-bin/test.py
NGINX_CONF=/etc/nginx/sites-available/default

# Display Help
function Help()
{
   
   printf "%s\n" \
"This script can check if NGINX is installed,
Check that the virtual host is configured. If not, 
it will ask for a virtual host name and configure it.
Check the dependencies of userdir, auth, and CGI. 
If they are not present, install them

Syntax: install_nginx.sh [-h|i|I|d|D]
options:
h     Print this Help.
i     Print if NGINX is installed or not.
I     Install NGINX.
d     Check that the virtual host is configured and configure it.
D     Check the dependencies of userdir, auth, and CGI. If they are not present, install them.
"

exit 0
}

function check_nginx()
{
    if [[ ! command -v nginx > /dev/null 2>&1 ]]; then
        echo "NGINX is not installed."
    else
        echo "NGINX is installed"
    fi
}

# Function will check if NGINX is installed and install if not presented.

function check_install_nginx()
{
    if [[ ! command -v  nginx > /dev/null 2>&1 ]]; then
        sudo apt update -y
        sudo apt install nginx -y
    else
        echo "NGINX is installed"
    fi
}

# Function will check if NGINX extras are installed and install them.

function check_install_extras(){
    for pkg in apache2-utils nginx-extras; do
        if [[ dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "installed" ]]; then
            echo "$pkg is installed."
        else
            echo "$pkg is NOT installed. Installing..."
            sudo apt install -y "$pkg"
        fi
    done
    }

# Function will create a virtual host in NGNIX  
function create_virtual_host(){
    read -p "Enter desired virtual host , for example example.com: " MY_DOMAIN
    if [[ -f "$S_AVAILABLE/$MY_DOMAIN.conf" ]]; then
        echo "Virtual host $MY_DOMAIN already exists. Skipping."
        return
    fi

    sudo tee > "$S_AVAILABLE/$MY_DOMAIN.conf" <<EOF
server {
    listen 80;
    server_name $MY_DOMAIN;
    root /var/www/$MY_DOMAIN;
    index index.html;
}
EOF
    if [[ ! -L "$S_ENABLED/$MY_DOMAIN.conf" ]]; then
        ln -s "$S_AVAILABLE/$MY_DOMAIN.conf" "$S_ENABLED/$MY_DOMAIN.conf"
    fi

    sudo systemctl restart nginx
}
function create_files(){
    if [[ ! -d "/var/www/$MY_DOMAIN" ]]; then 
        sudo mkdir -p "/var/www/$MY_DOMAIN"
        sudo chown -R www-data:www-data "/var/www/$MY_DOMAIN"
        sudo chmod -R 755 "/var/www/$MY_DOMAIN"
sudo tee > "/var/www/$MY_DOMAIN/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $MY_DOMAIN</title>
</head>
<body>
    <h1>Success! The $MY_DOMAIN virtual host is working!</h1>
</body>
</html>
EOF
    else
        echo "/var/www/$MY_DOMAIN already exists"
    fi


}

# Function will check if any virtual hosts exist except the default and create one.
function check_and_create_virtual_host() {
    existing_vhosts=$(find "$S_ENABLED" -type l ! -name "default" || true)

    if [[ -n "$existing_vhosts" ]]; then
        echo "Virtual hosts already exist:"
        echo "$existing_vhosts"
    else
        echo "No virtual hosts found. Creating a new one..."
        create_virtual_host
    fi
}

function add_auth(){
    local user=''
    local password=''
    local passfile="/etc/nginx/.htpasswd"
    local nginx_config="/etc/nginx/conf.d/restricted.conf"
    read -p "Enter username: " user
    echo
    read -s -p "Enter password: " password
    echo
    if [ ! -f "$passfile" ]; then
        sudo htpasswd -bc "$passfile" "$user" "$password"
    else
        sudo htpasswd -b "$passfile" "$user" "$password"
    fi
    echo "User '$user' added successfully to $passfile."
    sudo tee \$nginx_config > /dev/null <<EOF
    location /secure {
        auth_basic "Restricted Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
EOF
}

# Install CGI Packages  
function install_cgi(){
    sudo apt update -y 
    sudo apt install fcgiwrap spawn-fcgi -y 
    sudo systemctl enable --now fcgiwrap 

}

# Config CGI 
function config_cgi(){
    sudo cp "$NGINX_CONF" "$NGINX_CONF.bak"

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

    if [[ grep -q "location /cgi-bin/" "$NGINX_CONF" ]]; then
        echo "CGI configuration already exists in $NGINX_CONF"
    else
        sudo sed -i "/^}/i $cgi_block" "$NGINX_CONF"
        echo "CGI configuration added successfully!"
    fi

    sudo nginx -t && sudo systemctl restart nginx
    echo "Nginx restarted with CGI support."

}

# Create a CGI sctipt
function create_TEST_SCRIPT(){
    sudo tee > $TEST_SCRIPT <<EOF
#!/usr/bin/env python3

print("Content-type: text/html\n")
print("<html><body><h1>Hello from Python CGI</h1></body></html>")

EOF
    sudo chmod +x $TEST_SCRIPT
    sudo chown www-data: $TEST_SCRIPT 
}

# Config serdir
function config_userdir(){
user_dir=$(cat <<EOF
location ~ ^/~(.+?)(/.*)?$ {
    alias /home/\$1/public_html\$2;
}
EOF
)
    if [[ grep -q "alias /home/"  "$NGINX_CONF" ]]; then
        echo "Userdir configuration already exists in $NGINX_CONF"
    else
        sudo sed -i "/^}/i $user_dir" "$NGINX_CONF"
        echo  "Added user directory."
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
          create_TEST_SCRIPT
          config_userdir
          exit;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done
