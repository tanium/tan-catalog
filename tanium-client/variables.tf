variable "client_ipv4_address" {
  description = "Hostname/ip-address of target machine to install Tanium client"
}

variable "user" {
  default = "root"
  description = "Username"
}

variable "private_key" {
  description = "SSH private-key content"
}

variable "pass" {
  default=""
  description = "Password"
}

variable "server_ipv4_address" {
  description= "Tanium Server Hostname/ip-address"
}

variable "tanium_client_files_folder" {
  description = "Tanium client-files folder name. Eg:cos-bucket-name/path/to/tanium-client-files-folder"
}

variable "cos_bucket_public_endpoint" {
  description = "COS bucket public endpoint"
}

variable "cos_bucket_apikey" {
  description = "COS bucket API key"
}

variable "TF_VERSION" {
  default = "0.12"
  description = "Schematics Terraform version"
}