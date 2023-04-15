#!/bin/bash

# debug mode (prints the code while executing)
set -x

# Storing AWS account id in a variable (Query the account and send the output as text file)
aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)

# Print the aws account id
echo "AWS ACCOUNT ID: $aws_account_id

# Set AWS region and bucket name
aws_region="us-east-1"
bucket_name="Event-bucket"
lambda_func_name="s3-lambda-func"
role_name="s3-lambda-sns"
email_address="utsabsapkota4231@gmail.com"

# Create IAM Role
role_response=$(aws iam create-role --role-name s3-lambda-sns --assume-role-policy-document '{
	"Version": "2012-10-17",
	"Statement": [{
	  "Action": "sts:AssumeRole",
	  "Effect": "Allow",
	  "Principal": {
		"Service": [
		  "lambda.amazonaws.com",
		  "s3.amazonaws.com",
		  "sns.amazonaws.com"
		]
	  }
	}]
}')

# Extract the role ARN from the JSON response and store it in variable
# role_response provides various datas in json from which we are extracting role arn)
role_arn=$(echo "$role_response" | jq -r '.Role.Arn') 

# Print the role ARN
echo "Role ARN: $role_arn"

# Attach Permissions to the role
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

# Create the S3 bucket and capture the output in a variable
bucket_output=$(aws s3api create-bucket --bucket "$bucket_name" --region "$aws_region")

# Print the output from the variable
echo "Bucket creation output: $bucket_output"

# Upload a file to the bucket (Only for cross checking whether bucket is working)
aws s3 cp ./example.txt s3://"$bucket_name"/example.txt

# Create a zip file to upload lambda function
zip -r s3-lambda-func.zip ./s3-lambda-func

sleep 5

# Create a Lambda function
aws lambda create-function \
  --region "$aws_region" \
  --function-name $lambda_func_name \
  --runtime "python3.8" \
  --handler "s3-lambda-function/s3-lambda-function.lambda_handler" \
  --memory-size 128 \
  --timeout 30 \
  --role "arn:aws:iam::$aws_account_id:role/$role_name" \
  --zip-file "fileb://.s3-lambda-func.zip"

# Add permissions to s3 bucket to invoke lambda
aws lambda add-permission \
  --function-name "$lambda-func-name" \
  --statement-id "s3-lambda-sns" \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  -- source-arn "arn:aws:s3:::$bucket_name"

# Create an s3 event trigger for the Lambda function
aws s3api put-bucket-notification-configuration \
  --region "$aws-region" \
  --bucket "$bucket_name" \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [{
    	 "LambdaFunctionArn": "arn:aws:lambda:us-east-1:$aws_account_id:function:s3-lambda-func",
	 "Events": ["s3.ObjectCreated:*"]
    }]
}' 

# Create an SNS topic and save the topic ARN to a variable
topic_arn=$(aws sns create-topic --name s3-lambda-sns --output json | jq -r '.TopicArn')

# Print the TopicArn
echo "SNS Topic ARN: $topic_arn"

# Add SNS publish permission to the Lambda Function
aws sns subscribe \
  --topic-arn "$topic_arn" \
  --protocol email \
  --notification-endpoint "$email_address"

# Publish SNS
aws sns publish \
  --topic-arn "$topic_arn" \
  --subject "A new object created in s3 bucket" \
  --message "Event triggering in s3 bucket"

