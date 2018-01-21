Pod::Spec.new do |s|
  s.name         = "API"
  s.version      = "0.0.1"
  s.summary      = "API module"
  s.description  = <<-DESC
  Mastodon API module for this apps
                   DESC
  s.homepage     = "https://github.com/banjun/imastodon/tree/m@ster/API"
  s.license      = "MIT"
  s.author             = { "banjun" => "banjun@gmail.com" }
  s.social_media_url   = "https://twitter.com/banjun"
  s.ios.deployment_target = "11.0"
  s.osx.deployment_target = "10.13"
  s.source       = { :git => "https://github.com/banjun/imastodon", :tag => "api/#{s.version}" }
  s.source_files  = "API/**/*.swift"
  s.dependency "SwiftBeaker"
end
