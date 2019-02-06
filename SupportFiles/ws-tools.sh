#!/bin/bash
# shellcheck disable=SC2086,SC2015
#
# Script to install various of developer applications/tools on a 
# a STIG-harened, Enterprise Linux 7 "workstation"
#
#################################################################
PROGNAME="$(basename ${0})"

# Pull settings from env-file
# shellcheck disable=SC2163
while read -r WSENV
do
   export "${WSENV}"
done < /etc/cfn/ws-tools.envs
WorkstationUser="${WORKSTATION_USER_NAME:-UNDEF}"
VNCServerPasswd="${VNC_SEREVER_PASSWD:-UNDEF}"

####
## Set up global variables/constants (BEGIN)
# Tool constants
workstation_user_home="/home/${WorkstationUser}"
tool_home="/etc/cfn/tools"
tool_bundle_file="tools.tar.gz"
# Anaconda constants
anaconda_dir="anaconda"
anaconda_file="anaconda.sh"
anaconda_install_dir="${workstation_user_home}/anaconda3"
# Atom constants
atom_source_dir="atom"
atom_file="atom.x86_64.rpm"
# Eclipse constants
eclipse_source_dir="eclipse"
eclipse_file="eclipse-jee-neon-3-linux-gtk-x86_64.tar.gz"
# IntelliJ constants
intellij_source_dir="intellij"
intellij_file="ideaIC-2018.3.3.tar.gz"
intellij_install_dir="/opt/idea-IC-183.5153.38"
# Gradle contstants
gradle_source_dir="gradle"
gradle_file="gradle-5.1.1-bin.zip"
gradle_install_dir="/opt/gradle-5.1.1"
# Node.JS constants
nodejs_source_dir="nodejs"
NODEJS_BASE="node-v11.6.0-linux-x64"
nodejs_file="${NODEJS_BASE}.tar.xz"
nodejs_install_dir="/opt/${NODEJS_BASE}"
# PyCharm constants
pycharm_source_dir="pycharm"
PYCHARM_BASE="pycharm-community-2018.3.3"
pycharm_file="${PYCHARM_BASE}.tar.gz"
pycharm_install_dir="/opt/${PYCHARM_BASE}"
# ASCIIdoctor constants
asciidoctor_source_dir="asciidoctor"
asciidoctor_file="rubygem-asciidoctor-1.5.6.1-1.el7.noarch.rpm"
# VScode constants
vscode_source_dir="vscode"
vscode_file="code-1.30.2-1546901769.el7.x86_64.rpm"
# MongoDB constants
mongodb_source_dir="mongo"
mongodb_file="mongodb-org-shell-4.0.5-1.el7.x86_64.rpm"
# MySQL constants
mysql_source_dir="mysql"
mysql_file="mysql-workbench-community-8.0.13-1.el7.x86_64.rpm"
epel_6_8_file="epel-release-6-8.noarch.rpm"
# Joomla constants
joomla_source_dir="joomla"
joomla_file="Joomla_3.9.2-Stable-Full_Package.tar.gz"
## Set up global variables/constants (END)
####

####
## function() definitions

# Set up an error logging and exit-state
function err_exit {
   local ERRSTR="${1}"
   local SCRIPTEXIT=${2:-1}

   # Our output channels
   logger -s -t "${PROGNAME}" -p kern.crit "${ERRSTR}"

   # Need our exit to be an integer
   if [[ ${SCRIPTEXIT} =~ ^[0-9]+$ ]]
   then
      exit "${SCRIPTEXIT}"
   else
      exit 1
   fi
}
####


####
## Main program flow
####
# Install GNOME
# shellcheck disable=SC2143
if [[ $(yum grouplist -v | grep GNOME) ]]
then
   printf "Installing GNOME ... "
   yum install -y @gnome-desktop && echo "Success" || \
     err_exit "Installing GNOME Desktop failed"

   printf "Changing systemd target-state to "graphical"
   systemctl set-default graphical.target && echo "Success" || \
     err_exit "Couldn't set systemd target-state to 'graphical.target'"
else
   err_exit "GNOME Desktop group package is not found"
fi

