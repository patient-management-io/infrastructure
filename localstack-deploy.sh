#!/bin/bash

set -e

# Disable AWS CLI pager to prevent commands from opening in a separate viewer
export AWS_PAGER=""

echo "🧹 Cleaning up old stack..."
aws --endpoint-url=http://localhost:4566 cloudformation delete-stack \
    --stack-name patient-management \

echo "🚀 Starting fresh LocalStack deployment..."

# Deploy the CloudFormation stack
echo "📦 Deploying CloudFormation stack..."
aws --endpoint-url=http://localhost:4566 cloudformation deploy \
    --stack-name patient-management \
    --template-file "./cdk.out/localstack.template.json" \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset \
    --region us-east-1 \
    --no-paginate

#echo "✅ Checking deployment status..."
#aws --endpoint-url=http://localhost:4566 cloudformation describe-stacks \
#    --stack-name patient-management \
#    --region us-east-1 \
#    --no-paginate

echo "🔗 Getting load balancer DNS name..."
LB_DNS=$(aws --endpoint-url=http://localhost:4566 elbv2 describe-load-balancers \
    --region us-east-1 \
    --query "LoadBalancers[0].DNSName" \
    --output text \
    --no-paginate 2>/dev/null || echo "No load balancers found")

if [ "$LB_DNS" != "No load balancers found" ] && [ "$LB_DNS" != "None" ]; then
    echo "🎉 Deployment completed successfully!"
    echo "📍 API Gateway URL: http://$LB_DNS"
    echo "🔧 You can now access your microservices through this load balancer."
else
    echo "⚠️  Deployment completed but no load balancer found. Check the stack resources."
fi
