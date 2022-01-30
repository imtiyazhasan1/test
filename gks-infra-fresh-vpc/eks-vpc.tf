# data "aws_availability_zones" "available" {}

###### AWS VPC ######
resource "aws_vpc" "eksVPC" {
  cidr_block           = var.eks_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags,
    {
      Name                                        = var.vpc_name
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      Managed-by                                  = "Terraform"
    }
  )
}
#*******----- end resource -----********

##### AWS VPC Private Subnet ####
resource "aws_subnet" "eksVpcSubnet" {
  count             = var.count_subnet
  vpc_id            = aws_vpc.eksVPC.id
  cidr_block        = element(cidrsubnets(var.eks_cidr_block, 8, 8, 8, 8, 8, 8, 8, 8), count.index + 1)
  availability_zone =  var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags,
    {
      Name                                        = "${var.vpc_name}-private-subnet-${count.index + 1}"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"           = 1
      Managed-by                                  = "Terraform"
    }
  )
}
#*******----- end resource -----********


##### AWS VPC Route Table ####
resource "aws_route_table" "eksVpcRouteTable" {
  count  = var.count_subnet
  vpc_id = aws_vpc.eksVPC.id

  tags = merge(local.common_tags,
    {
      Name       = "${var.vpc_name}-private-route-table-${count.index + 1}"
      Managed-by = "Terraform"
    }
  )
}

resource "aws_route" "eksVpcRouteTableRoute" {
  count  = var.count_subnet
  route_table_id         = "${element(aws_route_table.eksVpcRouteTable.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${element(aws_nat_gateway.nat.*.id, count.index)}"
}

##### AWS VPC Route Table Associate with subnet ####
resource "aws_route_table_association" "eksVpcRouteTableAttach" {
  count          = var.count_subnet
  subnet_id      = aws_subnet.eksVpcSubnet[count.index].id
  route_table_id = "${element(aws_route_table.eksVpcRouteTable.*.id, count.index)}"
}

resource "aws_network_acl" "eksVpcACL" {
  vpc_id = aws_vpc.eksVPC.id


  tags = merge(local.common_tags,
    {
      Managed-by = "Terraform"
    }
  )
}
#*******----- end resource -----********

##############################################################################################################

##### Internet gateway for the public subnet 
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.eksVPC.id
  tags = merge(local.common_tags,
    {
      Name       = "${var.vpc_name}-Internet-Gateway"
      Managed-by = "Terraform"
    }
  )
}

##### Elastic IP for NAT 
resource "aws_eip" "nat_eip" {
  count  = var.count_subnet
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
}

##### NAT Gateway
resource "aws_nat_gateway" "nat" {
  count      = var.count_subnet
  depends_on    = [aws_internet_gateway.ig]
  allocation_id = "${element(aws_eip.nat_eip.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.eksVpcPublicSubnet.*.id, count.index)}"
  tags = merge(local.common_tags,
    {
      Name       = "${var.vpc_name}-Nat-Gateway-${count.index + 1}"
      Managed-by = "Terraform"
    }
  )
}

##### AWS VPC Private Subnet ####
resource "aws_subnet" "eksVpcPublicSubnet" {
  count             = var.count_subnet
  vpc_id            = aws_vpc.eksVPC.id
  cidr_block        = element(cidrsubnets(var.eks_cidr_block, 8, 8, 8, 8, 8, 8, 8, 8), count.index + var.count_subnet + 1)
  availability_zone =  var.availability_zones[count.index]
  map_public_ip_on_launch = true
  

  tags = merge(local.common_tags,
    {
      Name                                        = "${var.vpc_name}-public-subnet-${count.index + 1}"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/elb"           = 1
      Managed-by                                  = "Terraform"
    }
  )
}
#*******----- end resource -----********

##### AWS VPC Route Table ####
resource "aws_route_table" "eksVpcPublicRouteTable" {
  vpc_id = aws_vpc.eksVPC.id

  tags = merge(local.common_tags,
    {
      Name       = "${var.vpc_name}-public-route-table"
      Managed-by = "Terraform"
    }
  )
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.eksVpcPublicRouteTable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

##### AWS VPC Route Table Associate with subnet ####
resource "aws_route_table_association" "eksVpcPublicRouteTableAttach" {
  count          = var.count_subnet
  subnet_id      = aws_subnet.eksVpcPublicSubnet[count.index].id
  route_table_id = aws_route_table.eksVpcPublicRouteTable.id
}


############################ASSIGN ADDITIONAL PRIVATE SUBNETS#############################################################################


##### AWS VPC Additional Private Subnet ####
resource "aws_subnet" "eksVpcAdditionalPrivateSubnet" {
  count             = length(var.additional_subnets_cidr_block)
  vpc_id            = aws_vpc.eksVPC.id
  cidr_block        = var.additional_subnets_cidr_block[count.index]
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  

  tags = merge(local.common_tags,
    {
      Name                                        = "${var.vpc_name}-additional-private-subnet-${count.index + 1}"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"           = 1
      Managed-by                                  = "Terraform"
    }
  )
}
#*******----- end resource -----********

resource "aws_route_table_association" "eksVpcAdditionalPrivateSubnetRouteTableAttach" {
  count          = length(var.additional_subnets_cidr_block)
  subnet_id      = aws_subnet.eksVpcAdditionalPrivateSubnet[count.index].id
  route_table_id = "${element(aws_route_table.eksVpcRouteTable.*.id, 0)}"
}