#!/bin/bash

# Create EC2 instance for Frontline Watcher via AWS CLI
# Prerequisites: AWS CLI installed and configured

set -e

INSTANCE_TYPE="${1:-t3.medium}"
KEY_NAME="${2}"
SECURITY_GROUP="${3}"
AMI_ID="${4:-ami-0c55b159cbfafe1f0}"  # Ubuntu 22.04 LTS (us-east-1)

if [ -z "$KEY_NAME" ] || [ -z "$SECURITY_GROUP" ]; then
    echo "Usage: $0 [instance-type] <key-name> <security-group-id> [ami-id]"
    echo ""
    echo "Example:"
    echo "  $0 t3.medium my-key-pair sg-0123456789abcdef0"
    echo ""
    echo "To find your security group:"
    echo "  aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId,GroupName]' --output table"
    exit 1
fi

echo "🚀 Creating EC2 instance for Frontline Watcher"
echo "Instance Type: $INSTANCE_TYPE"
echo "Key Pair: $KEY_NAME"
echo "Security Group: $SECURITY_GROUP"
echo "AMI: $AMI_ID"
echo ""

# Create instance
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=frontline-watcher},{Key=Project,Value=sub67}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ Failed to create instance"
    exit 1
fi

echo "✅ Instance created: $INSTANCE_ID"
echo ""

# Wait for instance to be running
echo "⏳ Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "✅ Instance is running!"
echo ""
echo "📋 Connection details:"
echo "  Instance ID: $INSTANCE_ID"
echo "  Public IP: $PUBLIC_IP"
echo ""
echo "🔌 Connect via SSH:"
echo "  ssh -i your-key.pem ubuntu@$PUBLIC_IP"
echo ""
echo "📝 Next steps:"
echo "  1. SSH into the instance"
echo "  2. Clone repository: git clone https://github.com/mckaysmith27/frontline_watcher.git"
echo "  3. Run setup: cd frontline_watcher && ./ec2/setup-ec2.sh"
echo "  4. Configure credentials and install services"
