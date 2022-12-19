# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 's3_multipart_upload/version'

Gem::Specification.new do |spec|
  spec.name          = "s3_multipart_upload"
  spec.version       = S3MultipartUpload::VERSION
  spec.authors       = ["Ali B. Aslam"]
  spec.email         = ["ali@bletchley.co"]
  spec.homepage      = "http://github.com/bletchley/s3_multipart_upload"

  spec.summary       = %q{A library for uploading large files to S3.}

  spec.license       = "MIT"

  spec.files         = Dir["config/**/*", "lib/**/*.rb", "app/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-v1"
  spec.add_dependency "google-api-client", "~> 0.8.6"
  spec.add_dependency "railties"
  spec.add_dependency "coffee-script"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 10.0"
end
