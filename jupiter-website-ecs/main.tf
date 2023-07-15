# configure aws provider
provider "aws" {
  region    = var.region
  profile   = "default"
}

# create VPC
module "vpc" {
  source                        = "../modules/vpc"
  region                        = var.region
  project_name                  = var.project_name
  vpc_cidr                      = var.vpc_cidr
  public_subnet_az1_cidr        = var.public_subnet_az1_cidr
  public_subnet_az2_cidr        = var.public_subnet_az2_cidr
  private_app_subnet_az1_cidr   = var.private_app_subnet_az1_cidr
  private_app_subnet_az2_cidr   = var.private_app_subnet_az2_cidr
}

# create nat gateways
module "nat_gateway" {
  source                      = "../modules/nat-gateway"
  public_subnet_az1_id        = module.vpc.public_subnet_az1_id
  internet_gateway            = module.vpc.internet_gateway
  public_subnet_az2_id        = module.vpc.public_subnet_az2_id
  vpc_id                      = module.vpc.vpc_id
  private_app_subnet_az1_id   = module.vpc.private_app_subnet_az1_id
  private_app_subnet_az2_id   = module.vpc.private_app_subnet_az2_id
}

# create security groups
module "security_group" {
  source = "../modules/security-groups"
  vpc_id = module.vpc.vpc_id
}

# create iam role
module "ecs_task_execution_role" {
  source        = "../modules/ecs-tasks-execution-role"
  project_name  = module.vpc.project_name
}

# create Application Load Balancer
module "application_load_balancer" {
  source                  = "../modules/alb"
  project_name            = var.project_name
  alb_security_group_id   = module.security_group.alb_security_group_id
  public_subnet_az1_id    = module.vpc.public_subnet_az1_id
  public_subnet_az2_id    = module.vpc.public_subnet_az2_id
  vpc_id                  = module.vpc.vpc_id
}

# create ecs service
module "ecs" {
  source = "../modules/ecs"
  project_name = var.project_name
  ecs_tasks_execution_role_arn = module.ecs_task_execution_role.ecs_tasks_execution_role_arn
  container_image = var.container_image
  region = var.region
  private_app_subnet_az1_id = module.vpc.private_app_subnet_az1_id
  private_app_subnet_az2_id = module.vpc.private_app_subnet_az2_id
  ecs_security_group_id = module.security_group.ecs_security_group_id
  alb_target_group_arn = module.application_load_balancer.alb_target_group_arn
}

# create auto scaling group
module "auto_scaling_group" {
  source            = "../modules/asg"
  ecs_cluster_name  = module.ecs.ecs_cluster_name
  ecs_service_name  = module.ecs.ecs_service_name
}