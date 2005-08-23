class MyBenchmark < RailsBenchmarkWithActiveRecordStore
  def establish_test_session
    if ARGV.include?('-mysql_session')
      unless test_session = @session_class.find_session(@session_id)
        s_data = marshal( @session_data )
        test_session = @session_class.create_session(@session_id, s_data)
        test_session.update_session(s_data)
      end
    else
      super
    end
  end
  private 
  def marshal(data)
    Base64.encode64(Marshal.dump(data))
  end
end

RAILS_BENCHMARKER = MyBenchmark.new(:session_id_column => 'sessid')

require 'user'
RAILS_BENCHMARKER.session_data = {'account' => User.find_first("name='stefan'")}
