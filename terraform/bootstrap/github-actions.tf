module "github_actions_role" {
  source = "../modules/github-actions-role"
}

output "github_actions_role_arn" {
  value = module.github_actions_role.role_arn
}
