Create security group for LoadBalancer -> source 0.0.0.0.
Create Secutity group for app   -> source Loadbalancer security group

Next
Create Target group
Then Load-balancer (Application LB)

ECS Flow

Cluster -> Task Definition -> Service

Cluster for Infrastructure Setup

Task Definition - defines how your container should run 

Service - deploys container unto cluster and Handles High availability
