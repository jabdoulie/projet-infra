resource "tls_private_key" "instance_keys" {
  for_each = toset(var.instance_names)

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "instance_keys" {
  for_each = toset(var.instance_names)

  key_name   = each.key
  public_key = tls_private_key.instance_keys[each.key].public_key_openssh

}

resource "local_file" "private_key_files" {
  for_each = toset(var.instance_names)

  filename = "../Ansible/keys/${each.key}_private_key.pem"
  content  = tls_private_key.instance_keys[each.key].private_key_pem

  # On s'assure que le répertoire existe avant d'écrire
  directory_permission = "0700"
}

# Création de la VPC
resource "aws_vpc" "dev_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "dev"
  }
}

# Sous-réseau public
resource "aws_subnet" "dev_pub_subnet" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-3a"
  tags = {
    Name = "dev_pub"
  }
}

# Passerelle Internet
resource "aws_internet_gateway" "dev_igw" {
  vpc_id = aws_vpc.dev_vpc.id
  tags = {
    Name = "dev_igw"
  }
}

# Route Table
resource "aws_route_table" "dev_pub_route" {
  vpc_id = aws_vpc.dev_vpc.id
  tags = {
    Name = "dev_rt"
  }
}

# Route
resource "aws_route" "dev_route" {
  route_table_id         = aws_route_table.dev_pub_route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dev_igw.id
}

# Association de la table de routage avec le sous-réseau
resource "aws_route_table_association" "dev_pub_assoc" {
  subnet_id      = aws_subnet.dev_pub_subnet.id
  route_table_id = aws_route_table.dev_pub_route.id
}

# Groupe de sécurité avec règles dynamiques
resource "aws_security_group" "instance_sgs" {
  for_each = toset(var.instance_names)

  name        = "security-group-${each.value}"
  description = "Security group for ${each.value}"
  vpc_id      = aws_vpc.dev_vpc.id

  dynamic "ingress" {
    for_each = each.value == "CI-CD" ? [
      { from_port = 22, to_port = 22, protocol = "tcp" }
    ] : each.value == "Prod" ? [
      { from_port = 22, to_port = 22, protocol = "tcp" }
    ] : each.value == "Test" ? [
      { from_port = 22, to_port = 22, protocol = "tcp" }
    ] : each.value == "Monitoring" ? [
      { from_port = 22, to_port = 22, protocol = "tcp" }
    ] : each.value == "BDD" ? [ 
      { from_port = 22, to_port = 22, protocol = "tcp" }        
    ] : []

    content {
      description = "Access ${each.value}"
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-${each.value}"
  }
}

# Création des instances EC2 avec des clés SSH dynamiques
resource "aws_instance" "my_instances" {
  count               = var.instance_count * length(var.instance_names)  # Nombre d'instances
  ami                 = data.aws_ami.server_ami.id
  instance_type       = "t2.micro"
  key_name            = aws_key_pair.instance_keys[var.instance_names[count.index]].key_name  # Clé SSH spécifique à chaque instance
  vpc_security_group_ids = [aws_security_group.instance_sgs[var.instance_names[count.index]].id]
  subnet_id           = aws_subnet.dev_pub_subnet.id

  tags = {
    Name = var.instance_names[count.index]
  }
}

# Bucket S3
resource "aws_s3_bucket" "dev_s3_bucket" {
  bucket = "my-dev-env-s3"

  tags = {
    Name        = "My bucket"
    Environment = "dev"
  }
}

resource "local_file" "inventory_ini" {
  content = <<-EOF
    [serveurs]
    ${var.instance_names[0]} ansible_host=${aws_instance.my_instances[0].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=./keys/${var.instance_names[0]}_private_key.pem
    ${var.instance_names[1]} ansible_host=${aws_instance.my_instances[1].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=./keys/${var.instance_names[1]}_private_key.pem
    ${var.instance_names[2]} ansible_host=${aws_instance.my_instances[2].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=./keys/${var.instance_names[2]}_private_key.pem
    ${var.instance_names[3]} ansible_host=${aws_instance.my_instances[3].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=./keys/${var.instance_names[3]}_private_key.pem
    ${var.instance_names[4]} ansible_host=${aws_instance.my_instances[4].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=./keys/${var.instance_names[4]}_private_key.pem

    [all:vars]
    ansible_python_interpreter=/usr/bin/python3
  EOF

  # Le fichier sera stocké à la racine du projet
  filename = "../Ansible/inventory.ini"
}

# Appliquer les droits 600 sur les fichiers de clés
resource "null_resource" "chmod_private_keys" {
  provisioner "local-exec" {
    command = <<-EOT
      chmod 600 ../Ansible/keys/*_private_key.pem
    EOT
  }

  # Assurer que la ressource est exécutée après la création du fichier d'inventaire
  depends_on = [local_file.inventory_ini]
}