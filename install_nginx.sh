#!/usr/bin/env bash
# -----------------------------------------------------
#  Script Name:    install_nginx.sh
#  Version:        1.1.2
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

s_vailable=/etc/nginx/sites-available/
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
   echo "h     Print this Help."
   echo "i     Print if NGINX is installed or not."
   echo "I     Install NGINX."
   echo "d     Check dependencies."
   echo "D     Install dependencies  "
   echo
}

# Function will check if NGINX is installed.

check_nginix()
{
    if ! which nginx > /dev/null 2>&1; then
        return 1  # Return 1 if Nginx is NOT installed
    fi
    return 0  # Return 0 if Nginx is installed
}

#  Function will install  NGINX
install_nginx(){
    sudo apt update -y
    sudo apt install nginx -y
    sudo apt install apache2-utils nginx-extras -y
}

# Function will use check_nginix and check_nginix if needed.
install_ngnix_if_needed(){
    if ! check_nginx; then
        echo "Nginx not found. Installing now..."
        install_nginx
    else
        "Nginx installed"
    fi
}

# Function will create a virtual host in NGNIX 
create_virtual_host(){
    read -p "Enter desired virtual host , for example example.com: " my_domain
    cd $s_vailable
    cat > $my_domain << EOF
server {
    listen 80;
    server_name $my_domain;
    root /var/www/$my_domain;
    index index.html;
}
    ln -s /etc/nginx/sites-available/$my_domain /etc/nginx/sites-enabled/
    sudo systemctl restart nginx

EOF
}

# Functiuon will check if any virtual hosts are exists exchept the default.
check_and_create_virtual_host() {
    existing_vhosts=$(find "$s_enabled" -type l ! -name "default")

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
    local ngnix_config="/etc/nginx/conf.d/restricred.conf;"
    read -p "Enter username: " user
    read -s -p "Enter password: " password
    if [ ! -f "$passfile" ]; then
        sudo htpasswd -c "$passfile" "$user"
    else
        sudo htpasswd "$passfile" "$user"

    fi
    echo "User '$user' added successfully to $passfile."
    cat > $ngnix_config <<  EOF
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
    sudo systemctl enable --now fcgiwrap -y 

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
    cat > $test_script << EOF
#!/usr/bin/env python3

print("Content-type: text/html\n")
print("<html><body><h1>Hello from Python CGI</h1></body></html>")

EOF
    sudo chmod +x $test_script
    sudo chown www-data: $test_script 
}

# Userdir
config_userdir(){
user_dir=$(cat << EOF
location ~ ^/~(.+?)(/.*)?$ {
    alias /home/$1/public_html$2;
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
while getopts ":hiIdD:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      i) # Print if NGNIX installed 
         if check_nginix ; then
             echo "Nginx is installed"
         else
             echo "Nginx not found."
         fi
         exit;;
      I) # Install NGINX 
         install_ngnix_if_needed
         exit;;
      d) # Check dependencies
         check_and_create_virtual_host
         add_auth
         exit;;
      D) # Install  dependencies
          check_and_create_virtual_host
          add_auth
          create_test_script
          exit;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done
