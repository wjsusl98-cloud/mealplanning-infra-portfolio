variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "project_name" { type = string }
variable "operations_security_group_id" { type = string }
variable "eks_node_security_group_id" { type = string }
variable "bedrock_model_arns" {
  type        = list(string)
  description = "Approved model ARN list only."
}
