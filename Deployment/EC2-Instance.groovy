pipeline {

    agent any

    options {
        buildDiscarder(
            logRotator(
                numToKeepStr: '5',
                daysToKeepStr: '30',
                artifactDaysToKeepStr: '30',
                artifactNumToKeepStr: '3'
            )
        )
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        AWS_DEFAULT_REGION = "${AwsRegion}"
        AWS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'
        REQUESTS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'
    }

    parameters {
        string(name: 'AwsRegion', defaultValue: 'us-east-1', description: 'Amazon region to deploy resources into')
        string(name: 'AwsCred', description: 'Jenkins-stored AWS credential with which to execute cloud-layer commands')
        string(name: 'GitCred', description: 'Jenkins-stored Git credential with which to execute git commands')
        string(name: 'GitProjUrl', description: 'SSH URL from which to download the Jenkins git project')
        string(name: 'GitProjBranch', description: 'Project-branch to use from the Jenkins git project')
        string(name: 'CfnStackRoot', description: 'Unique token to prepend to all stack-element names')
        string(name: 'TemplateUrl', description: 'S3-hosted URL for the EC2 template file')
        string(name: 'AdminPubkeyURL', description: '(Optional) URL of file containing admin-group SSH key-bundle')
        string(name: 'AmiId', description: 'ID of the AMI to launch')
        string(name: 'CfnEndpointUrl', defaultValue: 'https://cloudformation.us-east-1.amazonaws.com', description: '(Optional) URL to the CloudFormation Endpoint. e.g. https://cloudformation.us-east-1.amazonaws.com')
        string(name: 'EpelRepo', defaultValue: 'epel', description: 'Name of network-available EPEL repo.')
        string(name: 'InstallToolScriptURL', description: 'S3 URL of the script which executes commands to install various tools.')
        string(name: 'WorkstationUserName', defaultValue: '', description: 'User name of the workstation owner.')
        string(name: 'WorkstationUserPasswd', defaultValue: '', description: 'Default password of the workstation owner.')
        string(name: 'InstanceRole', defaultValue: '', description: '(Optional) IAM instance role to apply to the instance')
        string(name: 'InstanceType', defaultValue: '', description: 'Amazon EC2 instance type')
        string(name: 'KeyPairName', description: 'Public/private key pair used to allow an operator to securely connect to instance immediately after the instance-SSHD comes online')
        string(name: 'NoPublicIp', defaultValue: 'true', description: 'Controls whether to assign the instance a public IP. Recommended to leave at \'true\' _unless_ launching in a public subnet')
        string(name: 'NoReboot', defaultValue: 'false', description: 'Controls whether to reboot the instance as the last step of cfn-init execution')
        string(name: 'PipRpm', defaultValue: 'python2-pip', description: 'Name of preferred pip RPM.')
        string(name: 'PrivateIp', defaultValue: '', description: '(Optional) Set a static, primary private IP. Leave blank to auto-select a free IP')
        string(name: 'ProvisionUser', defaultValue: '', description: 'Name for remote-administration account')
        string(name: 'PyStache', defaultValue: 'PyStache', description: 'Name of preferred pystache RPM.')
        string(name: 'RootVolumeSize', defaultValue: '20', description: 'Size in GB of the EBS volume to create. If smaller than AMI default, create operation will fail; If larger, partition containing root device-volumes will be upsized')
        string(name: 'SecurityGroupIds', description: 'List of security groups to apply to the instance')
        string(name: 'SubnetId', description: 'ID of the subnet to assign to the instance')
        string(name: 'ToolsURL', description: 'S3 URL of the archive file (in tar.gz format) where contains the binary files to be installed on the EC2.')
        string(name: 'VNCServerPasswd', defaultValue: '', description: 'Default VNC server password. Password must contain at least one letter, at least one number, and be longer than six characters.')
        string(name: 'WatchmakerConfig', defaultValue: '', description: '(Optional) Path to a Watchmaker config file.  The config file path can be a remote source (i.e. http[s]://, s3://) or local directory (i.e. file://)')
        string(name: 'WatchmakerEnvironment', defaultValue: '', description: 'Environment in which the instance is being deployed')
		string(name: 'SSHKey', defaultValue: '', description: 'SSH Key')
    }

    stages {
        stage ('Prepare Instance Environment') {
            steps {
                deleteDir()
                git branch: "${GitProjBranch}",
                    credentialsId: "${GitCred}",
                    url: "${GitProjUrl}"
                writeFile file: 'master.ec2.instance.parms.json',
                    text: /
                        [
                            {
                                "ParameterKey": "AdminPubkeyURL",
                                "ParameterValue": "${env.AdminPubkeyURL}"
                            },
                            {
                                "ParameterKey": "AmiId",
                                "ParameterValue": "${env.AmiId}"
                            },
                            {
                                "ParameterKey": "CfnEndpointUrl",
                                "ParameterValue": "${env.CfnEndpointUrl}"
                            },
                            {
                                "ParameterKey": "EpelRepo",
                                "ParameterValue": "${env.EpelRepo}"
                            },
                            {
                                "ParameterKey": "InstallToolScriptURL",
                                "ParameterValue": "${env.InstallToolScriptURL}"
                            },
                            {
                                "ParameterKey": "WorkstationUserName",
                                "ParameterValue": "${env.WorkstationUserName}"
                            },
                            {
                                "ParameterKey": "WorkstationUserPasswd",
                                "ParameterValue": "${env.WorkstationUserPasswd}"
                            },
                            {
                                "ParameterKey": "InstanceRole",
                                "ParameterValue": "${env.InstanceRole}"
                            },
                            {
                                "ParameterKey": "InstanceType",
                                "ParameterValue": "${env.InstanceType}"
                            },
                            {
                                "ParameterKey": "KeyPairName",
                                "ParameterValue": "${env.KeyPairName}"
                            },
                            {
                                "ParameterKey": "NoPublicIp",
                                "ParameterValue": "${env.NoPublicIp}"
                            },
                            {
                                "ParameterKey": "NoReboot",
                                "ParameterValue": "${env.NoReboot}"
                            },
                            {
                                "ParameterKey": "PipRpm",
                                "ParameterValue": "${env.PipRpm}"
                            },
                            {
                                "ParameterKey": "PrivateIp",
                                "ParameterValue": "${env.PrivateIp}"
                            },
                            {
                                "ParameterKey": "ProvisionUser",
                                "ParameterValue": "${env.ProvisionUser}"
                            },
                            {
                                "ParameterKey": "PyStache",
                                "ParameterValue": "${env.PyStache}"
                            },
                            {
                                "ParameterKey": "RootVolumeSize",
                                "ParameterValue": "${env.RootVolumeSize}"
                            },
                            {
                                "ParameterKey": "SecurityGroupIds",
                                "ParameterValue": "${env.SecurityGroupIds}"
                            },
                            {
                                "ParameterKey": "SubnetId",
                                "ParameterValue": "${env.SubnetId}"
                            },
                            {
                                "ParameterKey": "ToolsURL",
                                "ParameterValue": "${env.ToolsURL}"
                            },
                            {
                                "ParameterKey": "VNCServerPasswd",
                                "ParameterValue": "${env.VNCServerPasswd}"
                            },
                            {
                                "ParameterKey": "WatchmakerConfig",
                                "ParameterValue": "${env.WatchmakerConfig}"
                            },
                            {
                                "ParameterKey": "WatchmakerEnvironment",
                                "ParameterValue": "${env.WatchmakerEnvironment}"
                            }
                        ]
                    /
            }
		}
        stage ('Prepare AWS Environment') {
            steps {
                withCredentials(
                    [
                        [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: "${AwsCred}", secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'],
                        sshUserPrivateKey(credentialsId: "${SSHKey}", keyFileVariable: 'SSH_KEY_FILE', passphraseVariable: 'SSH_KEY_PASS', usernameVariable: 'SSH_KEY_USER')
                    ]
                ) {
                    sh '''#!/bin/bash
                        echo "Attempting to delete any active ${CfnStackRoot}-Ec2Inst-${BUILD_NUMBER} stacks..."
                        aws --region "${AwsRegion}" cloudformation delete-stack --stack-name "${CfnStackRoot}-Ec2Inst-${BUILD_NUMBER}"

                        aws cloudformation wait stack-delete-complete --stack-name ${CfnStackRoot}-Ec2Inst-${BUILD_NUMBER} --region ${AwsRegion}
                    '''
                }
            }
        }
        stage ('Launch Linux Workspaces EC2 Instance Stack') {
            steps {
                withCredentials(
                    [
                        [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: "${AwsCred}", secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'],
                        sshUserPrivateKey(credentialsId: "${SSHKey}", keyFileVariable: 'SSH_KEY_FILE', passphraseVariable: 'SSH_KEY_PASS', usernameVariable: 'SSH_KEY_USER')
                    ]
                ) {
                    sh '''#!/bin/bash
                        echo "Attempting to create stack ${CfnStackRoot}-Ec2Inst-${BUILD_NUMBER}..."
                        aws --region "${AwsRegion}" cloudformation create-stack --stack-name "${CfnStackRoot}-Ec2Inst-${BUILD_NUMBER}" \
                          --disable-rollback --capabilities CAPABILITY_NAMED_IAM \
                          --template-url "${TemplateUrl}" \
                          --parameters file://master.ec2.instance.parms.json

                        aws cloudformation wait stack-create-complete --stack-name ${CfnStackRoot}-Ec2Inst-${BUILD_NUMBER} --region ${AwsRegion}
                    '''
                }
            }
        }
    }
}
