variable "budget_name" {
  description = "Nome do AWS Budget"
  type        = string
}

variable "limit_amount" {
  description = "Limite mensal do Budget em USD"
  type        = number

  validation {
    condition     = var.limit_amount > 0
    error_message = "O limite do Budget deve ser maior que zero."
  }
}

variable "alert_email" {
  description = "E-mail que receberá o alerta de custo"
  type        = string
}