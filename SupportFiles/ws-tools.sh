#!/bin/bash
#
# Script to install various of developer applications/tools on a 
# a STIG-harened, Enterprise Linux 7 "workstation"
#
#################################################################
# shellcheck disable=SC2086
# shellcheck disable=SC2015
PROGNAME="$(basename ${0})"

# Pull settings from env-file
# shellcheck disable=SC2163
while read -r WSENV
do
   export "${WSENV}"
done < /etc/cfn/ws-tools.envs
WorkstationUser="${WORKSTATION_USER_NAME:-UNDEF}"
VNCServerPasswd="${VNC_SEREVER_PASSWD:-UNDEF}"

# Setting up varilables
workstation_user_home="/home/${WorkstationUser}"
tool_home="/etc/cfn/tools"
tool_bundle_file="tools.tar.gz"

anaconda_dir="anaconda"
anaconda_file="anaconda.sh"
anaconda_install_dir="${workstation_user_home}/anaconda3"

atom_source_dir="atom"
atom_file="atom.x86_64.rpm"

eclipse_source_dir="eclipse"
eclipse_file="eclipse-jee-neon-3-linux-gtk-x86_64.tar.gz"

intellij_source_dir="intellij"
intellij_file="ideaIC-2018.3.3.tar.gz"
intellij_install_dir="/opt/idea-IC-183.5153.38"

gradle_source_dir="gradle"
gradle_file="gradle-5.1.1-bin.zip"
gradle_install_dir="/opt/gradle-5.1.1"

git_source_dir="git"
git_file="endpoint-repo-1.7-1.x86_64.rpm"

nodejs_source_dir="nodejs"
nodejs_file="node-v11.6.0-linux-x64.tar.xz"
nodejs_install_dir="/opt/node-v11.6.0-linux-x64"

pycharm_source_dir="pycharm"
pycharm_file="pycharm-community-2018.3.3.tar.gz"
pycharm_install_dir="/opt/pycharm-community-2018.3.3"

asciidoctor_source_dir="asciidoctor"
asciidoctor_file="rubygem-asciidoctor-1.5.6.1-1.el7.noarch.rpm"

vscode_source_dir="vscode"
vscode_file="code-1.30.2-1546901769.el7.x86_64.rpm"

mongodb_source_dir="mongo"
mongodb_file="mongodb-org-shell-4.0.5-1.el7.x86_64.rpm"

mysql_source_dir="mysql"
mysql_file="mysql80-community-release-el7-1.noarch.rpm"
epel_6_8_file="epel-release-6-8.noarch.rpm"
epel_7_11_file="epel-release-7-11.noarch.rpm"

joomla_source_dir="joomla"
joomla_file="Joomla_3.9.2-Stable-Full_Package.tar.gz"

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


# Install GNOME
printf 'Installing GNOME ... '
yum -y groups install 'GNOME Desktop' && echo 'Success' || err_exit "Installing GNOME Desktop failed"
systemctl set-default graphical.target

# Install VNC server
printf 'Installing Tiger VNC Server ... '
yum -y install tigervnc-server || err_exit "Failed to install TigerVNC Server."

# Generate default VNC server password
# The "VNCServerPaswd" will be replaced with the VNCServerPasswd parameter and "WorkstationUser" with the WorkstationUser parameter in the CFN during runtime
install -Dm 000700 -o ${WorkstationUser} -g ${WorkstationUser} -d "${workstation_user_home}/.vnc"
install -Dm 000700 -o ${WorkstationUser} -g ${WorkstationUser} -b <( vncpasswd -f <<<${VNCServerPasswd} ) "${workstation_user_home}/.vnc/passwd"
printf 'Generating default VNC Server password ... Success'

# Configure VNC server
cp /lib/systemd/system/vncserver@.service  /etc/systemd/system/vncserver@:1.service
sed -i "s/<USER>/${WorkstationUser}/g" /etc/systemd/system/vncserver@:1.service
systemctl daemon-reload
systemctl start vncserver@:1
systemctl enable vncserver@:1
printf 'Configuring VNC Server ... Success'

