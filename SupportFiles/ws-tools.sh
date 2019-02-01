#!/bin/bash

# The "StackName" will be replaced with the AWS::StackName during runtime
function err_exit {
	echo "${1}"
	logger -p kern.crit -t ws-tools.sh "${1}"
	/opt/aws/bin/cfn-signal -e 1 --stack StackName --resource Ec2instance
	exit 1
}

# Install GNOME
yum -y groups install 'GNOME Desktop' || err_exit "Failed to install GNOME Desktop."
systemctl set-default graphical.target

# Install VNC server
yum -y install tigervnc-server || err_exit "Failed to install TigerVNC Server."

# Generate default VNC server password
# The "VNCServerPaswd" will be replaced with the VNCServerPasswd parameter and "WorkstationUser" with the WorkstationUser parameter in the CFN during runtime
umask 0077
mkdir -p /home/WorkstationUser/.vnc
chmod go-rwx /home/WorkstationUser/.vnc
vncpasswd -f <<<VNCServerPasswd> /home/WorkstationUser/.vnc/passwd
chown -R WorkstationUser:WorkstationUser /home/WorkstationUser/.vnc

# Configure VNC server
cp /lib/systemd/system/vncserver@.service  /etc/systemd/system/vncserver@:1.service
sed -i 's/<USER>/WorkstationUser/g' /etc/systemd/system/vncserver@:1.service
systemctl daemon-reload
systemctl start vncserver@:1
systemctl enable vncserver@:1

# Add firewall VNC server firewall rules
setenforce 0
firewall-cmd --add-port=5901/tcp
firewall-cmd --add-port=5901/tcp --permanent
setenforce 1

# Unzip the tools.tar.gz
tar xfz /etc/cfn/tools/tools.tar.gz -C /etc/cfn/tools || err_exit "Failed to unzip tools.tar.gz"

# Install Anaconda
bash /etc/cfn/tools/anaconda/anaconda.sh -b -p /home/WorkstationUser/anaconda3
chown -R WorkstationUser:WorkstationUser /home/WorkstationUser/anaconda3

cp /etc/cfn/tools/anaconda/anaconda.desktop /usr/share/applications/anaconda.desktop
cp /etc/cfn/tools/anaconda/anaconda.desktop /home/WorkstationUser/.local/share/applications/anaconda.desktop
chown WorkstationUser:WorkstationUser /home/WorkstationUser/.local/share/applications/anaconda.desktop
chmod 600 /home/WorkstationUser/.local/share/applications/anaconda.desktop

# Install ATOM
# Launch it from your terminal by running the command "atom"
yum -y install /etc/cfn/tools/atom/atom.x86_64.rpm || err_exit "Failed to install ATOM"

#Install Eclipse NEON IDE for Java EE Developers
tar xfz /etc/cfn/tools/eclipse/eclipse-jee-neon-3-linux-gtk-x86_64.tar.gz -C /opt/ || err_exit "Failed to unzip eclipse-jee-neon-3-linux-gtk-x86_64.tar.gz"
ln -s /opt/eclipse/eclipse /usr/local/bin/eclipse

cp /etc/cfn/tools/eclipse/eclipse.desktop /usr/share/applications/eclipse.desktop
cp /etc/cfn/tools/eclipse/eclipse.desktop /home/WorkstationUser/.local/share/applications/eclipse.desktop
chown WorkstationUser:WorkstationUser /home/WorkstationUser/.local/share/applications/eclipse.desktop
chmod 600 /home/WorkstationUser/.local/share/applications/eclipse.desktop

#Install Intellij
tar xfz /etc/cfn/tools/intellij/ideaIC-2018.3.3.tar.gz -C /opt/ || err_exit "Failed to unzip ideaIC-2018.3.3.tar.gz"
chmod -R 755 /opt/idea-IC-183.5153.38
ln -s /opt/idea-IC-183.5153.38/bin/idea.sh /usr/local/bin/idea

cp /etc/cfn/tools/intellij/jetbrains-idea-ce.desktop /usr/share/applications/jetbrains-idea-ce.desktop
cp /etc/cfn/tools/intellij/jetbrains-idea-ce.desktop /home/WorkstationUser/.local/share/applications/jetbrains-idea-ce.desktop
chown WorkstationUser:WorkstationUser /home/WorkstationUser/.local/share/applications/jetbrains-idea-ce.desktop
chmod 600 /home/WorkstationUser/.local/share/applications/jetbrains-idea-ce.desktop

