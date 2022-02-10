provider "aws" {
  region = "eu-north-1"
}
resource "aws_vpc" "myvpc" {
    cidr_block = "192.168.0.0/16"
    instance_tenancy = "default"
    enable_dns_hostnames = "true"
    tags = {
        Name = "myvpct4"
    }
}

resource "aws_subnet" "subnet1-wp" {
    depends_on = [ aws_vpc.myvpc ]
    vpc_id     = "{aws_vpc.myvpc.id}"
    cidr_block =  "192.168.1.0/24"
    availability_zone = "eu-north-1"
    map_public_ip_on_launch = true
    tags = {
        Name = "wp-subnet"
    }
}  

resource "aws_internet_gateway" "mygw" {
    depends_on = [ aws_vpc.myvpc ]
    vpc_id = "${aws_vpc.myvpc.id}"
    tags = {
        Name = "myigw"
    }
}

resource "aws_route_table" "route-table" {
    depends_on = [ aws_internet_gateway.mygw ]
    vpc_id = aws_vpc.myvpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.mygw.id}"
    }
    tags = {
        Name = "wproute-table"
    }
}

resource "aws_security_group" "sg1" {
  depends_on = [ aws_vpc.myvpc ]
  name        = "sg1-public"
  description = "Allow inbound traffic ssh and http"
  vpc_id      = aws_vpc.myvpc.id
  
  # SSH from all
  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound All
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "allow_ssh_httpd"
  }
  
}

resource "aws_subnet" "subnet2-mysql" {
  depends_on  = [ aws_vpc.myvpc ]
  vpc_id      = aws_vpc.myvpc.id
  cidr_block  = "192.168.2.0/24"
  availability_zone = "eu-north-1"
  tags = {
    Name = "sql=subnet"
  }
}

resource "aws_security_group" "sg2-mysql" {
  depends_on = [ aws_vpc.myvpc ]
  name        = "sg1-private"
  description = "Allow inbound traffic mysql from public subnet security group"
  vpc_id      = "{aws_vpc.myvpc.id}"
  
  ingress {
    description = "allow ssh"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [ aws_security_group.sg1.id ]
  }
  
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "allow_ssh_httpd"
  }
  
}

resource "aws_eip" "elastic_ip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = "${aws_eip.elastic_ip.id}"
  subnet_id     = "${aws_subnet.subnet1-wp.id}"
  depends_on    = [ aws_internet_gateway.mygw ]
}

resource "aws_route_table" "nat-rtable" {
  vpc_id = "${aws_vpc.myvpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat_gw.id}"
  }
  tags = {
    Name = "nat-routetable"
  }
}

resource "aws_route_table_association" "nat-b" {
  subnet_id = aws_subnet.subnet2-mysql.id
  route_table_id = aws_route_table.nat-rtable.id
}

resource "aws_instance" "wp" {
  depends_on = [aws_security_group.sg1, aws_subnet.subnet1-wp, aws_instance.mysql ]
    ami = "ami-092cce4a19b438926"
    instance_type = "t2.micro"
  

  vpc_security_group_ids = [ aws_security_group.sg1.id ]
  subnet_id = aws_subnet.subnet1-wp.id
  associate_public_ip_address = "true"
  key_name = "second_hope"

  tags = {
    Name = "wordpress"
  }
}

resource "aws_instance" "mysql" {
  depends_on = [ aws_security_group.sg2-mysql,aws_subnet.subnet2-mysql ]
  ami = "ami-092cce4a19b438926"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.sg2-mysql.id ]
  subnet_id = aws_subnet.subnet2-mysql.id

  tags = {
    Name = "mysql"
  }
}

resource "aws_instance" "bastion-host" {
  ami = "ami-092cce4a19b438926"
  instance_type = "t2.micro"
  key_name = "second_hope"
  availability_zone = "eu-north-1"
  subnet_id = "${aws_subnet.subnet1-wp.id}"
  vpc_security_group_ids = [ "${aws_security_group.bastion-sg.id}" ]
  tags = {
    Name = "bastion-host"
  }
}1
