# Linux Workstation

## Purpose

This project has been undertaken to provide a "developer desktop" experience that is uniform across all users' deployment-environments. The end state is to provide an automated mechanism for provisioning a STIG-harened, Enterprise Linux 7 "workstation" hostable within arbitrary AWS regions.

## Backround

The initial expectation was to utilize [AWS Workspaces](https://aws.amazon.com/about-aws/whats-new/2018/06/aws-introduces-amazon-linux-workspaces/) as a foundation. However, due to the following challenges, use of AWS Workspaces has proven to not be a feasible foundation for the common developer desktop:

* Linux Workspaces service only allows the use of custom images created from a **AWS standard workspaces** image. We have to go through the steps of launching a standard Workspace, customizing/harden it and creating a bundle out of that workspace.
* Amazon does not support web access for Linux Workspaces currently. Requiring a [Workspace Client](https://clients.amazonworkspaces.com) installation in order to access a Linux Workspace is not possible on high side environment.

Due to the above issues/limitations, the [SPEL AMI](https://github.com/plus3it/spel/blob/develop/README.md) was selected as the foundation for further work. Note that SPEL was chosen because it is identically available in all of the environments that the AWS Workspaces distribution would have been.

## Current Status

At the time of this document's writing, a prototype of Linux Workstation has been created. Note that the current state is sufficiently nascent as to be neither a release candidate nor a "developer preview" or "beta" release. The current prototype makes use of the following tooling and resources:

* EC2 AMI: [spel-minimal-centos-7-hvm](https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Images:visibility=public-images;ownerAlias=701759196663;name=spel-minimal-centos-7-hvm-.*x86_64-gp2;sort=desc:creationDate) (tested with [December 2018](https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Images:visibility=public-images;ownerAlias=701759196663;name=spel-minimal-centos-7-hvm-2018.12.*x86_64-gp2;sort=desc:creationDate) version)
* CloudFormation template: [`make_workspace_linux_EC2.tmplt.json`](Templates/make_workspace_linux_EC2.tmplt.json)
* Cloud-Init script:  [`ws-tools.sh`](SupportFiles/ws-tools.sh)
* Jenkins pipeline job: [EC2-Instance.groovy](Deployment/EC2-Instance.groovy) script
* Tools bundle

The remaining sections of this document will cover the details and instructions for using the prototype.

## EC2 AMI

The spel AMI is the STIG-partioned and FIPS-enabled AWS AMI image approved by primary customer for use in all supported AWS regions.

## CloudFormation

The `make_workspace_linux_EC2.tmplt.json` performes the primary orchestration  that creates the pre-configured EC2 instance. This orchestration:
* Launches an EC2 instance
* Pre-stages the configuration-scripts and tools bundle from S3 onto the instance
* Invokes the pre-staged configuration-script that installs the below-listed software

## Cloud-Init script

The `ws-tools.sh` installs the following applications/tools.  It references the latest-available versions of software at instance-launch:

* [Watchmaker](https://watchmaker.readthedocs.io/) standalone configuration-management tool
* [GNOME desktop](https://www.gnome.org/) graphical desktop environment
* Tiger [VNC Server](https://tigervnc.org/)
* [Firefox](https://www.mozilla.org/en-US/firefox/) Web Browser
* [Anaconda](https://www.anaconda.com) data science tool-set
* [ATOM](https://ide.atom.io/) integrated development environment
* [Eclipse](https://www.eclipse.org) integrated development environment for Java
* [IntelliJ](https://www.jetbrains.com/idea/) integrated development environment for Java
* [Emacs](https://www.gnu.org/s/emacs/) text editor
* [Gradle](https://gradle.org/) Java build tool
* [Maven](https://maven.apache.org/) Java build tool
* [Git](https://git-scm.com/) version control client
* [Ruby](https://www.ruby-lang.org/) programming language
* [Node.JS](https://nodejs.org/) JavaScript runtime engine
* [Pycharm](https://www.jetbrains.com/pycharm/) integrated development environment for Python
* [Asciidoctor](https://asciidoctor.org/) document-convertion tool chains 
* [Visual Studio Code](https://code.visualstudio.com/docs/setup/linux) integrated development environment
* [Mongo db Client/Mongo Shell](https://docs.mongodb.com/manual/mongo/) interactive JavaScript interface to MongoDB
* [MySQL/MySQL Workbench](https://www.mysql.com/products/workbench/) clients for working with MySQL databases
* [Joomla](https://www.joomla.org/) content management system tools
* [Qt Assistant and creator](https://www.qt.io/) integrated development environment for embedded tools

## Tools Bundle

### Contents

The `tools.tar.gz` contains the below-listed folders.  Inside each folder is: a binary file, shell script, and/or config file. The tool-bundle needs to be pre-staged to S3 before other desktop-provisioning activities:

* anaconda: anaconda.desktop, anaconda.sh
* asciidoctor: demo.adoc, readme, rubygem-asciidoctor-1.5.6.1-1.el7.noarch.rpm 
* atom: atom.x86_64.rpm
* git: endpoint-repo-1.7-1.x86_64.rpm
* gradle: gradle-5.1.1-bin.zip, gradle.sh
* intellij: ideaIC-2018.3.3.tar.gz, jetbrains-idea-ce.desktop
* Joomla: Joomla_3.9.2-Stable-Full_Package.tar.gz
* mongo: mongodb-org-shell-4.0.5-1.el7.x86_64.rpm
* mysql: epel-release-6-8.noarch.rpm, epel-release-7-11.noarch.rpm, mysql-workbench-community-8.0.13-1.el7.x86_64.rpm
* nodejs: node-v11.6.0-linux-x64.tar.xz
* pycharm: pycharm-community-2018.3.3.tar.gz, pycharm.desktop
* vscode: code-1.30.2-1546901769.el7.x86_64.rpm

### Creating the Bundle

To build a tools.tar.gz:

~~~
$ cd <source home>
[ download all source-archives and RPMs]
$ tar zcvf tools.tar.gz .
~~~

### Staging the Bundle

To stage the tools.tar.gz to S3:
~~~
$ aws s3 cp tools.tar.gz s3://<bucket and folder>/tools.tar.gz
$ aws s3api put-object-acl --bucket <bucket name> --key <folder name>/tools.tar.gz --grant-read uri=http://acs.amazonaws.com/groups/global/AllUsers
~~~

## Jenkins Job

A Jenkins pipeline job is created with the following parameters:

* `AwsRegion`:  Amazon region to deploy resources info
* `AwsCred`: Jenkins-stored AWS credential with which to execute cloud-layer commands
* `GitCred`: Jenkins-stored Git credential with which to execute Git commands
* `GitProjUrl`: SSH URL from which to download the Jenkins Git projet
* `GitProjBranch`: Project-branch to use from the Jenkins git project
* `CfnStackRoot`: Unique token to prepend to all stack-element names
* `TemplateUrl`: S3-hosted URL for the EC2 CloudFormation template file
* `AdminPubkeyURL`: S3-hosted URL for file containing admin-group SSH key-bundle
* `AmiId`:  ID of the AMI to launch
* `CfnEndpointUrl`: URL to the CloudFormation Endpoint. Default: https://cloudformation.us-east-1.amazonaws.com
* `EpelRepo`: Name of network-available EPEL repo.  Default: epel
* `InstallToolScriptURL`: S3-hosted URL for the scripts (e.g., ws-tools.sh) that executes commands to install various dev tools
* `WorkstationUserName`: User name of the workstation owner
* `WorkstationUserPasswd`: Default password of the workstation owner. 
* `InstanceRole`: IAM instance role to apply to the instance
* `InstanceType`: Amazon EC2 instance type
* `KeyPairName`: Public/private key pair used to allow an operator to securely connect to instance immediately after the instance-SSHD comes online
* `NoPublicIp`: Controls whether to assign the instance a public IP. Recommended to leave at 'true' _unless_ launching in a public subnet. Default: true
* `NoReboot`: Controls whether to reboot the instance as the last step of cfn-init execution. Default: false
* `RipRpm`: Name of preferred pip RPM. Default: python2-pip
* `PrivateIp`: (Optional) Set a static, primary private IP. Leave blank to auto-select a free IP
* `ProvisionUserName`: Name for remote-administration account
* `PyStache`: Name of preferred pystache RPM. Default: pystache
* `RootVolumeSize`: Size in GB of the EBS volume to create. If smaller than AMI default, create operation will fail; If larger, partition containing root * device-volumes will be upsized. Recommend: 50
* `SecurityGroupIds`: List of security groups to apply to the instance
* `SubnetId`: ID of the subnet to assign to the instance
* `ToolsURL`: S3-hosted URL for the gzip/tar file which contains all of the dev tools binaries
* `VNCServerPasswd`: Default VNC server password. (Specific to VNC's requirement) Password must contain at least one letter, at least one number, and be *longer than six characters.
* `WatchmakerConfig`: (Optional) Path to a Watchmaker config file.  The config file path can be a remote source (i.e. http[s]://, s3://) or local directory (i.e. file://)
* `WatchmakerEnvironment`: Environment in which the instance is being deployed. Default: dev
* `SSHKey`:  Provision User's SSH Key

Set Pipeline Definition: Fill in the following fields
* SCM: Git
* Repository URL  
* Credential (pre-configured within Jenkins project's scope)
	
Set Pipeline Script Path: Fill in `Deployment/EC2-Instance.groovy`
	
## Instruction on buidling and using the Linux workstation

Prerequisites:
1. Create the following three credentials in Jenkins:
    1. AwsCred: Jenkins-stored AWS credential with which to execute cloud-layer commands
    1. GitCred: Jenkins-stored Git credential (user name and password) with which to execute Git commands
    1. SSHKey:  SSH user name and private key	
1. The SSH public key is added to the file, specified in the AdminPubkeyURL parameter
1. An Jenkins job is created and pre-configured as per the instruction above.
1. The CloudFormation template, Cloud-init script, and tool bundles are uploaded to S3. The S3 URLS will be specified in the Jenkins TemplateUrl, InstallToolScriptURL, and ToolsURL parameters
1. An AWS EC2 instance profile/role with correct permissions have been creasted.  It will be used in the Jenkins InstanceRole parameter.
1. An AWS Security Group(s) have been created. It will be specified in the Jenkins SecurityGroupIds parameter

Steps:
1. Build the Jenkins job with parameters (see the list of parameters above). Based on the current CloudFormation template, it takes around 25 minutes to complete.  The template timeout is set to 45 minutes.
1. Once the EC2 is created successfully, connect to rdsh.dicelab.net. 
1. Start pageant, and add your SSH private key
1. Use putty or MobaXterm to connect to the EC2 using the account name, specified in the ProvisionUserName parameter
    * On MobaXTerm, create a SSH session:
        1. Click Session -> SSH -> Enter Remote Host with the EC2 private IP adress
        1. Click Advanced SSH settings, check the "Use private key" box and enter the location of the SSH private key
1. Set a default password for the workstation owner, specified in the WorkstationUserName parameter.  Note: the CloudFormation template can be enhanced to automate this step. 
1. On MobaXterm, crate a VNC session:
    * Click Session -> VNC -> Enter Remote Host with the EC2 private IP adress and change the port to 5901
1. Start VNC, and enter the password when prompted, the password is specified in the VNCServerPasswd parameter.
1. Verify the installation of the tools:
    * The following IDE apps can be accessed at the Application menu -> programming sub-menu
        * Anaconda
        * Atom
        * EclipseEmac
        * Git
        * Intellij IDEA
        * MySQL Workbench (refer to Future Enhancement)
        * PyCharm
        * Q4 Assistant
        * QT Creator (refer to Future Enhancement)
        * Virtual Studio Code
    * The following command line tools, type the following commands to verify: 
        * `gradle -v`
        * `mvn -version`
        * `ruby -v`
        * `node -v`
        * `npm -v`
        * `mongo -version`
        * `asciidoc -v`

## Future Enhancements

1. Further research is needed to identify good alternatives for MySQL Workbenach and QT Creator installation.  Refer to the Future Enhancement comments in [`ws-tools.sh`](SupportFiles/ws-tools.sh)
1. The [`ws-tools.sh`](SupportFiles/ws-tools.sh) only does default installation. Further configuratin for each tool may be required. 
1. Consideration for enhancing automation with [`ws-tools.sh`](SupportFiles/ws-tools.sh)
    1. Currently only does default installation. Further configuration for each tool may be required.
	1. Create a function to handle repetative installation tasks.
	    ~~~
		RPMLIST=(
                 PM1
                 RPM2
                 @RPMGROUP1
                 RPM3
                 ...
        )

        for TARGET in "${RPMLIST[@]}"
        do
            printf "Installing %s... " "${TARGET}"
            yum install --quiet -y "${TARGET}" && echo "Success" || err_exit "Failed installing ${TARGET}"
        done
		~~~
1. Consideration for further automation using CloudFormation: 
    1. Create EC2 instance profile and instance role
    1. Create Security Group(s)
1. Add constraints to Jenkins WorkstationUserName, WorkstationUserPasswd, and ProvisionUser, the value must be complied with agency's security policy
1. The following code does not work in the UserData section of the CloudForamtion template, require further troubleshoot.  Workaround: manually set a default password for the workstation owner.
    ~~~
    cloud-config
    chpasswd:
      expire: False
      list: |
          <WorkstationUserNam>: <WorkstationUserPasswdString>
    ~~~
