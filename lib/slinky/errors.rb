require 'continuation'

module Slinky
  # Common base class for all Slinky errors
  class SlinkyError < StandardError
    class NoContinuationError < StandardError; end

    attr_accessor :continuation

    # Continue where we left off
    def continue
      raise NoContinuationError unless continuation.respond_to?(:call)
      continuation.call
    end

    def messages
      [message]
    end
    
    # Raises an error with a continuation that allows us to continue
    # with processing as if no error had been thrown
    def self.raise(exception = SlinkyError, string = nil, array = caller)
      if exception.is_a?(String)
        string = exception
        exception = SlinkyError
      end

      callcc do |cc|
        obj = string.nil? ? exception : exception.exception(string)
        obj.set_backtrace(array)
        obj.continuation = cc
        super obj
      end
    end

    # batches all SlinkyErrors thrown in the supplied block and
    # re-raises them at the end of processing wrapped in a MultiError.
    def self.batch_errors
      errors = []
      result = nil
      begin
        result = yield
      rescue SlinkyError => e
        errors << e
        if e.continuation.respond_to?(:call)
          e.continue
        end
      end

      if !errors.empty?
        if errors.size == 1
          raise errors.first
        else
          raise MultiError, errors
        end
      end
      result
    end
  end

  # Raised when a compilation fails for any reason
  class BuildFailedError < SlinkyError; end
  # Raised when a required file is not found.
  class FileNotFoundError < SlinkyError; end
  # Raised when there is a cycle in the dependency graph (i.e., file A
  # requires file B which requires C which requires A)
  class DependencyError < SlinkyError; end
  # Raise when there is a request for a product that doesn't exist
  class NoSuchProductError < SlinkyError; end
  # Raise when there are multiple errors
  class MultiError < SlinkyError
    attr_reader :errors

    def initialize errors
      @errors = errors.map{|e|
        case e
        when MultiError then e.errors
        else e
        end
      }.flatten
    end

    def message
      @errors.map{|e| e.message}.join(", ")
    end

    def messages
      @errors.map{|e| e.message}
    end
  end
end
