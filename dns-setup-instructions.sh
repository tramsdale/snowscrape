#!/bin/bash

echo "🌍 DNS Setup Instructions for snow.tcla.me"
echo "==========================================="
echo ""
echo "Your custom domain is configured in AWS, but you need to set up DNS."
echo ""
echo "📝 Add this CNAME record to your DNS provider for tcla.me:"
echo ""
echo "   Name/Host: snow"
echo "   Value/Target: d2t7bhy0gcfwcx.cloudfront.net"
echo "   Type: CNAME"
echo "   TTL: 300 (or default)"
echo ""
echo "🔧 If you're using Route53, you can run this command:"
echo ""
echo "aws route53 change-resource-record-sets --hosted-zone-id YOUR_ZONE_ID --change-batch '{
    \"Changes\": [{
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
            \"Name\": \"snow.tcla.me\",
            \"Type\": \"CNAME\",
            \"TTL\": 300,
            \"ResourceRecords\": [{
                \"Value\": \"d2t7bhy0gcfwcx.cloudfront.net\"
            }]
        }
    }]
}'"
echo ""
echo "⏱️  After adding the DNS record, wait 5-10 minutes for propagation"
echo "🧪 Test with: curl https://snow.tcla.me/health"
echo ""
echo "🔍 Check DNS propagation:"
echo "   dig snow.tcla.me CNAME"
echo "   nslookup snow.tcla.me"