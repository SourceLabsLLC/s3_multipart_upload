# S3MultipartUpload

A client-side library for uploading very large files to S3.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 's3_multipart_upload'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install s3_multipart_upload

## Usage

### Configuration

#### S3

```ruby
S3MultipartUpload.config do |c|
  c.s3.bucket_name = "S3_BUCKET"
  c.s3.key = "S3_KEY"
  c.s3.secret = "S3_SECRET"
end
```

#### Google Drive

```ruby
S3MultipartUpload.config do |c|
  c.gd.client_email = "GD_CLIENT_EMAIL"
  c.gd.private_key = "GD_PRIVATE_KEY"
  c.gd.secret = "GD_SECRET"
end
```

### Direct Upload

Require S3MultipartUpload JS in your application.js

```
//= require s3-multipart-upload
```

The library has dependency on [JQuery](http://jquery.com/), [Underscore.js](http://underscorejs.org/) and [Bacon.js](https://baconjs.github.io/)

Mount S3MultipartUpload Engine in your routes.rb

```
mount S3MultipartUpload::Engine, at: "/s3multipart", as: "s3_multipart"
```

In order to use S3 request signing link, use the following (for the above mounted engine)

```
s3_multipart.sign_request_path
```

### Upload via Google Drive Share URL

```ruby
  S3MultipartUpload.upload_from_google_drive "GOOGLE_DRIVE_SHARE_URL", "S3_UPLOAD_PATH"
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/s3_multipart_upload/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
