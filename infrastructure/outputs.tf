output "api_endpoint" {
  value       = "${aws_api_gateway_deployment.prod.invoke_url}/state"
  description = "API Gateway endpoint"
}

output "frontend_bucket_name" {
  value       = aws_s3_bucket.frontend.bucket
  description = "S3 bucket for frontend files"
}

output "frontend_url" {
  value       = "http://${aws_s3_bucket.frontend.bucket}.s3-website-${var.aws_region}.amazonaws.com"
  description = "Frontend S3 website URL"
}