# Unzip the tools.tar.gz
if [ -f "${tool_home}/${tool_bundle_file}" ]
then
	printf 'Dearchiving tools.tar.gz ... '
	sudo tar xfz "${tool_home}/${tool_bundle_file}" -C /etc/cfn/tools && echo 'Success'
#elif [ gunzip -c test.txt "${tool_home}/${tool_bundle_file}" | tar t > /dev/null ] 
#	err_exit "${tool_bundle_file} is not a compressed file"
else
	err_exit "${tool_bundle_file} is not found"
fi

# Install Anaconda
if [ -f "${tool_home}/${anaconda_dir}/${anaconda_file}" ]
then
	printf 'Installing Anaconda ... '
	bash "${tool_home}/${anaconda_dir}/${anaconda_file}" -b -p ${anaconda_install_dir} && echo 'Success' || err_exit "Installing Anaconda failed"
else
	err_exit "${tool_home}/${anaconda_dir}/${anaconda_file} is not found"
fi

cp /etc/cfn/tools/anaconda/anaconda.desktop /usr/share/applications/anaconda.desktop
cp /etc/cfn/tools/anaconda/anaconda.desktop "${workstation_user_home}/.local/share/applications/anaconda.desktop"

# Install ATOM
printf 'Installing ATOM ... '
yum -y install "${tool_home}/${atom_source_dir}/${atom_file}" && echo 'Success' || err_exit "Installing ATOM failed"

#Install Eclipse NEON IDE for Java EE Developers
if [ -f "${tool_home}/${eclipse_source_dir}/${eclipse_file}" ]
then
	printf 'Installing Eclipse NEON IDE ... '
	tar xfz "${tool_home}/${eclipse_source_dir}/${eclipse_file}" -C /opt/ && echo 'Success' || err_exit "De-archiving ${eclipse_file} failed"
else
	err_exit "${tool_home}/${eclipse_source_dir}/${eclipse_file} is not found"
fi

ln -s /opt/eclipse/eclipse /usr/local/bin/eclipse
cp /etc/cfn/tools/eclipse/eclipse.desktop /usr/share/applications/eclipse.desktop
cp /etc/cfn/tools/eclipse/eclipse.desktop "${workstation_user_home}/.local/share/applications/eclipse.desktop"

#Install Intellij
if [ -f "${tool_home}/${intellij_source_dir}/${intellij_file}" ]
then
	printf 'Installing Intellij ... '
	tar xfz "${tool_home}/${intellij_source_dir}/${intellij_file}" -C /opt/ && echo 'Success' || err_exit "De-archiving ${intellij_file} failed"
else
	err_exit "${tool_home}/${intellij_source_dir}/${intellij_file} is not found"
fi

chmod -R 755 ${intellij_install_dir}
ln -s "${intellij_install_dir}/bin/idea.sh" /usr/local/bin/idea
cp /etc/cfn/tools/intellij/jetbrains-idea-ce.desktop /usr/share/applications/jetbrains-idea-ce.desktop
cp /etc/cfn/tools/intellij/jetbrains-idea-ce.desktop "${workstation_user_home}/.local/share/applications/jetbrains-idea-ce.desktop"

#Install emacs
printf 'Installing emacs ... '
yum -y install emacs && echo 'Success' || err_exit "Installing emacs failed"

#Install gradle
if [ -f "${tool_home}/${gradle_source_dir}/${gradle_file}" ]
then
	printf 'Installing gradle ... '
	unzip -d /opt/ "${tool_home}/${gradle_source_dir}/${gradle_file}" && echo 'Success' || err_exit "Unziping ${gradle_file} failed"
else
	err_exit "${tool_home}/${gradle_source_dir}/${gradle_file} is not found"
fi

chmod -R 755 ${gradle_install_dir}
ln -s "${gradle_install_dir}/bin/gradle" /usr/local/bin/gradle

# Install maven
printf 'Installing maven ... '
yum -y install maven && echo 'Success' || err_exit "Install maven failed"

