provider "aws" {
  # Credentials should be picked from ~/.aws/credentials
  region     = "us-east-1"
}

#variables start
variable "cidrblk" {
  type = "string"
  default = "10.0.0.0/16"
}

variable "pubsubblk" {
  type = "string"
  default = "10.0.1.0/24"
}

variable "prvsubblk1" {
  type = "string"
  default = "10.0.2.0/24"
}

variable "prvsubblk2" {
  type = "string"
  default = "10.0.3.0/24"
}

variable "key_name" {
  type = "string"
  default = "nginx_kp"
}

variable "ami_id" {
  type = "string"
  default = "ami-cd0f5cb6"
}

# main vpc
resource "aws_vpc" "main_vpc" {
  cidr_block = "${var.cidrblk}"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "useastvpc"
  }
}

resource "aws_subnet" "public_subnet_us_east_1a" {
  vpc_id                  = "${aws_vpc.main_vpc.id}"
  cidr_block              = "${var.pubsubblk}"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
  tags = {
  	Name =  "Subnet public az 1a"
  }
}

resource "aws_subnet" "private_1_subnet_us_east_1b" {
  vpc_id                  = "${aws_vpc.main_vpc.id}"
  cidr_block              = "${var.prvsubblk1}"
  availability_zone = "us-east-1b"
  tags = {
  	Name =  "Subnet private 1 az 1b"
  }
}
 
resource "aws_subnet" "private_2_subnet_us_east_1c" {
  vpc_id                  = "${aws_vpc.main_vpc.id}"
  cidr_block              = "${var.prvsubblk2}"
  availability_zone = "us-east-1c"
  tags = {
  	Name =  "Subnet private 2 az 1c"
  }
}
#create internet gateway
resource "aws_internet_gateway" "vpcigw" {
  vpc_id = "${aws_vpc.main_vpc.id}"
  tags {
        Name = "InternetGateway"
    }
}
#Add igw route to main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.main_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.vpcigw.id}"
}


resource "aws_eip" "tuto_eip" {
  vpc      = true
  depends_on = ["aws_internet_gateway.vpcigw"]
}

#Allows the instances in private subnets to connect to internet for downloading packages
resource "aws_nat_gateway" "nat" {
    allocation_id = "${aws_eip.tuto_eip.id}"
    subnet_id = "${aws_subnet.public_subnet_us_east_1a.id}"
    depends_on = ["aws_internet_gateway.vpcigw"]
}

resource "aws_route_table" "private_route_table" {
    vpc_id = "${aws_vpc.main_vpc.id}"

    tags {
        Name = "Private route table"
    }
}

resource "aws_route" "private_route" {
	route_table_id  = "${aws_route_table.private_route_table.id}"
	destination_cidr_block = "0.0.0.0/0"
	nat_gateway_id = "${aws_nat_gateway.nat.id}"
}

# Associate subnet public_subnet_eu_west_1a to public route table
resource "aws_route_table_association" "public_subnet_us_east_1a_association" {
    subnet_id = "${aws_subnet.public_subnet_us_east_1a.id}"
    route_table_id = "${aws_vpc.main_vpc.main_route_table_id}"
}

# Associate subnet private_1_subnet_eu_west_1a to private route table
resource "aws_route_table_association" "pr_1_subnet_us_east_1b_association" {
    subnet_id = "${aws_subnet.private_1_subnet_us_east_1b.id}"
    route_table_id = "${aws_route_table.private_route_table.id}"
}

# Associate subnet private_2_subnet_eu_west_1a to private route table
resource "aws_route_table_association" "pr_2_subnet_us_east_1c_association" {
    subnet_id = "${aws_subnet.private_2_subnet_us_east_1c.id}"
    route_table_id = "${aws_route_table.private_route_table.id}"
}


resource "aws_security_group" "elb" {
  name        = "elb_sg"
  description = "Used in the terraform"

  vpc_id = "${aws_vpc.main_vpc.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ensure the VPC has an Internet gateway or this step will fail
  depends_on = ["aws_internet_gateway.vpcigw"]
  
}

resource "aws_security_group" "bastionhost" {
  name        = "ec2_pubbsh_sg"
    vpc_id = "${aws_vpc.main_vpc.id}"
    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = ["aws_internet_gateway.vpcigw"]
  
}

resource "aws_security_group" "pub" {
  name        = "ec2_pub_sg"
  description = "Used in the terraform"

  vpc_id = "${aws_vpc.main_vpc.id}"
    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
      ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.cidrblk}"]
  }
    # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = ["aws_internet_gateway.vpcigw"]
  
}

