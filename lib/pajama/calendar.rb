module Pajama
  class Calendar
    def self.instance
      @instance ||= self.new
    end

    def workdays_between(a, b)
      (b - a) + 1
    end

    def developer_workdays_between(username, a, b)
      (b - a) + 1
    end

    def date_after_developer_workdays(username, start_date, workdays_count)
    end
  end
end
