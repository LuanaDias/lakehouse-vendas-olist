variable "alert_email" {
  description = "Email para alertas de billing"
  type        = string
}

variable "emr_key_name" {
  description = "Nome da key pair EC2 para SSH no EMR"
  type        = string
}
