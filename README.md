# Deployment Steps

* ## Create ACM Certs for CDN in N.virgina

* ## Configure aws profile in your local machine with respect to terraform provider

* ## Configure mlm-preprod.tfvars

* ## Initialize, Plan and Apply Terraform scripts

``` hcl
For e.g. preprod enviornment:

terraform init
terraform workspace select preprod
terraform plan --var-file=mlm-preprod.tfvars --out=preprod
terraform apply --var-file=mlm-preprod.tfvars

```

