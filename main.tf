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
  type  = "TERRAFORM_OPEN_SOURCE"
 
  provisioning_artifact_parameters {
    name        = "v1"
    description = "Initial version"
    type        = "TERRAFORM_OPEN_SOURCE"
    template_url = "https://${var.artifact_bucket}.s3.amazonaws.com/terraform.zip"
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