# Install VNC server
if [[ $( yum -q list available tigervnc-server > /dev/null 2>&1 )$? -eq 0 ]]
then
   printf "Installing Tiger VNC Server ... "
   yum --quiet -y install tigervnc-server && echo "Success" || \
     err_exit "Failed to install TigerVNC Server."
else
   err_exit "tigervnc-server package is not found"
fi

# Generate default VNC server password
# The "VNCServerPaswd" will be replaced with the VNCServerPasswd parameter and "WorkstationUser" with the WorkstationUser parameter in the CFN during runtime
install -Dm 000700 -o ${WorkstationUser} -g ${WorkstationUser} -d "${workstation_user_home}/.vnc"
install -Dm 000700 -o ${WorkstationUser} -g ${WorkstationUser} -b <( vncpasswd -f <<<${VNCServerPasswd} ) "${workstation_user_home}/.vnc/passwd"
printf "Generating default VNC Server password ... Success"

# Configure VNC server
printf "Copying stock service-def to localizable version... "
cp /lib/systemd/system/vncserver@.service \
  /etc/systemd/system/vncserver@:1.service && echo "Success" || \
    err_exit "Failed copying stock service-def to localizable version"

printf "Localizing VNC Server systemd-unit... "
sed -i "s/<USER>/${WorkstationUser}/g" \
  /etc/systemd/system/vncserver@:1.service && echo "Success" || \
    err_exit "Failed localizing VNC Server systemd-unit"

printf "Reloading systemd config-files... "
systemctl daemon-reload && echo "Success" || \
  err_exit "Failed reloading systemd config-files"

printf "Starting vncserver service... "
systemctl start vncserver@:1 && echo "Success" || \
  err_exit "Failed starting vncserver service"

printf "Enabling vncserver service... "
systemctl enable vncserver@:1 && echo "Success" || \
  err_exit "Failed to enable vncserver service... "


# Unzip the tools.tar.gz
if [ -f "${tool_home}/${tool_bundle_file}" ]
then
   printf "Dearchiving ${tool_bundle_file}... "
   tar xfz "${tool_home}/${tool_bundle_file}" -C "${tool_home}" && echo "Success"
else
   err_exit "${tool_bundle_file} is not found"
fi

# Install Anaconda
if [ -f "${tool_home}/${anaconda_dir}/${anaconda_file}" ]
then
   printf "Installing Anaconda ... "
   bash "${tool_home}/${anaconda_dir}/${anaconda_file}" -b -p \
     "${anaconda_install_dir}" && echo "Success" || \
       err_exit "Installing Anaconda failed"
else
   err_exit "${tool_home}/${anaconda_dir}/${anaconda_file} is not found"
fi

printf "Installing GNOME dt-config file for Anaconda... "
cp "${tool_home}"/anaconda/anaconda.desktop \
  /usr/share/applications/anaconda.desktop && echo "Success" || \
    err_exit "Failed installing GNOME dt-config file for Anaconda"

printf "Customizing GNOME dt-config file for Anaconda... "
sed -i "s/<USER>/${WorkstationUser}/g" \
  /usr/share/applications/anaconda.desktop && echo "Success" || \
    err_exit "Failed customizing GNOME dt-config file for Anaconda"

printf "Installing ${WorkstationUser}'s GNOME dt-config file for Anaconda... "
cp /usr/share/applications/anaconda.desktop \
  "${workstation_user_home}/.local/share/applications/anaconda.desktop" && \
    echo "Success" || \
      err_exit "Failed installing ${WorkstationUser}'s Anaconda dt-config file"

# Install ATOM
if [ -f "${tool_home}/${atom_source_dir}/${atom_file}" ]
then
   printf "Installing ATOM... "
   yum install -y "${tool_home}/${atom_source_dir}/${atom_file}" && \
     echo "Success" || err_exit "Installing ATOM failed"
else
   err_exit "${tool_home}/${atom_source_dir}/${atom_file}} is not found"
fi

#Install Eclipse NEON IDE for Java EE Developers
if [ -f "${tool_home}/${eclipse_source_dir}/${eclipse_file}" ]
then
   printf "Installing Eclipse NEON IDE ... "
   tar xfz "${tool_home}/${eclipse_source_dir}/${eclipse_file}" -C /opt/ && \
     echo "Success" || err_exit "De-archiving ${eclipse_file} failed"
