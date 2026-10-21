# The two Docker image repositories (created automatically - no manual work)
# force_delete = true lets "terraform destroy" remove them even if they contain images.
resource "aws_ecr_repository" "frontend" {
  name                 = "frontend"
  force_delete         = true
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "backend" {
  name                 = "backend"
  force_delete         = true
  image_tag_mutability = "MUTABLE"
}
