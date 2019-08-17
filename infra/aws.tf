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
  domain_name = "alltheclouds.app"
  subject_alternative_names = [
    "www.alltheclouds.app"
  ]
  validation_method = "DNS"

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