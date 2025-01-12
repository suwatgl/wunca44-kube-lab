#!/bin/bash

AUTH_URL=$(curl -s google.com | awk -F "\"" '{print $2}')

AUTH=$AUTH_URL 

MAGIC=$(curl -s $AUTH_URL | grep magic | awk -F "\"" '{print $6}')

if [ ! -z "$MAGIC" ]; then
 echo "MAGIC=$MAGIC"
 curl -v -X POST -d "username=admin&password=adminpassword&magic=$MAGIC&4Tredir=https://google.com" $AUTH_URL
else
 echo "Already auth!!"
fi
