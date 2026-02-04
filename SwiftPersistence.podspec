Pod::Spec.new do |s|
  s.name             = 'SwiftPersistence'
  s.version          = '1.0.0'
  s.summary          = 'Data persistence framework with CoreData and SwiftData support.'
  s.description      = 'SwiftPersistence provides unified data persistence with CoreData and SwiftData support.'
  s.homepage         = 'https://github.com/muhittincamdali/SwiftPersistence'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Muhittin Camdali' => 'contact@muhittincamdali.com' }
  s.source           = { :git => 'https://github.com/muhittincamdali/SwiftPersistence.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.swift_versions = ['5.9', '5.10', '6.0']
  s.source_files = 'Sources/**/*.swift'
  s.frameworks = 'Foundation', 'CoreData'
end
