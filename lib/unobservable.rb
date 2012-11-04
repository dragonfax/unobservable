require 'set'

module Unobservable

  # Unobservable is designed so that it will not interfere with
  # existing classes.  Rather than injecting an instance_events
  # method directly into Module, we have chosen to externalize
  # this logic.
  #
  # In short: instance_events_for produces a list of instance
  #           events for any module regardless of whether or
  #           not that module includes the Unobservable::ModuleSupport
  #           mixin.
  def self.instance_events_for(mod, include_supers = true)
    raise TypeError, "Only modules and classes can have instance_events" unless mod.is_a? Module

    contributors = [mod]
    if include_supers
      contributors += mod.included_modules
      contributors += mod.ancestors[1...-1] if mod.is_a? Class
    end

    retval = Set.new
    
    contributors.each do |c|
      if c.instance_variable_defined? :@unobservable_instance_events
        c.instance_variable_get(:@unobservable_instance_events).each do |e|
          retval.add(e)
        end
      end
    end
    
    return retval.to_a
  end

  module ModuleSupport
    
    # Returns the list of instance events that are associated with the
    # module or class.  If include_supers = true, then the list of events
    # will also include events defined in superclasses and included modules.
    # Otherwise, instance_events will only return the events defined explicitly
    # by this module or class.  By default, include_supers = true .
    def instance_events(include_supers = true)
      if include_supers == false
        @unobservable_instance_events ||= Set.new
        return @unobservable_instance_events.to_a
      else
        return Unobservable.instance_events_for(self, true)
      end
    end


    private
    
    # 
    def attr_event(*names)
      @unobservable_instance_events ||= Set.new
      
      names.each do |n|
        @unobservable_instance_events.add(n.to_sym)
        define_method n do
          return event(n)
        end
      end
      
      return @unobservable_instance_events.to_a
    end
  end



  module ObjectSupport

    def events
      unobservable_events_map.keys
    end
    
    def event(name)
      unobservable_events_map[name]
    end

    private
    def raise_event(name, *args, &block)
      event(name).call(*args, &block)
    end
    
    
    def unobservable_events_map
      @unobservable_events_map ||= initialize_unobservable_events_map(self.class)
    end


    def initialize_unobservable_events_map(clazz)
      retval = {}
      if clazz.respond_to? :instance_events
        clazz.instance_events.each do |e|
          retval[e] = Event.new
        end
      end

      return retval
    end
    
  end
  
  
  # Typically, when you add support for Events to a class, you also want
  # support for the handy attr_event keyword.  So, including this module
  # is equivalent to the following:
  #
  # class MyClass
  #   extend  Unobservable::ModuleSupport  # Get support for the attr_event keyword
  #   include Unobservable::ObjectSupport  # Get support for the instance methods
  # end
  module Support
    include ObjectSupport
    
    def self.included(other_mod)
      other_mod.extend ModuleSupport
    end
  end



  class Event
    attr_reader :handlers

    def initialize
      @handlers = []
    end

    # There are 3 ways for end-users to provide an event handler:
    #
    # 1. They can pass an object that has a #call method
    # 2. They can provide an object and the name of a method to invoke
    # 3. They can pass in a block
    def handler_for(*args, &block)
      if block
        return block
      elsif args.size == 1
        return args[0]
      elsif args.size == 2
        return args[0].method(args[1])
      end

      raise ArgumentError, "Unable to create an event handler using the given arguments"
    end

    # Registers the given event handler so that it will be
    # invoked when the event is raised.
    def register(*args, &block)
      h = handler_for(*args, &block)
      @handlers << h
      return h
    end


    def unregister(*args, &block)
      h = handler_for(*args, &block)
      index = @handlers.index(h)
      if index
        @handlers.slice!(index)
        return h
      else
        return nil
      end
    end


    
    # Pass the specific arguments / block to all of the
    # event handlers.  Return true if there was at least
    # 1 event handler; return false otherwise.
    def call(*args, &block)
      if @handlers.empty?
        return false
      else
        # TODO: Add some form of error-handling
        @handlers.each do |h|
          h.call(*args, &block)
        end

        return true
      end
    end


  end
  


end


