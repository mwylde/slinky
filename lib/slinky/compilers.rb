module Slinky
  class Compilers
    @compilers = []
    @compilers_by_ext = {}

    class << self
      def register_compiler klass, options
        options[:klass] = klass
        @compilers << options
        options[:outputs].each do |output|
          @compilers_by_ext[output] ||= []
          @compilers_by_ext[output] << options
        end
      end

      def compilers_by_ext
        @compilers_by_ext
      end
    end
  end
end
