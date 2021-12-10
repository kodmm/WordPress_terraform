variable "access_key" {}
variable "secret_key" {}

variable "username" {
  description = "username for mariaDB"
  type        = string
  default     = "root"
}
variable "password" {
  description = "password for mariaDB"
  type        = string
  default     = "ここにご自身で考えたパスワードを入力してくだいさい。"
}

variable "ami" {
  description = "Ubuntu Server 20.04 LTS (HVM)"
  type        = string
  default     = "ami-036d0684fc96830ca"
}

variable "ssh_key_file" {}