# Install git
if [ -f "${tool_home}/${git_source_dir}/${git_file}" ]
then
	printf 'Installing git rpm ... '
	rpm -Uvh "${tool_home}/${git_source_dir}/${git_file}" && echo 'Success' || err_exit "Installing ${git_file} failed"
else
	err_exit "${tool_home}/${git_source_dir}/${git_file} is not found"
fi

printf 'Installing git ... '
yum -y install git && echo 'Success' || err_exit "Installing git failed"
printf 'Installing git-gui ... '
yum -y install git-gui && echo 'Success' || err_exit "Installing git-gui failed"

# Install ruby
printf 'Installing ruby ... '
yum -y install ruby && echo 'Success' || err_exit "Install ruby failed"

# Install node.js
if [ -f "${tool_home}/${nodejs_source_dir}/${nodejs_file}" ]
then
	printf 'Installing node.js ... '
	tar -xvf  "${tool_home}/${nodejs_source_dir}/${nodejs_file}" -C /opt && echo 'Success' || err_exit "De-archiving ${nodejs_file} failed"
else
	err_exit "${tool_home}/${nodejs_source_dir}/${nodejs_file} is not found"
fi

chmod -R 755 ${nodejs_install_dir}
ln -s "${nodejs_install_dir}/bin/node" /usr/bin/node
ln -s "${nodejs_install_dir}/bin/npm" /usr/bin/npm

# Install pycharm
if [ -f "${tool_home}/${pycharm_source_dir}/${pycharm_file}" ]
then
	printf 'Installing pycharm ... '
	tar -xvf  "${tool_home}/${pycharm_source_dir}/${pycharm_file}" -C /opt && echo 'Success' || err_exit "De-archiving ${pycharm_file} failed"
else
	err_exit "${tool_home}/${pycharm_source_dir}/${pycharm_file} is not found"
fi

chmod -R 755 ${pycharm_install_dir}
ln -s "${pycharm_install_dir}/bin/pycharm.sh" /usr/local/bin/pycharm 
cp /etc/cfn/tools/pycharm/pycharm.desktop /usr/share/applications/pycharm.desktop
cp /etc/cfn/tools/pycharm/pycharm.desktop "${workstation_user_home}/.local/share/applications/pycharm.desktop"

# Install asciidoctor tool chains 
if [ -f "${tool_home}/${asciidoctor_source_dir}/${asciidoctor_file}" ]
then
	printf 'Installing asciidoctor rpm ... '
	rpm -Uvh "${tool_home}/${asciidoctor_source_dir}/${asciidoctor_file}" && echo 'Success' || err_exit "Installing ${asciidoctor_file} failed"
else
	err_exit "${tool_home}/${asciidoctor_source_dir}/${asciidoctor_file} is not found"
fi

printf 'Installing asciidoctor ... '
yum -y install rubygem-asciidoctor && echo 'Success' || err_exit "Installing rubygem-asciidoctor failed"

# Install Visual Studio Code
if [ -f "${tool_home}/${vscode_source_dir}/${vscode_file}" ]
then
	printf 'Installing Visual Studio Code rpm ... '
	rpm -Uvh "${tool_home}/${vscode_source_dir}/${vscode_file}" && echo 'Success' || err_exit "Installing ${vscode_file} failed"
else
	err_exit "${tool_home}/${vscode_source_dir}/${vscode_file} is not found"
fi

printf 'Installing Visual Studio Code ... '
yum -y install code && echo 'Success' || err_exit "Install code failed"       

# Install Mongo db Client – Mongo Shell                                          
if [ -f "${tool_home}/${mongodb_source_dir}/${mongodb_file}" ]
then
	printf 'Installing Mongo DB shell rpm ... '
	rpm -Uvh "${tool_home}/${mongodb_source_dir}/${mongodb_file}" && echo 'Success' || err_exit "Installing ${mongodb_file} failed"
else
	err_exit "${tool_home}/${mongodb_source_dir}/${mongodb_file} is not found"
fi

printf 'Installing Mongo DB shell ... '
yum install -y mongodb-org-shell && echo 'Success' || err_exit "Installing mongodb-org-shell failed"       