#Install emacs
yum -y install emacs || err_exit "Failed to install emacs"

#Install Gradle
unzip -d /opt/ /etc/cfn/tools/gradle/gradle-5.1.1-bin.zip
chmod -R 755 /opt/gradle-5.1.1
ln -s /opt/gradle-5.1.1/bin/gradle /usr/local/bin/gradle

# Install Maven
yum -y install maven || err_exit "Failed to install maven"

# Install git
rpm -Uvh /etc/cfn/tools/git/endpoint-repo-1.7-1.x86_64.rpm
yum -y install git  || err_exit "Failed to install git"
yum -y install git-gui || err_exit "Failed to install git-gui"

# Install ruby
yum -y install ruby || err_exit "Failed to install ruby"

# Install node.js
tar -xvf  /etc/cfn/tools/nodejs/node-v11.6.0-linux-x64.tar.xz -C /opt
chmod -R 755 /opt/node-v11.6.0-linux-x64
ln -s /opt/node-v11.6.0-linux-x64/bin/node /usr/bin/node
ln -s /opt/node-v11.6.0-linux-x64/bin/npm /usr/bin/npm

# Install pycharm
tar -xvf  /etc/cfn/tools/pycharm/pycharm-community-2018.3.3.tar.gz -C /opt
chmod -R 755 /opt/pycharm-community-2018.3.3
ln -s /opt/pycharm-community-2018.3.3/bin/pycharm.sh /usr/local/bin/pycharm 

cp /etc/cfn/tools/pycharm/pycharm.desktop /usr/share/applications/pycharm.desktop
cp /etc/cfn/tools/pycharm/pycharm.desktop /home/WorkstationUser/.local/share/applications/pycharm.desktop
chown WorkstationUser:WorkstationUser /home/WorkstationUser/.local/share/applications/pycharm.desktop
chmod 600 /home/WorkstationUser/.local/share/applications/pycharm.desktop     

# Install asciidoctor tool chains 
rpm -Uvh /etc/cfn/tools/asciidoctor/rubygem-asciidoctor-1.5.6.1-1.el7.noarch.rpm  
yum -y install rubygem-asciidoctor || err_exit "Failed to install rubygem-asciidoctor"

# Install Visual Studio Code
rpm -Uvh /etc/cfn/tools/vscode/code-1.30.2-1546901769.el7.x86_64.rpm  
yum -y install code || err_exit "Failed to install code"       

# Install Mongo db Client – Mongo Shell                                          
rpm -Uvh /etc/cfn/tools/mongo/mongodb-org-shell-4.0.5-1.el7.x86_64.rpm  
sudo yum install -y mongodb-org-shell || err_exit "Failed to install mongodb-org-shell"       

# Install MySQL and MySQL Workbench
# The "proj" libary is required by mysql-workbench but missing from the epel-release-7-11.
# Therefore, remove epel-release-7-11; and install epel-release-6-8.  We will remove epel-release-6-8
# and re-install epel-release-7-11 later
rpm -e epel-release-7-11.noarch
rpm -Uvh /etc/cfn/tools/mysql/epel-release-6-8.noarch.rpm
yum -y install proj

rpm -Uvh /etc/cfn/tools/mysql/mysql80-community-release-el7-1.noarch.rpm 
yum -y install mysql-server || err_exit "Failed to install mysql-server"
yum -y install mysql-workbench-community || err_exit "Failed to install mysql-workbench"

rpm -Uvh /etc/cfn/tools/mysql/epel-release-7-11.noarch.rpm

systemctl start mysqld
systemctl enable mysqld


# Install Joomla  (Need LAMP stack which includes Apache (2.x+), PHP (5.3.10+)  and MySQL / MariaDB (5.1+)) 
yum -y install httpd || err_exit "Failed to install httpd"  
systemctl start httpd
systemctl enable httpd

yum -y install php php-mysql php-pdo php-gd php-mbstring
tar -xvf /etc/cfn/tools/joomla/Joomla_3.9.2-Stable-Full_Package.tar.gz -C /var/www/html
chown -R apache:apache /var/www/html/
chmod -R 775 /var/www/html/
systemctl restart httpd

setenforce 0
#firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
setenforce 1

# Install Qt Assistant and creator
yum -y install qt-creator || err_exit "Failed to install qt-creator"
yum -y install qt-assistant || err_exit "Failed to install qt-assistant"


# (TODO) Remove rpm files