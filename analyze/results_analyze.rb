# frozen_string_literal: true

require 'csv'

if ARGV.empty?
  puts 'You need to provide report directory path!'
  exit 1
end

report_directory = ARGV[0]
unless Dir.exist? report_directory
  puts "Report directory [#{report_directory}] does not exist."
  exit 1
end

results = Hash.new { |hash, key| hash[key] = {} }



Dir.glob("#{report_directory}/*.report").each do |file|
  name = File.basename(file).split(/_bench.report/).first
  results[name][:total_time] = File.read(file).scan(/Total:\s*((?:\d|\.)+)/)[0][0].to_f
  results[name][:ok_responses] = begin
                                   File.read(file).scan(/\[OK\]\s*(\d+)/)[0][0].to_f
                                 rescue StandardError
                                   0
                                 end
  results[name][:avg_resp_time] = File.read(file).scan(/\s*Average:\s*(.*\w)/)[0][0]
  results[name][:_90pct] = File.read(file).scan(/\s*90 % in \s*(.*\w)/)[0][0]
  results[name][:_95pct] = File.read(file).scan(/\s*95 % in \s*(.*\w)/)[0][0]
  results[name][:_99pct] = File.read(file).scan(/\s*99 % in \s*(.*\w)/)[0][0]
  results[name][:req_per_s] = results[name][:ok_responses] / results[name][:total_time]
end

Dir.glob("#{report_directory}/*.stats").each do |file|
  name = File.basename(file).split(/_bench.stats/).first
  stats = File
          .read(file)
          .scan(/([0-9\.]+)%\s+([0-9\.]+)(\w+)/)[0..-2] # ignore the last sample, not very reliable
          .map { |cpu, memory, mem_unit| [cpu.to_f, memory.to_f * (mem_unit == 'GiB' ? 1024 : 1)] }
          .reject { |cpu, _mem| cpu < 1 }
          .transpose

  results[name][:avg_mem_unit] = 'MiB'

  if stats[0].nil?
    puts "Warning: no stats for #{file}"
    results[name][:avg_cpu] = 0
    results[name][:avg_mem] = 0
  else
    results[name][:avg_cpu] = stats[0].sum / stats[0].length
    results[name][:avg_mem] = stats[1].sum / stats[1].length
  end
end

server=CSV.read("#{report_directory}/energy_server.csv",{ :col_sep => ';' })

CSV.foreach( "#{report_directory}/energy_server.csv",  { headers: true, :col_sep => ';' }) do |row1|
  name = row1["benchmark"].sub! '_bench', ''
  results[name][:avg_power_cpu] = row1["CPU"].to_f./ (row1["DURATION"].to_f)
  results[name][:avg_power_dram] = row1["DRAM"].to_f./ (row1["DURATION"].to_f)
  results[name][:total_power] = results[name][:avg_power_cpu].to_f.+results[name][:avg_power_dram].to_f
  results[name][:energy_request]=results[name][:total_power].to_f./(results[name][:req_per_s].to_f).*1000
  

end


make_horizontal_line = -> { puts '-' * 185 }
make_data_line = lambda do |*args|
  puts "| #{args[0].to_s.ljust(18)} |" \
       "#{args[1].to_s.rjust(8)} |" \
       "#{args[2].to_s.rjust(15)} |" \
       "#{args[3].to_s.rjust(15)} |" \
       "#{args[4].to_s.rjust(15)} |" \
       "#{args[5].to_s.rjust(15)} |" \
       "#{args[6].to_s.rjust(9)} |" \
       "#{args[7].to_s.rjust(14)} |" \
       "#{args[8].to_s.rjust(15)} |" \
       "#{args[9].to_s.rjust(16)} |" \
       "#{args[10].to_s.rjust(22)} |" \
end
make_horizontal_line[]
make_data_line['name', 'req/s', 'avg. latency', '90 % in', '95 % in', '99 % in', 'avg. cpu', 'avg. memory',"avg. power cpu","avg. power dram","avg requesets's energy"]
make_horizontal_line[]
results.sort_by { |_k, v| v[:req_per_s] }.reverse_each do |name, result|
  make_data_line[name,
                 result[:req_per_s].round(0),
                 result[:avg_resp_time],
                 result[:_90pct],
                 result[:_95pct],
                 result[:_99pct],
                 result[:avg_cpu].round(2).to_s + '%',
                 result[:avg_mem].round(2).to_s + ' ' + result[:avg_mem_unit],
                 result[:avg_power_cpu].round(3).to_s + 'W',
                 result[:avg_power_dram].round(3).to_s + 'W',
                 result[:energy_request].round(3).to_s + 'mJ'
                 
                ]
end
make_horizontal_line[]
