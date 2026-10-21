resource "aws_instance" "ec2" {
  ami = data.aws_ami.ami.image_id
  # t3.large = 2 vCPU, 8 GB RAM (~$0.083/hour). Enough for Jenkins + SonarQube + Docker builds.
  # (t3.medium with 4 GB usually crashes when SonarQube and a React build run together.)
  instance_type          = "t3.large"
  key_name               = var.key-name
  subnet_id              = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = aws_iam_instance_profile.instance-profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  # Installs Java, Jenkins, Docker, SonarQube, AWS CLI, kubectl, eksctl, Helm, Trivy, Node.js
  user_data = templatefile("${path.module}/tools-install.sh", {})

  tags = {
    Name = var.instance-name
  }
}
