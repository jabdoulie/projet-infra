variable "aws_region" {
  description = "La région AWS dans laquelle déployer les ressources"
  type        = string
  default     = "eu-west-3"  # Par défaut, la région est 'eu-west-3'
}

variable "instance_count" {
  description = "Le nombre d'instances à créer"
  type        = number
  default     = 1  # Par défaut, 1 instance sera créée. Modifiez selon vos besoins.
}

variable "instance_names" {
  description = "Les noms des instances à créer"
  type        = list(string)
  default     = ["Monitoring", "Prod", "CI-CD", "Test", "BDD"]  # Noms d'instances par défaut
}
