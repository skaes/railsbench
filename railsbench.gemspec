# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{railsbench}
  s.version = "0.9.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Stefan Kaes"]
  s.date = %q{2009-08-16}
  s.default_executable = %q{railsbench}
  s.description = %q{rails benchmarking tools}
  s.email = %q{skaes@railsexpress.de}
  s.executables = ["railsbench"]
  s.extra_rdoc_files = ["Manifest.txt", "latest_changes.txt"]
  s.files = ["BUGS", "CHANGELOG", "GCPATCH", "INSTALL", "LICENSE", "Manifest.txt", "PROBLEMS", "README", "Rakefile", "bin/railsbench", "config/benchmarking.rb", "config/benchmarks.rb", "config/benchmarks.yml", "images/empty.png", "images/minus.png", "images/plus.png", "install.rb", "latest_changes.txt", "lib/benchmark.rb", "lib/railsbench/benchmark.rb", "lib/railsbench/benchmark_specs.rb", "lib/railsbench/gc_info.rb", "lib/railsbench/perf_info.rb", "lib/railsbench/perf_utils.rb", "lib/railsbench/railsbenchmark.rb", "lib/railsbench/version.rb", "lib/railsbench/write_headers_only.rb", "postinstall.rb", "ruby184gc.patch", "ruby185gc.patch", "ruby186gc.patch", "ruby19gc.patch", "script/convert_raw_data_files", "script/generate_benchmarks", "script/perf_bench", "script/perf_comp", "script/perf_comp_gc", "script/perf_diff", "script/perf_diff_gc", "script/perf_html", "script/perf_plot", "script/perf_plot_gc", "script/perf_prof", "script/perf_run", "script/perf_run_gc", "script/perf_table", "script/perf_tex", "script/perf_times", "script/perf_times_gc", "script/run_urls", "setup.rb", "test/railsbench_test.rb", "test/test_helper.rb"]
  s.homepage = %q{http://railsbench.rubyforge.org}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{railsbench}
  s.rubygems_version = %q{1.3.3}
  s.summary = %q{rails benchmarking tools}
  s.test_files = ["test/railsbench_test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<hoe>, [">= 1.12.2"])
    else
      s.add_dependency(%q<hoe>, [">= 1.12.2"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 1.12.2"])
  end
end
