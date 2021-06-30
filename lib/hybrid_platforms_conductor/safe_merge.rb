module HybridPlatformsConductor

  # Provide an easy way to safe-merge hashes
  module SafeMerge

    # Safe-merge 2 hashes.
    # Safe-merging is done by:
    # * Merging values that are hashes.
    # * Reporting errors when values conflict.
    # When values are conflicting, the initial hash won't modify those conflicting values and will stop the merge.
    #
    # Parameters::
    # * *hash* (Hash): Hash to be modified merging hash_to_merge
    # * *hash_to_merge* (Hash): Hash to be merged into hash
    # Result::
    # * nil or Array<Object>: nil in case of success, or the keys path leading to a conflicting value in case of error
    def safe_merge(hash, hash_to_merge)
      conflicting_path = nil
      hash_to_merge.each do |key, value_to_merge|
        if hash.key?(key)
          if hash[key].is_a?(Hash) && value_to_merge.is_a?(Hash)
            sub_conflicting_path = safe_merge(hash[key], value_to_merge)
            conflicting_path = [key] + sub_conflicting_path unless sub_conflicting_path.nil?
          elsif hash[key] != value_to_merge
            conflicting_path = [key]
          end
        else
          hash[key] = value_to_merge
        end
        break unless conflicting_path.nil?
      end
      conflicting_path
    end

  end

end
