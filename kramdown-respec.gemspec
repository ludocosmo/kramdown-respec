spec = Gem::Specification.new do |s|
  s.name = 'kramdown-respec'
  s.version = '0.0.0'
  s.summary = "Kramdown extension for generating respec HTML."
  s.description = %{A respec HTML generating backend for Thomas Leitner's "kramdown" markdown parser.  Mostly useful for RFC writers.}
  s.add_dependency('kramdown', '~> 1.14')
  s.files = Dir['lib/*.rb'] + %w(README.md LICENSE kramdown-respec.gemspec)
  s.require_path = 'lib'
  s.executables = ['kramdown-respec']
  s.required_ruby_version = '>= 2.3.0'
  s.authors = ['Ludovic Roux']
  s.email = "ludovic.roux@cosmosoftware.io"
  s.homepage = "http://github.com/ludocosmo/kramdown-respec"
  s.license = 'MIT'
end
