module DPL
  class Provider
    class CPAN < Provider
      CPAN_UPLOAD_FILE = '~/.pause'

      def self.install_cpan_upload
        shell 'cpanm --quiet --notest CPAN::Uploader'
      end

      install_cpan_upload

      def config
        {          
          "user: #{option(:user)}",
          "password: #{option(:password)}",
        }
      end

      def write_config
        File.open(File.expand_path(CPAN_UPLOAD_FILE), 'w') do |f|
          config.each do |key, val|
            f.puts("#{key} #{val}")
          end
        end
      end

      def check_auth
        write_config
        log "Authenticated as #{option(:user)}"
      end

      def check_app
      end

      def needs_key?
        false
      end

      def push_app
        if File.exists?('Build')
          context.shell "perl Build dist"
        else
          context.shell "make dist"
        end
        context.shell "cpan-upload *.tar.gz"
      end
    end
  end
end