resource "aws_security_group" "prv" {
  name        = "ec2_prv_sg"
  description = "Used in the terraform"

  vpc_id = "${aws_vpc.main_vpc.id}"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.cidrblk}"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.cidrblk}"]
	}
 ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["${var.cidrblk}"]
  }

# outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = ["aws_internet_gateway.vpcigw"]
  
}


resource "aws_elb" "weblb" {
  name = "webapp-elb"

  # The same availability zone as our instance
  subnets = ["${aws_subnet.public_subnet_us_east_1a.id}", "${aws_subnet.private_1_subnet_us_east_1b.id}", "${aws_subnet.private_2_subnet_us_east_1c.id}"]

  security_groups = ["${aws_security_group.elb.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }
  instances                   = ["${aws_instance.webpub.id}", "${aws_instance.webprv1.id}", "${aws_instance.webprv2.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  
  tags {
    Name = "webapp-elb"
  }
}

resource "aws_elb" "weblb2" {
  name = "webapp-elb2"

  # The same availability zone as our instance
  subnets = ["${aws_subnet.private_1_subnet_us_east_1b.id}", "${aws_subnet.private_2_subnet_us_east_1c.id}"]

  security_groups = ["${aws_security_group.elb.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }
  instances                   = ["${aws_instance.webprv1.id}", "${aws_instance.webprv2.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  
  tags {
    Name = "webapp-elb2"
  }
}



resource "aws_instance" "webprv1" {
  instance_type = "t2.micro"
  ami = "${var.ami_id}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.prv.id}"]
  subnet_id              = "${aws_subnet.private_1_subnet_us_east_1b.id}"
  user_data              = "${file("userdata.sh")}"
  tags {
    Name = "webserverprv1"
  }
}
resource "aws_instance" "webprv2" {
  instance_type = "t2.micro"
  ami = "${var.ami_id}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.prv.id}"]
  subnet_id              = "${aws_subnet.private_2_subnet_us_east_1c.id}"
  user_data              = "${file("userdata.sh")}"
  tags {
    Name = "webserverprv2"
  }
}
resource "aws_instance" "webpub" {
  instance_type = "t2.micro"
  ami = "${var.ami_id}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.pub.id}"]
  subnet_id              = "${aws_subnet.public_subnet_us_east_1a.id}"
  user_data              = "${file("userdata.sh")}"
  tags {
    Name = "webserverpub"
  }
}

resource "aws_instance" "bastionhost" {
  instance_type = "t2.micro"
  ami = "${var.ami_id}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.bastionhost.id}"]
  subnet_id              = "${aws_subnet.public_subnet_us_east_1a.id}"
  user_data              = "${file("userdata.sh")}"
  tags {
    Name = "bastionhost"
  }
}
resource "aws_route53_zone" "webapp" {
  name = "webapp.com"
}
resource "aws_route53_record" "webapp" {
  zone_id = "${aws_route53_zone.webapp.zone_id}"
  name    = "www"
  type    = "CNAME"
  ttl     = "5"
  set_identifier = "prod"
  weighted_routing_policy {
    weight = 50
  }
  records        = ["${aws_elb.weblb.dns_name}"]
}
resource "aws_route53_record" "webapp2" {
  zone_id = "${aws_route53_zone.webapp.zone_id}"
  name    = "www"
  type    = "CNAME"
  ttl     = "5"
  set_identifier = "prod"
  weighted_routing_policy {
    weight = 50
  }
  records        = ["${aws_elb.weblb2.dns_name}"]
}

module "admin-sns-email-topic" {
    source = "github.com/deanwilson/tf_sns_email"

    display_name  = "WebApp health Check Notifications"
    email_address = "amjadhussain3751@gmail.com"
    owner         = "Amjad"
    stack_name    = "admin-sns-email"
}

resource "aws_cloudwatch_metric_alarm" "webappalarm" {
  alarm_name = "webapphealthcheckalarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "HealthCheckStatus"
  namespace = "AWS/Route53"
  period = "60"
  statistic = "Minimum"
  threshold = "0"
  alarm_description = "This metric monitor whether the app is down or not."
  alarm_actions = ["${module.admin-sns-email-topic.arn}"]
  insufficient_data_actions = []
}

resource "aws_route53_health_check" "webapp-hc" {
  fqdn = "${aws_elb.weblb.dns_name}"
  port = 80
  type = "TCP"
  failure_threshold = "3"
  request_interval = "30"
  measure_latency = 1
  cloudwatch_alarm_name = "${aws_cloudwatch_metric_alarm.webappalarm.alarm_name}"
  cloudwatch_alarm_region = "us-east-1"
}