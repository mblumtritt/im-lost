# frozen_string_literal: true

#
# If you have overlooked something again and don't really understand what your
# code is doing. If you have to maintain this application but can't really find
# your way around and certainly can't track down that stupid error. If you feel
# lost in all that code, here's the gem to help you out!
#
# ImLost helps you by analyzing function calls of objects, informing you about
# exceptions and logging your way through your code. In short, ImLost is your
# debugging helper!
#
module ImLost
  class << self
    #
    # Enables/disables to include code location into traced call information.
    # This is enabled by default.
    #
    # @return [Boolean] whether code location will be included
    #
    attr_reader :caller_locations

    def caller_locations=(value)
      @caller_locations = value ? true : false
    end

    #
    # The output device used to write information.
    # This should be an `IO` device or any other object responding to `#puts`.
    #
    # `$stderr` is configured by default.
    #
    # @example Write to a file
    #   ImLost.output = File.new('./trace', 'w')
    #
    # @example Write temporary into a memory stream
    #   require 'stringio'
    #
    #   original = ImLost.output
    #   begin
    #     ImLost.output = StringIO.new
    #     # ... collect trace information
    #     puts(ImLost.output.string) # or whatever
    #   ensure
    #     ImLost.output = original
    #   end
    #
    # @return [#puts] the output device
    #
    attr_reader :output

    def output=(value)
      return @output = value if value.respond_to?(:puts)
      raise(ArgumentError, "invalid output device - #{value.inspect}")
    end

    #
    # @return [TimerStore] the timer store used to estimate the runtime of
    #   your code
    #
    attr_reader :timer

    #
    # Enables/disables tracing of method calls.
    # This is enabled by default.
    #
    # @attribute [r] trace_calls
    # @return [Boolean] whether method calls will be traced
    #
    def trace_calls = @trace_calls[0].enabled?

    def trace_calls=(value)
      if value
        @trace_calls.each(&:enable) unless trace_calls
      elsif trace_calls
        @trace_calls.each(&:disable)
      end
    end

    #
    # Traces execptions raised within a given block.
    #
    # @example Trace exception and rescue handling
    #   ImLost.trace_exceptions do
    #     File.write('/', 'test')
    #   rescue SystemCallError
    #     raise('something went wrong!')
    #   end
    #
    #   # output will look like
    #   #   x Errno::EEXIST: File exists @ rb_sysopen - /
    #   #   /projects/test.rb:2
    #   #   ! Errno::EEXIST: File exists @ rb_sysopen - /
    #   #   /projects/test.rb:3
    #   #   x RuntimeError: something went wrong!
    #   #   /projects/test.rb:4
    #
    # @param with_locations [Boolean] wheter the locations should be included
    #   into the exception trace information
    # @yieldreturn [Object] return result
    #
    def trace_exceptions(with_locations: true)
      return unless block_given?
      we = @trace_exceptions.enabled?
      el = @exception_locations
      @exception_locations = with_locations
      @trace_exceptions.enable unless we
      yield
    ensure
      @trace_exceptions.disable unless we
      @exception_locations = el
    end

    #
    # Enables/disables tracing of returned valuess of method calls.
    # This is disabled by default.
    #
    # @attribute [r] trace_results
    # @return [Boolean] whether return values will be traced
    #
    def trace_results = @trace_results[0].enabled?

    def trace_results=(value)
      if value
        @trace_results.each(&:enable) unless trace_results
      elsif trace_results
        @trace_results.each(&:disable)
      end
    end

    #
    # Print the call location conditionally.
    #
    # @example simply print location
    #   ImLost.here
    #
    # @example print location when instance variable is empty
    #   ImLost.here(@name.empty?)
    #
    # @example print location when instance variable is nil or empty
    #   ImLost.here { @name.nil? || @name.empty? }
    #
    # @overload here
    #   Prints the caller location.
    #   @return [true]
    #
    # @overload here(test)
    #   Prints the caller location when given argument is truthy.
    #   @param test [Object]
    #   @return [Object] test
    #
    # @overload here
    #   Prints the caller location when given block returns a truthy result.
    #   @yield When the block returns a truthy result the location will be print
    #   @yieldreturn [Object] return result
    #
    def here(test = true)
      return test if !test || (block_given? && !(test = yield))
      loc = Kernel.caller_locations(1, 1)[0]
      @output.puts(": #{loc.path}:#{loc.lineno}")
      test
    end

    #
    # Trace objects.
    #
    # The given arguments can be any object instance or module or class.
    #
    # @example trace method calls of an instance variable for a while
    #   ImLost.trace(@file)
    #   # ...
    #   ImLost.untrace(@file)
    #
    # @example temporary trace method calls
    #   File.open('test.txt', 'w') do |file|
    #     ImLost.trace(file) do
    #       file << 'hello '
    #       file.puts(:world!)
    #     end
    #   end
    #
    #   # output will look like
    #   #   > IO#<<(?)
    #   #     /projects/test.rb:1
    #   #   > IO#write(*)
    #   #     /projects/test.rb:1
    #   #   > IO#puts(*)
    #   #     /projects/test.rb:2
    #   #   > IO#write(*)
    #   #     /projects/test.rb:2
    #
    # @overload trace(*args)
    #   @param args [[Object]] one or more objects to be traced
    #   @return [[Object]] the traced object(s)
    #   Start tracing the given objects.
    #   @see untrace
    #   @see untrace_all!
    #
    # @overload trace(*args)
    #   @param args [[Object]] one or more objects to be traced
    #   @yieldparam args [Object] the traced object(s)
    #   @yieldreturn [Object] return result
    #   Traces the given object(s) inside the block only.
    #   The object(s) will not be traced any longer after the block call.
    #
    def trace(*args, &block)
      return block&.call if args.empty?
      return args.size == 1 ? _trace(args[0]) : _trace_all(args) unless block
      args.size == 1 ? _trace_b(args[0], &block) : _trace_all_b(args, &block)
    end

    #
    # Stop tracing objects.
    #
    # @example trace some objects for some code lines
    #   traced_vars = ImLost.trace(@file, @client)
    #   # ...
    #   ImLost.untrace(*traced_vars)
    #
    # @see trace
    #
    # @param args [[Object]] one or more objects which should not longer be
    #   traced
    # @return [[Object]] the object(s) which are not longer be traced
    # @return [nil] when none of the objects was traced before
    #
    def untrace(*args)
      ret = args.filter_map { @trace.delete(_1.__id__) ? _1 : nil }
      args.size == 1 ? ret[0] : ret
    end

    #
    # Stop tracing any object.
    # (When you are really lost and just like to stop tracing of all your
    #   objects.)
    #
    # @see trace
    #
    # @return [self] itself
    #
    def untrace_all!
      @trace = {}.compare_by_identity
      self
    end

    #
    # Inspect internal variables.
    #
    # @overload vars(binding)
    #   Inspect local variables of given Binding.
    #   @param binding [Binding] which local variables should be print
    #   @return [self] itself
    #
    # @overload vars(object)
    #   Inspect instance variables of given object.
    #   @param object [Object] which instance variables should be print
    #   @return [Object] the given object
    #
    def vars(object)
      traced = @trace.delete(object.__id__)
      return _local_vars(object) if object.is_a?(Binding)
      return unless object.respond_to?(:instance_variables)
      _vars(object, Kernel.caller_locations(1, 1)[0])
    ensure
      @trace[traced] = traced if traced
    end

    private

    def as_sig(prefix, info, args)
      args = args.join(', ')
      case info.self
      when Class, Module
        "#{prefix} #{info.self}.#{info.method_id}(#{args})"
      else
        "#{prefix} #{info.defined_class}##{info.method_id}(#{args})"
      end
    end

    def _trace(arg)
      id = arg.__id__
      @trace[id] = id if __id__ != id && @output.__id__ != id
      arg
    end

    def _trace_all(args)
      args.each do |arg|
        arg = arg.__id__
        @trace[arg] = arg if __id__ != arg && @output.__id__ != arg
      end
      args
    end

    def _trace_b(arg)
      id = arg.__id__
      return yield(arg) if __id__ == id || @output.__id__ == id
      begin
        @trace[id] = id
        yield(arg)
      ensure
        @trace.delete(id) if id
      end
    end

    def _trace_all_b(args)
      ids =
        args.filter_map do |arg|
          arg = arg.__id__
          @trace[arg] = arg if __id__ != arg && @output.__id__ != arg
        end
      yield(args)
    ensure
      ids.each { @trace.delete(_1) }
    end

    def _vars(obj, location)
      @output.puts("= #{location.path}:#{location.lineno}")
      vars = obj.instance_variables
      if vars.empty?
        @output.puts('  <no instance variables defined>')
      else
        @output.puts('  instance variables:')
        vars.sort!.each do |name|
          @output.puts("  #{name}: #{obj.instance_variable_get(name).inspect}")
        end
      end
      obj
    end

    def _local_vars(binding)
      @output.puts("= #{binding.source_location.join(':')}")
      vars = binding.local_variables
      if vars.empty?
        @output.puts('  <no local variables>')
      else
        @output.puts('  local variables:')
        vars.sort!.each do |name|
          @output.puts("  #{name}: #{binding.local_variable_get(name).inspect}")
        end
      end
      self
    end
  end

  #
  # A store to create and register timers you can use to estimate the runtime of
  # some code.
  #
  # All timers are identified by an unique ID or a name.
  #
  # @example Use a named timer
  #   ImLost.timer.create('my_test')
  #
  #   # ...your code here...
  #
  #   ImLost.timer['my_test']
  #   # => prints the timer name, this location and runtime so far
  #
  #   # ...more code here...
  #
  #   ImLost.timer['my_test']
  #   # => prints the timer name, this location and runtime since the timer was created
  #
  #   ImLost.timer.delete('my_test')
  #   # the timer with name 'my_test' is not longer valid now
  #
  #
  # @example Use an anonymous timer (identified by ID)
  #   tmr = ImLost.timer.create
  #
  #   # ...your code here...
  #
  #   ImLost.timer[tmr]
  #   # => prints the timer ID, this location and runtime so far
  #
  #   # ...more code here...
  #
  #   ImLost.timer[tmr]
  #   # => prints the timer ID, this location and runtime since the timer was created
  #
  #   ImLost.timer.delete(tmr)
  #   # the timer with the ID `tmr` is not longer valid now
  #
  # @see ImLost.timer
  #
  class TimerStore
    if defined?(Process::CLOCK_MONOTONIC)
      # @return [Float] current time
      def self.now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    else
      # @return [Float] current time
      def self.now = ::Time.now
    end

    #
    # Create and register a new named or anonymous timer.
    #
    # @param name [#to_s] optional timer name
    # @return [Integer] timer ID
    #
    def create(name = nil)
      timer = []
      @ll[id = timer.__id__] = timer
      name ? @ll[name = name.to_s] = timer : name = id
      @cb[name, Kernel.caller_locations(1, 1)[0]]
      timer << name << self.class.now
      id
    end

    #
    # Delete and unregister a timer.
    #
    # @param id_or_name [Integer, #to_s] the identifier or the name of the timer
    # @return [nil]
    #
    def delete(id_or_name)
      if id_or_name.is_a?(Integer)
        del = @ll.delete(id_or_name)
        @ll.delete(del[0]) if del
      else
        del = @ll.delete(id_or_name.to_s)
        @ll.delete(del.__id__) if del
      end
      nil
    end

    #
    # Print the name or ID, the caller location and the runtime since timer was
    # created.
    #
    # @param id_or_name [Integer, #to_s] the identifier or the name of the timer
    # @return [Integer] timer ID
    # @raise [ArgumentError] when the given id or name is not a registered timer
    #   identifier or name
    #
    def [](id_or_name)
      time = self.class.now
      timer = @ll[id_or_name.is_a?(Integer) ? id_or_name : id_or_name.to_s]
      raise(ArgumentError, "not a timer - #{id_or_name.inspect}") unless timer
      @cb[timer[0], Kernel.caller_locations(1, 1)[0], time - timer[1]]
      timer.__id__
    end

    # @!visibility private
    def initialize(&block)
      @cb = block
      @ll = {}
    end
  end

  ARG_SIG = { rest: '*', keyrest: '**', block: '&' }.compare_by_identity.freeze
  NO_NAME = { :* => 1, :** => 1, :& => 1 }.compare_by_identity.freeze
  private_constant :ARG_SIG, :NO_NAME

  @trace = {}.compare_by_identity
  @caller_locations = true
  @output = $stderr.respond_to?(:puts) ? $stderr : STDERR

  @timer =
    TimerStore.new do |title, location, time|
      @output.puts("T#{'*' unless time} #{title}")
      @output.puts("  #{location.path}:#{location.lineno}") if @caller_locations
      @output.puts("  #{time} sec.") if time
    end
  TimerStore.private_class_method(:new)

  @trace_calls = [
    TracePoint.new(:c_call) do |tp|
      next if !@trace.key?(tp.self.__id__) || tp.path == __FILE__
      @output.puts(as_sig('>', tp, tp.parameters.map { ARG_SIG[_1[0]] || '?' }))
      @output.puts("  #{tp.path}:#{tp.lineno}") if @caller_locations
    end,
    TracePoint.new(:call) do |tp|
      next if !@trace.key?(tp.self.__id__) || tp.path == __FILE__
      ctx = tp.binding
      @output.puts(
        as_sig(
          '>',
          tp,
          tp.parameters.map do |kind, name|
            next name if NO_NAME.key?(name)
            "#{ARG_SIG[kind]}#{ctx.local_variable_get(name).inspect}"
          end
        )
      )
      next unless @caller_locations
      loc = ctx.eval('caller_locations(4,1)')[0]
      @output.puts("  #{loc.path}:#{loc.lineno}")
    end
  ]

  @trace_results = [
    TracePoint.new(:c_return) do |tp|
      next if !@trace.key?(tp.self.__id__) || tp.path == __FILE__
      @output.puts(as_sig('<', tp, tp.parameters.map { ARG_SIG[_1[0]] || '?' }))
      @output.puts("  = #{tp.return_value.inspect}")
    end,
    TracePoint.new(:return) do |tp|
      next if !@trace.key?(tp.self.__id__) || tp.path == __FILE__
      ctx = tp.binding
      @output.puts(
        as_sig(
          '<',
          tp,
          tp.parameters.map do |kind, name|
            next name if NO_NAME.key?(name)
            "#{ARG_SIG[kind]}#{ctx.local_variable_get(name).inspect}"
          end
        )
      )
      @output.puts("  = #{tp.return_value.inspect}")
    end
  ]

  supported = RUBY_VERSION.to_f < 3.3 ? %i[raise] : %i[raise rescue]
  @trace_exceptions =
    TracePoint.new(*supported) do |tp|
      ex = tp.raised_exception.inspect
      @output.puts(
        "#{tp.event == :raise ? 'x' : '!'} #{ex[0] == '#' ? ex[2..-2] : ex}"
      )
      @output.puts("  #{tp.path}:#{tp.lineno}") if @exception_locations
    end

  self.trace_calls = true
end
