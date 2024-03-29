# Rakefile for project management (from chris2)  -*-ruby-*-
require 'rake/testtask'

desc "Run all the tests"
task :default => [:test]

desc "Do predistribution stuff"
task :predist => [:chmod, :changelog, :doc]


desc "Run all the tests"
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['tests/test_*.rb']
  t.verbose = true
end

desc "Make an archive as .tar.gz"
task :dist => :test do
  system "export DARCS_REPO=#{File.expand_path "."}; " +
         "darcs dist -d kashmir#{get_darcs_tree_version}"
end

desc "Make binaries executable"
task :chmod do
  Dir["bin/*"].each { |binary| File.chmod(0775, binary) }
end

desc "Generate a ChangeLog"
task :changelog do
  system "darcs changes --repo=#{ENV["DARCS_REPO"] || "."} >ChangeLog"
end

# Helper to retrieve the "revision number" of the darcs tree.
def get_darcs_tree_version
  return ""  unless File.directory? "_darcs"

  changes = `darcs changes`
  count = 0
  tag = "0.0"
  
  changes.each("\n\n") { |change|
    head, title, desc = change.split("\n", 3)
    
    if title =~ /^  \*/
      # Normal change.
      count += 1
    elsif title =~ /tagged (.*)/
      # Tag.  We look for these.
      tag = $1
      break
    else
      warn "Unparsable change: #{change}"
    end
  }

  "-" + tag + "." + count.to_s
end
