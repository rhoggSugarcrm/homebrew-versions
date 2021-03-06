class Elasticsearch56 < Formula
  desc "Distributed search & analytics engine"
  homepage "https://www.elastic.co/products/elasticsearch"
  url "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-5.6.4.tar.gz"
  sha256 "1098fc776fae8c74e65f8e17cf2ea244c1d07c4e6711340c9bb9f6df56aa45b0"

  bottle :unneeded

  depends_on :java => "1.8+"

  def cluster_name
    "elasticsearch_#{ENV["USER"]}"
  end

  conflicts_with "elasticsearch", :because => "You can only install one version of ElasticSearch"
  conflicts_with "rhoggsugarcrm/versions/elasticsearch14", :because => "You can only install one version of ElasticSearch"
  conflicts_with "rhoggsugarcrm/versions/elasticsaerch17", :because => "You can only install one version of ElasticSearch"
  conflicts_with "rhoggsugarcrm/versions/elasticsearch51", :because => "You can only install one version of ElasticSearch"
  conflicts_with "rhoggsugarcrm/versions/elasticsearch54", :because => "You can only install one version of ElasticSearch"

  def install
    # Remove Windows files
    rm_f Dir["bin/*.bat"]
    rm_f Dir["bin/*.exe"]

    # Install everything else into package directory
    libexec.install "bin", "config", "lib", "modules"

    # Set up Elasticsearch for local development:
    inreplace "#{libexec}/config/elasticsearch.yml" do |s|
      # 1. Give the cluster a unique name
      s.gsub!(/#\s*cluster\.name\: .*/, "cluster.name: #{cluster_name}")

      # 2. Configure paths
      s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/elasticsearch/")
      s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/elasticsearch/")
    end

    inreplace "#{libexec}/bin/elasticsearch.in.sh" do |s|
      # Configure ES_HOME
      s.sub!(%r{#\!/bin/bash\n}, "#!/bin/bash\n\nES_HOME=#{libexec}")
    end

    inreplace "#{libexec}/bin/elasticsearch-plugin" do |s|
      # Add the proper ES_CLASSPATH configuration
      s.sub!(/SCRIPT="\$0"/, %Q(SCRIPT="$0"\nES_CLASSPATH=#{libexec}/lib))
      # Replace paths to use libexec instead of lib
      s.gsub!(%r{\$ES_HOME/lib/}, "$ES_CLASSPATH/")
    end

    # Move config files into etc
    (etc/"elasticsearch").install Dir[libexec/"config/*"]
    (etc/"elasticsearch/scripts").mkdir unless File.exist?(etc/"elasticsearch/scripts")
    (libexec/"config").rmtree

    bin.write_exec_script Dir[libexec/"bin/elasticsearch"]
    bin.write_exec_script Dir[libexec/"bin/elasticsearch-plugin"]
  end

  def post_install
    # Make sure runtime directories exist
    (var/"elasticsearch/#{cluster_name}").mkpath
    (var/"log/elasticsearch").mkpath
    ln_s etc/"elasticsearch", libexec/"config"
    (libexec/"plugins").mkdir
  end

  def caveats
    s = <<-EOS
      Data:    #{var}/elasticsearch/#{cluster_name}/
      Logs:    #{var}/log/elasticsearch/#{cluster_name}.log
      Plugins: #{libexec}/plugins/
      Config:  #{etc}/elasticsearch/
      plugin script: #{libexec}/bin/elasticsearch-plugin
    EOS

    s
  end

  plist_options :manual => "elasticsearch"

  def plist; <<-EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>KeepAlive</key>
          <false/>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{opt_bin}/elasticsearch</string>
          </array>
          <key>EnvironmentVariables</key>
          <dict>
          </dict>
          <key>RunAtLoad</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>#{var}</string>
          <key>StandardErrorPath</key>
          <string>#{var}/log/elasticsearch.log</string>
          <key>StandardOutPath</key>
          <string>#{var}/log/elasticsearch.log</string>
        </dict>
      </plist>
    EOS
  end

  test do
    system "#{libexec}/bin/elasticsearch-plugin", "list"
    pid = "#{testpath}/pid"
    begin
      system "#{bin}/elasticsearch", "-d", "-p", pid, "-Epath.data=#{testpath}/data"
      sleep 10
      system "curl", "-XGET", "localhost:9200/"
    ensure
      Process.kill(9, File.read(pid).to_i)
    end
  end
end
