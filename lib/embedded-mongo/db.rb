module EmbeddedMongo
  class DB < Mongo::DB
    # mostly verbatim
    def command(selector, opts={})
      check_response = opts.fetch(:check_response, true)
      socket         = opts[:socket]
      raise MongoArgumentError, "command must be given a selector" unless selector.is_a?(Hash) && !selector.empty?
      if selector.keys.length > 1 && RUBY_VERSION < '1.9' && selector.class != BSON::OrderedHash
        raise MongoArgumentError, "DB#command requires an OrderedHash when hash contains multiple keys"
      end

      begin
        result = Cursor.new(system_command_collection,
          :limit => -1, :selector => selector, :socket => socket).next_document
      rescue Mongo::OperationFailure => ex
        raise OperationFailure, "Database command '#{selector.keys.first}' failed: #{ex.message}"
      end

      if result.nil?
        raise Mongo::OperationFailure, "Database command '#{selector.keys.first}' failed: returned null."
      elsif (check_response && !ok?(result))
        raise Mongo::OperationFailure, "Database command '#{selector.keys.first}' failed: #{result.inspect}"
      else
        result
      end
    end

    # verbatim
    def collection(name, opts={})
      if strict? && !collection_names.include?(name)
        raise Mongo::MongoDBError, "Collection #{name} doesn't exist. Currently in strict mode."
      else
        opts[:safe] = opts.fetch(:safe, @safe)
        opts.merge!(:pk => @pk_factory) unless opts[:pk]
        Collection.new(name, self, opts)
      end
    end
    alias_method :[], :collection

    # verbatim
    def collections
      collection_names.map do |name|
        Collection.new(name, self)
      end
    end
  end
end