else
   err_exit "${tool_home}/${eclipse_source_dir}/${eclipse_file} is not found"
fi

printf "Linking /opt/eclipse/eclipse into /usr/local/bin... "
ln -s /opt/eclipse/eclipse /usr/local/bin/eclipse && echo "Success"
  err_exit "Failed linking /opt/eclipse/eclipse into /usr/local/bin... "

printf "Installing Eclipse dt-config file for GNOME... "
cp "${tool_home}"/eclipse/eclipse.desktop \
  /usr/share/applications/eclipse.desktop && echo "Success" || \
    err_exit "Failed installing Eclipse dt-config file for GNOME... "

printf "Installing ${WorkstationUser}'s GNOME dt-config file for Eclipse... "
cp "${tool_home}"/eclipse/eclipse.desktop && \
  "${workstation_user_home}/.local/share/applications/eclipse.desktop" || \
      err_exit "Failed installing ${WorkstationUser}'s Eclipse dt-config file"

#Install Intellij
if [ -f "${tool_home}/${intellij_source_dir}/${intellij_file}" ]
then
   printf "Installing Intellij ... "
   tar xfz "${tool_home}/${intellij_source_dir}/${intellij_file}" -C /opt/ \
     && echo "Success" || err_exit "De-archiving ${intellij_file} failed"
else
   err_exit "${tool_home}/${intellij_source_dir}/${intellij_file} is not found"
fi

printf "Setting mode on %s..." "${intellij_install_dir}"
chmod -R 755 ${intellij_install_dir} && echo "Success" || \
  err_exit "Failed setting mode on ${intellij_install_dir}"

ln -s "${intellij_install_dir}/bin/idea.sh" /usr/local/bin/idea
cp "${tool_home}"/intellij/jetbrains-idea-ce.desktop /usr/share/applications/jetbrains-idea-ce.desktop
cp "${tool_home}"/intellij/jetbrains-idea-ce.desktop "${workstation_user_home}/.local/share/applications/jetbrains-idea-ce.desktop"

#Install emacs
if [[ $( yum list "emacs" > /dev/null )$? -eq 0 ]]
then
   printf "Installing emacs ... "
   yum install -y emacs && echo "Success" || err_exit "Installing emacs failed"
else
   err_exit "emacs rpm package is not found"
fi

#Install gradle
if [ -f "${tool_home}/${gradle_source_dir}/${gradle_file}" ]
then
   printf "Installing gradle ... "
   unzip -d /opt/ "${tool_home}/${gradle_source_dir}/${gradle_file}" && \
     echo "Success" || err_exit "Unziping ${gradle_file} failed"
else
   err_exit "${tool_home}/${gradle_source_dir}/${gradle_file} is not found"
fi

printf "Setting permissions on %s... " "${gradle_install_dir}"
chmod -R 755 "${gradle_install_dir}" && echo "Success" || \
  err_exit "Failed setting permissions on ${gradle_install_dir}"
  
printf "Linking %s/bin/gradle to /usr/local/bin/gradle... " "${gradle_install_dir}"
ln -s "${gradle_install_dir}/bin/gradle" /usr/local/bin/gradle
  err_exit "Failed linking ${gradle_install_dir}/bin/gradle to /usr/local/bin/gradle"

# Install maven
if [[ $( yum list "maven" > /dev/null )$? -eq 0 ]]
then
   printf "Installing maven ... "
   yum install -y maven && echo "Success" || err_exit "Install maven failed"
else
   err_exit "maven rpm package is not found"
fi

# Install git
if [[ $( yum list "git" > /dev/null )$? -eq 0 ]]
then
   printf "Installing git ... "
   yum install -y git && echo "Success" || err_exit "Installing git failed"
else
   err_exit "git package is not found"
fi

# Install git-gui
if [[ $( yum list "git-gui" > /dev/null )$? -eq 0 ]]
then
   printf "Installing git-gui ... "
   yum install -y git-gui && echo "Success" || err_exit "Installing git-gui failed"
else
   err_exit "git-gui package is not found"
fi

# Install ruby
if [[ $( yum list "ruby" > /dev/null )$? -eq 0 ]]
then
   printf "Installing ruby ... "
   yum install -y ruby && echo "Success" || err_exit "Install ruby failed"
