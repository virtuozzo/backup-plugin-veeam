# frozen_string_literal: true

Backups::Plugin.helper do
  DAILY_SCHEDULE_KINDS = [
    HOURS         = 'Hours',
    EVERY_DAY     = 'Everyday',
    SELECTED_DAYS = 'SelectedDays'
  ].freeze

  FIRST = 'First'

  TIME_FORMAT = '%H:%M:%S.0000000%:z'

  def schedule_params(schedule)
    Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
      xml.Job(
        'xmlns' => 'http://www.veeam.com/ent/v1.0',
        'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
      ) do
        xml.Description "Created by OnApp at #{Time.now.utc.strftime('%m/%d/%Y %I:%M %p %Z')}"
        xml.ScheduleConfigured true
        xml.ScheduleEnabled    true
        xml.JobScheduleOptions do
          xml.Standart do
            public_send(schedule.period, xml, schedule)
          end
        end
      end
    end
  end

  def hourly(xml, schedule)
    xml.OptionsPeriodically(Enabled: schedule.enabled) do
      xml.Kind HOURS
      xml.FullPeriod 1
    end
  end

  def daily(xml, schedule)
    xml.OptionsDaily(Enabled: schedule.enabled) do
      xml.Kind EVERY_DAY
      xml.Time format_time(schedule.start_time)
    end
  end

  def weekly(xml, schedule)
    xml.OptionsDaily(Enabled: schedule.enabled) do
      xml.Kind SELECTED_DAYS

      Date::DAYNAMES.values_at(*schedule.days_to_run_on).compact.each do |day|
        xml.Days day
      end

      xml.Time format_time(schedule.start_time)
    end
  end

  def monthly(xml, schedule)
    xml.OptionsMonthly(Enabled: schedule.enabled) do
      xml.Time             format_time(schedule.start_time)
      xml.DayNumberInMonth FIRST
      xml.DayOfWeek        Date::DAYNAMES[schedule.day_to_run_on]

      Date::MONTHNAMES.compact.each do |month|
        xml.Months month
      end
    end
  end

  def yearly(xml, schedule)
    xml.OptionsMonthly(Enabled: schedule.enabled) do
      xml.Time             format_time(schedule.start_time)
      xml.DayNumberInMonth FIRST
      xml.DayOfWeek        Date::DAYNAMES[schedule.day_to_run_on]
      xml.Months           Date::MONTHNAMES[schedule.month_to_run_on]
    end
  end

  def format_time(time)
    time.strftime(TIME_FORMAT)
  end
end
