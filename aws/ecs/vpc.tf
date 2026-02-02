# Create a new VPC (Virtual Private Cloud) with a CIDR block
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

# Create an Internet Gateway to allow resources inside the VPC to access the internet
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

# Create two Public Subnets across different Availability Zones
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  # Dynamically divide VPC CIDR block into smaller /24 subnets
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)

  # Automatically assign public IP to instances launched here
  map_public_ip_on_launch = true 

  # Spread subnets across available AZs (e.g., us-west-2a, us-west-2b)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
}

# Fetch the list of available AWS Availability Zones in the region
data "aws_availability_zones" "available" {}

# Create a Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  # Route all outbound traffic (to anywhere)
  route {
    cidr_block = "0.0.0.0/0"
    # Use Internet Gateway to send traffic to internet
    gateway_id = aws_internet_gateway.this.id
  }
}

# Associate each Public Subnet with the Public Route Table
resource "aws_route_table_association" "public" {
  count          = 2 # One association per public subnet
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

