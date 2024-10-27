#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Set environment variables
HOST="localhost"
PORT="8030"
LOGIN_URL="/streampipes-backend/api/v2/auth/login"

SP_USERNAME="admin@streampipes.apache.org"
SP_PASSWORD="admin"

INSTALL_ELEMENT_URL="/streampipes-backend/api/v2/extension-installation"

API_KEY_URL="/streampipes-backend/api/v2/users/$SP_USERNAME/tokens"
API_KEY_USER_NAME="admin@streampipes.apache.org"

loginRequestBody='{
  "username": "'"$SP_USERNAME"'",
  "password": "'"$SP_PASSWORD"'"
}'

# Login and get accessToken
#response=$(curl -s -X POST "http://$HOST:$PORT$LOGIN_URL" \
#   -H "Content-Type: application/json" \
#   -d "$loginRequestBody")
#if [ $? -ne 0 ]; then
#    echo "Error: Login request failed"
#    exit 1
#fi

# Login and get accessToken
curl_output="curl_output.txt"
curl_error="curl_error.txt"

response=$(curl -s -o "$curl_output" -e "$curl_error" -w "%{http_code}" -X POST "http://$HOST:$PORT$LOGIN_URL" \
   -H "Content-Type: application/json" \
   -d "$loginRequestBody" 2> "$curl_error")

if [ $? -ne 0 ]; then
    echo "Error: Login request failed"
    # Print the error details from curl_error
    echo "Error details:"
    cat "$curl_error"
    exit 1
else
    echo "Login request successful"
    # Print the response details from curl_output
    echo "Response details:"
    cat "$curl_output"
    # You can also print the HTTP status code
    echo "HTTP Status Code: $response"
fi

# Remove the temporary files if not needed anymore
rm "$curl_output" "$curl_error"

accessToken=$(echo "$response" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')

if [ -z "$accessToken" ]; then
    echo "Error: Failed to retrieve access token"
    exit 1
fi

apiKeyRequestBody='{
  "tokenName": "'"$API_KEY_USER_NAME"'"
}'

# Get APIKEY
APIKEYRESP=$(curl -s -X POST "http://$HOST:$PORT$API_KEY_URL" \
   -H "Content-Type: application/json" \
   -H "authorization: Bearer $accessToken" \
   -d "$apiKeyRequestBody")
if [ $? -ne 0 ]; then
    echo "Error: API Key request failed"
    exit 1
fi

APIKEY=$(echo "$APIKEYRESP" | sed 's/.*"rawToken":"\([^"]*\)".*/\1/')
if [ -z "$APIKEY" ]; then
    echo "Error: Failed to retrieve API key"
    exit 1
fi


installRequestBody='{
  "appId":"org.apache.streampipes.connect.iiot.adapters.simulator.machine",
  "publicElement":true,
  "serviceTagPrefix":"ADAPTER"
  }'

curl -s -X POST "http://$HOST:$PORT$INSTALL_ELEMENT_URL" \
   -H "Content-Type: application/json" \
   -H "authorization: Bearer $accessToken" \
   -d "$installRequestBody"

installRequestBody='{
  "appId":"org.apache.streampipes.processors.transformation.jvm.booloperator.inverter",
  "publicElement":true,
  "serviceTagPrefix":"DATA_PROCESSOR"
  }'

curl -s -X POST "http://$HOST:$PORT$INSTALL_ELEMENT_URL" \
   -H "Content-Type: application/json" \
   -H "authorization: Bearer $accessToken" \
   -d "$installRequestBody"

installRequestBody='{
  "appId":"org.apache.streampipes.sinks.internal.jvm.datalake",
  "publicElement":true,
  "serviceTagPrefix":"DATA_SINK"
  }'

curl -s -X POST "http://$HOST:$PORT$INSTALL_ELEMENT_URL" \
   -H "Content-Type: application/json" \
   -H "authorization: Bearer $accessToken" \
   -d "$installRequestBody"

cd ../go-client-e2e || exit
go test -v ../go-client-e2e/... -args "$HOST" "$PORT" "$APIKEY" "$API_KEY_USER_NAME"
if [ $? -ne 0 ]; then
    echo "Error: go test failed"
    exit 1
fi

cd ../tool || exit

# add other client test
#...

echo "All tests passed successfully"