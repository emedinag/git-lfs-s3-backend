import Config

config :lfs,
       http_port: 8083,
       enable_server: false,
       region: "us-east-1",
       redis_url: "redis://192.168.64.6:30343",
       dynamo_lock_table: "devops-lfs-lock-tracking"

config :ex_aws,
       region: "us-east-1",
       access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, {:awscli, "default", 30}, :instance_role],
       secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, {:awscli, "default", 30}, :instance_role]
