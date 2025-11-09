
####Defining basic network components####
resource "aws_vpc" "main" {
  cidr_block = var.VPC_CIDR_Block
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags = {
        Name = "main_vpc"
    }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_a_CIDR_Block
  availability_zone = var.private_subnet_a_AZ
    tags = {
        Name = "private_subnet"
    }
    depends_on = [ aws_vpc.main ]
}   

resource "aws_subnet" "private_subnet_b" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnet_b_CIDR_Block
    availability_zone = var.private_subnet_b_AZ
    tags = {
      Name="Privaet_subnet_b"
    }
    depends_on = [ aws_vpc.main ]
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_CIDR_Block
  availability_zone = var.public_subnet_a_AZ
  map_public_ip_on_launch = true

    tags = {
        Name = "public_subnet"
    }   
    depends_on = [ aws_vpc.main ]
}

resource "aws_internet_gateway" "public_subnet_igw" {
    vpc_id = aws_vpc.main.id
        tags = {
            Name = "public_subnet_igw"
        }
        depends_on = [ aws_subnet.public_subnet ]

}

resource "aws_eip" "nat_eip" {
    domain = "vpc"
        tags = {
            Name = "nat_eip"
        }
}

resource "aws_nat_gateway" "private_subnet_natgw" {
    subnet_id = aws_subnet.public_subnet.id
    allocation_id = aws_eip.nat_eip.id
        tags = {
            Name = "private_subnet_natgw"
        }
        depends_on = [ aws_internet_gateway.public_subnet_igw, aws_eip.nat_eip ]
}
####Defining route tables and associations####
resource "aws_route_table" "public_subnet_to_igw" {
    vpc_id = aws_vpc.main.id
        tags = {
            Name = "public_subnet_to_igw"
        }
        route {
            cidr_block = "0.0.0.0/0"
            gateway_id = aws_internet_gateway.public_subnet_igw.id
        }
        depends_on = [ aws_internet_gateway.public_subnet_igw ]
}

resource "aws_route_table_association" "public_subnet_rta" {
    subnet_id      = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.public_subnet_to_igw.id
}

resource "aws_route_table" "private_subnet_to_natgw" {
    vpc_id = aws_vpc.main.id
        tags = {
            Name = "private_subnet_to_natgw"
        }
        route {
            cidr_block = "0.0.0.0/0"
            nat_gateway_id = aws_nat_gateway.private_subnet_natgw.id  
    }
depends_on = [ aws_nat_gateway.private_subnet_natgw ]
}

resource "aws_route_table_association" "private_subnet_rta" {
    subnet_id      = aws_subnet.private_subnet.id
    route_table_id = aws_route_table.private_subnet_to_natgw.id
}