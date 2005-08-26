# create benchmarker instance
RAILS_BENCHMARKER = RailsBenchmark.new

# if your session storage is ActiveRecordStore, and if you want
# sessions to be automatically deleted after benchmarking, use
# RAILS_BENCHMARKER = RailsBenchmarkWithActiveRecordStore.new

# WARNING: don't use RailsBenchmarkWithActiveRecordStore running on
# your production database!


# create session data required to run the benchmark
# customize this code if your benchmark needs session data

# require 'user'
# RAILS_BENCHMARKER.session_data = {'account' => User.find_first("name='stefan'")}
