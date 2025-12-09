#!/usr/bin/env bash

set -e

# export KUBECONFIG env variable
export KUBECONFIG=$(pwd)/kubeconfig

# Get host from ingress to access APL
CONSOLE_HOST=$(kubectl get ingress -n istio-system nginx-team-admin-platform-public-auth -o jsonpath='{.spec.rules[1].host}')
API_HOST=$(kubectl get ingress -n istio-system nginx-team-admin-platform-public-open -o jsonpath='{.spec.rules[0].host}')
KEYCLOAK_HOST=$(kubectl get ingress -n istio-system nginx-team-admin-platform-public-open -o jsonpath='{.spec.rules[2].host}')

# get username and password from kubernetes secret
USERNAME=$(kubectl get secrets -n keycloak platform-admin-initial-credentials -o jsonpath='{.data.username}' | base64 --decode)
PASSWORD=$(kubectl get secrets -n keycloak platform-admin-initial-credentials -o jsonpath='{.data.password}' | base64 --decode)

# Print APL access information
echo "========================================="
echo "  APL Access Information"
echo "========================================="
echo ""
echo "APL Console URL: https://$CONSOLE_HOST"
#  https://console.<domainSuffix>/api/api-docs/swagger/
echo "Swagger UI: https://$CONSOLE_HOST/api/api-docs/swagger/"
# OpenAPI in json format
echo "OpenAPI Json: https://$CONSOLE_HOST/api/api-docs"
# API URL:  https://api.<domainSuffix>
echo "API URL: https://$API_HOST"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo ""

# API Usage Example
echo "Open this file and uncomment the following lines for example of using APL API."

# CLIENT_SECRET=$(kubectl get -n apl-keycloak-operator secrets apl-keycloak-operator-secret -ojson | jq -r '.data.KEYCLOAK_CLIENT_SECRET' | base64 -d)

# echo "Getting access token from Keycloak..."
# cat <<'EOT'
# curl -k -s -X POST "https://KEYCLOAK_HOST/realms/otomi/protocol/openid-connect/token" \
# -H "Content-Type: application/x-www-form-urlencoded" \
# --data-urlencode "client_id=otomi" \
# --data-urlencode "client_secret=CLIENT_SECRET" \
# --data-urlencode "grant_type=password" \
# --data-urlencode "username=USERNAME" \
# --data-urlencode "password=PASSWORD" | jq -r '.access_token'
# EOT
# echo ""
# echo "Note: Using --data-urlencode to properly handle special characters in password"
# echo ""

# echo "Debug - Executing with actual values:"
# echo "  KEYCLOAK_HOST: $KEYCLOAK_HOST"
# echo "  USERNAME: $USERNAME"
# echo "  CLIENT_SECRET: ${CLIENT_SECRET:0:10}..." # Show only first 10 chars
# echo ""

# RESPONSE=$(curl -k -s -X POST "https://$KEYCLOAK_HOST/realms/otomi/protocol/openid-connect/token" \
# -H "Content-Type: application/x-www-form-urlencoded" \
# --data-urlencode "client_id=otomi" \
# --data-urlencode "client_secret=$CLIENT_SECRET" \
# --data-urlencode "grant_type=password" \
# --data-urlencode "username=$USERNAME" \
# --data-urlencode "password=$PASSWORD")

# echo "Full Response:"
# echo "$RESPONSE" | jq '.'
# echo ""

# ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

# if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
#     echo "Error: Failed to get access token"
#     echo "Response: $RESPONSE"
# else
#     echo "Access Token (first 20 chars): ${ACCESS_TOKEN:0:20}..."
# fi
# echo ""

# # Enable Knative via APL API
# echo "Enabling Knative via APL API..."
# cat <<EOT
# curl -k -s -X PUT "https://$API_HOST/v1/apps/admin" \\
# -H "Authorization: Bearer $ACCESS_TOKEN" \\
# -H "Content-Type: application/json" \\
# -d '{"ids":["knative"],"enabled":true}'
# EOT
# echo ""

# RESPONSE=$(curl -k -s -X PUT "https://$API_HOST/v1/apps/admin" \
# -H "Authorization: Bearer $ACCESS_TOKEN" \
# -H "Content-Type: application/json" \
# -d '{"ids":["knative"],"enabled":true}')

# echo "API Response: $RESPONSE"

# echo ""
# echo "========================================="
# echo ""

# # Print teams
# cat <<EOT
# curl -k -s -X GET "https://$API_HOST/v1/teams" \\
# -H "Authorization: Bearer $ACCESS_TOKEN" \\
# -H "Content-Type: application/json"
# EOT
# echo ""

# RESPONSE=$(curl -k -s -X GET "https://$API_HOST/v1/teams" \
# -H "Authorization: Bearer $ACCESS_TOKEN" \
# -H "Content-Type: application/json")

# echo "API Response: $RESPONSE"

echo ""
echo "========================================="
