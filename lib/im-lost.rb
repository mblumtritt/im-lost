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
    # This should be an `IO` device or any other object responding to `#<<`
    # like a Logger.
    #
    # `STDERR` is configured by default.
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
      return @output = value if defined?(value.<<)
      raise(
        NoMethodError,
        "undefined method `<<' for an instance of #{
          Kernel.instance_method(:class).bind(value).call
        }"
      )
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
    #   #     /examples/test.rb:2
    #   #   ! Errno::EEXIST: File exists @ rb_sysopen - /
    #   #     /examples/test.rb:3
    #   #   x RuntimeError: something went wrong!
    #   #     /examples/test.rb:4
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
    # This is enabled by default.
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
    # @example Print current location
    #   ImLost.here
    #
    # @example Print current location when instance variable is empty
    #   ImLost.here(@name.empty?)
    #
    # @example Print current location when instance variable is nil or empty
    #   ImLost.here { @name.nil? || @name.empty? }
    #
    # @overload here
    #   Prints the call location.
    #   @return [true]
    #
    # @overload here(test)
    #   Prints the call location when given argument is truthy.
    #   @param test [Object]
    #   @return [Object] test
    #
    # @overload here
    #   Prints the call location when given block returns a truthy result.
    #   @yield When the block returns a truthy result the location will be print
    #   @yieldreturn [Object] return result
    #
    def here(test = true)
      return test if !test || (block_given? && !(test = yield))
      loc = Kernel.caller_locations(1, 1)[0]
      @output << "* #{loc.path}:#{loc.lineno}\n"
      test
    end

    #
    # Trace objects.
    #
    # The given arguments can be any object instance or module or class.
    #
    # @example Trace method calls of an instance variable for a while
    #   ImLost.trace(@file)
    #   # ...
    #   ImLost.untrace(@file)
    #
    # @example Temporary trace method calls
    #   File.open('test.txt', 'w') do |file|
    #     ImLost.trace(file) do
    #       file << 'hello '
    #       file.puts(:world!)
    #     end
    #   end
    #
    #   # output will look like
    #   #   > IO#<<(?)
    #   #     /examples/test.rb:1
    #   #   > IO#write(*)
    #   #     /examples/test.rb:1
    #   #   > IO#puts(*)
    #   #     /examples/test.rb:2
    #   #   > IO#write(*)
    #   #     /examples/test.rb:2
    #
    # @overload trace(*args)
    #   @param args [[Object]] one or more objects to be traced
    #   @return [Array<Object>] the traced object(s)
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
    # Test if a given object is currently traced.
    #
    # @param arg [Object] object to be tested
    # @return [Boolean] wheter the object is beeing traced
    #
    def traced?(obj) = @trace.key?(obj)

    #
    # Stop tracing objects.
    #
    # @example Trace some objects for some code lines
    #   traced_obj = ImLost.trace(@file, @client)
    #   # ...
    #   ImLost.untrace(*traced_obj)
    #
    # @see trace
    #
    # @param args [[]Object]] one or more objects which should not longer be
    #   traced
    # @return [Array<Object>] the object(s) which are not longer be traced
    # @return [nil] when none of the objects was traced before
    #
    def untrace(*args)
      args = args.filter_map { @trace.delete(_1) }
      args.size < 2 ? args[0] : args
    end

    #
    # Stop tracing any object. When you are really lost and just like to stop
    # tracing of all your objects.
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
    # Inspect internal variables of a given object.
    #
    # @note The dedictaed handling of `Fiber` is platform dependend!
    #
    # @example Inspect current instance variables
    #   @a = 22
    #   b = 20
    #   c = @a + b
    #   ImLost.vars(self)
    #   # => print value of `@a`
    #
    # @example Inspect local variables
    #   @a = 22
    #   b = 20
    #   c = @a + b
    #   ImLost.vars(binding)
    #   # => print values of `b` and 'c'
    #
    # @example Inspect a thread's variables
    #   th = Thread.new { th[:var1] += 20 }
    #   th[:var1] = 22
    #   ImLost.vars(th)
    #   # => print value of `var1`
    #   th.join
    #   ImLost.vars(th)
    #
    # @example Inspect the current fiber's storage
    #   Fiber[:var1] = 22
    #   Fiber[:var2] = 20
    #   Fiber[:var3] = Fiber[:var1] + Fiber[:var2]
    #   ImLost.vars(Fiber.current)
    #
    # When the given object is
    #
    # - a `Binding` it prints the local variables of the binding
    # - a `Thread` it prints the fiber-local and thread variables
    # - the current `Fiber` it prints the fibers' storage
    #
    # Be aware that only the current fiber can be inspected.
    #
    # When the given object can not be inspected it prints an error message.
    #
    # @param object [Object] which instance variables should be print
    # @return [Object] the given object
    #
    def vars(object)
      out = Out.new
      traced = @trace.delete(object)
      return _local_vars(out, object) if Binding === object
      location = Kernel.caller_locations(1, 1)[0]
      out << "* #{location.path}:#{location.lineno}"
      return _thread_vars(out, object) if Thread === object
      return _fiber_vars(out, object) if @fiber_supported && Fiber === object
      return _instance_vars(out, object) if defined?(object.instance_variables)
      out << '  !!! unable to retrieve vars'
      object
    ensure
      @trace[traced] = traced if traced
      out.flush(@output)
    end

    private

    def _can_trace?(arg)
      (id = arg.__id__) != __id__ && id != @output.__id__
    end

    def _trace(arg)
      @trace[arg] = arg if _can_trace?(arg)
      arg
    end

    def _trace_all(args)
      args.each { |arg| @trace[arg] = arg if _can_trace?(arg) }
      args
    end

    def _trace_b(arg)
      return yield(arg) if @trace.key?(arg) || !_can_trace?(arg)
      begin
        @trace[arg] = arg
        yield(arg)
      ensure
        @trace.delete(arg)
      end
    end

    def _trace_all_b(args)
      temp =
        args.filter_map do |arg|
          @trace[arg] = arg if !@trace.key?(arg) && _can_trace?(arg)
        end
      yield(args)
    ensure
      temp.each { @trace.delete(_1) }
    end

    def _local_vars(out, binding)
      out << "* #{binding.source_location.join(':')}"
      out.vars('local variables', binding.local_variables) do |name|
        binding.local_variable_get(name)
      end
      binding
    end

    def _thread_vars(out, thread)
      out << "  #{_thread_identifier(thread)}"
      flv = thread.keys
      out.vars('fiber-local variables', flv) { thread[_1] } unless flv.empty?
      out.vars('thread variables', thread.thread_variables) do |name|
        thread.thread_variable_get(name)
      end
      thread
    end

    def _fiber_vars(out, fiber)
      if Fiber.current == fiber
        storage = fiber.storage || {}
        out.vars('fiber storage', storage.keys) { storage[_1] }
      else
        out << '  !!! given Fiber is not the current Fiber' <<
          "      #{fiber.inspect}"
      end
      fiber
    end

    def _instance_vars(out, object)
      out.vars('instance variables', object.instance_variables) do |n|
        object.instance_variable_get(n)
      end
      object
    end

    def _thread_identifier(thread)
      "#{THREAD_STATE[thread.status] || thread.status} Thread #{
        if defined?(thread.native_thread_id)
          thread.native_thread_id
        else
          thread.__id__
        end
      } #{thread.name}".rstrip
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
  # @example Use an anonymous timer
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

    # @attribute [r] count
    # @return [Integer] the number of registered timers
    def count = ids.size

    # @attribute [r] empty?
    # @return [Boolean] wheter the timer store is empty or not
    def empty? = ids.empty?

    # @attribute [r] ids
    # @return [Array<Integer>] IDs of all registered timers
    def ids = (@ll.keys.keep_if { _1.is_a?(Integer) })

    #
    # Create and register a new named or anonymous timer.
    # It print the ID or name of the created timer and includes the location.
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
    # Delete and unregister timers.
    #
    # @param id_or_names [Array<Integer, #to_s>] the IDs or the names
    # @return [nil]
    #
    def delete(*id_or_names)
      id_or_names.flatten.each do |id|
        if id.is_a?(Integer)
          del = @ll.delete(id)
          @ll.delete(del[0]) if del
        else
          del = @ll.delete(id.to_s)
          @ll.delete(del.__id__) if del
        end
      end
      nil
    end

    #
    # Print the ID or name and the runtime since a timer was created.
    # It includes the location.
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

    #
    # Print the ID or name and the runtime of all active timers.
    # It includes the location.
    #
    # @return [nil]
    #
    def all
      now = self.class.now
      loc = Kernel.caller_locations(1, 1)[0]
      @ll.values.uniq.reverse_each { |name, start| @cb[name, loc, now - start] }
      nil
    end

    # @!visibility private
    def initialize(&block)
      @cb = block
      @ll = {}
    end
  end

  class Out
    def initialize(*lines) = (@lines = lines)
    def <<(str) = @lines << str
    def location(loc) = @lines << "  #{loc.path}:#{loc.lineno}"
    def flush(dev) = dev << (@lines << nil).join("\n")

    def sig(prefix, info, args)
      args = args.join(', ')
      @lines << case info.self
      when Class, Module
        "#{prefix} #{info.self}.#{info.method_id}(#{args})"
      else
        "#{prefix} #{info.defined_class}##{info.method_id}(#{args})"
      end
    end

    def vars(kind, names)
      return @lines << "  <no #{kind} defined>" if names.empty?
      @lines << "  > #{kind}"
      names.sort!.each { @lines << "    #{_1}: #{yield(_1).inspect}" }
    end
  end
  private_constant :Out

  ARG_SIG = { rest: '*', keyrest: '**', block: '&' }.compare_by_identity.freeze
  NO_NAME = { :* => 1, :** => 1, :& => 1 }.compare_by_identity.freeze
  THREAD_STATE = {
    false => 'terminated',
    nil => 'aborted'
  }.compare_by_identity.freeze
  private_constant :ARG_SIG, :NO_NAME, :THREAD_STATE

  @trace = {}.compare_by_identity
  @caller_locations = @exception_locations = true
  @output = STDERR

  @timer = TimerStore.new { |title, location, time| @output << <<~TIMER_MSG }
    T #{title}: #{time ? "#{time} sec." : 'created'}
      #{location.path}:#{location.lineno}
  TIMER_MSG
  TimerStore.private_class_method(:new)

  @trace_calls = [
    TracePoint.new(:c_call) do |tp|
      next if !@trace.key?(tp.self) || tp.path == __FILE__
      out = Out.new
      out.sig('>', tp, tp.parameters.map { ARG_SIG[_1[0]] || '?' })
      out.location(tp) if @caller_locations
      out.flush(@output)
    end,
    TracePoint.new(:call) do |tp|
      next if !@trace.key?(tp.self) || tp.path == __FILE__
      ctx = tp.binding
      out = Out.new
      out.sig(
        '>',
        tp,
        tp.parameters.map do |kind, name|
          next name if NO_NAME.key?(name)
          "#{ARG_SIG[kind]}#{ctx.local_variable_get(name).inspect}"
        end
      )
      out.location(ctx.eval('caller_locations(4,1)')[0]) if @caller_locations
      out.flush(@output)
    end
  ]

  @trace_results = [
    TracePoint.new(:c_return) do |tp|
      next if !@trace.key?(tp.self) || tp.path == __FILE__
      out = Out.new
      out.sig('<', tp, tp.parameters.map { ARG_SIG[_1[0]] || '?' })
      out.location(tp) if @caller_locations
      out << "  = #{tp.return_value.inspect}"
      out.flush(@output)
    end,
    TracePoint.new(:return) do |tp|
      next if !@trace.key?(tp.self) || tp.path == __FILE__
      ctx = tp.binding
      out = Out.new
      out.sig(
        '<',
        tp,
        tp.parameters.map do |kind, name|
          next name if NO_NAME.key?(name)
          "#{ARG_SIG[kind]}#{ctx.local_variable_get(name).inspect}"
        end
      )
      out.location(ctx.eval('caller_locations(4,1)')[0]) if @caller_locations
      out << "  = #{tp.return_value.inspect}"
      out.flush(@output)
    end
  ]

  supported = RUBY_VERSION.to_f < 3.3 ? %i[raise] : %i[raise rescue]
  @trace_exceptions =
    TracePoint.new(*supported) do |tp|
      ex = tp.raised_exception
      mark, parent = tp.event == :rescue ? ['!', ex.cause] : 'x'
      ex = ex.inspect
      out = Out.new("#{mark} #{ex[0] == '#' ? ex[2..-2] : ex}")
      while parent
        ex = parent.inspect
        out << "  [#{ex[0] == '#' ? ex[2..-2] : ex}]"
        parent = parent.cause
      end
      out.location(tp) if @exception_locations
      out.flush(@output)
    end

  @fiber_supported =
    !!(defined?(Fiber.current) && defined?(Fiber.current.storage))

  self.trace_calls = self.trace_results = true
end
