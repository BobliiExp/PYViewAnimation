Pod::Spec.new do |s|
  pod_name       = "CustomAnimation"
  name           = "#{pod_name}"
  url            = "https://github.com/BobliiExp/#{name}"
  git_url        = "#{url}.git"
  version        = "1.0.0"
  source_files   = "#{pod_name}/#{pod_name}/Classes/*.{json, swift, txt}"

  s.name         = name
  s.version      = version
  s.summary      = "PY for iOS"
  s.description  = <<-DESC
                  The PY framework is designed to work seamlessly with your existing apps and projects.
                  you can simply add the pod your project.
                    
                    DESC

  s.homepage     = url
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Bob Lee" => "boblii@hotmail.com" }
  s.source       = { :git => git_url, :tag => s.version.to_s}
  

  s.ios.deployment_target = '9.0'
  s.requires_arc = true
  s.frameworks = 'Foundation'

end
