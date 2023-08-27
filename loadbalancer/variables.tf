# Region for the resources
variable "region"{
    default = "ap-southeast-2"
}

variable "template_name"{
    default = "My_image"
}

variable "instance_id" {
    default = "instance"
}

variable "vpc_id"{
    default = "instanceid"
}

variable "security_group_port"{
    default = "5000"
}

variable "access_ip"{
    default = "0.0.0.0/0"
}

variable "instance_id"{
    default = "instanceid"
}

variable "subnet_ids" {
  type    = list(string)
  default = ["sub1", "sub2"]
}