# Install MySQL Workbench
# The "proj" libary is required by mysql-workbench but missing from the epel-release-7-11.
# Therefore, remove epel-release-7-11; and install epel-release-6-8.  We will remove epel-release-6-8
# and re-install epel-release-7-11 later
rpm -e epel-release-7-11.noarch

if [ -f "${tool_home}/${mysql_source_dir}/${epel_6_8_file}" ]
then
	printf 'Installing epel-release-6-8 rpm ... '
	rpm -Uvh "${tool_home}/${mysql_source_dir}/${epel_6_8_file}" && echo 'Success' || err_exit "Installing ${epel_6_8_file} failed"
else
	err_exit "${tool_home}/${mysql_source_dir}/${epel_6_8_file} is not found"
fi

printf 'Installing proj ... '
yum -y install proj && echo 'Success' || err_exit "Installing proj failed"

if [ -f "${tool_home}/${mysql_source_dir}/${mysql_file}" ]
then
	printf 'Installing mysql rpm ... '
	rpm -Uvh "${tool_home}/${mysql_source_dir}/${mysql_file}" && echo 'Success' || err_exit "Installing ${mysql_file} failed"
else
	err_exit "${tool_home}/${mysql_source_dir}/${mysql_file} is not found"
fi

printf 'Installing mysql workbench ... '
yum -y install mysql-workbench-community && echo 'Success' || err_exit "Installing mysql-workbench failed"

if [ -f "${tool_home}/${mysql_source_dir}/${epel_7_11_file}" ]
then
	printf 'Installing epel-release-7-11 rpm ... '
	rpm -Uvh "${tool_home}/${mysql_source_dir}/${epel_7_11_file}" && echo 'Success' || err_exit "Installing ${epel_7_11_file} failed"
else
	err_exit "${tool_home}/${mysql_source_dir}/${epel_7_11_file} is not found"
fi

# Install Joomla  (Need LAMP stack which includes Apache (2.x+), PHP (5.3.10+)  and MySQL / MariaDB (5.1+)) 
printf 'Installing httpd ... '
yum -y install httpd && echo 'Success' || err_exit "Installing httpd failed"  
systemctl start httpd
systemctl enable httpd

printf 'Installing php php-mysql php-pdo php-gd php-mbstring ... '
yum -y install php php-mysql php-pdo php-gd php-mbstring && echo 'Success' || err_exit "Installing php, php-mysql, php-pdo, php-gd, or php-mbstring failed"

if [ -f "${tool_home}/${joomla_source_dir}/${joomla_file}" ]
then
	printf 'Installing Joomla ... '
	tar -xvf "${tool_home}/${joomla_source_dir}/${joomla_file}" -C /var/www/html && echo 'Success' || err_exit "De-archiving ${joomla_file} failed"
else
	err_exit "${tool_home}/${joomla_source_dir}/${joomla_file} is not found"
fi

chown -R apache:apache /var/www/html/
chmod -R 775 /var/www/html/
systemctl restart httpd


# Install Qt Assistant first and creator second.  Don't change the order because of package dependence.
printf 'Installing qt-creator ... '
yum -y install qt-creator && echo 'Success' || err_exit "Installing qt-creator failed"
printf 'Installing qt-assistant... '
yum -y install qt-assistant && echo 'Success' || err_exit "Installing qt-assistant failed"

# Change ownership and permission for files in user home
chown -R ${WorkstationUser}:${WorkstationUser} ${workstation_user_home}
chmod -R 700 "${workstation_user_home}/.local/share/applications"

# Add firewall rules
setenforce 0

# for VNC server
firewall-cmd --add-port=5901/tcp
firewall-cmd --add-port=5901/tcp --permanent

# for Joomla
#firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

setenforce 1
printf 'Setting firewall rules ... Success'

# Remove rpm files
printf 'Removing tools.tar.gz ... '
rm /etc/cfn/ws-tools.envs
rm /etc/cfn/tools/tools.tar.gz && echo 'Success' || err_exit "Deleting tools bundle failed"
