terraform {
  backend "s3" {
    bucket         = "lavanya-bucket001"
    key            = "amplify/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = false
  }
}
