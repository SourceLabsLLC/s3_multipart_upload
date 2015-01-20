S3MultipartUpload::Engine.routes.draw do
  post "/sign_request" => "signatures#generate", :as => :sign_request
end