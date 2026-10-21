output "jenkins_public_ip" {
  value = aws_instance.ec2.public_ip
}

output "jenkins_url" {
  value = "http://${aws_instance.ec2.public_ip}:8080"
}

output "sonarqube_url" {
  value = "http://${aws_instance.ec2.public_ip}:9000"
}

output "ecr_frontend_repo" {
  value = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_repo" {
  value = aws_ecr_repository.backend.repository_url
}
