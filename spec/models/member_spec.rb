require 'spec_helper'

describe Member do
  before(:each) do
    @member = FactoryGirl.create(:full_member)
  end

  it { should respond_to :full_name }
  it { should validate_presence_of(:first_name) }
  it { should validate_presence_of(:last_name) }
  it { should validate_presence_of(:email) }
  it { should validate_presence_of(:member_type) }
  it { should validate_presence_of(:billing_plan) }

  it { should validate_uniqueness_of(:email) }
  it { should validate_uniqueness_of(:rfid)}

  it { should ensure_inclusion_of(:member_type).in_array(['current',
  																											 'former',
  																											 'courtesy key']) }

  it { should ensure_inclusion_of(:billing_plan).in_array(['full',
                                                         'full - no work',
                                                         'affiliate',
                                                         'student',
                                                         'supporter',
                                                         'none']) }

  # it { should ensure_inclusion_of(:key_enabled).in_array([true, false]) }

  describe ".current_billing_period" do
    before(:each) do
      @member.update_attributes(:anniversary_date => Date.new(2012, 2, 15))
    end

    it "should return the current billing period" do
      Timecop.freeze(Date.new(2012, 11, 10))
      expected_period = Date.new(2012,10,15)..Date.new(2012,11,14)
      @member.current_billing_period.should eq(expected_period)
    end

    it "should not be confused by month or year boundaries" do
      Timecop.freeze(Date.new(2013, 1, 10))
      expected_period = Date.new(2012,12,15)..Date.new(2013,1,14)
      @member.current_billing_period.should eq(expected_period)

      Timecop.freeze(Date.new(2013, 1, 16))
      expected_period = Date.new(2013,1,15)..Date.new(2013,2,14)
      @member.current_billing_period.should eq(expected_period)
    end
  end

  describe ".previous_billing_period" do
    before(:each) do
      @member.update_attributes(:anniversary_date => Date.new(2012, 2, 15))
    end

    it "should return the current billing period" do
      Timecop.freeze(Date.new(2012, 11, 10))
      expected_period = Date.new(2012,9,15)..Date.new(2012,10,14)
      @member.previous_billing_period.should eq(expected_period)
    end

    it "should not be confused by month or year boundaries" do
      Timecop.freeze(Date.new(2013, 2, 10))
      expected_period = Date.new(2012,12,15)..Date.new(2013,1,14)
      @member.previous_billing_period.should eq(expected_period)

      Timecop.freeze(Date.new(2013, 2, 16))
      expected_period = Date.new(2013,1,15)..Date.new(2013,2,14)
      @member.previous_billing_period.should eq(expected_period)
    end
  end

  describe ".usage_this_billing_period" do
    before(:each) do
      @member.update_attributes(:anniversary_date => Date.new(2012, 2, 15))
      2.times { FactoryGirl.create(:log_success, 
                                   :access_date => Date.new(2012, 11, 18),
                                   :member => @member)}
      1.upto(3) { |i| FactoryGirl.create(:log_success, 
                                         :access_date => Date.new(2012, 11, 18) + i.day,
                                         :member => @member) }
    end

    it "should count multipla access on 1 day as 1 day's usage" do
      Timecop.freeze(Date.new(2012, 11, 30))
      @member.usage_this_billing_period.should eq(4)
    end

    it "should not be confused by boundary conditions" do
      FactoryGirl.create(:log_success, :access_date => Date.new(2012,11,15), :member => @member)
      FactoryGirl.create(:log_success, :access_date => Date.new(2012,12,14), :member => @member)
      Timecop.freeze(Date.new(2012,12,14))
      @member.usage_this_billing_period.should eq(6)
    end

    it "should not count usage from the previous billing period" do
      FactoryGirl.create(:log_success, :access_date => Date.new(2012,10,14), :member => @member)
      Timecop.freeze(Date.new(2012,11,30))
      @member.usage_this_billing_period.should eq(4)
    end
  end

  describe ".usage_this_month" do
    before(:each) do
      @this_is_now = Timecop.freeze(Date.new(2012, 11, 15))
      2.times { FactoryGirl.create(:log_success, :access_date => @this_is_now, :member => @member)}
      1.upto(3) { |i| FactoryGirl.create(:log_success, 
                                         :access_date => @this_is_now + i.day,
                                         :member => @member) }
    end

    it "should count multiple accesses on 1 day as 1 day's usage" do
      @member.usage_this_month.should eq(4)
    end

    it "should not count usage from last month" do
      FactoryGirl.create(:log_success,
                         :access_date => @this_is_now.prev_month,
                         :member => @member)
      @member.usage_this_month.should eq(4)
    end

    it "should not count usage belonging to another member" do
      @member2 = FactoryGirl.create(:affiliate_member)
      FactoryGirl.create(:log_success,
                         :access_date => @this_is_now,
                         :member => @member2)
      @member.usage_this_month.should eq(4)
      @member2.usage_this_month.should eq(1)
    end
  end

  describe ".check_member_type" do
    it "should set the termination date when a member leaves" do
      expect {
        @member.update_attributes(:member_type => 'former')
      }.to change(@member, :termination_date).from(nil).to(Date.today)
    end

    it "should change billing plan to 'none' when a member leaves" do
      expect {
        @member.update_attributes(:member_type => 'former')
      }.to change(@member, :billing_plan).from(@member.billing_plan).to('none')
    end

    it "should not set the termination date or billing plan otherwise" do
      expect {
        @member.update_attributes(:task => 'some task')
      }.not_to change(@member, :termination_date)

      expect {
        @member.update_attributes(:task => 'some task')
      }.not_to change(@member, :billing_plan)
    end
  end

  describe ".billing_period_begins" do
    it "should return the day of the month a member's billing period begins" do
      @member.anniversary_date = Date.new(2012,5,6)
      @member.billing_period_begins.should include '6'
    end
  end

  describe ".grant_access?" do
    before(:each) do
      @door = FactoryGirl.create(:door)
    end

    scenarios = [{:member_type => 'current', :key_enabled => true, :desired_outcome => true},
                 {:member_type => 'current', :key_enabled => false, :desired_outcome => false},
                 {:member_type => 'former', :key_enabled => true, :desired_outcome => false},
                 {:member_type => 'former', :key_enabled => false, :desired_outcome => false},
                 {:member_type => 'courtesy key', :key_enabled => true, :desired_outcome => true},
                 {:member_type => 'courtesy key', :key_enabled => false, :desired_outcome => false}]

    scenarios.collect do |scenario|
      it "#{scenario[:desired_outcome] ? 'should' : 'should not'} grant access to a 
          #{scenario[:member_type]} member when their key is 
          #{scenario[:key_enabled] ? 'enabled' : 'disabled'}" do
        @member.update_attributes(:member_type => scenario[:member_type], 
                                  :key_enabled => scenario[:key_enabled])
        Member.grant_access?(@member.rfid, @door.address).should scenario[:desired_outcome] ? be_true : be_false
      end
    end

    it "should not grant access to a non-existant member" do
      @member.destroy
      Member.grant_access?(@member.rfid, @door.address).should be_false
    end

    it "should not grant access to a non-existant door" do
      Member.grant_access?(@member.rfid, 'bad door').should be_false
    end

    it "should log successful access attempts" do
      expect {
        Member.grant_access?(@member.rfid, @door.address)
      }.to change(AccessLog, :count).by(1)
    end

    it "should log denials" do
      pending "we need to log denials"
      @member.update_attributes(:member_type => 'former')
      expect {
        Member.grant_access?(@member.rfid, @door.address)
      }.to change(AccessLog, :count).by(1)
    end

    it "should not log unsuccessful access attempts" do
      @member.destroy
      expect {
        Member.grant_access?(@member.rfid, @door.address)
      }.to change(AccessLog, :count).by(0)
    end
  end

end
