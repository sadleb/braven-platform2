# Speed up specs by only compiling Webpacker once since we don't care
# about assests changing while the tests are running.
# Adapted from here: https://github.com/rails/webpacker/issues/2814#issuecomment-1017262038
if Rails.env.test? && Webpacker.config.compile?
  module Webpacker
    module OneTimeCompiler
      def compile
        @compiled ||= super
      end
    end

    Compiler.prepend(OneTimeCompiler)
  end
end
