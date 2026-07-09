variable "repository" {
  description = "GitHub repository in format owner/repo"
  type        = string
  default     = "OsahonJay/vaultpay-platform"
}

variable "branch" {
  description = "Branch allowed to assume this role"
  type        = string
  default     = "main"
}
