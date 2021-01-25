# Deployment Steps

* Create ACM Certs for CDN in N.virgina

* Configure aws profile in your local machine with respect to terraform provider

* Configure tapin-admin-dev.tfvars

* Initialize, Plan and Apply Terraform scripts

``` hcl
For e.g. preprod enviornment:

terraform init
terraform workspace select dev
terraform plan --var-file=tapin-admin.tfvars --out=dev
terraform apply --var-file=tapin-admin.tfvars

```

*  Upload .env to Tapin Admin UI Config Bucket

