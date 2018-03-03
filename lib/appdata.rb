module Appdata
  def self._hash_proc
    ->hsh,key{
      hsh[key] = {}.tap do |h|
        h.default_proc = _hash_proc()
      end
    }
  end

  def self.config
    @config ||= begin
      hsh = Hash.new
      hsh.default_proc = _hash_proc()
      hsh
    end
  end
end
