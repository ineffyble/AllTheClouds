provider "aws" {
  version = "~> 2.24"
  region  = "us-east-1"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "alltheclouds"
  acl    = "public-read"
  website {
    index_document = "index.html"
  }
  policy = <<-POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPublicRead",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::alltheclouds/*"
    }
  ]
}
POLICY

}

resource "aws_s3_bucket_object" "index_page" {
  bucket       = aws_s3_bucket.bucket.id
  key          = "index.html"
  content      = templatefile("../frontend/index.html", { cloud_provider = "Amazon Web Services" })
  content_type = "text/html"
}

resource "aws_acm_certificate" "certificate" {
  private_key       = acme_certificate.certificate.private_key_pem
  certificate_body  = acme_certificate.certificate.certificate_pem
  certificate_chain = acme_certificate.certificate.issuer_pem
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.website_endpoint
    origin_id   = aws_s3_bucket.bucket.id

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["alltheclouds.app", "www.alltheclouds.app"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.bucket.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    default_ttl = 300
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.certificate.arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

data "archive_file" "function_source" {
  type = "zip"
  source {
    content = templatefile("../backend/index.js", { cloud_provider = "Amazon Web Services" })
    filename = "index.js"
  }
  output_path = "${path.module}/function.zip"
}

resource "aws_lambda_function" "function" {
  function_name = "AllTheClouds"

  filename = data.archive_file.function_source.output_path
  source_code_hash = filebase64sha256(data.archive_file.function_source.output_path)

  handler = "index.handler"
  runtime  = "nodejs8.10"

  role = aws_iam_role.function_role.arn

}

resource "aws_iam_role" "function_role" {
  name = "alltheclouds_backend_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_api_gateway_rest_api" "api" {
  name        = "AllTheClouds"
  description = "Let's use all the clouds"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.function.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [ aws_api_gateway_integration.lambda ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

resource "aws_lambda_permission" "api_to_function_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name =  aws_lambda_function.function.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_deployment.deployment.execution_arn}/*/*"
}

output "base_url" {
  value = aws_api_gateway_domain_name.domain.regional_domain_name
}

resource "aws_api_gateway_domain_name" "domain" {
  domain_name              = "api.alltheclouds.app"
  regional_certificate_arn = aws_acm_certificate.certificate.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "path_mapping" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_deployment.deployment.stage_name
  domain_name = aws_api_gateway_domain_name.domain.domain_name
}