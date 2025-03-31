# Sortie des clés privées SSH générées pour chaque instance
output "private_keys" {
  description = "Clés privées SSH générées pour l'accès aux instances"
  value       = { for instance_name, key in tls_private_key.instance_keys : instance_name => key.private_key_pem }
  sensitive   = true
}

# Sortie des clés publiques SSH générées pour chaque instance
output "public_keys" {
  description = "Clés publiques SSH générées pour l'accès aux instances"
  value       = { for instance_name, key in tls_private_key.instance_keys : instance_name => key.public_key_openssh }
}

# Sortie des noms des instances créées
output "instance_names" {
  description = "Noms des instances créées"
  value       = [for instance in aws_instance.my_instances : instance.tags["Name"]]
}

# Sortie des noms des groupes de sécurité associés aux instances
output "instance_security_groups" {
  description = "Groupes de sécurité associés à chaque instance"
  value       = { for instance_name, sg in aws_security_group.instance_sgs : instance_name => sg.id }
}

# Sortie des adresses IP publiques des instances créées (si nécessaire)
output "instance_public_ips" {
  description = "Adresses IP publiques des instances créées"
  value       = { for instance in aws_instance.my_instances : instance.tags["Name"] => instance.public_ip }
}

# Sortie des IDs des instances créées
output "instance_ids" {
  description = "IDs des instances créées"
  value       = [for instance in aws_instance.my_instances : instance.id]
}
