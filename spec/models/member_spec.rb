require 'spec_helper'

describe Member do
  let!(:member)   { FactoryGirl.create(:full_member) }

  it { should respond_to :full_name }
  it { should respond_to :last_date_invoiced }
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

  it { should have_many(:access_logs) }
  it { should have_many(:pending_updates) }

  context "counting total, billable, and non-billable usage" do
    let!(:affilate) { FactoryGirl.create(:affiliate_member) }
    let(:free_days)         { Member::AFFILIATE_FREE_DAY_PASSES }
    let(:start_date)        { Date.new(2012,11,1) }
    let(:free_dates)        { (0..(free_days - 1)).map { |n| start_date + n.day } }
    let(:billable_dates)    { (free_days..(free_days + 1)).map { |n| start_date + n.day } }
    let(:non_billable_date) { start_date + (free_days + 2).day }

    before(:each) do
      free_dates.each do |date|
        2.times { FactoryGirl.create( :log_success, 
                            :access_date => date,
                            :member => member ) }
      end        

      2.times { FactoryGirl.create( :log_success,
                          :access_date => non_billable_date,
                          :member => member,
                          :billable => false) }

      FactoryGirl.create( :log_success,
                          :access_date => start_date.prev_month,
                          :member => member)
      FactoryGirl.create( :log_success,
                          :access_date => start_date,
                          :member => affilate)
    end

    context "in this month" do
      before :each do
        Timecop.freeze(start_date + (free_days + 3).day)
      end

      describe ".usage_this_month" do
        it "returns the number of days the user used the facility" do
          expect(member.usage_this_month).to eq(5)
        end
      end

      describe ".non_billable_usage_this_month" do
        it "returns the number of non-billable days used this month" do
          expect(member.non_billable_usage_this_month).to eq(1)
        end
      end

      describe ".billable_usage_this_month" do
        it "returns 0 if there are no billable days this month" do
          expect(member.billable_usage_this_month).to eq(0)
        end

        it "returns the number of billable days this month" do
          billable_dates.each do |date|
            FactoryGirl.create( :log_success, 
                                :access_date => date,
                                :member => member )
          end
          expect(member.billable_usage_this_month).to eq(2)
        end
      end

    end

    context "from last month" do
      before :each do
        Timecop.freeze(start_date.next_month)
      end

      describe ".usage_last_month" do
        it "returns the number of days the user used the facility last month" do
          expect(member.usage_last_month).to eq(5)
        end
      end

      describe ".non_billable_usage_last_month" do
        it "counts non-billable days from last month" do
          expect(member.non_billable_usage_last_month).to eq(1)
        end
      end

      describe ".billable_usage_last_month" do
        it "returns 0 if there are no billable days from last month" do
          expect(member.billable_usage_last_month).to eq(0)
        end

        it "counts billable days from last month" do
          billable_dates.each do |date|
            FactoryGirl.create( :log_success, 
                                :access_date => date,
                                :member => member )
          end
          expect(member.billable_usage_last_month).to eq(2)
        end
      end

    end
  end

  describe ".check_member_type" do
    it "should set the termination date when a member leaves" do
      expect {
        member.update_attributes(:member_type => 'former')
      }.to change(member, :termination_date).from(nil).to(Date.today)
    end

    it "should change billing plan to 'none' when a member leaves" do
      expect {
        member.update_attributes(:member_type => 'former')
      }.to change(member, :billing_plan).from(member.billing_plan).to('none')
    end

    it "should not set the termination date or billing plan otherwise" do
      expect {
        member.update_attributes(:task => 'some task')
      }.not_to change(member, :termination_date)

      expect {
        member.update_attributes(:task => 'some task')
      }.not_to change(member, :billing_plan)
    end
  end

  describe ".send_usage_email" do
    before(:each) do
      Delayed::Worker.delay_jobs = false
    end
    after(:each) do
      Delayed::Worker.delay_jobs = true
    end      
    
    it "should send an email to affiliate members" do
      @affiliate = FactoryGirl.create(:affiliate_member)
      @affiliate.send_usage_email
      last_email.to.should include(@affiliate.email)
    end

    it "should not send an email to a full member" do
      member.send_usage_email
      last_email.should be_nil
    end

    it "should not send more than one email in one day to a member" do
      @affiliate = FactoryGirl.create(:affiliate_member)
      now = Timecop.freeze(Date.today)
      @affiliate.send_usage_email
      @affiliate.reload
      @affiliate.send_usage_email
      all_emails.count.should eq(1)

      Timecop.freeze(now + 1.day)
      @affiliate.send_usage_email
      @affiliate.reload
      @affiliate.send_usage_email
      all_emails.count.should eq(2)
    end

    it "should send a free day pass email if period-to-date usage is <= affilate free day passes" do
      start_date = Timecop.freeze(Date.new(2012,1,1))

      @affiliate = FactoryGirl.create(:affiliate_member)
      Member::AFFILIATE_FREE_DAY_PASSES.times { 
        |n| FactoryGirl.create(:log_success, 
                               :access_date => start_date + n.day,
                               :member => @affiliate)
      }
      
      MemberEmail.should_receive(:free_day_pass_use).with(@affiliate).and_return(double("mailer", :deliver => true))
      @affiliate.send_usage_email
    end

    it "should send a billable day pass email if period-to-date usage is > affilate free day passes" do
      start_date = Timecop.freeze(Date.new(2012,1,1))

      @affiliate = FactoryGirl.create(:affiliate_member)
      (Member::AFFILIATE_FREE_DAY_PASSES + 1).times { 
        |n| FactoryGirl.create(:log_success, 
                               :access_date => start_date + n.day,
                               :member => @affiliate)
      }
      
      MemberEmail.should_receive(:billable_day_pass_use).with(@affiliate).and_return(double("mailer", :deliver => true))
      @affiliate.send_usage_email
    end

  end

  describe ".delay_update" do
    before(:each) do
      Delayed::Worker.delay_jobs = true  # make sure this fucking thing is always on for these examples
      @affiliate = FactoryGirl.create(:affiliate_member)
      Timecop.freeze(Date.new(2012,1,15))  
      @affiliate.delay_update(:member_type, "former")
      @pending = @affiliate.pending_updates.first
    end

    it "should create a pending update object" do
      @pending.should_not be_nil
    end

    it "should create a delayed job object" do
      Delayed::Job.exists?(@pending.delayed_job_id).should be_true
    end

    it "the delayed job should run at the beginning of next month" do
      run_at = @affiliate.last_of_month + 1.day
      Delayed::Job.find(@pending.delayed_job_id).run_at.to_date.should eq(run_at)
    end
  end

  describe ".destroy_pending_updates" do
    before(:each) do
      Delayed::Worker.delay_jobs = true  # make sure this fucking thing is always on for these examples
      @affiliate = FactoryGirl.create(:affiliate_member)
      Timecop.freeze(Date.new(2012,1,15))  
      @affiliate.delay_update(:member_type, "former")
      @pending = @affiliate.pending_updates.first
      @affiliate.destroy_pending_updates
    end

    it "should destroy pending update objects" do
      @affiliate.pending_updates.count.should eq(0)
    end

    it "should delete associated delayed jobs" do
      Delayed::Job.exists?(@pending.delayed_job_id).should be_false
    end
  end
  
  describe ".lookup_type_plan" do
    before(:each) do
      FactoryGirl.create(:full_member)
      FactoryGirl.create(:affiliate_member)
      FactoryGirl.create(:former_member)
    end

    it "should return plan asked for" do
      members = Member.lookup_type_plan("current", "all")
      members.map(&:billing_plan).should include("full", "affiliate")
    end

    it "should return type asked for" do
      member = Member.lookup_type_plan("former", "all").first
      member.member_type.should eq("former")
    end

  end

  describe ".last_day_present" do
    it "should return the last day present" do
      yesterday = Date.today.prev_day
      Timecop.freeze(yesterday)
      FactoryGirl.create(:log_success, :member => member)
      Timecop.return
      FactoryGirl.create(:log_success, :member => member)
      member.last_day_present.should eq(Date.today)
    end
  end

  describe ".needs_invoicing?" do
    before(:each) do
      @start_date = Date.new(2012, 1, 1)
      @affiliate_yes = FactoryGirl.create(:affiliate_member)
      (Member::AFFILIATE_FREE_DAY_PASSES + 2).times { 
        |n| FactoryGirl.create(:log_success, 
                               :access_date => @start_date + n.day,
                               :member => @affiliate_yes)
      }
      @affiliate_no = FactoryGirl.create(:affiliate_member)
      (Member::AFFILIATE_FREE_DAY_PASSES).times { 
        |n| FactoryGirl.create(:log_success, 
                               :access_date => @start_date + n.day,
                               :member => @affiliate_no)
      }
      @former = FactoryGirl.create(:former_member)
      Timecop.freeze(@start_date.next_month)
    end

    it "should say yes only to current affiliate members" do
      member.needs_invoicing?.should be_false
      @affiliate_yes.needs_invoicing?.should be_true
      @former.needs_invoicing?.should be_false
    end

    it "should say yes only to members with excess uasge in the previous billing period" do
      @affiliate_yes.needs_invoicing?.should be_true
      @affiliate_no.needs_invoicing?.should be_false
    end

    it "should say yes only to members where the last_date_invoiced is blank or prior to the start of the current billing period" do
      @affiliate_yes.update_attributes(:last_date_invoiced => "")
      @affiliate_yes.needs_invoicing?.should be_true

      @affiliate_yes.update_attributes(:last_date_invoiced => @affiliate_yes.last_month.first)
      @affiliate_yes.needs_invoicing?.should be_true

      @affiliate_yes.update_attributes(:last_date_invoiced => @affiliate_yes.this_month.first)
      @affiliate_yes.needs_invoicing?.should be_false
    end
  end

  describe ".access_enabled?" do
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
        member.update_attributes(:member_type => scenario[:member_type], 
                                  :key_enabled => scenario[:key_enabled])
        member.access_enabled?.should scenario[:desired_outcome] ? be_true : be_false
      end
    end
  end

  describe ".members_to_invoice" do
    before(:each) do
      start_date = Date.new(2012, 1, 1)
      FactoryGirl.create(:affiliate_member)
      2.times do 
        affiliate = FactoryGirl.create(:affiliate_member)
        (Member::AFFILIATE_FREE_DAY_PASSES + 2).times { 
          |n| FactoryGirl.create(:log_success, 
                                 :access_date => start_date + n.day,
                                 :member => affiliate)
        }
      end
      Timecop.freeze(start_date.next_month)
    end

    it "should return affiliate members with excess day pass usage in the previous billing period" do
      Member.members_to_invoice.count.should eq(2)
    end
  end

  describe ".members_absent" do
    it "should return an array of members absent for a specified number of weeks or more" do
      absent_member_1 = FactoryGirl.create(:full_member)
      absent_member_2 = FactoryGirl.create(:full_member)
      previously = Date.today - 30.day

      Timecop.freeze(previously)
      FactoryGirl.create(:log_success,
                         :member => member)
      FactoryGirl.create(:log_success,
                         :member => absent_member_1)
      FactoryGirl.create(:log_success,
                         :member => absent_member_2)

      Timecop.return
      FactoryGirl.create(:log_success,
                         :member => member)
      
      Member.members_absent(3).should eq([absent_member_1, absent_member_2])
    end

    it "should not return suppoting members" do
      absent_member = FactoryGirl.create(:supporter_member)
      previously = Date.today - 30.day
      Timecop.freeze(previously)
      FactoryGirl.create(:log_success,
                         :member => member)
      FactoryGirl.create(:log_success,
                         :member => absent_member)
      Timecop.return
      Member.members_absent(3).should eq([member])
    end
  end

  describe ".find_by_key" do
    let(:rfid_number)       { "a1b2" }
    let!(:member_with_key)  { FactoryGirl.create(:full_member, rfid: rfid_number) }

    it "should return a member with a given rfid key" do
      Member.find_by_key(rfid_number).should eq(member_with_key)
    end

    it "should return a member with a given rfid key with a case-insensitive serch" do
      Member.find_by_key(rfid_number.upcase).should eq(member_with_key)
    end

    it "should return nil if the key does not belong to any member" do
      Member.find_by_key("non-existent key").should eq(nil)
    end
  end

  describe ".export_to_csv" do 
    before(:each) do
      FactoryGirl.create(:full_member)
      FactoryGirl.create(:affiliate_member)
      FactoryGirl.create(:former_member)
    end

    it "should return a comma-separated string containing member types and plans specified" do
      Member.export_to_csv('current', 'all').should match(/,current/)
      Member.export_to_csv('current', 'all').should match(/,full/)
      Member.export_to_csv('current', 'all').should match(/,affiliate/)
    end
  end

end
