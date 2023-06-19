variable "mykey" {
  default = "XXXXXXXX"
}

variable "instancetype" {
  default = "t3a.medium"
}
variable "tag" {
  default = "Jenkins_Server"
}
variable "jenkins-sg" {
  default = "jenkins-server-sec-gr"
}

variable "user" {
  default = "XXXXXx"
}