else
   err_exit "ruby rpm package is not found"
fi

# Install node.js
if [ -f "${tool_home}/${nodejs_source_dir}/${nodejs_file}" ]
then
   printf "Installing node.js ... "
   tar -xvf  "${tool_home}/${nodejs_source_dir}/${nodejs_file}" -C /opt && \
     echo "Success" || err_exit "De-archiving ${nodejs_file} failed"
else
   err_exit "${tool_home}/${nodejs_source_dir}/${nodejs_file} is not found"
fi

printf "Setting mode on %s... " "${nodejs_install_dir}"
chmod -R 755 "${nodejs_install_dir}" && echo "Success" || \
   err_exit "Failed setting mode on ${nodejs_install_dir}"

printf "Linking ${nodejs_install_dir}/bin/node to /usr/bin/node... "
ln -s "${nodejs_install_dir}/bin/node" /usr/bin/node && echo "Success" || \
  err_exit "Failed linking ${nodejs_install_dir}/bin/node to /usr/bin/node... "

printf "Linking ${nodejs_install_dir}/bin/npm to /usr/bin/npm... "
ln -s "${nodejs_install_dir}/bin/npm" /usr/bin/npm && echo "Success" || \
  err_exit "Linking ${nodejs_install_dir}/bin/npm to /usr/bin/npm... "

# Install pycharm
if [ -f "${tool_home}/${pycharm_source_dir}/${pycharm_file}" ]
then
   printf "Installing pycharm ... "
   tar -xvf  "${tool_home}/${pycharm_source_dir}/${pycharm_file}" -C /opt && \
     echo "Success" || err_exit "De-archiving ${pycharm_file} failed"
else
   err_exit "${tool_home}/${pycharm_source_dir}/${pycharm_file} is not found"
fi

printf "Setting mode on %s... " "${pycharm_install_dir}"
chmod -R 755 "${pycharm_install_dir}" && echo "Success" || \
  err_exit "Failed setting mode on ${pycharm_install_dir}"

printf "Linking ${pycharm_install_dir}/bin/pycharm.sh to /usr/local/bin/pycharm... "
ln -s "${pycharm_install_dir}/bin/pycharm.sh" /usr/local/bin/pycharm && \
  echo "Success" || \
    err_exit "Failed linking ${pycharm_install_dir}/bin/pycharm.sh to /usr/local/bin/pycharm... "
    
cp "${tool_home}"/pycharm/pycharm.desktop /usr/share/applications/pycharm.desktop

printf "Installing ${WorkstationUser}'s GNOME dt-config file for PyCharm... "
cp "${tool_home}"/pycharm/pycharm.desktop \
  "${workstation_user_home}/.local/share/applications/pycharm.desktop" && \
    echo "Success" || \
      err_exit "Failed installing ${WorkstationUser}'s PyCharm dt-config file"

# Install asciidoctor tool chains - rubygem-asciidoctor
if [ -f "${tool_home}/${asciidoctor_source_dir}/${asciidoctor_file}" ]
then
   printf "Installing asciidoctor ... "
   yum install -y "${tool_home}/${asciidoctor_source_dir}/${asciidoctor_file}" \
     && echo "Success" || err_exit "Installing rubygem-asciidoctor failed"
else
   err_exit "${tool_home}/${asciidoctor_source_dir}/${asciidoctor_file} is not found"
fi

# Install Visual Studio Code - code
if [ -f "${tool_home}/${vscode_source_dir}/${vscode_file}" ]
then
   printf "Installing Visual Studio Code ... "
   yum install -y code "${tool_home}/${vscode_source_dir}/${vscode_file}" && \
     echo "Success" || err_exit "Install of VScode failed"       
else
   err_exit "${tool_home}/${vscode_source_dir}/${vscode_file} is not found"
fi

# Install Mongo db Client – mongodb-org-shell                                       
if [ -f "${tool_home}/${mongodb_source_dir}/${mongodb_file}" ]
then
   printf "Installing Mongo DB shell ... "
   yum install -y "${tool_home}/${mongodb_source_dir}/${mongodb_file}" && \
     echo "Success" || err_exit "Installing mongodb-org-shell failed"       
else
   err_exit "${tool_home}/${mongodb_source_dir}/${mongodb_file} is not found"
