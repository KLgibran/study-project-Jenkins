pipeline{
    agent any
    tools{
        terraform 'terraform'
        ansible 'ansible'
    }

    environment{
        PATH=sh(script:"echo $PATH:/usr/local/bin", returnStdout:true).trim()
        AWS_REGION = "us-east-1"
        AWS_ACCOUNT_ID = sh(script: 'export PATH="$PATH:/usr/local/bin" && aws sts get-caller-identity --query Account --output text', returnStdout:true).trim()
        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        APP_REPO_NAME = "gibran-repo/study-project-jenkins"
    }

    stages{
        stage('Create infrastructure for the app') {
            steps{
                echo "creating infrastructure for the app on aws cloud"
                sh 'terraform init'
                sh 'terraform apply --auto-approve'
            }
        }

        stage('create ECR Repo') {
            steps{
                echo "Creating ECR Repo for images"
                sh '''
                aws ecr describe -repositories --region ${AWS_REGION} --repository-name ${APP_REPO_NAME} || \
                aws ecr create-repository \
                    --repository-name ${APP_REPO_NAME} \
                    --image-scanning-configuration scanOnPush=false \
                    --image-tag-mutability MUTABLE \
                    --region ${AWS_REGION}
                  '''
            }
        }

        stage('Build App Docker Images') {
            steps{
                echo 'building app images'
                script{
                    env.NODE_IP = sh(script: 'terraform output -raw node_public_ip', returnStdout:true).trim()
                    env.DB_HOST = sh(script: 'terraform output -raw postgre_private_ip', returnStdout:true).trim()
                    env.DB_NAME = sh(script: 'aws --region=us-east-1 ssm get-parameters --names "DB_NAME" --query "Parameters[*].{Value:Value}" --output text', returnStdout:true).reim()
                    env.DB_PASSWORD = sh(script: 'aws --region=us-east-1 ssm get-parameters --names "DB_PASSWORD" --query "Parameters[*].{Value:Value}" --output text', returnStdout:true).reim()
                }
                sh 'echo ${DB_HOST}'
                sh 'echo ${NODE_IP}'
                sh 'echo ${DB_NAME}'
                sh 'echo ${DB_PASSWORD}'
                sh 'envsubst < node-env-template > ./nodejs/server/.env'
                sh 'cat ./nodejs/server/.env'
                sh 'envsubst < react-env-template > ./react/client/.env'
                sh 'cat ./react/client/.env'
                sh 'docker build --force-rm "${ECR_REGISTRY}/${APP_REPO_NAME}:postgre" -f ./postgresql/Dockerfile .'
                sh 'docker build --force-rm "${ECR_REGISTRY}/${APP_REPO_NAME}:nodejs" -f ./nodejs/Dockerfile .'
                sh 'docker build --force-rm "${ECR_REGISTRY}/${APP_REPO_NAME}:react" -f ./react/Dockerfile .'
                sh 'docker image ls'
            }
        }


        stage('Push Image to ECR Repo') {
            steps {
                echo 'Pushing App Image to ECR Repo'
                sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "$ECR_REGISTRY"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:postgre"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:nodejs"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:react"'
            }
        }


        stage('wait the instance') {
            steps {
                script {
                echo 'Waiting for the instance'
                id = sh(script: 'aws ec2 describe-instances --filters Name=tag-value,Values=ansible_postgresql Name=instance-state-name,Values=running --query Reservations[*].Instances[*].[InstanceId] --output text',  returnStdout:true).trim()
                sh 'aws ec2 wait instance-status-ok --instance-ids $id'
                }
            }
        }
        
        stage('Deploy the App') {
            steps {
                echo 'Deploy the App'
                sh 'ls -l'
                sh 'ansible --version'
                sh 'ansible-inventory --graph'
                ansiblePlaybook credentialsId: 'gibranAWS', disableHostKeyChecking: true, installation: 'ansible', inventory: 'inventory_aws_ec2.yml', playbook: 'docker_project.yml'
             }
        }
        
        stage('Destroy the infrastructure'){
            steps{
                timeout(time:5, unit:'DAYS'){
                    input message:'Approve terminate'
                }
                sh """
                docker image prune -af
                terraform destroy --auto-approve
                aws ecr delete-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --region ${AWS_REGION} \
                  --force
                """
            }
        }
    }

    post {
        always {
            echo 'Deleting all local images'
            sh 'docker image prune -af'
        }
        failure {

            echo 'Delete the Image Repository on ECR due to the Failure'
            sh """
                aws ecr delete-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --region ${AWS_REGION}\
                  --force
                """
            echo 'Deleting Terraform Stack due to the Failure'
            sh 'terraform destroy --auto-approve'
        }
    }
}
            