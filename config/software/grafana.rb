#
# Copyright:: Copyright (c) 2019 GitLab Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "#{Omnibus::Config.project_root}/lib/gitlab/version"
require "#{Omnibus::Config.project_root}/lib/gitlab/ohai_helper.rb"

name 'grafana'
version = Gitlab::Version.new('grafana', '7.5.5')
default_version version.print(false)

license 'APACHE-2.0'
license_file 'LICENSE'
license_file 'NOTICE.md'

skip_transitive_dependency_licensing true

arch, sha = if OhaiHelper.raspberry_pi?
              %w[armv7 13a5fde5651d75b8ec560b52b6c7eccfda997015077f2a9ff3bbdb2709938def]
            elsif /aarch64/.match?(ohai['kernel']['machine'])
              %w[arm64 cd65cd84c38c7a43afeb0b1895e97a7b4f3203340be2da070a6dee75ead3fdfe]
            else
              %w[amd64 ecf09e49301679f50829c756c446802a124e8981dec0d22dcbfaaa4df81c3fb7]
            end

source url: "https://dl.grafana.com/oss/release/grafana-#{default_version}.linux-#{arch}.tar.gz",
       sha256: sha

relative_path "grafana-#{default_version}"

build do
  # Binaries.
  copy 'bin/grafana-server', "#{install_dir}/embedded/bin/grafana-server"
  copy 'bin/grafana-cli', "#{install_dir}/embedded/bin/grafana-cli"
  # Static assets.
  command "mkdir -p '#{install_dir}/embedded/service/grafana/public'"
  sync 'public/', "#{install_dir}/embedded/service/grafana/public/"
  # Default configuration.
  command "mkdir -p '#{install_dir}/embedded/service/grafana/conf'"
  copy 'conf/defaults.ini', "#{install_dir}/embedded/service/grafana/conf/defaults.ini"
end
