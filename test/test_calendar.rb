require 'minitest/autorun'
require 'pajama'

describe "Calendar" do
  let(:calendar) { Pajama::Calendar.instance }

  describe "#workdays_between" do
    describe "a single workweek" do
      let(:mon) { Date.new(1981, 3, 30) }
      let(:tue) { Date.new(1981, 3, 31) }
      let(:wed) { Date.new(1981, 4,  1) }
      let(:thu) { Date.new(1981, 4,  2) }
      let(:fri) { Date.new(1981, 4,  3) }

      it "counts days inside a week" do
        calendar.workdays_between(mon, mon).must_equal 1
        calendar.workdays_between(tue, tue).must_equal 1
        calendar.workdays_between(wed, wed).must_equal 1
        calendar.workdays_between(thu, thu).must_equal 1
        calendar.workdays_between(fri, fri).must_equal 1

        calendar.workdays_between(mon, tue).must_equal 2
        calendar.workdays_between(tue, wed).must_equal 2
        calendar.workdays_between(wed, thu).must_equal 2
        calendar.workdays_between(thu, fri).must_equal 2

        calendar.workdays_between(mon, wed).must_equal 3
        calendar.workdays_between(tue, thu).must_equal 3
        calendar.workdays_between(wed, fri).must_equal 3

        calendar.workdays_between(mon, thu).must_equal 4
        calendar.workdays_between(tue, fri).must_equal 4

        calendar.workdays_between(mon, fri).must_equal 5
      end
    end

    describe "a single weekend" do
      let(:fri) { Date.new(1981, 1, 30) }
      let(:sat) { Date.new(1981, 1, 31) }
      let(:sun) { Date.new(1981, 2,  1) }
      let(:mon) { Date.new(1981, 2,  2) }

      it "ignores weekends" do
        calendar.workdays_between(sat, sat).must_equal 0
        calendar.workdays_between(sat, sun).must_equal 0
        calendar.workdays_between(sun, sun).must_equal 0
      end

      it "ignores leading weekends" do
        calendar.workdays_between(sat, mon).must_equal 1
        calendar.workdays_between(sun, mon).must_equal 1
      end

      it "ignores trailing weekends" do
        calendar.workdays_between(fri, sat).must_equal 1
        calendar.workdays_between(fri, sun).must_equal 1
      end

      it "ignores inside weekends" do
        calendar.workdays_between(fri, mon).must_equal 2
      end
    end

    describe "over several weeks" do
      let(:from_date) { Date.new(1981, 2, 1) }
      let(:to_date)   { Date.new(1981, 2, 28) }

      it "ignores weekends" do
        calendar.workdays_between(from_date, to_date).must_equal 20
      end
    end

    it "ignores holidays" do
      mon1 = Date.new(1984, 7, 2)
      fri1 = Date.new(1984, 7, 6)
      fri2 = Date.new(1984, 3, 13)
      calendar.workdays_between(mon1, fri1).must_equal 4
      calendar.workdays_between(mon1, fri2).must_equal 9
    end

    it "ignores vacation" do
      who  = "test_october" # vacation: 1984-10-29 to 1984-11-02
      from = Date.new(1984, 10, 24) # Wednesday
      to   = Date.new(1984, 11,  6) # Tuesday
      calendar.developer_workdays_between(who, from, to).must_equal 5
    end

    it "ignores vacation and holidays" do
      who  = "test_july" # vacation: 1984-07-03 to 1984-07-06
      from = Date.new(1984, 6, 28) # Thursday
      to   = Date.new(1984, 7, 10) # Tuesday
      calendar.developer_workdays_between(who, from, to).must_equal 5
    end
  end
end