fi


## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##
## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##
## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##
## # Install MySQL Workbench - mysql-workbench-community
## # The "proj" libary is required by mysql-workbench but missing from the epel-release-7-11.
## # Therefore, remove epel-release-7-11; and install epel-release-6-8.  We will remove epel-release-6-8
## # and re-install epel-release-7-11 later
## printf "Uninstalling epel-release-7-11.noarch ... "
## yum -y remove epel-release-7-11.noarch && echo "Success" || err_exit "Uninstalling epel-release-7-11.noarch failed" 
## 
## if [ -f "${tool_home}/${mysql_source_dir}/${epel_6_8_file}" ]
## then
##    printf "Installing epel-release-6-8 rpm ... "
##    yum install -y "${tool_home}/${mysql_source_dir}/${epel_6_8_file}" && echo "Success" || err_exit "Installing ${epel_6_8_file} failed"
## else
##    err_exit "${tool_home}/${mysql_source_dir}/${epel_6_8_file} is not found"
## fi
## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##
## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##
## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##

printf "Installing proj ... "
yum install -y proj && echo "Success" || err_exit "Installing proj failed"

if [ -f "${tool_home}/${mysql_source_dir}/${mysql_file}" ]
then
   printf "Installing mysql workbench ... "
   yum install -y "${tool_home}/${mysql_source_dir}/${mysql_file}" && \
     echo "Success" || err_exit "Installing mysql-workbench failed"
else
   err_exit "${tool_home}/${mysql_source_dir}/${mysql_file} is not found"
fi

## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##
## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##
## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##
## printf "Installing epel-release-7-11.noarch ... "
## yum install -y epel-release-7-11.noarch && echo "Success" || err_exit "Installing epel-release-7-11.noarch failed"
## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##
## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##
## *NO*: NEVER INSTALL RPMS FROM A DIFFERENT ENTERPRISE LINUX RELEASE. *EVER* ##

# Install Joomla  (Need LAMP stack which includes Apache (2.x+), PHP (5.3.10+)  and MySQL / MariaDB (5.1+)) 
printf "Installing httpd ... "
yum install -y httpd && echo "Success" || err_exit "Installing httpd failed"  

printf "Starting httpd service... "
systemctl start httpd && echo "Success" || \
  err_exit "Failed starting httpd service"

printf "Enabling httpd service... "
systemctl enable httpd && echo "Success" || \
  err_exit "Failed enabling httpd service"

printf "Installing php php-mysql php-pdo php-gd php-mbstring ... "
yum install -y php php-mysql php-pdo php-gd php-mbstring && echo "Success" || \
  err_exit "Installing php, php-mysql, php-pdo, php-gd, or php-mbstring failed"

if [ -f "${tool_home}/${joomla_source_dir}/${joomla_file}" ]
then
   printf "Installing Joomla ... "
   tar -xvf "${tool_home}/${joomla_source_dir}/${joomla_file}" \
     -C /var/www/html && echo "Success" || \
       err_exit "De-archiving ${joomla_file} failed"
else
   err_exit "${tool_home}/${joomla_source_dir}/${joomla_file} is not found"
fi

chown -R apache:apache /var/www/html/
chmod -R 775 /var/www/html/
systemctl restart httpd


# Install Qt Assistant first and creator second.  Don't change the order because of package dependence.
printf "Installing qt-creator ... "
yum install -y qt-creator && echo "Success" || err_exit "Installing qt-creator failed"
printf "Installing qt-assistant... "
yum install -y qt-assistant && echo "Success" || err_exit "Installing qt-assistant failed"

# Change ownership and permission for files in user home
chown -R ${WorkstationUser}:${WorkstationUser} ${workstation_user_home}
chmod -R 700 "${workstation_user_home}/.local/share/applications"

# Add firewall rules
setenforce 0
# for VNC server
firewall-cmd --add-service=vnc-server
firewall-cmd --add-service=vnc-server --permanent
# for Joomla
#firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
setenforce 1
printf "Setting firewall rules ... Success"

# Remove rpm files
printf "Removing tools.tar.gz ... "
rm /etc/cfn/ws-tools.envs
rm "${tool_home}"/tools.tar.gz && echo "Success" || err_exit "Deleting tools bundle failed"
