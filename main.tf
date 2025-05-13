module "s3" {
  source      = "./modules/s3"
  bucket_name = var.bucket_name
}
 
module "ec2" {
  source        = "./modules/ec2"
  instance_type = var.instance_type
  ami_id        = var.ami_id
  key_name      = var.key_name
}
 
resource "aws_s3_bucket_object" "tf_zip_upload" {
bucket = var.artifact_bucket
key = "terraform.zip"
source = "terraform.zip"
etag = filemd5("terraform.zip")
}
 
resource "aws_servicecatalog_portfolio" "demo_portfolio" {
  name          = "DevOps Demo Portfolio"
  description   = "Contains EC2 and S3 Terraform deployment"
  provider_name = "DevOps Team"
}
 
resource "aws_servicecatalog_product" "demo_product" {
  name  = "EC2 and S3 Terraform Product"
  owner = "DevOps Team"
  type  = "EXTERNAL"
 
  provisioning_artifact_parameters {
    name        = "v1"
    description = "Initial version"
    type        =  "EXTERNAL"
    template_url = "https://${var.artifact_bucket}.s3.amazonaws.com/terraform.zip"
    disable_template_validation = true
  }
    
}
 
resource "aws_servicecatalog_product_portfolio_association" "assoc" {
portfolio_id = aws_servicecatalog_portfolio.demo_portfolio.id
product_id = aws_servicecatalog_product.demo_product.id
}
 
resource "aws_servicecatalog_principal_portfolio_association" "user_assoc" {
portfolio_id = aws_servicecatalog_portfolio.demo_portfolio.id
principal_arn = var.end_user_arn
}
resource "aws_iam_role" "service_catalog_role" {
  name = "ServiceCatalogRole"
 
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
Service = "servicecatalog.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
 
# 2. Create IAM Role Policy with permissions for Service Catalog
resource "aws_iam_role_policy" "service_catalog_policy" {
  name = "ServiceCatalogPolicy"
role = aws_iam_role.service_catalog_role.id
 
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "arn:aws:sqs:us-west-1:123456789012:ServiceCatalogProvisionQueue"
      },
      {
        Effect   = "Allow"
        Action   = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:us-west-1:123456789012:function:ServiceCatalogExternalProvisioningLambda"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::my-bucket-name/*"
      }
    ]
  })
}
 
# 3. Create SQS Queue for Service Catalog Provisioning
resource "aws_sqs_queue" "service_catalog_queue" {
  name = "ServiceCatalogProvisionQueue"
 
  # Optional: Add attributes for the queue
  fifo_queue       = false
  delay_seconds    = 0
  message_retention_seconds = 86400
}
 
# 4. Create IAM Policy for Lambda Invoke Permissions
resource "aws_iam_role_policy" "lambda_invoke_permission" {
  name = "LambdaInvokePermission"
role = aws_iam_role.service_catalog_role.id
 
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = "arn:aws:lambda:us-west-1:123456789012:function:ServiceCatalogExternalProvisioningLambda"
      }
    ]
  })
}
 
# 5. IAM Policy for SQS permissions
resource "aws_iam_policy" "sqs_policy" {
  name        = "ServiceCatalogSQSPolicy"
  description = "Allow Service Catalog to interact with the SQS queue"
 
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.service_catalog_queue.arn
      }
    ]
  })
}
 
# 6. Attach SQS Policy to IAM Role
resource "aws_iam_policy_attachment" "attach_sqs_policy" {
  name       = "AttachSQSServiceCatalogPolicy"
  policy_arn = aws_iam_policy.sqs_policy.arn
roles = [aws_iam_role.service_catalog_role.name]
}
 
# Optional: 7. IAM Policy to allow Service Catalog to interact with EC2 (if needed for provisioning)
resource "aws_iam_policy" "ec2_policy" {
  name        = "ServiceCatalogEC2Policy"
  description = "Allow Service Catalog to interact with EC2"
 
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      }
    ]
  })
}
 
# Optional: 8. Attach EC2 Policy to IAM Role
resource "aws_iam_policy_attachment" "attach_ec2_policy" {
  name       = "AttachEC2ServiceCatalogPolicy"
  policy_arn = aws_iam_policy.ec2_policy.arn
roles = [aws_iam_role.service_catalog_role.name]
}
