require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'
puts 'doing something ....'

contents = CSV.read(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

puts "Doing Part 1"
# Part 1: Clean phone numbers
template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

filtered_contents = contents.filter_map do |row|
  homephone = row[:homephone].gsub(/[()-.]/, '')
  len = homephone.length
  if len == 10 || (len == 11 && homephone[0] == '1')
    if len == 11
      homephone = homephone[1, 10]
    end
    row[:homephone] = homephone
    row
  else
    false
  end
end

filtered_contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  homephone = row[:homephone]
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end
puts "Done Part 1"

# Part 2 Time targeting
# tabulate HOUR of registration
puts "Doing Part2"
frequency_hour = Hash.new(0)
contents.each do |row|
  reg_date = row[:regdate]
  _, hour_minutes = reg_date.split(" ")

  hr, _ = hour_minutes.split(":").map { |s| s.to_i}
  frequency_hour[hr] += 1
end
puts frequency_hour
max_freq = frequency_hour.values.max
frequency_hour.each { |k,v| puts "#{k} is the peak-registered hour with #{v} count" if v == max_freq}
puts "Done Part 2"

# Part 3 Day of the week targeting
# tabulate WeekDays of registration
puts "Doing Part3"
frequency_weekday = Hash.new(0)
contents.each do |row|
  # 11/12/08 10:47
  reg_date = row[:regdate]
  date, _ = reg_date.split(" ")

  month,day,year = date.split("/").each_with_index.map do |s, i|
    i == 2 ? 2000+s.to_i : s.to_i
  end

  time = Date.new(year,month,day)
  wday = time.strftime("%A")

  frequency_weekday[wday] += 1
end
puts frequency_weekday
max_freq = frequency_weekday.values.max
frequency_weekday.each { |k,v| puts "#{k} is the peak-registered hour with #{v} count" if v == max_freq}
puts "Done part 3"

puts 'Finished'