require 'chef_helper'

# NOTE: These specs do not verify whether the code actually ran
# Nor whether the resource inside of the recipe was notified correctly.
# At this moment they only verify whether the expected commands are passed
# to the resource block.

RSpec.describe 'gitlab::database-migrations' do
  let(:chef_run) { ChefSpec::SoloRunner.converge('gitlab::default') }

  before do
    allow(Gitlab).to receive(:[]).and_call_original
  end

  context 'when migration should run' do
    before do
      stub_default_not_listening?(false)
    end

    let(:bash_block) { chef_run.bash('migrate gitlab-rails database') }
    let(:migration_block) { chef_run.rails_migration('gitlab-rails') }

    it 'runs the migrations with expected attributes' do
      expect(chef_run).to run_rails_migration('gitlab-rails') do |resource|
        expect(resource.rake_task).to eq('gitlab:db:configure')
        expect(resource.logfile_prefix).to eq('gitlab-rails-db-migrate')
        expect(resource.helper).to be_a(RailsMigrationHelper)
      end
    end

    it 'skips outdated external databases warning by default' do
      expect(migration_block).to notify('ruby_block[check remote PG version]').to(:run)
      expect(chef_run.ruby_block('check remote PG version').should_skip?(:run)).to be_truthy
    end

    context 'using external db' do
      before { stub_gitlab_rb(postgresql: { enable: false }) }

      it 'warns about outdated databases' do
        allow(GitlabRailsEnvHelper).to receive(:db_version).and_return(11)

        expect(migration_block).to notify('ruby_block[check remote PG version]').to(:run)
        expect(chef_run.ruby_block('check remote PG version').should_skip?(:run)).to be_falsey
        expect(LoggingHelper).to receive(:warning).with(/Support for PostgreSQL 11 will be removed/)

        chef_run.ruby_block('check remote PG version').block.call
      end
    end

    it 'runs with the initial_root_password in the environment' do
      stub_gitlab_rb(gitlab_rails: { initial_root_password: '123456789' })

      expect(chef_run).to run_rails_migration('gitlab-rails').with(
        environment: { 'GITLAB_ROOT_PASSWORD' => '123456789' }
      )
    end

    it 'runs with the initial_root_password and initial_shared_runners_registration_token in the environment' do
      stub_gitlab_rb(
        gitlab_rails: { initial_root_password: '123456789', initial_shared_runners_registration_token: '987654321' }
      )

      expect(chef_run).to run_rails_migration('gitlab-rails').with(
        environment: {
          'GITLAB_ROOT_PASSWORD' => '123456789',
          'GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN' => '987654321'
        }
      )
    end

    context 'initial license file' do
      it 'detects license file from /etc/gitlab' do
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with('/etc/gitlab/*.gitlab-license').and_return(%w[/etc/gitlab/company.gitlab-license /etc/gitlab/company2.gitlab-license])

        expect(chef_run).to run_rails_migration('gitlab-rails').with(
          environment: {
            'GITLAB_LICENSE_FILE' => '/etc/gitlab/company.gitlab-license'
          }
        )
      end

      it 'license file specified in gitlab.rb gets priority' do
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with('/etc/gitlab/*.gitlab-license').and_return(%w[/etc/gitlab/company.gitlab-license /etc/gitlab/company2.gitlab-license])

        stub_gitlab_rb(
          gitlab_rails: { initial_license_file: '/mnt/random.gitlab-license' }
        )

        expect(chef_run).to run_rails_migration('gitlab-rails').with(
          environment: {
            'GITLAB_LICENSE_FILE' => '/mnt/random.gitlab-license'
          }
        )
      end

      it 'Does not fail if no license file found in /etc/gitlab' do
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with('/etc/gitlab/*.gitlab-license').and_return([])

        expect(chef_run).to run_rails_migration('gitlab-rails').with(
          environment: {}
        )
      end
    end

    it 'should notify rails cache clear resource' do
      expect(migration_block).to notify(
        'execute[clear the gitlab-rails cache]')
    end
  end

  context 'with auto_migrate off' do
    before { stub_gitlab_rb(gitlab_rails: { auto_migrate: false }) }

    it 'skips running the migrations' do
      expect(chef_run).not_to run_rails_migration('gitlab-rails')
    end
  end
end
