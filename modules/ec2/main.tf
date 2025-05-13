resource "aws_instance" "encrypted_ec2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
 
  root_block_device {
    volume_size = 8
    volume_type = "gp2"
    encrypted   = true
  }
 
  tags = {
    Name = "EncryptedEC2Instance"
  }
}
