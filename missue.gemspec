Gem::Specification.new do |s|
  s.name        = 'missue'
  s.version     = '1.0.2'
  s.summary     = "Migrate github issues like a boss!"
  s.description = "List, migrate and batch copy issues and labels across github repos with links to original authors and issues."
  s.authors     = ["E3V3A"]
  s.email       = 'xdae3v3a@gmail.com'
  s.bindir      = 'bin'
  s.files       = ["bin/missue.rb"]
  s.executables << 'missue.rb'
  s.homepage    = 'https://github.com/E3V3A/gh-missue'
  s.license     = 'MIT'
  s.post_install_message = "Thanks! Now you can migrate like a boss!"
  s.requirements << 'docopt, oktokit'
  s.required_ruby_version = '>= 2.7.0'
end

# References:
# https://guides.rubygems.org/specification-reference/
# https://rubygems.org/gems/missue
