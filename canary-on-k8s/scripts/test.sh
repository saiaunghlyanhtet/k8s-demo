#!/bin/bash

count_v1=0
count_v2=0

# Replace with your ALB URL
ELB_URL=""

for i in {1..10}; do
  response=$(curl -s $ELB_URL)

  if [[ $response == *"1"* ]]; then
    ((count_v1++))
  elif [[ $response == *"2"* ]]; then
    ((count_v2++))
  fi

  echo "Request $i: $response"
done

echo "Service v1 response count: $count_v1"
echo "Service v2 response count: $count_v2"
