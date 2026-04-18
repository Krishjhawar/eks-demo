pipeline {
    agent any

    // ── Environment Variables ────────────────────────────────────────────
    environment {
        AWS_REGION      = "us-east-1"
        CLUSTER_NAME    = "eks-demo"
        ECR_REGISTRY    = "582260130471.dkr.ecr.us-east-1.amazonaws.com"
        ECR_REPO        = "demo-app"
        IMAGE_TAG       = "${BUILD_NUMBER}"
        FULL_IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
        ANSIBLE_DIR     = "${WORKSPACE}/ansible"
        TF_DIR          = "${WORKSPACE}/terraform"
        K8S_DIR         = "${WORKSPACE}/k8s"
    }

    // ── Build options ────────────────────────────────────────────────────
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    // ── Pipeline Stages ──────────────────────────────────────────────────
    stages {

        // ── Stage 1: Checkout ────────────────────────────────────────────
        stage('Checkout') {
            steps {
                echo '======== Checking out source code ========'
                checkout scm
                sh '''
                    echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
                    echo "Commit: $(git rev-parse --short HEAD)"
                    echo "Files:"
                    ls -la
                '''
            }
        }

        // ── Stage 2: Docker Build ─────────────────────────────────────────
        stage('Docker Build') {
            steps {
                echo '======== Building Docker image ========'
                sh '''
                    cd app
                    docker build \
                        --tag ${ECR_REPO}:${IMAGE_TAG} \
                        --tag ${ECR_REPO}:latest \
                        --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
                        --build-arg VCS_REF=$(git rev-parse --short HEAD) \
                        .
                    echo "Image built successfully:"
                    docker images | grep ${ECR_REPO}
                '''
            }
        }

        // ── Stage 3: Push to ECR ──────────────────────────────────────────
        stage('Push to ECR') {
            steps {
                echo '======== Pushing image to Amazon ECR ========'
                sh '''
                    # Authenticate Docker with ECR
                    aws ecr get-login-password \
                        --region ${AWS_REGION} | \
                    docker login \
                        --username AWS \
                        --password-stdin ${ECR_REGISTRY}

                    # Tag image with ECR URI
                    docker tag ${ECR_REPO}:${IMAGE_TAG} ${FULL_IMAGE_NAME}
                    docker tag ${ECR_REPO}:latest ${ECR_REGISTRY}/${ECR_REPO}:latest

                    # Push both tags
                    docker push ${FULL_IMAGE_NAME}
                    docker push ${ECR_REGISTRY}/${ECR_REPO}:latest

                    echo "Pushed: ${FULL_IMAGE_NAME}"
                '''
            }
        }

        // ── Stage 4: Terraform Apply ──────────────────────────────────────
        stage('Terraform Apply') {
            steps {
                echo '======== Provisioning EKS cluster with Terraform ========'
                sh '''
                    cd ${TF_DIR}

                    # Initialise Terraform
                    terraform init \
                        -input=false

                    # Show plan first
                    terraform plan \
                        -var="region=${AWS_REGION}" \
                        -var="cluster_name=${CLUSTER_NAME}" \
                        -var="ecr_uri=${FULL_IMAGE_NAME}" \
                        -input=false \
                        -out=tfplan

                    # Apply the plan
                    terraform apply \
                        -input=false \
                        -auto-approve \
                        tfplan

                    # Print outputs
                    echo "======== Terraform Outputs ========"
                    terraform output
                '''
            }
        }

        // ── Stage 5: Ansible Configure ────────────────────────────────────
        stage('Ansible Configure') {
            steps {
                echo '======== Configuring environment with Ansible ========'
                sh '''
                    cd ${ANSIBLE_DIR}

                    # Run playbook against Jenkins EC2 (localhost on the agent)
                    ansible-playbook playbook.yml \
                        -i inventory.ini \
                        -e "aws_region=${AWS_REGION}" \
                        -e "cluster_name=${CLUSTER_NAME}" \
                        -e "ecr_uri=${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}" \
                        -v
                '''
            }
        }

        // ── Stage 6: Deploy to EKS ────────────────────────────────────────
        stage('Deploy to EKS') {
            steps {
                echo '======== Deploying application to EKS ========'
                sh '''
                    # Update kubeconfig
                    aws eks update-kubeconfig \
                        --region ${AWS_REGION} \
                        --name ${CLUSTER_NAME}

                    # Replace ECR URI placeholder in deployment.yaml
                    sed -i "s|REPLACE_WITH_ECR_URI|${ECR_REGISTRY}/${ECR_REPO}|g" \
                        ${K8S_DIR}/deployment.yaml

                    # Apply all manifests
                    kubectl apply -f ${K8S_DIR}/

                    # Update image to latest build
                    kubectl set image deployment/demo-app \
                        demo-app=${FULL_IMAGE_NAME} \
                        --namespace default

                    # Wait for rollout
                    kubectl rollout status deployment/demo-app \
                        --namespace default \
                        --timeout=5m

                    echo "======== Deployment Status ========"
                    kubectl get pods -n default
                    kubectl get hpa  -n default
                    kubectl get svc  -n default
                '''
            }
        }

        // ── Stage 7: Smoke Test ───────────────────────────────────────────
        stage('Smoke Test') {
            steps {
                echo '======== Running smoke tests ========'
                sh '''
                    # Get the app URL
                    APP_URL=$(kubectl get svc demo-app-service \
                        -n default \
                        -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")

                    echo "App URL: http://${APP_URL}"

                    # Wait for DNS to propagate
                    sleep 30

                    # Test health endpoint
                    curl -f http://${APP_URL}/health && \
                        echo "Health check PASSED" || \
                        echo "Health check FAILED — LoadBalancer may still be provisioning"

                    # Test status endpoint
                    curl -f http://${APP_URL}/status && \
                        echo "Status check PASSED" || \
                        echo "Status check FAILED"

                    echo "======== Final Pod Status ========"
                    kubectl get pods -n default -o wide
                    kubectl get hpa  -n default
                '''
            }
        }
    }

    // ── Post Actions ─────────────────────────────────────────────────────
    post {

        success {
            echo '''
            ============================================
              Pipeline SUCCEEDED
            ============================================
              Image : ${FULL_IMAGE_NAME}
              Cluster: ${CLUSTER_NAME}
              Region : ${AWS_REGION}
            ============================================
            '''
        }

        failure {
            echo '======== Pipeline FAILED — check logs above ========'
            sh '''
                echo "======== Debug Info ========"
                kubectl get pods -n default || true
                kubectl get events -n default --sort-by=".lastTimestamp" || true
            '''
        }

        always {
            // Clean up local Docker images to save disk space
            sh '''
                docker rmi ${ECR_REPO}:${IMAGE_TAG} || true
                docker rmi ${ECR_REPO}:latest       || true
                docker rmi ${FULL_IMAGE_NAME}        || true
            '''
        }
    }
}