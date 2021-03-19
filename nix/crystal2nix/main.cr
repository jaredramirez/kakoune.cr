require "json"
require "yaml"

class PrefetchJSON
    include JSON::Serializable

    @[JSON::Field(key: "sha256")]
    property sha256 : String
end

class ShardLock
    include YAML::Serializable
    
    @[YAML::Field(key: "version")]
    property version : Float32
    
    @[YAML::Field(key: "shards")]
    property shards : Hash(String, Shard)
end

class Shard
    include YAML::Serializable

    @[JSON::Field(key: "git")]
    property git : String
    
    @[JSON::Field(key: "version")]
    property version : String?
    
    @[JSON::Field(key: "commit")]
    property commit : String?
    
end

File.open "nix/shard.nix", "w+" do |file|
    print "Generating nix/shard.nix based on shard.lock...\n"
    file.puts %({)
    yaml = ShardLock.from_yaml(File.read("shard.lock"))
    yaml.shards.each do |key, value|
        rev =
            if version = value.version
                _, commit = version.split("+git.commit.")
                commit
            elsif commit =  value.commit
                commit
            else
                raise "Shard must have either a version or a commit"
            end
              
        file.puts %(  #{key} = { url = "#{value.git}"; rev = "#{rev}"; };)
    end
    file.puts %(})
    print "done!"
end
