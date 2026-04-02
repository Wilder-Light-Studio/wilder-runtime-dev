package runtime

#RuntimeConfig: {
  mode: "development" | "debug" | "production"
  transport: "json" | "protobuf"
  logLevel: "trace" | "debug" | "info" | "warn" | "error"
  endpoint: string & != ""
  port: int & >=1 & <=65535
}

runtime: #RuntimeConfig
