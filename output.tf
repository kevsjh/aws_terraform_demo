output "iam_user_details" {
  value = module.iam_user.iam_user_arn
}

# keybase_password_decrypt_command
output "iam_user_password" {
  value = module.iam_user.keybase_password_decrypt_command
}

output "lb_dns_name" {
  value = module.nlb.this_lb_dns_name
}