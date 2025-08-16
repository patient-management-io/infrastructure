#!/bin/bash

set -e

# Disable AWS CLI pager to prevent commands from opening in a separate viewer
export AWS_PAGER=""

STACK_NAME="patient-management"
BUCKET_NAME="cd-templates"
TEMPLATE_FILE="./cdk.out/localstack.template.json"
TEMPLATE_KEY="patient-stack.template.json"
REGION="us-east-1"
LOCALSTACK_URL="http://localhost:4566"

# Required for LocalStack CLI compatibility
export AWS_DEFAULT_REGION=$REGION
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

echo "🔍 Ensuring S3 bucket for templates exists..."
if ! aws --endpoint-url="$LOCALSTACK_URL" s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "🆕 Bucket not found. Creating s3://$BUCKET_NAME..."
  aws --endpoint-url="$LOCALSTACK_URL" s3 mb "s3://$BUCKET_NAME"
fi

echo "📤 Uploading CloudFormation template to S3..."
aws --endpoint-url=$LOCALSTACK_URL s3 cp "$TEMPLATE_FILE" "s3://$BUCKET_NAME/$TEMPLATE_KEY"

# For LocalStack, use the LocalStack S3 URL format
TEMPLATE_URL="http://localhost:4566/$BUCKET_NAME/$TEMPLATE_KEY"

echo "🧹 Cleaning up old stack..."
# Check if stack exists before trying to delete
if aws --endpoint-url=http://localhost:4566 cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region us-east-1 \
    --no-paginate 2>/dev/null; then
  echo "🗑️  Deleting existing stack..."
  aws --endpoint-url=http://localhost:4566 cloudformation delete-stack \
      --stack-name $STACK_NAME \
      --region us-east-1

  echo "⏳ Waiting for stack deletion to complete..."
  aws --endpoint-url=http://localhost:4566 cloudformation wait stack-delete-complete \
      --stack-name $STACK_NAME \
      --region us-east-1
else
  echo "ℹ️  No existing stack found to delete."
fi

echo "🚀 Starting fresh LocalStack deployment..."

# Deploy the CloudFormation stack using create-stack for template-url
echo "📦 Deploying CloudFormation stack..."
aws --endpoint-url=http://localhost:4566 cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-url $TEMPLATE_URL \
    --capabilities CAPABILITY_IAM \
    --region us-east-1 \
    --no-paginate

echo "⏳ Waiting for stack creation to complete..."
aws --endpoint-url=http://localhost:4566 cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME \
    --region us-east-1

echo "🔗 Getting load balancer DNS name..."
LB_DNS=$(aws --endpoint-url=http://localhost:4566 elbv2 describe-load-balancers \
    --region us-east-1 \
    --query "LoadBalancers[-1].DNSName" \
    --output text \
    --no-paginate 2>/dev/null || echo "No load balancers found")

if [ "$LB_DNS" != "No load balancers found" ] && [ "$LB_DNS" != "None" ]; then
    echo "🎉 Deployment completed successfully!"
    echo "📍 API Gateway URL: http://$LB_DNS"
    echo "🔧 You can now access your microservices through this load balancer."
else
    echo "⚠️  Deployment completed but no load balancer found. Check the stack resources."
    echo "📋 Stack resources:"
    aws --endpoint-url=http://localhost:4566 cloudformation describe-stack-resources \
        --stack-name $STACK_NAME \
        --region us-east-1 \
        --query "StackResources[*].[ResourceType,LogicalResourceId,PhysicalResourceId]" \
        --output table \
        --no-paginate 2>/dev/null || echo "Could not retrieve stack resources"
fi
