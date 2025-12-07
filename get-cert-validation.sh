#!/bin/bash

# Get certificate validation details
CERT_ARN="arn:aws:acm:us-east-1:758655430746:certificate/f1246f4e-f548-414b-8999-2d6e613b4d97"

echo "🔍 Getting certificate validation details..."
aws acm describe-certificate \
    --certificate-arn $CERT_ARN \
    --region us-east-1 \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord' \
    --output table

echo ""
echo "📝 Add this CNAME record to your DNS provider:"
echo ""

VALIDATION_NAME=$(aws acm describe-certificate \
    --certificate-arn $CERT_ARN \
    --region us-east-1 \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Name' \
    --output text)

VALIDATION_VALUE=$(aws acm describe-certificate \
    --certificate-arn $CERT_ARN \
    --region us-east-1 \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Value' \
    --output text)

echo "Name: $VALIDATION_NAME"
echo "Value: $VALIDATION_VALUE"
echo "Type: CNAME"
echo ""
echo "After adding this record, run: ./setup-custom-domain.sh"