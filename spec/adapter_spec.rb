require 'spec_helper'
User.sorcery_config.authentications_class = Authentication

describe User do
  specify { respond_to(:sorcery_adapter) }
  after(:each) { DatabaseCleaner.clean }

  it 'instance respond to :sorcery_adapter' do
    expect(User.new).to respond_to(:sorcery_adapter)
  end

  context '.sorcery_adapter' do
    subject { User.sorcery_adapter }

    describe '.define_field' do
      it 'create getter and setter' do
        expect(User.new).not_to respond_to(:phone)
        expect(User.new).not_to respond_to(:phone=)
        subject.define_field :phone, String
        expect(User.new).to respond_to(:phone)
        expect(User.new).to respond_to(:phone=)
      end
    end

    describe '.find_by_credentials' do
      it 'find user by email' do
        user = User.new(email: 'sasha@alexandrov.me')
        user.save

        expect(subject.find_by_credentials(['sasha@alexandrov.me'])).to eq user
      end

      it 'find user by username' do
        User.sorcery_config.username_attribute_names << :username
        user = User.new(email: 'sasha@alexandrov.me', username: 'sasha')
        user.save

        expect(subject.find_by_credentials(['sasha'])).to eq user
      end

      it 'find user with independent register' do
        User.sorcery_config.downcase_username_before_authenticating = true
        user = User.new(email: 'sasha@alexandrov.me')
        user.save

        expect(subject.find_by_credentials(['SASHA@ALEXANDROV.ME'])).to eq user
      end
    end

    describe '.find_by_oauth_credentials' do
      it 'find user by provider and uid' do
        user = User.new
        user.authentications.build(provider: 'twitter', uid: '42')
        user.save

        expect(subject.find_by_oauth_credentials('twitter', '42')).to eq user
      end

      it 'find nothing when no authentications' do
        user = User.new
        user.authentications.build(provider: 'twitter', uid: '42')
        user.save

        expect(subject.find_by_oauth_credentials('twitter', '77')).to be nil
      end

      it 'find nothing when authentication lost link to user' do
        Authentication.create(provider: 'twitter', uid: '42', user_id: 14)

        expect(subject.find_by_oauth_credentials('twitter', '42')).to be nil
      end
    end

    describe '.find_by_id' do
      it 'find user by id' do
        user = User.create email: 'sasha@alexandrov.me'

        expect(subject.find_by_id(user.id)).to eq user
      end

      it 'find nothing when given wrong id' do
        user = User.create email: 'sasha@alexandrov.me'

        expect(subject.find_by_id(177)).to eq nil
      end
    end

    describe '.find_by_username' do
      it 'find user by username' do
        User.sorcery_config.username_attribute_names << :username
        user = User.new(email: 'sasha@alexandrov.me', username: 'sasha')
        user.save

        expect(subject.find_by_username('sasha')).to eq user
      end
    end

    describe '.get_current_users' do
      let(:kir) { User.create(username: 'kir') }
      let(:sasha) { User.create(username: 'sasha') }

      it 'get active users' do
        now = Time.now.in_time_zone
        kir.set_last_activity_at(now)
        expect(subject.get_current_users).to match_array([kir])
      end

      it 'does not get users after logout' do
        now = Time.now.in_time_zone
        kir.set_last_activity_at(now)
        sasha.set_last_activity_at(now)
        kir.set_last_logout_at(now)
        expect(subject.get_current_users).to match_array([sasha])
      end

      it 'does not get users when active too long ago' do
        User.sorcery_config.activity_timeout = 5
        now = Time.now.in_time_zone - 10
        kir.set_last_activity_at(now)
        expect(subject.get_current_users).to match_array([])
      end
    end

    let (:user) { User.create(email: 'bob@example.com') }

    describe '#update_attributes' do
      it 'update attributes' do
        user.sorcery_adapter.update_attributes username: 'Bob'
        u = User.find(user.id)
        expect(u.username).to eq 'Bob'
      end

      it 'update datetime attributes' do
        now = Time.now
        user.sorcery_adapter.update_attributes register_at: now
        u = User.find(user.id)
        expect(u.register_at.to_i).to eq now.utc.to_i
      end
    end

    describe '#increment' do
      it 'add 1 to given attribute' do
        expect(user.age).to be nil
        user.sorcery_adapter.increment(:age)
        u = User.find(user.id)
        expect(u.age).to eq 1
      end
    end
  end
end
