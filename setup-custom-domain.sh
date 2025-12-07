#!/bin/bash

# Custom domain setup script for snow.tcla.me
set -e

DOMAIN_NAME="snow.tcla.me"
CERTIFICATE_ARN=""
HOSTED_ZONE_ID=""

echo "🌐 Setting up custom domain: $DOMAIN_NAME"
echo "=========================================="

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Get the API Gateway ID from the existing stack
echo "📋 Getting API Gateway information..."
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='sam-snowscape-app'].id" --output text)

if [ -z "$API_ID" ]; then
    echo "❌ Could not find API Gateway 'sam-snowscape-app'."
    echo "   Available APIs:"
    aws apigateway get-rest-apis --query "items[].{Name:name,ID:id}" --output table
    exit 1
fi

echo "✅ Found API Gateway: $API_ID"

# Check if certificate exists or needs to be created
echo "🔐 Checking SSL certificate..."
CERT_ARN=$(aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME'].CertificateArn" --output text)

if [ -z "$CERT_ARN" ]; then
    echo "📜 Creating SSL certificate for $DOMAIN_NAME..."
    CERT_ARN=$(aws acm request-certificate \
        --domain-name $DOMAIN_NAME \
        --validation-method DNS \
        --region us-east-1 \
        --query 'CertificateArn' \
        --output text)
    
    echo "✅ Certificate requested: $CERT_ARN"
    echo "⚠️  You need to validate this certificate in the AWS Console or via DNS before proceeding."
    echo "   Go to: https://console.aws.amazon.com/acm/home?region=us-east-1#/"
    echo ""
    echo "   After validation, run this script again to continue setup."
    exit 0
else
    echo "✅ Found existing certificate: $CERT_ARN"
fi

# Check certificate status
CERT_STATUS=$(aws acm describe-certificate --certificate-arn $CERT_ARN --region us-east-1 --query 'Certificate.Status' --output text)
if [ "$CERT_STATUS" != "ISSUED" ]; then
    echo "⚠️  Certificate status: $CERT_STATUS"
    echo "   Please validate your certificate first, then run this script again."
    exit 0
fi

# Create custom domain for REST API (v1)
echo "🌐 Creating custom domain mapping..."
aws apigateway create-domain-name \
    --domain-name $DOMAIN_NAME \
    --certificate-arn $CERT_ARN \
    --security-policy TLS_1_2 \
    --region eu-west-2 \
    2>/dev/null || echo "Domain may already exist"

# Get the domain's target domain name for DNS
TARGET_DOMAIN=$(aws apigateway get-domain-name \
    --domain-name $DOMAIN_NAME \
    --region eu-west-2 \
    --query 'CloudFrontDomainName' \
    --output text)

echo "✅ Custom domain created/found"
echo "🎯 Target domain: $TARGET_DOMAIN"

# Create base path mapping
echo "🔗 Creating base path mapping..."
aws apigateway create-base-path-mapping \
    --domain-name $DOMAIN_NAME \
    --rest-api-id $API_ID \
    --stage Prod \
    --region eu-west-2 \
    2>/dev/null || echo "Base path mapping may already exist"

echo "✅ API mapping created"

# Get Route53 hosted zone (if exists)
echo "🌍 Checking Route53 hosted zone..."
ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='tcla.me.'].Id" --output text | cut -d'/' -f3)

if [ -z "$ZONE_ID" ]; then
    echo "⚠️  No Route53 hosted zone found for tcla.me"
    echo "   You need to manually create a CNAME record:"
    echo "   Name: snow.tcla.me"
    echo "   Value: $TARGET_DOMAIN"
    echo ""
else
    echo "✅ Found hosted zone: $ZONE_ID"
    
    # Create Route53 record
    echo "📝 Creating DNS record..."
    cat > /tmp/dns-record.json << EOF
{
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "$DOMAIN_NAME",
            "Type": "CNAME",
            "TTL": 300,
            "ResourceRecords": [{
                "Value": "$TARGET_DOMAIN"
            }]
        }
    }]
}
EOF

    aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONE_ID \
        --change-batch file:///tmp/dns-record.json

    rm /tmp/dns-record.json
    echo "✅ DNS record created"
fi

echo ""
echo "🎉 Custom domain setup complete!"
echo ""
echo "📄 Your API is now available at:"
echo "   https://$DOMAIN_NAME/"
echo "   https://$DOMAIN_NAME/health"
echo "   https://$DOMAIN_NAME/forecast/html"
echo ""
echo "⏱️  DNS propagation may take 5-10 minutes"
echo "🔧 Test with: curl https://$DOMAIN_NAME/health"