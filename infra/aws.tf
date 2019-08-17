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
