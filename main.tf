module "iam" {
  source = "github.com/makeen-project/terraform-templates-infra/modules/iam"
  iam_role = [{
    name  = "${var.project_name}-${var.environment}-${var.codebuild_iam_role_name}"
    assume_role_policy = "${file("roles_and_policies/codebuild_project_assume_role.json")}"
  },
  {
    name  = "${var.project_name}-${var.environment}-${var.codepipeline_iam_role_name}"
    assume_role_policy = "${file("roles_and_policies/codepipeline_assume_role.json")}"
  }]
  iam_role_policy = [{
    name = "${var.project_name}-${var.environment}-${var.codebuild_iam_role_name}"
    role_id = "${module.iam.iam_role_id["${var.project_name}-${var.environment}-${var.codebuild_iam_role_name}"]}"
    policy = "${file("roles_and_policies/codebuild_project_policy.json")}"
  },
  {
    name = "${var.project_name}-${var.environment}-${var.codepipeline_iam_role_name}"
    role_id = "${module.iam.iam_role_id["${var.project_name}-${var.environment}-${var.codepipeline_iam_role_name}"]}"
    policy = "${file("roles_and_policies/codepipeline_policy.json")}"
  }]
  environment = var.environment
  project_name = var.project_name  
}

module "codepipeline_s3" {
  source = "github.com/makeen-project/terraform-templates-infra/modules/s3"
  s3_bucket_name = ["${var.codepipeline_bucket_name}"]
  environment = var.environment
  project_name = var.project_name  
}


data "template_file" "s3_bucket_policy" {
  template = "${file("roles_and_policies/s3_bucket_policy.json")}"

  vars = {
    bucket_name     = "${var.project_name}-${var.environment}-${var.mlm_web_bucket_name}"
    aws_cloudfront_origin_access_identity_iam_arn = "${module.cdn.cloudfront_origin_access_identity_iam_arn}"
    environment = "${var.environment}"
    project_name = "${var.project_name}"
  }
}

module "mlm_web_s3" {
  source = "github.com/makeen-project/terraform-templates-infra/modules/s3"
  s3_bucket_name = ["${var.mlm_web_bucket_name}"]
  s3_policy_document = "${data.template_file.s3_bucket_policy.rendered}"
  s3_static_website_vars = {
    index_document = "index.html"
    error_document = null
    redirect_all_requests_to = null
    routing_rules = null
  }
  s3_versioning = {
    enabled = true
    mfa_delete = null
  }
  environment = var.environment
  project_name = var.project_name  
}

data "template_file" "buildspec" {
  template = "${file("buildspec.yaml")}"

  vars = {
    bucket_name     = "${module.mlm_web_s3.bucket_id["${var.mlm_web_bucket_name}"]}"
  }
}

module "cicd"{
    source = "github.com/makeen-project/terraform-templates-infra/modules/cicd"
    codebuild_project = ["${var.codebuild_project_name}"]
    environment = var.environment
    project_name = var.project_name
    service_role                    = module.iam.iam_role_arn["${var.project_name}-${var.environment}-${var.codebuild_iam_role_name}"]
    artifacts = [{
        type = "CODEPIPELINE"
        artifact_identifier         = null
        encryption_disabled         = null
        override_artifact_name      = null
        location                    = null
        name                        = null
        namespace_type              = null
        packaging                   = null
        path                        = null
    }]
    codebuild_environment = [{
        compute_type                = "BUILD_GENERAL1_MEDIUM"
        image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
        type                        = "LINUX_CONTAINER"
        image_pull_credentials_type = "CODEBUILD"
        environment_variable = []
        privileged_mode            = true
        certificate                 = null
    }]
    codebuild_source = [{
        type                        = "CODEPIPELINE"
        auth_type                   = "OAUTH"
        resource                    = null
        buildspec                   = "${data.template_file.buildspec.rendered}"
        git_clone_depth             = null
        fetch_submodules            = false
        insecure_ssl                = null
        location                    = null
        report_build_status         = null
    }]
    codepipeline_project = ["${var.codepipeline_project_name}"]
    role_arn                    = module.iam.iam_role_arn["${var.project_name}-${var.environment}-${var.codepipeline_iam_role_name}"]
    artifact_store = [{
        location = "${var.project_name}-${var.environment}-${var.codepipeline_bucket_name}"
        type = "S3"
        encryption_key = []
        region = null
    }]
    stage = [{
        name = "Source"
        action = [{
            category = "Source"
            owner = "ThirdParty"
            name= "Source"
            provider = "GitHub"
            version = "1"
            configuration  = { 
                OAuthToken = "${var.repo_token}"
                Owner      = "${var.repo_owner}"
                Repo       = "${var.repo_name}"
                Branch     = "${var.repo_branch}"
            }
            input_artifacts = []
            output_artifacts = ["source"]
            role_arn= null
            run_order =null
            region = null
            namespace = null
        }]
    },
    {
        name = "Build"
        action = [{
            category = "Build"
            owner = "AWS"
            name= "Build"
            provider = "CodeBuild"
            version = "1"
            configuration  = {
                ProjectName = "${var.project_name}-${var.environment}-${var.codebuild_project_name}"
            }
            input_artifacts = ["source"]
            output_artifacts = []
            role_arn= null
            run_order =null
            region = null
            namespace = null
        }]
    }]

}



module "cdn" {
    source = "github.com/makeen-project/terraform-templates-infra/modules/cdn"
    distribution_state = true
    default_root_object = "index.html"
    alternate_domain_names = ["preprod.majorleaguemarkets.io"]
    cloudfront_default_cache_behavior = [{
      allowed_http_methods = ["GET", "HEAD"]
      cached_http_methods = ["GET", "HEAD"]
      automatically_compress_objects = true
      default_ttl = 3600
      max_ttl  = 3600
      min_ttl = 0
      smooth_streaming = null
      trusted_signers = []
      target_origin_id = "${module.mlm_web_s3.bucket_id["${var.mlm_web_bucket_name}"]}"
      viewer_protocol_policy = "redirect-to-https"
      forwarded_values = [{
        forward_cookies = "none"
        whitelisted_cookies = []
        forward_query_string = false
        headers = []
      }]
      lambda_function_association = []
    }]
    cloudfront_custom_error_response = [{
      error_code = 403
      response_code = 200
      error_caching_min_ttl = 10
      response_page_path = "/"
    },
    {
      error_code = 404
      response_code = 200
      error_caching_min_ttl = 10
      response_page_path = "/"
    }]
    cloudfront_origin = [{
      custom_origin_config = []
      domain_name = "${module.mlm_web_s3.bucket_domain_name["${var.mlm_web_bucket_name}"]}"
      origin_id = "${module.mlm_web_s3.bucket_id["${var.mlm_web_bucket_name}"]}"
      origin_path = null
    }] 
    restrictions = [{
      locations = []
      restriction_type = "none"
    }] 
    viewer_certificate = [{
      acm_certificate_arn = "${var.acm_arn}"
      cloudfront_default_certificate = false
      minimum_protocol_version = null
      iam_certificate_id = null
      ssl_support_method = "sni-only"
    }]
  environment = var.environment
  project_name = var.project_name  
}