
Pod::Spec.new do |s|


  s.name         = "KKHttp"
  s.version      = "1.0.2"
  s.summary      = "HTTP"
  s.description  = "HTTP, 支持 JavascriptCore"

  s.homepage     = "https://github.com/hailongz/KKHttp"
  s.license      = "MIT"
  s.author       = { "zhang hailong" => "hailongz@qq.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/hailongz/KKHttp.git", :tag => "#{s.version}" }

  s.vendored_frameworks = 'KKHttp.framework'
  s.requires_arc = true

end
