# Génération automatique des clés SSH pour chaque instance
resource "tls_private_key" "instance_keys" {
  for_each = toset(var.instance_names)  # Crée une clé pour chaque instance

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "instance_keys" {
  for_each = toset(var.instance_names)  # Crée une paire de clés pour chaque instance

  key_name   = each.key
  public_key = tls_private_key.instance_keys[each.key].public_key_openssh
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
    for_each = each.value == "CI/CD" ? [
      { from_port = 8080, to_port = 8080, protocol = "tcp" },
      { from_port = 9000, to_port = 9000, protocol = "tcp" }
    ] : each.value == "Prod" || each.value == "Prod-2" ? [
      { from_port = 8080, to_port = 8080, protocol = "tcp" },
      { from_port = 8000, to_port = 8000, protocol = "tcp" }
    ] : each.value == "Test" ? [
      { from_port = 22, to_port = 22, protocol = "tcp" }
    ] : each.value == "Monitoring" ? [
      { from_port = 22, to_port = 22, protocol = "tcp" }
    ] : each.value == "BDD" ? [
      { from_port = 3306, to_port = 3306, protocol = "tcp" },  
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
    monitoring ansible_host=${aws_instance.my_instances[0].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=~/.ssh/monitoring_key
    bdd ansible_host=${aws_instance.my_instances[1].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=~/.ssh/bdd_key
    prod ansible_host=${aws_instance.my_instances[2].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=~/.ssh/prod_key
    prod-2 ansible_host=${aws_instance.my_instances[3].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=~/.ssh/prod-2_key
    test ansible_host=${aws_instance.my_instances[4].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=~/.ssh/test_key
    cicd ansible_host=${aws_instance.my_instances[5].public_ip} ansible_user=ubuntu ansible_connection=ssh ansible_ssh_private_key_file=~/.ssh/cicd_key

    [all:vars]
    ansible_python_interpreter=/usr/bin/python3
  EOF

  # Le fichier sera stocké à la racine du projet
  filename = "./inventory.ini"
}
